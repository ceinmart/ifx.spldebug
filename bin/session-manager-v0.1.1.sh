#!/usr/bin/env bash
# v0.1.1 | 2026-09-11T19:30:37Z | Criado com auxílio de ChatGPT.
# Inicia manager standalone em primeiro plano. Não encerra outros managers.
source "$(dirname -- "${BASH_SOURCE[0]}")/common-v0.1.1.sh"
spldbg_manager() {
    if [[ -z ${DBGM_JAR:-} || ! -f $DBGM_JAR ]]; then echo "FAIL DBGM_JAR_REQUIRED"; return 2; fi
    local port=${SM_PORT:-4554}
    [[ $port =~ ^[0-9]+$ ]] && (( port>0 && port<65536 )) || { echo "FAIL INVALID_SM_PORT"; return 2; }
    local private_log="$SPLDBG_ROOT/bin/outputs/session-manager-v0.1.1-$(date -u +%Y%m%dT%H%M%SZ)-$$.private.log"
    "$SPLDBG_JAVA" -cp "$DBGM_JAR" com.ibm.db2.psmd.mgr.Daemon -port "$port" -log "$private_log"
}
spldbg_logged session-manager spldbg_manager
