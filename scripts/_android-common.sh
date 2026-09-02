# Sourced pelos scripts android-*.sh — não é pra rodar direto.

AVD_NAME="${AVD_NAME:-Pixel_6_API_35}"
DEVICE_ID="${DEVICE_ID:-emulator-5554}"
PACKAGE_NAME="com.codsoft.to_do_app"

export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$HOME/.local/share/mise/installs/android-sdk/23.0}"
export ANDROID_HOME="${ANDROID_HOME:-$ANDROID_SDK_ROOT}"
export PATH="$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/emulator:$PATH"

# Garante que $DEVICE_ID está rodando e com boot completo, subindo o AVD
# sem janela própria (-no-window) se precisar.
ensure_emulator() {
  if ! command -v emulator >/dev/null || ! command -v adb >/dev/null; then
    echo "emulator/adb não encontrados. Confira ANDROID_SDK_ROOT (atual: $ANDROID_SDK_ROOT)." >&2
    exit 1
  fi

  if adb devices | grep -q "^${DEVICE_ID}"; then
    echo "Emulador $DEVICE_ID já está rodando."
    return
  fi

  echo "Iniciando $AVD_NAME sem janela própria (-no-window)..."
  emulator -avd "$AVD_NAME" -no-snapshot -no-window &
  disown

  echo "Aguardando o device aparecer..."
  adb wait-for-device

  echo "Aguardando boot completo..."
  until [[ "$(adb -s "$DEVICE_ID" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]]; do
    sleep 2
  done
  echo "Emulador pronto."
}

# Garante que o scrcpy está aberto olhando pro $DEVICE_ID (janela única,
# sem o bug de foco duplo da janela Qt do emulador no Hyprland).
ensure_scrcpy() {
  if ! command -v scrcpy >/dev/null; then
    echo "scrcpy não encontrado. Instale com: omarchy pkg add scrcpy" >&2
    return 1
  fi
  if pgrep -f "scrcpy -s $DEVICE_ID" >/dev/null; then
    echo "scrcpy já está rodando."
  else
    echo "Abrindo scrcpy..."
    scrcpy -s "$DEVICE_ID" &
    disown
  fi
}
