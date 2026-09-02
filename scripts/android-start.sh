#!/usr/bin/env bash
# Abre o app Android já instalado (via android-build.sh) direto no
# emulador + scrcpy, sem rebuildar nem passar pelo `flutter run` — mais
# rápido quando você só quer reabrir o app já buildado. Sobe o emulador e
# o scrcpy sozinho se não estiverem rodando.
#
# Uso:
#   ./scripts/android-start.sh
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source scripts/_android-common.sh

ensure_emulator
ensure_scrcpy

if ! adb -s "$DEVICE_ID" shell pm list packages | tr -d '\r' | grep -q "^package:$PACKAGE_NAME$"; then
  echo "App não instalado ainda. Rode primeiro: ./scripts/android-build.sh" >&2
  exit 1
fi

echo "Abrindo $PACKAGE_NAME..."
# `monkey -c LAUNCHER` acha a activity de entrada sozinho — mais robusto que
# `am start -n` porque o namespace do build.gradle e o applicationId deste
# projeto são diferentes (com.example.to_do_app vs com.codsoft.to_do_app).
adb -s "$DEVICE_ID" shell monkey -p "$PACKAGE_NAME" -c android.intent.category.LAUNCHER 1 >/dev/null
