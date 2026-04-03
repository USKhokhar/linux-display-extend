#!/usr/bin/env bash

set -euo pipefail

APP_NAME="Linux Display Extend"
APP_SLUG="linux-display-extend"
REPO_URL="https://github.com/USKhokhar/linux-display-extend"
DEFAULT_REF="${DISPLAY_EXTEND_REF:-main}"
RAW_BASE_URL="https://raw.githubusercontent.com/USKhokhar/linux-display-extend/$DEFAULT_REF"

INSTALL_BIN_DIR="/usr/local/bin"
INSTALL_SHARE_DIR="/usr/local/share/$APP_SLUG"
LOCAL_BIN_DIR="$HOME/.local/bin"
LOCAL_SHARE_DIR="$HOME/.local/share/$APP_SLUG"
DESKTOP_DIR="$HOME/.local/share/applications"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/$APP_SLUG"
RUNTIME_URL="$RAW_BASE_URL/scripts/display-extend.sh"
VERSION_URL="$RAW_BASE_URL/VERSION"

VERSION="dev"
BIN_TARGET=""
SYSTEM_INSTALL=0

if [[ -t 1 ]]; then
    RESET=$'\033[0m'
    BOLD=$'\033[1m'
    GREEN=$'\033[32m'
    YELLOW=$'\033[33m'
    CYAN=$'\033[36m'
    RED=$'\033[31m'
else
    RESET=""
    BOLD=""
    GREEN=""
    YELLOW=""
    CYAN=""
    RED=""
fi

paint() {
    printf '%b%s%b\n' "$1" "$2" "$RESET"
}

info() {
    printf '%b[INFO]%b %s\n' "$GREEN" "$RESET" "$1"
}

warn() {
    printf '%b[WARN]%b %s\n' "$YELLOW" "$RESET" "$1"
}

die() {
    printf '%b[ERROR]%b %s\n' "$RED" "$RESET" "$1" >&2
    exit 1
}

banner() {
    printf '\n'
    paint "${CYAN}${BOLD}" "=============================================="
    paint "${CYAN}${BOLD}" "          LINUX DISPLAY EXTEND INSTALLER"
    paint "${CYAN}" "      Secure X11 setup for Android displays"
    paint "${CYAN}${BOLD}" "=============================================="
}

resolve_version() {
    local script_dir repo_version
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    repo_version="$script_dir/VERSION"

    if [[ -f "$repo_version" ]]; then
        VERSION="$(tr -d '[:space:]' < "$repo_version")"
    fi
}

require_linux() {
    [[ "$(uname -s)" == "Linux" ]] || die "This installer can only run on Linux"
}

detect_distro() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        DISTRO="${ID:-unknown}"
    else
        DISTRO="unknown"
    fi
}

install_dependencies() {
    info "Installing runtime dependencies for $DISTRO"

    case "$DISTRO" in
        ubuntu|debian|linuxmint|pop|elementary)
            sudo apt update
            sudo apt install -y curl x11vnc x11-xserver-utils xserver-xorg-video-dummy
            ;;
        fedora)
            sudo dnf install -y curl x11vnc xrandr xorg-x11-drv-dummy
            ;;
        centos|rhel|rocky|almalinux)
            sudo yum install -y epel-release
            sudo yum install -y curl x11vnc xrandr xorg-x11-drv-dummy
            ;;
        arch|manjaro|endeavouros)
            sudo pacman -S --noconfirm curl x11vnc xorg-xrandr xf86-video-dummy
            ;;
        opensuse|opensuse-leap|opensuse-tumbleweed)
            sudo zypper install -y curl x11vnc xrandr xf86-video-dummy
            ;;
        *)
            warn "Unsupported distribution. Install these manually before running the tool:"
            printf '  - curl\n'
            printf '  - x11vnc\n'
            printf '  - xrandr / x11-xserver-utils\n'
            printf '  - xserver dummy driver package\n'
            ;;
    esac
}

is_local_checkout() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    [[ -f "$script_dir/scripts/display-extend.sh" && -f "$script_dir/VERSION" ]]
}

download_runtime() {
    local target_script="$1"
    local target_version="$2"

    command -v curl >/dev/null 2>&1 || die "curl is required for remote installation"
    curl -fsSL "$RUNTIME_URL" -o "$target_script"
    curl -fsSL "$VERSION_URL" -o "$target_version"
}

install_runtime_files() {
    local source_script="$1"
    local source_version="$2"

    sudo install -d "$INSTALL_BIN_DIR" "$INSTALL_SHARE_DIR"
    sudo install -m 755 "$source_script" "$INSTALL_BIN_DIR/display-extend"
    sudo install -m 644 "$source_version" "$INSTALL_SHARE_DIR/VERSION"
    BIN_TARGET="$INSTALL_BIN_DIR/display-extend"
    SYSTEM_INSTALL=1
}

install_runtime_files_local() {
    local source_script="$1"
    local source_version="$2"

    mkdir -p "$LOCAL_BIN_DIR" "$LOCAL_SHARE_DIR"
    install -m 755 "$source_script" "$LOCAL_BIN_DIR/display-extend"
    install -m 644 "$source_version" "$LOCAL_SHARE_DIR/VERSION"
    BIN_TARGET="$LOCAL_BIN_DIR/display-extend"

    if [[ ":$PATH:" != *":$LOCAL_BIN_DIR:"* ]]; then
        printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$HOME/.profile"
        warn "Added $LOCAL_BIN_DIR to ~/.profile. Restart your shell or run: source ~/.profile"
    fi
}

install_runtime() {
    local source_script source_version temp_dir script_dir

    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    if is_local_checkout; then
        info "Installing from local checkout"
        source_script="$script_dir/scripts/display-extend.sh"
        source_version="$script_dir/VERSION"
    else
        info "Installing from remote source at ref '$DEFAULT_REF'"
        temp_dir="$(mktemp -d)"
        source_script="$temp_dir/display-extend.sh"
        source_version="$temp_dir/VERSION"
        download_runtime "$source_script" "$source_version"
        trap 'rm -rf "$temp_dir"' EXIT
    fi

    if sudo -v >/dev/null 2>&1; then
        install_runtime_files "$source_script" "$source_version"
    else
        warn "Falling back to a user-local install under ~/.local because sudo is unavailable."
        install_runtime_files_local "$source_script" "$source_version"
    fi
}

create_default_config() {
    mkdir -p "$CONFIG_DIR"
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_DIR/config" <<'EOF'
# Linux Display Extend configuration
DISPLAY_WIDTH=1280
DISPLAY_HEIGHT=720
DISPLAY_POSITION=right
MAIN_MONITOR=auto
VNC_PORT=5900
BIND_ADDRESS=0.0.0.0
SECURITY_MODE=password
QUALITY_PROFILE=balanced
EOF
    fi
}

create_desktop_entry() {
    mkdir -p "$DESKTOP_DIR"
    cat > "$DESKTOP_DIR/display-extend.desktop" <<EOF
[Desktop Entry]
Name=Linux Display Extend
Comment=Use an Android device as an extended display on X11
Exec=$BIN_TARGET
Icon=display
Terminal=true
Type=Application
Categories=System;Utility;
Keywords=display;extend;android;vnc;x11;
EOF
}

create_uninstaller() {
    local target="$INSTALL_BIN_DIR/display-extend-uninstall"
    sudo tee "$target" >/dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

display-extend stop >/dev/null 2>&1 || true
sudo rm -f /usr/local/bin/display-extend
sudo rm -f /usr/local/bin/display-extend-uninstall
sudo rm -rf /usr/local/share/linux-display-extend
rm -f "$HOME/.local/share/applications/display-extend.desktop"

printf 'Remove configuration files in ~/.config/linux-display-extend? [y/N]: '
read -r reply
if [[ "$reply" =~ ^[Yy]$ ]]; then
    rm -rf "$HOME/.config/linux-display-extend"
fi

printf 'Linux Display Extend removed.\n'
EOF

    sudo chmod +x "$target"
}

show_help() {
    cat <<EOF
$APP_NAME installer

Usage:
  $0 [--help] [--version] [--skip-deps]

Options:
  --skip-deps   Skip distro package installation
  --help        Show this help
  --version     Show installer version

This installer is intended for Linux hosts only.
The runtime itself currently supports X11 sessions only.
EOF
}

main() {
    local skip_deps=0

    resolve_version
    banner

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                show_help
                exit 0
                ;;
            --version|-v)
                printf '%s installer v%s\n' "$APP_NAME" "$VERSION"
                exit 0
                ;;
            --skip-deps)
                skip_deps=1
                shift
                ;;
            *)
                die "Unknown option: $1"
                ;;
        esac
    done

    require_linux
    detect_distro

    if [[ "$(id -u)" -eq 0 ]]; then
        die "Run the installer as a regular user. It will request sudo only when needed."
    fi

    if [[ "$skip_deps" == "0" ]]; then
        install_dependencies
    fi

    install_runtime
    create_default_config
    create_desktop_entry

    if [[ "$SYSTEM_INSTALL" == "1" ]]; then
        create_uninstaller
    else
        warn "Skipped uninstaller creation for the user-local install"
    fi

    section="Quick start"
    printf '\n%b[%s]%b %s\n' "$BOLD$CYAN" "$section" "$RESET" "The tool is installed."
    printf '  1. Run: %s start\n' "$BIN_TARGET"
    printf '  2. Run: %s doctor\n' "$BIN_TARGET"
    printf '  3. Start your Android VNC client and connect using the printed host/port\n'
    printf '\nRepository: %s\n' "$REPO_URL"
}

CONFIG_FILE="$CONFIG_DIR/config"
main "$@"
