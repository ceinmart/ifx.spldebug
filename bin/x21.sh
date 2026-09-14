#!/usr/bin/env bash
# ==============================================================================
# Script: x21.sh
# Versão: v1.0.1
# Criado em: 2026-09-11 16:51:20 -03:00
# Atualizado em: 2026-09-13 16:22:10 -03:00
# Criado por: Codex (ChatGPT)
# Projeto: ifx.spldebug
# Finalidade: localizar nos JARs do ODS a origem de SupportedRoutines e coletar
#             RoutineService, classes relacionadas e registros de extensão.
# Modo de uso: bash x21.sh [--ods-root DIRETORIO] [--output DIRETORIO]
# Ambiente alvo: Linux com Bash, JDK, unzip, tar e utilitários GNU.
# Segurança: somente leitura nos JARs; o arquivo *-private.tar.gz não deve ser
#            commitado porque contém bytecode e metadados proprietários.
# ==============================================================================

set -euo pipefail

SCRIPT_VERSION="1.0.1"
DEFAULT_ODS_ROOT="$PWD/ods-2.2.1.1"
DEFAULT_OUTPUT="$PWD/x21"
ROUTINE_SERVICE_ENTRY="com/ibm/debug/spd/internal/core/RoutineService.class"
RELEVANT_METADATA_REGEX='RoutineService|getRoutineType|SupportedRoutines|routine(Debug|Type|Language|Service)|debug[^<]*routine|routine[^<]*debug|Informix[[:space:]]+SPL|com\.ibm\.debug\.spd'
RELEVANT_CLASS_REGEX='(RoutineService|RoutineType|RoutineLanguage|SupportedRoutine|SPL.*Debug|Debug.*SPL)'

ODS_ROOT="$DEFAULT_ODS_ROOT"
OUTPUT_DIR="$DEFAULT_OUTPUT"
TEMP_DIR=""
JAVA_CMD=()
JAR_CMD=()
JAVAP_CMD=()

_usage() {
    cat <<'EOF'
Uso:
  bash x21.sh [--ods-root DIRETORIO] [--output DIRETORIO]

Padrões, quando executado em /home/informix/tmp/spl.debug:
  ODS:    ./ods-2.2.1.1
  saída:  ./x21

Exemplo:
  bash x21.sh --ods-root /home/informix/tmp/spl.debug/ods-2.2.1.1 \
      --output /home/informix/tmp/spl.debug/x21
EOF
}

_fail() {
    printf 'FAIL %s\n' "$*" >&2
    exit 1
}

_cleanup() {
    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
        rm -rf -- "$TEMP_DIR"
    fi
}

_require_command() {
    command -v "$1" >/dev/null 2>&1 || _fail "COMMAND_NOT_FOUND name=$1"
}

_configure_java_tools() {
    local java_executable java_bin_dir
    if [[ -n ${JAVA_HOME:-} && -x "$JAVA_HOME/bin/java" ]]; then
        java_executable="$JAVA_HOME/bin/java"
    else
        java_executable=$(command -v java 2>/dev/null || true)
    fi
    [[ -n "$java_executable" ]] || _fail "COMMAND_NOT_FOUND name=java"
    JAVA_CMD=("$java_executable")
    java_bin_dir=$(dirname -- "$(readlink -f "$java_executable")")

    if command -v jar >/dev/null 2>&1; then
        JAR_CMD=(jar)
    elif [[ -x "$java_bin_dir/jar" ]]; then
        JAR_CMD=("$java_bin_dir/jar")
    elif "${JAVA_CMD[@]}" --list-modules 2>/dev/null | grep -q '^jdk\.jartool@'; then
        JAR_CMD=("${JAVA_CMD[@]}" -m jdk.jartool/sun.tools.jar.Main)
    else
        _fail "JAVA_TOOL_NOT_FOUND name=jar"
    fi

    if command -v javap >/dev/null 2>&1; then
        JAVAP_CMD=(javap)
    elif [[ -x "$java_bin_dir/javap" ]]; then
        JAVAP_CMD=("$java_bin_dir/javap")
    elif "${JAVA_CMD[@]}" --list-modules 2>/dev/null | grep -q '^jdk\.jdeps@'; then
        JAVAP_CMD=("${JAVA_CMD[@]}" -m jdk.jdeps/com.sun.tools.javap.Main)
    else
        _fail "JAVA_TOOL_NOT_FOUND name=javap"
    fi
}

_parse_arguments() {
    while (($#)); do
        case "$1" in
            --ods-root)
                (($# >= 2)) || _fail "MISSING_VALUE option=--ods-root"
                ODS_ROOT=$2
                shift 2
                ;;
            --output)
                (($# >= 2)) || _fail "MISSING_VALUE option=--output"
                OUTPUT_DIR=$2
                shift 2
                ;;
            --help|-h)
                _usage
                exit 0
                ;;
            *)
                _usage >&2
                _fail "UNKNOWN_ARGUMENT value=$1"
                ;;
        esac
    done
}

_safe_file_name() {
    printf '%s' "$1" | tr '/.$' '___' | tr -cd 'A-Za-z0-9_-'
}

_class_name_from_entry() {
    local entry=${1%.class}
    printf '%s' "${entry//\//.}"
}

_jar_hash() {
    sha256sum "$1" | awk '{print $1}'
}

_record_error() {
    printf '%s\n' "$*" >> "$OUTPUT_DIR/errors.log"
}

_save_metadata_if_relevant() {
    local jarfile=$1 entry=$2 serial=$3 content_file=$TEMP_DIR/metadata-current
    if ! unzip -p "$jarfile" "$entry" > "$content_file" 2>/dev/null; then
        _record_error "METADATA_READ_FAILED jar=$(basename -- "$jarfile") entry=$entry"
        return
    fi
    if grep -Eiq "$RELEVANT_METADATA_REGEX" "$content_file"; then
        local target="$OUTPUT_DIR/metadata/$(printf '%05d' "$serial")-$(_safe_file_name "$(basename -- "$jarfile")")-$(_safe_file_name "$entry").txt"
        {
            printf 'jar=%s\n' "$(basename -- "$jarfile")"
            printf 'jar_sha256=%s\n' "$(_jar_hash "$jarfile")"
            printf 'entry=%s\n' "$entry"
            printf '%s\n' '----- BEGIN METADATA -----'
            cat "$content_file"
            printf '\n%s\n' '----- END METADATA -----'
        } > "$target"
        printf '%s\t%s\t%s\n' "$(basename -- "$jarfile")" "$entry" "${target#"$OUTPUT_DIR/"}" >> "$OUTPUT_DIR/metadata.index.tsv"
    fi
}

_run_javap() {
    local jarfile=$1 class_entry=$2 serial=$3
    local class_name output_name base
    class_name=$(_class_name_from_entry "$class_entry")
    base="$(printf '%05d' "$serial")-$(_safe_file_name "$class_name")"
    output_name="$OUTPUT_DIR/javap/$base.txt"
    {
        printf 'jar=%s\n' "$(basename -- "$jarfile")"
        printf 'jar_sha256=%s\n' "$(_jar_hash "$jarfile")"
        printf 'class=%s\n' "$class_name"
        printf '%s\n' '----- BEGIN JAVAP -p -c -l -s -----'
        "${JAVAP_CMD[@]}" -classpath "$jarfile" -p -c -l -s "$class_name"
    } > "$output_name" 2>> "$OUTPUT_DIR/errors.log" || {
        _record_error "JAVAP_BASIC_FAILED jar=$(basename -- "$jarfile") class=$class_name"
        return
    }
    {
        printf 'jar=%s\n' "$(basename -- "$jarfile")"
        printf 'jar_sha256=%s\n' "$(_jar_hash "$jarfile")"
        printf 'class=%s\n' "$class_name"
        printf '%s\n' '----- BEGIN JAVAP -p -v -----'
        "${JAVAP_CMD[@]}" -classpath "$jarfile" -p -v "$class_name"
    } > "$OUTPUT_DIR/javap/$base.verbose.txt" 2>> "$OUTPUT_DIR/errors.log" ||
        _record_error "JAVAP_VERBOSE_FAILED jar=$(basename -- "$jarfile") class=$class_name"
    printf '%s\t%s\t%s\n' "$(basename -- "$jarfile")" "$class_name" "javap/$base.txt" >> "$OUTPUT_DIR/javap.index.tsv"
}

_derive_direct_pairs() {
    local file=$1
    awk '
        /getRoutineType\(java\.util\.ArrayList/ { in_method=1; next }
        in_method && /^  (public|protected|private)/ { exit }
        in_method && /\/\/ String [0-9][0-9]+$/ {
            encoded=$NF
            distance=0
            next
        }
        in_method && encoded != "" {
            distance++
            if (/\/\/ (InterfaceMethod|Method) java\/util\/(ArrayList|List)\.add:/) {
                print substr(encoded,1,1) ":" substr(encoded,2)
                encoded=""
            } else if (distance > 8) {
                encoded=""
            }
        }
    ' "$file" | awk '!seen[$0]++'
}

_derive_metadata_pairs() {
    local file tag type language
    while IFS= read -r -d '' file; do
        while IFS= read -r tag; do
            [[ "$tag" =~ ^\<[[:space:]]*Routine([[:space:]]|\>) ]] || continue
            type=$(sed -nE "s/.*[[:space:]]type[[:space:]]*=[[:space:]]*['\"]([0-9]+)['\"].*/\\1/p" <<< "$tag")
            language=$(sed -nE "s/.*[[:space:]]language[[:space:]]*=[[:space:]]*['\"]([0-9]+)['\"].*/\\1/p" <<< "$tag")
            if [[ -n "$type" && -n "$language" ]]; then printf '%s:%s\n' "$type" "$language"; fi
        done < <(tr '\n' ' ' < "$file" | grep -Eo '<[^>]+>' || true)
    done < <(find "$OUTPUT_DIR/metadata" -type f -name '*.txt' -print0)
}

_write_summary() {
    local direct_file=$TEMP_DIR/direct-pairs metadata_file=$TEMP_DIR/metadata-pairs
    : > "$direct_file"
    : > "$metadata_file"

    local routine_javap
    while IFS=$'\t' read -r _ class relative; do
        if [[ "$class" == "com.ibm.debug.spd.internal.core.RoutineService" ]]; then
            _derive_direct_pairs "$OUTPUT_DIR/$relative" >> "$direct_file"
        fi
    done < "$OUTPUT_DIR/javap.index.tsv"
    awk '!seen[$0]++' "$direct_file" > "$direct_file.unique"
    _derive_metadata_pairs | awk '!seen[$0]++' > "$metadata_file"

    local owner_count class_count metadata_count javap_count direct_pairs metadata_pairs status
    owner_count=$(wc -l < "$OUTPUT_DIR/routine-service.owners.tsv")
    class_count=$(wc -l < "$OUTPUT_DIR/classes.candidates.tsv")
    metadata_count=$(wc -l < "$OUTPUT_DIR/metadata.index.tsv")
    javap_count=$(wc -l < "$OUTPUT_DIR/javap.index.tsv")
    direct_pairs=$(paste -sd, "$direct_file.unique")
    metadata_pairs=$(paste -sd, "$metadata_file")
    if [[ -n "$direct_pairs" ]]; then status="RESOLVED_STATIC_REVIEW"
    elif (( owner_count > 0 )); then status="ROUTINE_SERVICE_FOUND_UNRESOLVED"
    else status="ROUTINE_SERVICE_NOT_FOUND"
    fi

    {
        printf 'x21_version=%s\n' "$SCRIPT_VERSION"
        printf 'collected_utc=%s\n' "$(date -u +%FT%TZ)"
        printf 'discovery_status=%s\n' "$status"
        printf 'jars_scanned=%s\n' "$(wc -l < "$OUTPUT_DIR/jars.tsv")"
        printf 'routine_service_owners=%s\n' "$owner_count"
        printf 'candidate_classes=%s\n' "$class_count"
        printf 'relevant_metadata_entries=%s\n' "$metadata_count"
        printf 'javap_classes=%s\n' "$javap_count"
        printf 'routine_service_direct_pairs=%s\n' "$direct_pairs"
        printf 'metadata_routine_pairs=%s\n' "$metadata_pairs"
        if [[ -n "$direct_pairs" ]]; then
            printf 'psmd.supported.types=%s\n' "$direct_pairs"
            printf '%s\n' 'review_required=yes'
        else
            printf '%s\n' 'psmd.supported.types='
            printf '%s\n' 'review_required=yes'
        fi
        printf '%s\n' 'private_archive_must_not_be_committed=yes'
    } > "$OUTPUT_DIR/x21-summary.txt"
}

_main() {
    _parse_arguments "$@"
    for command in awk basename cat date dirname find grep paste readlink sed sha256sum sort tar tr unzip wc; do
        _require_command "$command"
    done
    _configure_java_tools
    [[ -d "$ODS_ROOT/plugins" ]] || _fail "ODS_PLUGINS_NOT_FOUND path=$ODS_ROOT/plugins"
    [[ ! -e "$OUTPUT_DIR" ]] || _fail "OUTPUT_ALREADY_EXISTS path=$OUTPUT_DIR"
    [[ ! -e "$OUTPUT_DIR-private.tar.gz" ]] || _fail "ARCHIVE_ALREADY_EXISTS path=$OUTPUT_DIR-private.tar.gz"

    TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/ifx-spldebug-x21.XXXXXX")
    trap _cleanup EXIT INT TERM
    mkdir -p "$OUTPUT_DIR/javap" "$OUTPUT_DIR/metadata"
    : > "$OUTPUT_DIR/classes.candidates.tsv"
    : > "$OUTPUT_DIR/errors.log"
    : > "$OUTPUT_DIR/jars.tsv"
    : > "$OUTPUT_DIR/javap.index.tsv"
    : > "$OUTPUT_DIR/metadata.index.tsv"
    : > "$OUTPUT_DIR/routine-service.owners.tsv"

    find "$ODS_ROOT/plugins" -type f -name '*.jar' -print0 | sort -z > "$TEMP_DIR/jars.list"
    [[ -s "$TEMP_DIR/jars.list" ]] || _fail "NO_JARS_FOUND path=$ODS_ROOT/plugins"

    local jarfile entry_count=0 metadata_serial=0
    while IFS= read -r -d '' jarfile; do
        if ! "${JAR_CMD[@]}" tf "$jarfile" > "$TEMP_DIR/entries" 2>> "$OUTPUT_DIR/errors.log"; then
            _record_error "JAR_LIST_FAILED jar=$(basename -- "$jarfile")"
            continue
        fi
        printf '%s\t%s\n' "$(basename -- "$jarfile")" "$(_jar_hash "$jarfile")" >> "$OUTPUT_DIR/jars.tsv"
        if grep -Fxq "$ROUTINE_SERVICE_ENTRY" "$TEMP_DIR/entries"; then
            printf '%s\t%s\n' "$(basename -- "$jarfile")" "$(_jar_hash "$jarfile")" >> "$OUTPUT_DIR/routine-service.owners.tsv"
        fi
        while IFS= read -r class_entry; do
            [[ -n "$class_entry" ]] || continue
            printf '%s\t%s\n' "$jarfile" "$class_entry" >> "$OUTPUT_DIR/classes.candidates.tsv"
        done < <(grep -E "${RELEVANT_CLASS_REGEX}[^/]*\.class$" "$TEMP_DIR/entries" || true)

        while IFS= read -r metadata_entry; do
            [[ -n "$metadata_entry" ]] || continue
            ((metadata_serial+=1))
            _save_metadata_if_relevant "$jarfile" "$metadata_entry" "$metadata_serial"
        done < <(grep -E '(^|/)(plugin|fragment)\.xml$|(^|/)schema(s)?/.*\.exsd$' "$TEMP_DIR/entries" || true)

        ((entry_count+=1))
        if (( entry_count % 250 == 0 )); then printf 'PROGRESS jars=%d\n' "$entry_count"; fi
    done < "$TEMP_DIR/jars.list"

    sort -u "$OUTPUT_DIR/classes.candidates.tsv" -o "$OUTPUT_DIR/classes.candidates.tsv"
    local class_serial=0 candidate_jar candidate_entry
    while IFS=$'\t' read -r candidate_jar candidate_entry; do
        [[ -n "$candidate_jar" && -n "$candidate_entry" ]] || continue
        ((class_serial+=1))
        _run_javap "$candidate_jar" "$candidate_entry" "$class_serial"
    done < "$OUTPUT_DIR/classes.candidates.tsv"

    _write_summary
    tar -C "$(dirname -- "$OUTPUT_DIR")" -czf "$OUTPUT_DIR-private.tar.gz" "$(basename -- "$OUTPUT_DIR")"
    cat "$OUTPUT_DIR/x21-summary.txt"
    printf 'PRIVATE_ARCHIVE=%s\n' "$OUTPUT_DIR-private.tar.gz"
    printf 'PASS X21_STATIC_COLLECTION\n'
}

_main "$@"
