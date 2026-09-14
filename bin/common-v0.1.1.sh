#!/usr/bin/env bash
# v0.1.1 | 2026-09-11T19:30:37Z | Criado com auxílio de ChatGPT.
# Infraestrutura de logs. Nunca registrar ambiente completo, senha ou conteúdo SQL.
set -euo pipefail
SPLDBG_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
SPLDBG_JAVA=${JAVA_HOME:+$JAVA_HOME/bin/}java
spldbg_logged() {
    local mode=$1
    shift
    mkdir -p "$SPLDBG_ROOT/bin/outputs"
    local logfile="$SPLDBG_ROOT/bin/outputs/${mode}-v0.1.1-$(date -u +%Y%m%dT%H%M%SZ)-$$.log"
    local -a result
    set +e
    (
        set -e
        echo "spldbg_version=0.1.1 mode=$mode utc=$(date -u +%FT%TZ)"
        git -C "$SPLDBG_ROOT" rev-parse HEAD 2>/dev/null || true
        if [[ -n $(git -C "$SPLDBG_ROOT" status --porcelain 2>/dev/null) ]]; then echo "worktree_dirty=yes"; else echo "worktree_dirty=no"; fi
        (cd "$SPLDBG_ROOT" && sha256sum src/main/java/ifx/spldebug/*.java src/test/java/ifx/spldebug/*.java)
        "$@"
    ) 2>&1 | tee "$logfile"
    result=("${PIPESTATUS[@]}")
    set -e
    echo "exit_code=${result[0]} log_exit_code=${result[1]}" | tee -a "$logfile"
    echo "Output: $logfile"
    if (( result[0] != 0 )); then return "${result[0]}"; fi
    return "${result[1]}"
}
