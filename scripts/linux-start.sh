#!/usr/bin/env bash
# Abre o binário já buildado do app Linux Desktop rapidamente, sem passar
# pelo `flutter run` (mais rápido quando você só quer reabrir o app, sem
# recompilar). Builda sozinho na primeira vez ou se o binário não existir.
#
# Uso:
#   ./scripts/linux-start.sh            # debug
#   ./scripts/linux-start.sh release    # release
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

MODE="${1:-debug}"
if [[ "$MODE" != "debug" && "$MODE" != "release" ]]; then
  echo "Uso: $0 [debug|release]" >&2
  exit 1
fi

BIN="build/linux/x64/$MODE/bundle/to_do_app"

if [[ ! -x "$BIN" ]]; then
  echo "Binário não encontrado ($BIN), buildando primeiro..."
  ./scripts/linux-build.sh "$MODE"
fi

exec "$BIN"
