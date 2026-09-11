#!/usr/bin/env bash
# v0.1.0 | 2026-09-11T12:34:07Z | Criado com auxílio de ChatGPT.
# Teste local sem banco/JAR IBM; não representa teste de integração Informix.
source "$(dirname -- "${BASH_SOURCE[0]}")/common-v0.1.0.sh"
spldbg_test() {
    bash "$SPLDBG_ROOT/bin/build-v0.1.0.sh"
    "$SPLDBG_JAVA" -cp "$SPLDBG_ROOT/bin/classes" ifx.spldebug.ProtocolTest
    "$SPLDBG_JAVA" -cp "$SPLDBG_ROOT/bin/classes" ifx.spldebug.Main --catalog
}
spldbg_logged test-local spldbg_test
