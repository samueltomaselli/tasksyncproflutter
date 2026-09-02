#!/usr/bin/env bash
# Builda o app para Linux Desktop (modo de teste sem Firebase, ver RUNNING_LINUX.md).
#
# Uso:
#   ./scripts/linux-build.sh            # build debug
#   ./scripts/linux-build.sh release    # build release
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

MODE="${1:-debug}"
if [[ "$MODE" != "debug" && "$MODE" != "release" ]]; then
  echo "Uso: $0 [debug|release]" >&2
  exit 1
fi

flutter build linux --"$MODE"

BIN="build/linux/x64/$MODE/bundle/to_do_app"
echo
echo "Build ok: $BIN"
echo "Rodar com: ./scripts/linux-start.sh $MODE"
