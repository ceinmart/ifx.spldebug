#!/usr/bin/env bash
# v0.1.0 | 2026-09-11T12:34:07Z | Criado com auxílio de ChatGPT.
# Executa console/POC; preserva saída e status, exige JCC apenas para --run.
source "$(dirname -- "${BASH_SOURCE[0]}")/common-v0.1.0.sh"
spldbg_run() {
    local cp="$SPLDBG_ROOT/bin/classes"
    if [[ ${1:-} == --run ]]; then
        if [[ -z ${JCC_JAR:-} || ! -f $JCC_JAR ]]; then echo "FAIL JCC_JAR_REQUIRED"; return 2; fi
        cp="$cp:$JCC_JAR"
        # Perguntar antes de tee/redirecionamentos; /dev/tty não registra a senha.
        if [[ -z ${SPLDBG_PASSWORD+x} ]]; then
            read -r -s -p 'Senha Informix: ' SPLDBG_PASSWORD </dev/tty
            echo >/dev/tty
            export SPLDBG_PASSWORD
        fi
    fi
    "$SPLDBG_JAVA" -cp "$cp" ifx.spldebug.Main "$@"
}
spldbg_logged run spldbg_run "$@"
