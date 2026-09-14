#!/usr/bin/env bash
# ==============================================================================
# Script: x22.sh
# Versão: v1.0.1
# Criado em: 2026-09-14T18:51:29Z
# Atualizado em: 2026-09-14T18:55:10Z
# Criado por: Codex (ChatGPT)
# Projeto: ifx.spldebug
# Finalidade: localizar implementações de IRoutineService registradas nos
#             metadados Eclipse coletados pelo x21 e derivar SupportedRoutines.
# Uso: bash x22.sh --ods-root DIR --x21-output DIR [--output DIR]
# Segurança: somente leitura; x22-private.tar.gz contém bytecode proprietário e
#            nunca deve ser commitado.
# ==============================================================================

set -euo pipefail

SCRIPT_VERSION="1.0.1"
ODS_ROOT="$PWD/ods-2.2.1.1"
X21_OUTPUT="$PWD/x21"
OUTPUT_DIR="$PWD/x22"
TEMP_DIR=""
JAVA_CMD=()
JAR_CMD=()
JAVAP_CMD=()

_usage() {
    cat <<'EOF'
Uso:
  bash x22.sh --ods-root DIRETORIO --x21-output DIRETORIO [--output DIRETORIO]

Exemplo:
  bash /CAMINHO/DO/REPOSITORIO/bin/x22.sh \
    --ods-root /home/informix/tmp/spl.debug/ods-2.2.1.1 \
    --x21-output /home/informix/tmp/spl.debug/x21 \
    --output /home/informix/tmp/spl.debug/x22
EOF
}

_fail() {
    printf 'FAIL %s\n' "$*" >&2
    exit 1
}

_cleanup() {
    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then rm -rf -- "$TEMP_DIR"; fi
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
            --ods-root) (($# >= 2)) || _fail "MISSING_VALUE option=--ods-root"; ODS_ROOT=$2; shift 2 ;;
            --x21-output) (($# >= 2)) || _fail "MISSING_VALUE option=--x21-output"; X21_OUTPUT=$2; shift 2 ;;
            --output) (($# >= 2)) || _fail "MISSING_VALUE option=--output"; OUTPUT_DIR=$2; shift 2 ;;
            --help|-h) _usage; exit 0 ;;
            *) _usage >&2; _fail "UNKNOWN_ARGUMENT value=$1" ;;
        esac
    done
}

_safe_name() {
    printf '%s' "$1" | tr '/.$' '___' | tr -cd 'A-Za-z0-9_-'
}

_class_from_entry() {
    local value=${1%.class}
    printf '%s' "${value//\//.}"
}

_extract_provider_candidates() {
    local file
    while IFS= read -r -d '' file; do
        grep -Eo '([A-Za-z_][A-Za-z0-9_]*[Cc]lass|class)[[:space:]]*=[[:space:]]*"[^"]+"' "$file" |
            sed -E 's/^[^=]+=[[:space:]]*"([^"]+)"/\1/' || true
        grep -Eo "([A-Za-z_][A-Za-z0-9_]*[Cc]lass|class)[[:space:]]*=[[:space:]]*'[^']+'" "$file" |
            sed -E "s/^[^=]+=[[:space:]]*'([^']+)'/\1/" || true
    done < <(find "$X21_OUTPUT/metadata" -type f -name '*.txt' -print0)
}

_derive_pairs() {
    local file=$1
    awk '
        /getRoutineType\(java\.util\.ArrayList/ { in_method=1; next }
        in_method && /^  (public|protected|private)/ { in_method=0; encoded="" }
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
            } else if (distance > 16) {
                encoded=""
            }
        }
    ' "$file"
}

_main() {
    _parse_arguments "$@"
    for command in awk basename date dirname find grep paste readlink sed sha256sum sort tar tr wc; do
        _require_command "$command"
    done
    _configure_java_tools

    [[ -d "$ODS_ROOT/plugins" ]] || _fail "ODS_PLUGINS_NOT_FOUND path=$ODS_ROOT/plugins"
    [[ -d "$X21_OUTPUT/metadata" ]] || _fail "X21_METADATA_NOT_FOUND path=$X21_OUTPUT/metadata"
    [[ ! -e "$OUTPUT_DIR" ]] || _fail "OUTPUT_ALREADY_EXISTS path=$OUTPUT_DIR"
    [[ ! -e "$OUTPUT_DIR-private.tar.gz" ]] || _fail "ARCHIVE_ALREADY_EXISTS path=$OUTPUT_DIR-private.tar.gz"

    TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/ifx-spldebug-x22.XXXXXX")
    trap _cleanup EXIT INT TERM
    mkdir -p "$OUTPUT_DIR/javap"
    : > "$OUTPUT_DIR/errors.log"
    : > "$OUTPUT_DIR/providers.candidates.txt"
    : > "$OUTPUT_DIR/providers.owners.tsv"
    : > "$OUTPUT_DIR/providers.services.tsv"
    : > "$OUTPUT_DIR/javap.index.tsv"

    _extract_provider_candidates |
        grep -E '^[A-Za-z_][A-Za-z0-9_$]*(\.[A-Za-z_][A-Za-z0-9_$]*)+

    awk '{ value=$0; gsub(/\./,"/",value); print value ".class" }' \
        "$OUTPUT_DIR/providers.candidates.txt" > "$TEMP_DIR/provider.entries"

    find "$ODS_ROOT/plugins" -type f -name '*.jar' -print0 | sort -z > "$TEMP_DIR/jars.list"
    local jarfile jars=0
    while IFS= read -r -d '' jarfile; do
        if ! "${JAR_CMD[@]}" tf "$jarfile" > "$TEMP_DIR/entries" 2>> "$OUTPUT_DIR/errors.log"; then
            printf 'JAR_LIST_FAILED jar=%s\n' "$(basename -- "$jarfile")" >> "$OUTPUT_DIR/errors.log"
            continue
        fi
        grep -Fxf "$TEMP_DIR/provider.entries" "$TEMP_DIR/entries" |
            while IFS= read -r entry; do
                printf '%s\t%s\n' "$jarfile" "$entry"
            done >> "$OUTPUT_DIR/providers.owners.tsv" || true
        ((jars+=1))
        if (( jars % 250 == 0 )); then printf 'PROGRESS jars=%d\n' "$jars"; fi
    done < "$TEMP_DIR/jars.list"
    sort -u "$OUTPUT_DIR/providers.owners.tsv" -o "$OUTPUT_DIR/providers.owners.tsv"

    local serial=0 entry class_name base output
    while IFS=$'\t' read -r jarfile entry; do
        [[ -n "$jarfile" && -n "$entry" ]] || continue
        ((serial+=1))
        class_name=$(_class_from_entry "$entry")
        base="$(printf '%05d' "$serial")-$(_safe_name "$class_name")"
        output="$OUTPUT_DIR/javap/$base.txt"
        {
            printf 'jar=%s\n' "$(basename -- "$jarfile")"
            printf 'jar_sha256=%s\n' "$(sha256sum "$jarfile" | awk '{print $1}')"
            printf 'class=%s\n' "$class_name"
            printf '%s\n' '----- BEGIN JAVAP -p -c -l -s -----'
            "${JAVAP_CMD[@]}" -classpath "$jarfile" -p -c -l -s "$class_name"
        } > "$output" 2>> "$OUTPUT_DIR/errors.log" || {
            printf 'JAVAP_FAILED jar=%s class=%s\n' "$(basename -- "$jarfile")" "$class_name" >> "$OUTPUT_DIR/errors.log"
            continue
        }
        printf '%s\t%s\t%s\n' "$(basename -- "$jarfile")" "$class_name" "javap/$base.txt" >> "$OUTPUT_DIR/javap.index.tsv"
        if grep -q 'getRoutineType(java.util.ArrayList' "$output"; then
            printf '%s\t%s\t%s\n' "$(basename -- "$jarfile")" "$class_name" "javap/$base.txt" >> "$OUTPUT_DIR/providers.services.tsv"
        fi
    done < "$OUTPUT_DIR/providers.owners.tsv"

    : > "$TEMP_DIR/pair-evidence"
    while IFS=
    if [[ -n "$pairs" ]]; then
        status="RESOLVED_STATIC_REVIEW"
    elif [[ -s "$OUTPUT_DIR/providers.services.tsv" ]]; then
        status="PROVIDERS_FOUND_UNRESOLVED"
    elif [[ -s "$OUTPUT_DIR/providers.owners.tsv" ]]; then
        status="CANDIDATE_CLASSES_FOUND_NO_SERVICE"
    else
        status="PROVIDER_CLASSES_NOT_FOUND"
    fi

    {
        printf 'x22_version=%s\n' "$SCRIPT_VERSION"
        printf 'collected_utc=%s\n' "$(date -u +%FT%TZ)"
        printf 'discovery_status=%s\n' "$status"
        printf 'jars_scanned=%s\n' "$jars"
        printf 'metadata_provider_candidates=%s\n' "$(wc -l < "$OUTPUT_DIR/providers.candidates.txt")"
        printf 'provider_class_owners=%s\n' "$(wc -l < "$OUTPUT_DIR/providers.owners.tsv")"
        printf 'routine_service_implementations=%s\n' "$(wc -l < "$OUTPUT_DIR/providers.services.tsv")"
        printf 'routine_service_providers=%s\n' "$providers"
        printf 'routine_service_pairs=%s\n' "$pairs"
        printf 'routine_service_pair_evidence=%s\n' "$evidence"
        printf 'psmd.supported.types=%s\n' "$pairs"
        printf '%s\n' 'review_required=yes'
        printf '%s\n' 'private_archive_must_not_be_committed=yes'
    } > "$OUTPUT_DIR/x22-summary.txt"

    tar -C "$(dirname -- "$OUTPUT_DIR")" -czf "$OUTPUT_DIR-private.tar.gz" "$(basename -- "$OUTPUT_DIR")"
    cat "$OUTPUT_DIR/x22-summary.txt"
    printf 'PRIVATE_ARCHIVE=%s\n' "$OUTPUT_DIR-private.tar.gz"
    printf 'PASS X22_STATIC_COLLECTION\n'
}

_main "$@"
 |
        sort -u > "$OUTPUT_DIR/providers.candidates.txt" || true

    awk '{ value=$0; gsub(/\./,"/",value); print value ".class" }' \
        "$OUTPUT_DIR/providers.candidates.txt" > "$TEMP_DIR/provider.entries"

    find "$ODS_ROOT/plugins" -type f -name '*.jar' -print0 | sort -z > "$TEMP_DIR/jars.list"
    local jarfile jars=0
    while IFS= read -r -d '' jarfile; do
        if ! "${JAR_CMD[@]}" tf "$jarfile" > "$TEMP_DIR/entries" 2>> "$OUTPUT_DIR/errors.log"; then
            printf 'JAR_LIST_FAILED jar=%s\n' "$(basename -- "$jarfile")" >> "$OUTPUT_DIR/errors.log"
            continue
        fi
        grep -Fxf "$TEMP_DIR/provider.entries" "$TEMP_DIR/entries" |
            while IFS= read -r entry; do
                printf '%s\t%s\n' "$jarfile" "$entry"
            done >> "$OUTPUT_DIR/providers.owners.tsv" || true
        ((jars+=1))
        if (( jars % 250 == 0 )); then printf 'PROGRESS jars=%d\n' "$jars"; fi
    done < "$TEMP_DIR/jars.list"
    sort -u "$OUTPUT_DIR/providers.owners.tsv" -o "$OUTPUT_DIR/providers.owners.tsv"

    local serial=0 entry class_name base output
    while IFS=$'\t' read -r jarfile entry; do
        [[ -n "$jarfile" && -n "$entry" ]] || continue
        ((serial+=1))
        class_name=$(_class_from_entry "$entry")
        base="$(printf '%05d' "$serial")-$(_safe_name "$class_name")"
        output="$OUTPUT_DIR/javap/$base.txt"
        {
            printf 'jar=%s\n' "$(basename -- "$jarfile")"
            printf 'jar_sha256=%s\n' "$(sha256sum "$jarfile" | awk '{print $1}')"
            printf 'class=%s\n' "$class_name"
            printf '%s\n' '----- BEGIN JAVAP -p -c -l -s -----'
            "${JAVAP_CMD[@]}" -classpath "$jarfile" -p -c -l -s "$class_name"
        } > "$output" 2>> "$OUTPUT_DIR/errors.log" || {
            printf 'JAVAP_FAILED jar=%s class=%s\n' "$(basename -- "$jarfile")" "$class_name" >> "$OUTPUT_DIR/errors.log"
            continue
        }
        printf '%s\t%s\t%s\n' "$(basename -- "$jarfile")" "$class_name" "javap/$base.txt" >> "$OUTPUT_DIR/javap.index.tsv"
        if grep -q 'getRoutineType(java.util.ArrayList' "$output"; then
            printf '%s\t%s\t%s\n' "$(basename -- "$jarfile")" "$class_name" "javap/$base.txt" >> "$OUTPUT_DIR/providers.services.tsv"
        fi
    done < "$OUTPUT_DIR/providers.owners.tsv"

    : > "$TEMP_DIR/pairs"
    while IFS=$'\t' read -r _ _ relative; do
        [[ -n "$relative" ]] || continue
        _derive_pairs "$OUTPUT_DIR/$relative" >> "$TEMP_DIR/pairs"
    done < "$OUTPUT_DIR/providers.services.tsv"
    awk '!seen[$0]++' "$TEMP_DIR/pairs" > "$TEMP_DIR/pairs.unique"

    local pairs status
    pairs=$(paste -sd, "$TEMP_DIR/pairs.unique")
    if [[ -n "$pairs" ]]; then
        status="RESOLVED_STATIC_REVIEW"
    elif [[ -s "$OUTPUT_DIR/providers.services.tsv" ]]; then
        status="PROVIDERS_FOUND_UNRESOLVED"
    elif [[ -s "$OUTPUT_DIR/providers.owners.tsv" ]]; then
        status="CANDIDATE_CLASSES_FOUND_NO_SERVICE"
    else
        status="PROVIDER_CLASSES_NOT_FOUND"
    fi

    {
        printf 'x22_version=%s\n' "$SCRIPT_VERSION"
        printf 'collected_utc=%s\n' "$(date -u +%FT%TZ)"
        printf 'discovery_status=%s\n' "$status"
        printf 'jars_scanned=%s\n' "$jars"
        printf 'metadata_provider_candidates=%s\n' "$(wc -l < "$OUTPUT_DIR/providers.candidates.txt")"
        printf 'provider_class_owners=%s\n' "$(wc -l < "$OUTPUT_DIR/providers.owners.tsv")"
        printf 'routine_service_implementations=%s\n' "$(wc -l < "$OUTPUT_DIR/providers.services.tsv")"
        printf 'routine_service_pairs=%s\n' "$pairs"
        printf 'psmd.supported.types=%s\n' "$pairs"
        printf '%s\n' 'review_required=yes'
        printf '%s\n' 'private_archive_must_not_be_committed=yes'
    } > "$OUTPUT_DIR/x22-summary.txt"

    tar -C "$(dirname -- "$OUTPUT_DIR")" -czf "$OUTPUT_DIR-private.tar.gz" "$(basename -- "$OUTPUT_DIR")"
    cat "$OUTPUT_DIR/x22-summary.txt"
    printf 'PRIVATE_ARCHIVE=%s\n' "$OUTPUT_DIR-private.tar.gz"
    printf 'PASS X22_STATIC_COLLECTION\n'
}

_main "$@"
\t' read -r provider_jar provider_class relative; do
        [[ -n "$relative" ]] || continue
        while IFS= read -r pair; do
            [[ -n "$pair" ]] || continue
            printf '%s|%s|%s\n' "$provider_jar" "$provider_class" "$pair" >> "$TEMP_DIR/pair-evidence"
        done < <(_derive_pairs "$OUTPUT_DIR/$relative")
    done < "$OUTPUT_DIR/providers.services.tsv"
    awk -F '|' '!seen[$3]++ { print $3 }' "$TEMP_DIR/pair-evidence" > "$TEMP_DIR/pairs.unique"

    local pairs providers evidence status
    pairs=$(paste -sd, "$TEMP_DIR/pairs.unique")
    providers=$(awk -F '\t' '{ print $1 "|" $2 }' "$OUTPUT_DIR/providers.services.tsv" | paste -sd,)
    evidence=$(paste -sd, "$TEMP_DIR/pair-evidence")
    if [[ -n "$pairs" ]]; then
        status="RESOLVED_STATIC_REVIEW"
    elif [[ -s "$OUTPUT_DIR/providers.services.tsv" ]]; then
        status="PROVIDERS_FOUND_UNRESOLVED"
    elif [[ -s "$OUTPUT_DIR/providers.owners.tsv" ]]; then
        status="CANDIDATE_CLASSES_FOUND_NO_SERVICE"
    else
        status="PROVIDER_CLASSES_NOT_FOUND"
    fi

    {
        printf 'x22_version=%s\n' "$SCRIPT_VERSION"
        printf 'collected_utc=%s\n' "$(date -u +%FT%TZ)"
        printf 'discovery_status=%s\n' "$status"
        printf 'jars_scanned=%s\n' "$jars"
        printf 'metadata_provider_candidates=%s\n' "$(wc -l < "$OUTPUT_DIR/providers.candidates.txt")"
        printf 'provider_class_owners=%s\n' "$(wc -l < "$OUTPUT_DIR/providers.owners.tsv")"
        printf 'routine_service_implementations=%s\n' "$(wc -l < "$OUTPUT_DIR/providers.services.tsv")"
        printf 'routine_service_pairs=%s\n' "$pairs"
        printf 'psmd.supported.types=%s\n' "$pairs"
        printf '%s\n' 'review_required=yes'
        printf '%s\n' 'private_archive_must_not_be_committed=yes'
    } > "$OUTPUT_DIR/x22-summary.txt"

    tar -C "$(dirname -- "$OUTPUT_DIR")" -czf "$OUTPUT_DIR-private.tar.gz" "$(basename -- "$OUTPUT_DIR")"
    cat "$OUTPUT_DIR/x22-summary.txt"
    printf 'PRIVATE_ARCHIVE=%s\n' "$OUTPUT_DIR-private.tar.gz"
    printf 'PASS X22_STATIC_COLLECTION\n'
}

_main "$@"
 |
        sort -u > "$OUTPUT_DIR/providers.candidates.txt" || true

    awk '{ value=$0; gsub(/\./,"/",value); print value ".class" }' \
        "$OUTPUT_DIR/providers.candidates.txt" > "$TEMP_DIR/provider.entries"

    find "$ODS_ROOT/plugins" -type f -name '*.jar' -print0 | sort -z > "$TEMP_DIR/jars.list"
    local jarfile jars=0
    while IFS= read -r -d '' jarfile; do
        if ! "${JAR_CMD[@]}" tf "$jarfile" > "$TEMP_DIR/entries" 2>> "$OUTPUT_DIR/errors.log"; then
            printf 'JAR_LIST_FAILED jar=%s\n' "$(basename -- "$jarfile")" >> "$OUTPUT_DIR/errors.log"
            continue
        fi
        grep -Fxf "$TEMP_DIR/provider.entries" "$TEMP_DIR/entries" |
            while IFS= read -r entry; do
                printf '%s\t%s\n' "$jarfile" "$entry"
            done >> "$OUTPUT_DIR/providers.owners.tsv" || true
        ((jars+=1))
        if (( jars % 250 == 0 )); then printf 'PROGRESS jars=%d\n' "$jars"; fi
    done < "$TEMP_DIR/jars.list"
    sort -u "$OUTPUT_DIR/providers.owners.tsv" -o "$OUTPUT_DIR/providers.owners.tsv"

    local serial=0 entry class_name base output
    while IFS=$'\t' read -r jarfile entry; do
        [[ -n "$jarfile" && -n "$entry" ]] || continue
        ((serial+=1))
        class_name=$(_class_from_entry "$entry")
        base="$(printf '%05d' "$serial")-$(_safe_name "$class_name")"
        output="$OUTPUT_DIR/javap/$base.txt"
        {
            printf 'jar=%s\n' "$(basename -- "$jarfile")"
            printf 'jar_sha256=%s\n' "$(sha256sum "$jarfile" | awk '{print $1}')"
            printf 'class=%s\n' "$class_name"
            printf '%s\n' '----- BEGIN JAVAP -p -c -l -s -----'
            "${JAVAP_CMD[@]}" -classpath "$jarfile" -p -c -l -s "$class_name"
        } > "$output" 2>> "$OUTPUT_DIR/errors.log" || {
            printf 'JAVAP_FAILED jar=%s class=%s\n' "$(basename -- "$jarfile")" "$class_name" >> "$OUTPUT_DIR/errors.log"
            continue
        }
        printf '%s\t%s\t%s\n' "$(basename -- "$jarfile")" "$class_name" "javap/$base.txt" >> "$OUTPUT_DIR/javap.index.tsv"
        if grep -q 'getRoutineType(java.util.ArrayList' "$output"; then
            printf '%s\t%s\t%s\n' "$(basename -- "$jarfile")" "$class_name" "javap/$base.txt" >> "$OUTPUT_DIR/providers.services.tsv"
        fi
    done < "$OUTPUT_DIR/providers.owners.tsv"

    : > "$TEMP_DIR/pairs"
    while IFS=$'\t' read -r _ _ relative; do
        [[ -n "$relative" ]] || continue
        _derive_pairs "$OUTPUT_DIR/$relative" >> "$TEMP_DIR/pairs"
    done < "$OUTPUT_DIR/providers.services.tsv"
    awk '!seen[$0]++' "$TEMP_DIR/pairs" > "$TEMP_DIR/pairs.unique"

    local pairs status
    pairs=$(paste -sd, "$TEMP_DIR/pairs.unique")
    if [[ -n "$pairs" ]]; then
        status="RESOLVED_STATIC_REVIEW"
    elif [[ -s "$OUTPUT_DIR/providers.services.tsv" ]]; then
        status="PROVIDERS_FOUND_UNRESOLVED"
    elif [[ -s "$OUTPUT_DIR/providers.owners.tsv" ]]; then
        status="CANDIDATE_CLASSES_FOUND_NO_SERVICE"
    else
        status="PROVIDER_CLASSES_NOT_FOUND"
    fi

    {
        printf 'x22_version=%s\n' "$SCRIPT_VERSION"
        printf 'collected_utc=%s\n' "$(date -u +%FT%TZ)"
        printf 'discovery_status=%s\n' "$status"
        printf 'jars_scanned=%s\n' "$jars"
        printf 'metadata_provider_candidates=%s\n' "$(wc -l < "$OUTPUT_DIR/providers.candidates.txt")"
        printf 'provider_class_owners=%s\n' "$(wc -l < "$OUTPUT_DIR/providers.owners.tsv")"
        printf 'routine_service_implementations=%s\n' "$(wc -l < "$OUTPUT_DIR/providers.services.tsv")"
        printf 'routine_service_pairs=%s\n' "$pairs"
        printf 'psmd.supported.types=%s\n' "$pairs"
        printf '%s\n' 'review_required=yes'
        printf '%s\n' 'private_archive_must_not_be_committed=yes'
    } > "$OUTPUT_DIR/x22-summary.txt"

    tar -C "$(dirname -- "$OUTPUT_DIR")" -czf "$OUTPUT_DIR-private.tar.gz" "$(basename -- "$OUTPUT_DIR")"
    cat "$OUTPUT_DIR/x22-summary.txt"
    printf 'PRIVATE_ARCHIVE=%s\n' "$OUTPUT_DIR-private.tar.gz"
    printf 'PASS X22_STATIC_COLLECTION\n'
}

_main "$@"
