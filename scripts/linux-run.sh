#!/usr/bin/env bash
# `flutter run -d linux` com hot reload (r/R/q), pra quando você está
# mexendo no código e quer ver mudanças ao vivo. Pra só reabrir o app já
# buildado sem hot reload, use ./scripts/linux-start.sh (mais rápido).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

exec flutter run -d linux "$@"
