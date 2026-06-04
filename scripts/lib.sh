#!/usr/bin/env bash
# Shared library for Linux Display Extend.
# Sourced by display-extend.sh and universal_installer.sh.

[[ -n "${_LDE_LIB_LOADED:-}" ]] && return 0
_LDE_LIB_LOADED=1

shopt -s extglob

APP_NAME="Linux Display Extend"
APP_SLUG="linux-display-extend"
REPO_URL="https://github.com/USKhokhar/linux-display-extend"
DISTRO="unknown"

if [[ -t 1 ]]; then
    RESET=$'\033[0m'
    BOLD=$'\033[1m'
    DIM=$'\033[2m'
    RED=$'\033[31m'
    GREEN=$'\033[32m'
    YELLOW=$'\033[33m'
    BLUE=$'\033[34m'
    MAGENTA=$'\033[35m'
    CYAN=$'\033[36m'
else
    RESET="" BOLD="" DIM="" RED="" GREEN="" YELLOW="" BLUE="" MAGENTA="" CYAN=""
fi

paint()   { printf '%b%s%b\n' "$1" "$2" "$RESET"; }
section() { printf '\n%b[%s]%b %s\n' "$BOLD$BLUE" "$1" "$RESET" "$2"; }
info()    { printf '%b[INFO]%b %s\n' "$GREEN" "$RESET" "$1"; }
warn()    { printf '%b[WARN]%b %s\n' "$YELLOW" "$RESET" "$1"; }
error()   { printf '%b[ERROR]%b %s\n' "$RED" "$RESET" "$1" >&2; }
success() { printf '%b[OK]%b %s\n' "$GREEN$BOLD" "$RESET" "$1"; }

debug() {
    [[ "${DEBUG:-0}" == "1" ]] && printf '%b[DEBUG]%b %s\n' "$DIM" "$RESET" "$1"
    return 0
}

die() { error "$1"; exit 1; }

trim() {
    local value="$1"
    value="${value##+([[:space:]])}"
    value="${value%%+([[:space:]])}"
    printf '%s' "$value"
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

require_linux() {
    [[ "$(uname -s)" == "Linux" ]] || die "This command is only supported on Linux"
}

log_event() {
    local level="$1" message="$2"
    local ts
    ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%d %H:%M:%S")"
    [[ -n "${LOG_FILE:-}" ]] && printf '[%s] [%s] %s\n' "$ts" "$level" "$message" >> "$LOG_FILE" 2>/dev/null || true
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

distro_packages() {
    case "$DISTRO" in
        ubuntu|debian|linuxmint|pop|elementary)
            printf '%s\n' "curl" "x11vnc" "x11-xserver-utils" "xserver-xorg-video-dummy" ;;
        fedora)
            printf '%s\n' "curl" "x11vnc" "xrandr" "xorg-x11-drv-dummy" ;;
        centos|rhel|rocky|almalinux)
            printf '%s\n' "epel-release" "curl" "x11vnc" "xrandr" "xorg-x11-drv-dummy" ;;
        arch|manjaro|endeavouros)
            printf '%s\n' "curl" "x11vnc" "xorg-xrandr" "xf86-video-dummy" ;;
        opensuse|opensuse-leap|opensuse-tumbleweed)
            printf '%s\n' "curl" "x11vnc" "xrandr" "xf86-video-dummy" ;;
        *) return 1 ;;
    esac
}

confirm_action() {
    local prompt="${1:-Continue?}" reply
    [[ ! -t 0 ]] && return 0
    printf '%s [Y/n]: ' "$prompt"
    read -r reply
    case "${reply,,}" in
        n|no) return 1 ;;
        *) return 0 ;;
    esac
}

install_distro_packages() {
    case "$DISTRO" in
        ubuntu|debian|linuxmint|pop|elementary)
            sudo apt update && sudo apt install -y curl x11vnc x11-xserver-utils xserver-xorg-video-dummy ;;
        fedora)
            sudo dnf install -y curl x11vnc xrandr xorg-x11-drv-dummy ;;
        centos|rhel|rocky|almalinux)
            sudo yum install -y epel-release && sudo yum install -y curl x11vnc xrandr xorg-x11-drv-dummy ;;
        arch|manjaro|endeavouros)
            sudo pacman -S --noconfirm curl x11vnc xorg-xrandr xf86-video-dummy ;;
        opensuse|opensuse-leap|opensuse-tumbleweed)
            sudo zypper install -y curl x11vnc xrandr xf86-video-dummy ;;
        *)
            warn "Unsupported distribution. Install these manually:"
            printf '  - curl\n  - x11vnc\n  - xrandr / x11-xserver-utils\n  - xserver dummy driver package\n'
            return 1 ;;
    esac
}

write_default_config() {
    cat > "$1" <<'EOF'
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
}
