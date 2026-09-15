#!/usr/bin/env bash
# v0.1.2 | 2026-09-15T19:03:14Z | Atualizado com auxílio de ChatGPT.
# Executa console/POC e recompila automaticamente quando os fontes mudarem.
source "$(dirname -- "${BASH_SOURCE[0]}")/common-v0.1.1.sh"
spldbg_run() {
    local fingerprint_file="$SPLDBG_ROOT/bin/classes/.source-sha256"
    local expected actual=""
    expected=$(spldbg_source_fingerprint)
    if [[ -f $fingerprint_file ]]; then actual=$(<"$fingerprint_file"); fi
    if [[ $actual != "$expected" || ! -f $SPLDBG_ROOT/bin/classes/ifx/spldebug/Main.class ]]; then
        echo "BUILD_REQUIRED source_fingerprint_changed=yes"
        bash "$SPLDBG_ROOT/bin/build-v0.1.1.sh"
    fi
    local cp="$SPLDBG_ROOT/bin/classes"
    if [[ ${1:-} == --run ]]; then
        if [[ -z ${JCC_JAR:-} || ! -f $JCC_JAR ]]; then echo "FAIL JCC_JAR_REQUIRED"; return 2; fi
        cp="$cp:$JCC_JAR"
        if [[ -z ${SPLDBG_PASSWORD+x} ]]; then
            read -r -s -p 'Senha Informix: ' SPLDBG_PASSWORD </dev/tty
            echo >/dev/tty
            export SPLDBG_PASSWORD
        fi
    fi
    "$SPLDBG_JAVA" -cp "$cp" ifx.spldebug.Main "$@"
}
spldbg_logged run spldbg_run "$@"
