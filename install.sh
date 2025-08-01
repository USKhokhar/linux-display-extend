#!/bin/bash
# Linux Display Extend - Branded Installer
# Author: USKhokhar (https://github.com/USKhokhar)
# Email: contact.uskhokhar@gmail.com
# Twitter: https://twitter.com/US_Khokhar
# Portfolio: https://uskhokhar.vercel.app
# Repository: https://github.com/USKhokhar/linux-display-extend

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER="$SCRIPT_DIR/installer/universal_installer.sh"

if [[ ! -f "$INSTALLER" ]]; then
    echo "[ERROR] universal_installer.sh not found! Please make sure you have a complete clone of the repository."
    exit 1
fi

bash "$INSTALLER" "$@"
