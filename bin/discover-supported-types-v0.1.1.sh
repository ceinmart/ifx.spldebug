#!/usr/bin/env bash
# v0.1.1 | 2026-09-11T19:30:37Z | Criado com auxílio de ChatGPT.
# Extrai apenas type:language de uma captura autorizada do InitializeClient.
source "$(dirname -- "${BASH_SOURCE[0]}")/common-v0.1.1.sh"
spldbg_discover_supported_types() {
    if [[ $# -ne 2 || ( $1 != --raw && $1 != --tshark-hex ) ]]; then
        echo "Uso: bash bin/discover-supported-types-v0.1.1.sh (--raw|--tshark-hex) ARQUIVO"
        return 2
    fi
    if [[ ! -f $2 ]]; then echo "FAIL CAPTURE_FILE_NOT_FOUND"; return 2; fi
    bash "$SPLDBG_ROOT/bin/build-v0.1.1.sh"
    "$SPLDBG_JAVA" -cp "$SPLDBG_ROOT/bin/classes" ifx.spldebug.SupportedTypesDiscovery "$1" "$2"
}
spldbg_logged supported-types-discovery spldbg_discover_supported_types "$@"
