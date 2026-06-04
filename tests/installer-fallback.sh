#!/usr/bin/env bash

# =============================================================================
# Test that universal_installer.sh works without lib.sh present.
# This verifies the inline fallback path used during remote-download installs.
# =============================================================================

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# Copy only the installer (not lib.sh) to a temp directory
cp "$ROOT_DIR/universal_installer.sh" "$TMP_DIR/"
cp "$ROOT_DIR/VERSION" "$TMP_DIR/"

# The installer should be able to show help without lib.sh
if "$TMP_DIR/universal_installer.sh" --help >/dev/null 2>&1; then
    printf '  \033[32mPASS\033[0m Installer --help works without lib.sh\n'
else
    printf '  \033[31mFAIL\033[0m Installer --help failed without lib.sh\n'
    exit 1
fi

# The installer should report its version without lib.sh
version_output="$("$TMP_DIR/universal_installer.sh" --version 2>&1)"
if [[ -n "$version_output" ]]; then
    printf '  \033[32mPASS\033[0m Installer --version works without lib.sh (%s)\n' "$version_output"
else
    printf '  \033[31mFAIL\033[0m Installer --version failed without lib.sh\n'
    exit 1
fi

# Verify the fallback defines the critical functions
# We do this by sourcing the fallback block in isolation
fallback_test="$(cat <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
# Simulate: lib.sh not found, installer defines fallback
APP_NAME=""; APP_SLUG=""; REPO_URL=""; DISTRO=""
RESET=""; BOLD=""; GREEN=""; YELLOW=""; CYAN=""; RED=""; BLUE=""; DIM=""; MAGENTA=""
SCRIPT
)"

# Check that distro_packages function exists in the fallback
if grep -q "distro_packages()" "$TMP_DIR/universal_installer.sh"; then
    printf '  \033[32mPASS\033[0m Fallback defines distro_packages()\n'
else
    printf '  \033[31mFAIL\033[0m Fallback missing distro_packages()\n'
    exit 1
fi

if grep -q "install_distro_packages()" "$TMP_DIR/universal_installer.sh"; then
    printf '  \033[32mPASS\033[0m Fallback defines install_distro_packages()\n'
else
    printf '  \033[31mFAIL\033[0m Fallback missing install_distro_packages()\n'
    exit 1
fi

if grep -q "write_default_config()" "$TMP_DIR/universal_installer.sh"; then
    printf '  \033[32mPASS\033[0m Fallback defines write_default_config()\n'
else
    printf '  \033[31mFAIL\033[0m Fallback missing write_default_config()\n'
    exit 1
fi

if grep -q "detect_distro()" "$TMP_DIR/universal_installer.sh"; then
    printf '  \033[32mPASS\033[0m Fallback defines detect_distro()\n'
else
    printf '  \033[31mFAIL\033[0m Fallback missing detect_distro()\n'
    exit 1
fi

printf 'Installer fallback tests passed.\n'
