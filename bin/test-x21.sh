#!/usr/bin/env bash
# ==============================================================================
# Script: test-x21.sh
# Versão: v1.0.2
# Criado em: 2026-09-11 16:51:20 -03:00
# Atualizado em: 2026-09-13 16:22:10 -03:00
# Criado por: Codex (ChatGPT)
# Projeto: ifx.spldebug
# Finalidade: compilar um JAR sintético e validar a coleta estática do x21.sh.
# Modo de uso: bash bin/test-x21.sh
# Ambiente alvo: Linux com Bash, JDK, unzip, tar e utilitários GNU.
# Segurança: usa somente diretório temporário, removido ao final.
# ==============================================================================

set -euo pipefail
ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source "$ROOT_DIR/bin/common-v0.1.1.sh"
TEMP_DIR=""
JAVA_CMD=()
JAR_CMD=()
JAVAC_CMD=()

_cleanup() {
    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then rm -rf -- "$TEMP_DIR"; fi
}

_configure_java_tools() {
    local java_executable java_bin_dir
    if [[ -n ${JAVA_HOME:-} && -x "$JAVA_HOME/bin/java" ]]; then
        java_executable="$JAVA_HOME/bin/java"
    else
        java_executable=$(command -v java 2>/dev/null || true)
    fi
    [[ -n "$java_executable" ]] || { printf 'FAIL COMMAND_NOT_FOUND name=java\n' >&2; return 1; }
    JAVA_CMD=("$java_executable")
    java_bin_dir=$(dirname -- "$(readlink -f "$java_executable")")

    if command -v javac >/dev/null 2>&1; then
        JAVAC_CMD=(javac)
    elif [[ -x "$java_bin_dir/javac" ]]; then
        JAVAC_CMD=("$java_bin_dir/javac")
    elif "${JAVA_CMD[@]}" --list-modules 2>/dev/null | grep -q '^jdk\.compiler@'; then
        JAVAC_CMD=("${JAVA_CMD[@]}" -m jdk.compiler/com.sun.tools.javac.Main)
    else
        printf 'FAIL JAVA_TOOL_NOT_FOUND name=javac\n' >&2
        return 1
    fi

    if command -v jar >/dev/null 2>&1; then
        JAR_CMD=(jar)
    elif [[ -x "$java_bin_dir/jar" ]]; then
        JAR_CMD=("$java_bin_dir/jar")
    elif "${JAVA_CMD[@]}" --list-modules 2>/dev/null | grep -q '^jdk\.jartool@'; then
        JAR_CMD=("${JAVA_CMD[@]}" -m jdk.jartool/sun.tools.jar.Main)
    else
        printf 'FAIL JAVA_TOOL_NOT_FOUND name=jar\n' >&2
        return 1
    fi
}

_main() {
    _configure_java_tools
    TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/ifx-spldebug-test-x21.XXXXXX")
    trap _cleanup EXIT INT TERM
    local ods="$TEMP_DIR/ods-2.2.1.1" source_dir="$TEMP_DIR/source" classes="$TEMP_DIR/classes"
    mkdir -p "$ods/plugins" "$source_dir/com/ibm/debug/spd/internal/core" "$classes"
    cat > "$source_dir/com/ibm/debug/spd/internal/core/RoutineService.java" <<'EOF'
package com.ibm.debug.spd.internal.core;
import java.util.ArrayList;
public final class RoutineService {
    public void getRoutineType(ArrayList values) {
        values.add("12");
        values.add("34");
    }
}
EOF
    mkdir -p "$TEMP_DIR/jar-content"
    cat > "$TEMP_DIR/jar-content/plugin.xml" <<'EOF'
<plugin><extension point="test.routineDebug"><Routine type="5" language="6"/></extension></plugin>
EOF
    "${JAVAC_CMD[@]}" -source 8 -target 8 -d "$classes" "$source_dir/com/ibm/debug/spd/internal/core/RoutineService.java" 2> "$TEMP_DIR/javac.stderr"
    cp -R "$classes/com" "$TEMP_DIR/jar-content/"
    "${JAR_CMD[@]}" cf "$ods/plugins/com.ibm.debug.spd.test.jar" -C "$TEMP_DIR/jar-content" .
    bash "$ROOT_DIR/bin/x21.sh" --ods-root "$ods" --output "$TEMP_DIR/x21" > "$TEMP_DIR/x21.stdout"
    grep -Fxq 'discovery_status=RESOLVED_STATIC_REVIEW' "$TEMP_DIR/x21/x21-summary.txt"
    grep -Fxq 'routine_service_direct_pairs=1:2,3:4' "$TEMP_DIR/x21/x21-summary.txt"
    grep -Fxq 'metadata_routine_pairs=5:6' "$TEMP_DIR/x21/x21-summary.txt"
    grep -Fxq 'psmd.supported.types=1:2,3:4' "$TEMP_DIR/x21/x21-summary.txt"
    [[ -s "$TEMP_DIR/x21-private.tar.gz" ]]
    printf 'PASS X21_SELF_TEST\n'
}

spldbg_logged x21-self-test _main "$@"
