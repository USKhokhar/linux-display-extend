#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_HOME="$(mktemp -d)"
trap 'rm -rf "$TMP_HOME" "$ROOT_DIR/build"' EXIT

export HOME="$TMP_HOME"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"

bash -n "$ROOT_DIR/scripts/display-extend.sh"
bash -n "$ROOT_DIR/scripts/start-monitor.sh"
bash -n "$ROOT_DIR/scripts/stop-monitor.sh"
bash -n "$ROOT_DIR/universal_installer.sh"
bash -n "$ROOT_DIR/installer/universal_installer.sh"
bash -n "$ROOT_DIR/display_extend_package.sh"
bash -n "$ROOT_DIR/installer/display_extend_package.sh"
bash -n "$ROOT_DIR/install.sh"

"$ROOT_DIR/scripts/display-extend.sh" --help >/dev/null
"$ROOT_DIR/scripts/display-extend.sh" --version >/dev/null
"$ROOT_DIR/scripts/display-extend.sh" status >/dev/null
"$ROOT_DIR/universal_installer.sh" --help >/dev/null
"$ROOT_DIR/display_extend_package.sh" >/dev/null

test -f "$ROOT_DIR/build/package/linux-display-extend-$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")/DEBIAN/control"
test -f "$ROOT_DIR/CODE_OF_CONDUCT.md"
test -f "$ROOT_DIR/SECURITY.md"
test -f "$ROOT_DIR/SUPPORT.md"
test -f "$ROOT_DIR/.github/pull_request_template.md"

printf 'Smoke checks passed.\n'
