#!/usr/bin/env bash
# v0.1.0 | 2026-09-11T12:34:07Z | Criado com auxílio de ChatGPT.
# Compila fontes próprios com alvo Java 8, sem baixar ou distribuir dependências.
source "$(dirname -- "${BASH_SOURCE[0]}")/common-v0.1.0.sh"
spldbg_build() {
    cd "$SPLDBG_ROOT"
    "$SPLDBG_JAVA" -version
    mkdir -p bin/classes
    local -a compiler options
    if [[ -n ${JAVA_HOME:-} && -x $JAVA_HOME/bin/javac ]]; then compiler=("$JAVA_HOME/bin/javac")
    elif command -v javac >/dev/null 2>&1; then compiler=(javac)
    else compiler=("$SPLDBG_JAVA" -m jdk.compiler/com.sun.tools.javac.Main)
    fi
    local compiler_version
    compiler_version=$("${compiler[@]}" -version 2>&1)
    echo "$compiler_version"
    if [[ $compiler_version == javac\ 1.8.* ]]; then options=(-source 8 -target 8)
    else options=(--release 8)
    fi
    "${compiler[@]}" "${options[@]}" -encoding UTF-8 -Xlint:all -d bin/classes src/main/java/ifx/spldebug/*.java src/test/java/ifx/spldebug/*.java
    echo "PASS BUILD"
}
spldbg_logged build spldbg_build
