#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_PACKAGER="$SCRIPT_DIR/../display_extend_package.sh"

if [[ ! -f "$ROOT_PACKAGER" ]]; then
    printf 'Root package builder not found at %s\n' "$ROOT_PACKAGER" >&2
    exit 1
fi

exec "$ROOT_PACKAGER" "$@"
