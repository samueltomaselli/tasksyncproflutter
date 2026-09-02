#!/usr/bin/env bash
# Sobe o emulador Android sem janela própria + scrcpy (janela única, sem o
# bug de foco duplo no Hyprland) + `flutter run` (com hot reload). Ver
# RUNNING_LINUX.md seção 5 para detalhes/troubleshooting.
#
# Pra um fluxo build-então-abrir mais rápido (sem hot reload, sem recompilar
# toda vez), use ./scripts/android-build.sh + ./scripts/android-start.sh.
#
# Uso:
#   ./scripts/android-run.sh                      # usa o AVD padrão
#   AVD_NAME=OutroAvd ./scripts/android-run.sh     # usa outro AVD
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source scripts/_android-common.sh

ensure_emulator
ensure_scrcpy

echo "Rodando flutter (hot reload: r/R, sair: q)..."
flutter run -d "$DEVICE_ID" "$@"
