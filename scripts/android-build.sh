#!/usr/bin/env bash
# Builda o APK e instala no emulador Android (sobe o emulador sozinho se
# precisar). Não abre o app nem o scrcpy — depois rode
# ./scripts/android-start.sh pra abrir.
#
# Uso:
#   ./scripts/android-build.sh            # build+install debug
#   ./scripts/android-build.sh release    # build+install release
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source scripts/_android-common.sh

MODE="${1:-debug}"
if [[ "$MODE" != "debug" && "$MODE" != "release" ]]; then
  echo "Uso: $0 [debug|release]" >&2
  exit 1
fi

ensure_emulator

flutter build apk --"$MODE"

APK="build/app/outputs/flutter-apk/app-$MODE.apk"
echo "Instalando $APK em $DEVICE_ID..."
adb -s "$DEVICE_ID" install -r "$APK"

echo
echo "Build+install ok."
echo "Abrir com: ./scripts/android-start.sh"
