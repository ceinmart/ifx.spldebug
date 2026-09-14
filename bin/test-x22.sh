#!/usr/bin/env bash
# ==============================================================================
# Script: test-x22.sh
# Versão: v1.0.0
# Criado em: 2026-09-14T18:51:29Z
# Criado por: Codex (ChatGPT)
# Projeto: ifx.spldebug
# Finalidade: validar a descoberta de um IRoutineService registrado em plugin.xml.
# Uso: bash bin/test-x22.sh
# Segurança: usa somente diretório temporário e JAR sintético.
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
    TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/ifx-spldebug-test-x22.XXXXXX")
    trap _cleanup EXIT INT TERM

    local ods="$TEMP_DIR/ods-2.2.1.1"
    local source_dir="$TEMP_DIR/source"
    local classes="$TEMP_DIR/classes"
    local jar_content="$TEMP_DIR/jar-content"
    mkdir -p "$ods/plugins" \
        "$source_dir/com/ibm/debug/spd/internal/core" \
        "$source_dir/com/ibm/debug/spd/internal/services" \
        "$source_dir/com/example" "$classes" "$jar_content"

    cat > "$source_dir/com/ibm/debug/spd/internal/services/IRoutineService.java" <<'EOF'
package com.ibm.debug.spd.internal.services;
import java.util.ArrayList;
public interface IRoutineService {
    void getRoutineType(ArrayList<String> values);
}
EOF

    cat > "$source_dir/com/ibm/debug/spd/internal/services/RoutineServiceExtensionManager.java" <<'EOF'
package com.ibm.debug.spd.internal.services;
import java.util.Collection;
import java.util.Collections;
public final class RoutineServiceExtensionManager {
    private static final RoutineServiceExtensionManager INSTANCE = new RoutineServiceExtensionManager();
    public static RoutineServiceExtensionManager getInstance() { return INSTANCE; }
    public Collection<IRoutineService> getAllServices() { return Collections.emptyList(); }
}
EOF

    cat > "$source_dir/com/ibm/debug/spd/internal/core/RoutineService.java" <<'EOF'
package com.ibm.debug.spd.internal.core;
import java.util.ArrayList;
import com.ibm.debug.spd.internal.services.IRoutineService;
import com.ibm.debug.spd.internal.services.RoutineServiceExtensionManager;
public final class RoutineService {
    public void getRoutineType(ArrayList<String> values) {
        for (IRoutineService service : RoutineServiceExtensionManager.getInstance().getAllServices()) {
            service.getRoutineType(values);
        }
    }
}
EOF

    cat > "$source_dir/com/example/InformixProvider.java" <<'EOF'
package com.example;
import java.util.ArrayList;
import com.ibm.debug.spd.internal.services.IRoutineService;
public final class InformixProvider implements IRoutineService {
    public void getRoutineType(ArrayList<String> values) {
        values.add("12");
        values.add("34");
    }
}
EOF

    cat > "$jar_content/plugin.xml" <<'EOF'
<plugin>
  <extension point="com.ibm.debug.spd.routineService">
    <service class="com.example.InformixProvider"/>
  </extension>
</plugin>
EOF

    find "$source_dir" -type f -name '*.java' -print0 |
        xargs -0 "${JAVAC_CMD[@]}" -source 8 -target 8 -d "$classes" \
        2> "$TEMP_DIR/javac.stderr"
    cp -R "$classes/com" "$jar_content/"
    "${JAR_CMD[@]}" cf "$ods/plugins/com.ibm.debug.spd.test.jar" -C "$jar_content" .

    bash "$ROOT_DIR/bin/x21.sh" --ods-root "$ods" --output "$TEMP_DIR/x21" \
        > "$TEMP_DIR/x21.stdout"
    grep -Fxq 'discovery_status=ROUTINE_SERVICE_FOUND_UNRESOLVED' \
        "$TEMP_DIR/x21/x21-summary.txt"

    bash "$ROOT_DIR/bin/x22.sh" --ods-root "$ods" \
        --x21-output "$TEMP_DIR/x21" --output "$TEMP_DIR/x22" \
        > "$TEMP_DIR/x22.stdout"
    grep -Fxq 'discovery_status=RESOLVED_STATIC_REVIEW' "$TEMP_DIR/x22/x22-summary.txt"
    grep -Fxq 'routine_service_implementations=1' "$TEMP_DIR/x22/x22-summary.txt"
    grep -Fxq 'routine_service_pairs=1:2,3:4' "$TEMP_DIR/x22/x22-summary.txt"
    grep -Fxq 'psmd.supported.types=1:2,3:4' "$TEMP_DIR/x22/x22-summary.txt"
    [[ -s "$TEMP_DIR/x22-private.tar.gz" ]]
    printf 'PASS X22_SELF_TEST\n'
}

spldbg_logged x22-self-test _main "$@"
