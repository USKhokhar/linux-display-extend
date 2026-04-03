#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_INSTALLER="$SCRIPT_DIR/../universal_installer.sh"

if [[ ! -f "$ROOT_INSTALLER" ]]; then
    printf 'Root installer not found at %s\n' "$ROOT_INSTALLER" >&2
    exit 1
fi

exec "$ROOT_INSTALLER" "$@"
