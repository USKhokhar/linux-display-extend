#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER="$SCRIPT_DIR/universal_installer.sh"

if [[ ! -f "$INSTALLER" ]]; then
    echo "[ERROR] universal_installer.sh not found. Make sure you have a complete checkout."
    exit 1
fi

exec "$INSTALLER" "$@"
