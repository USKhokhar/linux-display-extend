#!/usr/bin/env bash

set -euo pipefail

shopt -s extglob

APP_NAME="Linux Display Extend"
APP_SLUG="linux-display-extend"
REPO_URL="https://github.com/USKhokhar/linux-display-extend"
CHANGELOG_URL="$REPO_URL/blob/main/CHANGELOG.md"
DISTRO="unknown"

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

CONFIG_DIR="$XDG_CONFIG_HOME/$APP_SLUG"
STATE_DIR="$XDG_STATE_HOME/$APP_SLUG"
CACHE_DIR="$XDG_CACHE_HOME/$APP_SLUG"
LOG_FILE="$STATE_DIR/display-extend.log"
CONFIG_FILE="$CONFIG_DIR/config"
RUNTIME_FILE="$STATE_DIR/runtime.env"
PASSWORD_FILE="$CONFIG_DIR/vnc.pass"
PASSWORD_HINT_FILE="$CONFIG_DIR/connection.secret"
LOCK_DIR="$STATE_DIR/lock"

DISPLAY_WIDTH=1280
DISPLAY_HEIGHT=720
DISPLAY_POSITION="right"
MAIN_MONITOR="auto"
VNC_PORT=5900
BIND_ADDRESS="0.0.0.0"
SECURITY_MODE="password"
QUALITY_PROFILE="balanced"

VERSION="dev"
DEBUG="${DISPLAY_EXTEND_DEBUG:-0}"
STARTED_PID=""
STARTED_OUTPUT=""
STARTED_MODE=""
STARTED_CLIP=""
START_SUCCESS=0

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
    RESET=""
    BOLD=""
    DIM=""
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    MAGENTA=""
    CYAN=""
fi

trim() {
    local value="$1"
    value="${value##+([[:space:]])}"
    value="${value%%+([[:space:]])}"
    printf '%s' "$value"
}

ensure_dirs() {
    mkdir -p "$CONFIG_DIR" "$STATE_DIR" "$CACHE_DIR"
}

resolve_version() {
    local script_dir repo_version share_version user_share_version
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    repo_version="$(cd "$script_dir/.." 2>/dev/null && pwd)/VERSION"
    share_version="/usr/local/share/$APP_SLUG/VERSION"
    user_share_version="$HOME/.local/share/$APP_SLUG/VERSION"

    if [[ -f "$repo_version" ]]; then
        VERSION="$(tr -d '[:space:]' < "$repo_version")"
    elif [[ -f "$share_version" ]]; then
        VERSION="$(tr -d '[:space:]' < "$share_version")"
    elif [[ -f "$user_share_version" ]]; then
        VERSION="$(tr -d '[:space:]' < "$user_share_version")"
    fi
}

paint() {
    printf '%b%s%b\n' "$1" "$2" "$RESET"
}

banner() {
    printf '\n'
    paint "${CYAN}${BOLD}" "=============================================="
    paint "${CYAN}${BOLD}" "            LINUX DISPLAY EXTEND"
    paint "${MAGENTA}" "        Android-as-monitor for X11 rigs"
    paint "${CYAN}${BOLD}" "=============================================="
    printf '%bVersion:%b %s\n' "$DIM" "$RESET" "$VERSION"
}

section() {
    printf '\n%b[%s]%b %s\n' "$BOLD$BLUE" "$1" "$RESET" "$2"
}

info() {
    printf '%b[INFO]%b %s\n' "$GREEN" "$RESET" "$1"
}

warn() {
    printf '%b[WARN]%b %s\n' "$YELLOW" "$RESET" "$1"
}

error() {
    printf '%b[ERROR]%b %s\n' "$RED" "$RESET" "$1" >&2
}

success() {
    printf '%b[OK]%b %s\n' "$GREEN$BOLD" "$RESET" "$1"
}

debug() {
    if [[ "$DEBUG" == "1" ]]; then
        printf '%b[DEBUG]%b %s\n' "$DIM" "$RESET" "$1"
    fi
}

die() {
    error "$1"
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

require_linux() {
    [[ "$(uname -s)" == "Linux" ]] || die "This command is only supported on Linux"
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

set_defaults() {
    DISPLAY_WIDTH=1280
    DISPLAY_HEIGHT=720
    DISPLAY_POSITION="right"
    MAIN_MONITOR="auto"
    VNC_PORT=5900
    BIND_ADDRESS="0.0.0.0"
    SECURITY_MODE="password"
    QUALITY_PROFILE="balanced"
}

create_default_config() {
    cat > "$CONFIG_FILE" <<'EOF'
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

parse_config_file() {
    local line key value

    while IFS= read -r line || [[ -n "$line" ]]; do
        line="$(trim "${line%%#*}")"
        [[ -z "$line" ]] && continue
        [[ "$line" != *=* ]] && continue

        key="$(trim "${line%%=*}")"
        value="$(trim "${line#*=}")"
        value="${value%\"}"
        value="${value#\"}"
        value="${value%\'}"
        value="${value#\'}"

        case "$key" in
            DISPLAY_WIDTH) DISPLAY_WIDTH="$value" ;;
            DISPLAY_HEIGHT) DISPLAY_HEIGHT="$value" ;;
            DISPLAY_POSITION) DISPLAY_POSITION="$value" ;;
            MAIN_MONITOR) MAIN_MONITOR="$value" ;;
            VNC_PORT) VNC_PORT="$value" ;;
            BIND_ADDRESS) BIND_ADDRESS="$value" ;;
            SECURITY_MODE) SECURITY_MODE="$value" ;;
            QUALITY_PROFILE) QUALITY_PROFILE="$value" ;;
            *) warn "Ignoring unknown config key: $key" ;;
        esac
    done < "$CONFIG_FILE"
}

load_config() {
    set_defaults
    ensure_dirs

    if [[ ! -f "$CONFIG_FILE" ]]; then
        create_default_config
    fi

    parse_config_file
}

save_config() {
    ensure_dirs
    cat > "$CONFIG_FILE" <<EOF
# Linux Display Extend configuration
DISPLAY_WIDTH=$DISPLAY_WIDTH
DISPLAY_HEIGHT=$DISPLAY_HEIGHT
DISPLAY_POSITION=$DISPLAY_POSITION
MAIN_MONITOR=$MAIN_MONITOR
VNC_PORT=$VNC_PORT
BIND_ADDRESS=$BIND_ADDRESS
SECURITY_MODE=$SECURITY_MODE
QUALITY_PROFILE=$QUALITY_PROFILE
EOF
}

is_integer() {
    [[ "$1" =~ ^[0-9]+$ ]]
}

validate_position() {
    case "$1" in
        right|left|above|below) return 0 ;;
        *) return 1 ;;
    esac
}

validate_quality() {
    case "$1" in
        low-bandwidth|balanced|high-quality) return 0 ;;
        *) return 1 ;;
    esac
}

validate_security_mode() {
    case "$1" in
        password|none) return 0 ;;
        *) return 1 ;;
    esac
}

validate_port() {
    is_integer "$1" && (( "$1" >= 1 && "$1" <= 65535 ))
}

validate_resolution() {
    is_integer "$DISPLAY_WIDTH" || return 1
    is_integer "$DISPLAY_HEIGHT" || return 1
    (( DISPLAY_WIDTH >= 320 && DISPLAY_WIDTH <= 7680 )) || return 1
    (( DISPLAY_HEIGHT >= 240 && DISPLAY_HEIGHT <= 4320 )) || return 1
}

validate_loaded_config() {
    validate_resolution || die "Invalid resolution in config: ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}"
    validate_position "$DISPLAY_POSITION" || die "Invalid display position: $DISPLAY_POSITION"
    validate_port "$VNC_PORT" || die "Invalid VNC port: $VNC_PORT"
    validate_security_mode "$SECURITY_MODE" || die "Invalid SECURITY_MODE: $SECURITY_MODE"
    validate_quality "$QUALITY_PROFILE" || die "Invalid QUALITY_PROFILE: $QUALITY_PROFILE"
}

config_is_valid() {
    validate_resolution &&
        validate_position "$DISPLAY_POSITION" &&
        validate_port "$VNC_PORT" &&
        validate_security_mode "$SECURITY_MODE" &&
        validate_quality "$QUALITY_PROFILE"
}

list_connected_outputs() {
    xrandr --query | awk '$2 == "connected" { print $1 }'
}

list_disconnected_outputs() {
    xrandr --query | awk '$2 == "disconnected" { print $1 }'
}

detect_primary_output() {
    xrandr --query | awk '$2 == "connected" && $3 == "primary" { print $1; exit }'
}

choose_main_monitor() {
    local detected_primary first_connected

    if [[ "$MAIN_MONITOR" != "auto" && -n "$MAIN_MONITOR" ]]; then
        if list_connected_outputs | grep -Fx "$MAIN_MONITOR" >/dev/null 2>&1; then
            return 0
        fi
        die "Configured main monitor '$MAIN_MONITOR' is not connected"
    fi

    detected_primary="$(detect_primary_output || true)"
    if [[ -n "$detected_primary" ]]; then
        MAIN_MONITOR="$detected_primary"
        return 0
    fi

    first_connected="$(list_connected_outputs | head -n 1)"
    [[ -n "$first_connected" ]] || die "No connected X11 outputs found"
    MAIN_MONITOR="$first_connected"
}

get_output_geometry() {
    local output="$1"
    xrandr --query | awk -v target="$output" '
        $1 == target && $2 == "connected" {
            for (i = 1; i <= NF; i++) {
                if ($i ~ /^[0-9]+x[0-9]+\+[0-9]+\+[0-9]+$/) {
                    print $i
                    exit
                }
            }
        }
    '
}

split_geometry() {
    local geometry="$1"
    local dims rest x y

    dims="${geometry%%+*}"
    rest="${geometry#*+}"
    x="${rest%%+*}"
    y="${rest#*+}"

    GEOM_W="${dims%x*}"
    GEOM_H="${dims#*x}"
    GEOM_X="$x"
    GEOM_Y="$y"
}

find_target_output() {
    local output
    output="$(list_disconnected_outputs | head -n 1)"
    [[ -n "$output" ]] || die "No disconnected output is available for extending the desktop"
    printf '%s' "$output"
}

ensure_x11_session() {
    if [[ "${XDG_SESSION_TYPE:-}" == "wayland" || -n "${WAYLAND_DISPLAY:-}" ]]; then
        die "Wayland sessions are not supported yet. Please use an X11 session for now."
    fi

    [[ -n "${DISPLAY:-}" ]] || die "DISPLAY is not set. Start this from an active X11 desktop session."
}

ensure_runtime_requirements() {
    ensure_x11_session
    require_command xrandr
    require_command x11vnc
    require_command cvt
    require_command hostname
    require_command nohup
}

generate_random_secret() {
    od -An -N16 -tx1 /dev/urandom | tr -d ' \n' | cut -c1-16
}

ensure_password_file() {
    local generated_password

    [[ "$SECURITY_MODE" == "password" ]] || return 0

    if [[ -f "$PASSWORD_FILE" ]]; then
        return 0
    fi

    generated_password="$(generate_random_secret)"
    mkdir -p "$CONFIG_DIR"
    x11vnc -storepasswd "$generated_password" "$PASSWORD_FILE" >/dev/null 2>&1
    chmod 600 "$PASSWORD_FILE"
    printf '%s\n' "$generated_password" > "$PASSWORD_HINT_FILE"
    chmod 600 "$PASSWORD_HINT_FILE"
    warn "Generated a first-run VNC password and stored a recovery copy in $PASSWORD_HINT_FILE"
}

load_runtime_state() {
    RUNTIME_PID=""
    RUNTIME_OUTPUT=""
    RUNTIME_MODE=""
    RUNTIME_CLIP=""
    RUNTIME_MAIN=""
    RUNTIME_BIND=""
    RUNTIME_PORT=""

    [[ -f "$RUNTIME_FILE" ]] || return 0

    local line key value
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="$(trim "${line%%#*}")"
        [[ -z "$line" ]] && continue
        [[ "$line" != *=* ]] && continue
        key="${line%%=*}"
        value="${line#*=}"

        case "$key" in
            PID) RUNTIME_PID="$value" ;;
            OUTPUT) RUNTIME_OUTPUT="$value" ;;
            MODE_NAME) RUNTIME_MODE="$value" ;;
            CLIP_GEOMETRY) RUNTIME_CLIP="$value" ;;
            MAIN_MONITOR) RUNTIME_MAIN="$value" ;;
            BIND_ADDRESS) RUNTIME_BIND="$value" ;;
            VNC_PORT) RUNTIME_PORT="$value" ;;
        esac
    done < "$RUNTIME_FILE"
}

write_runtime_state() {
    cat > "$RUNTIME_FILE" <<EOF
PID=$1
OUTPUT=$2
MODE_NAME=$3
CLIP_GEOMETRY=$4
MAIN_MONITOR=$5
BIND_ADDRESS=$6
VNC_PORT=$7
EOF
}

is_runtime_alive() {
    load_runtime_state
    [[ -n "${RUNTIME_PID:-}" ]] && kill -0 "$RUNTIME_PID" >/dev/null 2>&1
}

remove_lock() {
    rm -rf "$LOCK_DIR"
}

cleanup_failed_start() {
    if [[ "$START_SUCCESS" == "1" ]]; then
        return 0
    fi

    if [[ -n "$STARTED_PID" ]] && kill -0 "$STARTED_PID" >/dev/null 2>&1; then
        kill "$STARTED_PID" >/dev/null 2>&1 || true
    fi

    if [[ -n "$STARTED_OUTPUT" ]]; then
        xrandr --output "$STARTED_OUTPUT" --off >/dev/null 2>&1 || true
    fi

    remove_lock
}

resolve_connection_ip() {
    local ip

    ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
    if [[ -n "$ip" ]]; then
        printf '%s' "$ip"
        return 0
    fi

    printf '%s' "127.0.0.1"
}

quality_flags() {
    case "$QUALITY_PROFILE" in
        low-bandwidth) printf '%s\n' "-wait 40 -noxdamage" ;;
        high-quality) printf '%s\n' "-wait 5" ;;
        *) printf '%s\n' "-wait 15" ;;
    esac
}

show_help() {
    banner
    section "CLI" "Command guide"
    cat <<EOF
Usage:
  display-extend <command> [options]

Core commands:
  start                 Start the extended display session
  stop                  Stop the owned display session
  restart               Restart the session cleanly
  status                Show configuration and runtime status
  config                Configure resolution, placement, and network defaults

Support commands:
  doctor                Validate dependencies and X11 readiness
  install-deps          Install runtime dependencies for this distro
  install-dependencies  Alias for install-deps
  logs                  Show recent runtime logs
  set-password          Set or rotate the VNC password
  install-vnc           Show Android client setup help
  update                Show safe update guidance
  --help, -h            Show this help
  --version, -v         Show the installed version

Start options:
  --resolution WxH      Override configured resolution for this run
  --position POS        Override configured position (right|left|above|below)
  --monitor NAME        Override configured main monitor
  --port PORT           Override VNC port for this run
  --bind ADDR           Override bind address for this run
  --quality PROFILE     Use low-bandwidth, balanced, or high-quality
  --insecure-lan        Disable password auth for this run only
  --debug               Print extra diagnostic output

Files:
  Config: $CONFIG_FILE
  State:  $RUNTIME_FILE
  Logs:   $LOG_FILE

This tool currently supports X11 sessions only.
EOF
}

show_version() {
    printf '%s v%s\n' "$APP_NAME" "$VERSION"
}

parse_start_options() {
    local option value

    while [[ $# -gt 0 ]]; do
        option="$1"
        case "$option" in
            --resolution)
                value="${2:-}"
                [[ "$value" =~ ^([0-9]+)x([0-9]+)$ ]] || die "Resolution must look like 1280x720"
                DISPLAY_WIDTH="${BASH_REMATCH[1]}"
                DISPLAY_HEIGHT="${BASH_REMATCH[2]}"
                shift 2
                ;;
            --position)
                value="${2:-}"
                validate_position "$value" || die "Invalid position: $value"
                DISPLAY_POSITION="$value"
                shift 2
                ;;
            --monitor)
                value="${2:-}"
                [[ -n "$value" ]] || die "Monitor name cannot be empty"
                MAIN_MONITOR="$value"
                shift 2
                ;;
            --port)
                value="${2:-}"
                validate_port "$value" || die "Invalid port: $value"
                VNC_PORT="$value"
                shift 2
                ;;
            --bind)
                value="${2:-}"
                [[ -n "$value" ]] || die "Bind address cannot be empty"
                BIND_ADDRESS="$value"
                shift 2
                ;;
            --quality)
                value="${2:-}"
                validate_quality "$value" || die "Invalid quality profile: $value"
                QUALITY_PROFILE="$value"
                shift 2
                ;;
            --insecure-lan)
                SECURITY_MODE="none"
                shift
                ;;
            --debug)
                DEBUG=1
                shift
                ;;
            *)
                die "Unknown start option: $option"
                ;;
        esac
    done
}

configure() {
    local width_input height_input position_input monitor_input port_input bind_input security_input quality_input

    load_config
    validate_loaded_config

    banner
    section "Config" "Interactive configuration"
    printf 'Connected outputs: %s\n' "$(list_connected_outputs | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
    printf '\n'

    read -r -p "Resolution width [$DISPLAY_WIDTH]: " width_input
    read -r -p "Resolution height [$DISPLAY_HEIGHT]: " height_input
    read -r -p "Position right|left|above|below [$DISPLAY_POSITION]: " position_input
    read -r -p "Main monitor name or auto [$MAIN_MONITOR]: " monitor_input
    read -r -p "VNC port [$VNC_PORT]: " port_input
    read -r -p "Bind address [$BIND_ADDRESS]: " bind_input
    read -r -p "Security mode password|none [$SECURITY_MODE]: " security_input
    read -r -p "Quality low-bandwidth|balanced|high-quality [$QUALITY_PROFILE]: " quality_input

    DISPLAY_WIDTH="${width_input:-$DISPLAY_WIDTH}"
    DISPLAY_HEIGHT="${height_input:-$DISPLAY_HEIGHT}"
    DISPLAY_POSITION="${position_input:-$DISPLAY_POSITION}"
    MAIN_MONITOR="${monitor_input:-$MAIN_MONITOR}"
    VNC_PORT="${port_input:-$VNC_PORT}"
    BIND_ADDRESS="${bind_input:-$BIND_ADDRESS}"
    SECURITY_MODE="${security_input:-$SECURITY_MODE}"
    QUALITY_PROFILE="${quality_input:-$QUALITY_PROFILE}"

    validate_loaded_config
    choose_main_monitor
    save_config

    success "Configuration saved to $CONFIG_FILE"
}

set_password() {
    local first second

    ensure_dirs
    require_command x11vnc

    banner
    section "Security" "Set VNC password"

    read -r -s -p "Enter new VNC password: " first
    printf '\n'
    read -r -s -p "Confirm new VNC password: " second
    printf '\n'

    [[ -n "$first" ]] || die "Password cannot be empty"
    [[ "$first" == "$second" ]] || die "Passwords did not match"

    x11vnc -storepasswd "$first" "$PASSWORD_FILE" >/dev/null 2>&1
    chmod 600 "$PASSWORD_FILE"
    printf '%s\n' "$first" > "$PASSWORD_HINT_FILE"
    chmod 600 "$PASSWORD_HINT_FILE"

    success "Password updated"
    info "Recovery copy written to $PASSWORD_HINT_FILE"
}

install_dependencies() {
    require_linux
    detect_distro
    banner
    section "Dependencies" "Installing runtime prerequisites"
    info "Detected distribution: $DISTRO"
    info "This command may prompt for sudo to install system packages"

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
            warn "Unsupported distribution. Install these manually:"
            printf '  - curl\n'
            printf '  - x11vnc\n'
            printf '  - xrandr / x11-xserver-utils\n'
            printf '  - xserver dummy driver package\n'
            return 1
            ;;
    esac

    success "Dependency installation completed"
    info "Run 'display-extend doctor' again to verify the environment"
}

doctor() {
    local connected disconnected missing_count

    load_config
    banner
    section "Doctor" "Environment diagnostics"

    printf 'Session type: %s\n' "${XDG_SESSION_TYPE:-unknown}"
    printf 'DISPLAY: %s\n' "${DISPLAY:-unset}"

    missing_count=0
    for cmd in xrandr x11vnc cvt hostname nohup; do
        if command -v "$cmd" >/dev/null 2>&1; then
            success "Found dependency: $cmd"
        else
            warn "Missing dependency: $cmd"
            missing_count=$((missing_count + 1))
        fi
    done

    if [[ "${XDG_SESSION_TYPE:-}" == "wayland" || -n "${WAYLAND_DISPLAY:-}" ]]; then
        warn "Wayland detected. Runtime support is currently X11-only."
    else
        success "X11-compatible session detected"
    fi

    if command -v xrandr >/dev/null 2>&1 && [[ -n "${DISPLAY:-}" ]]; then
        connected="$(list_connected_outputs | tr '\n' ' ')"
        disconnected="$(list_disconnected_outputs | tr '\n' ' ')"
        printf 'Connected outputs: %s\n' "${connected:-none}"
        printf 'Disconnected outputs: %s\n' "${disconnected:-none}"
    fi

    if config_is_valid; then
        success "Config file is valid"
    else
        warn "Config file has invalid values"
    fi

    if [[ -f "$PASSWORD_FILE" ]]; then
        success "VNC password file is present"
    else
        warn "VNC password file is missing; one will be generated on first secure start"
    fi

    if (( missing_count > 0 )); then
        printf '\n'
        info "To install the missing runtime packages, run: display-extend install-deps"
    fi
}

show_logs() {
    ensure_dirs
    [[ -f "$LOG_FILE" ]] || die "No log file exists yet at $LOG_FILE"
    tail -n 80 "$LOG_FILE"
}

show_status() {
    load_config
    validate_loaded_config
    load_runtime_state

    banner
    section "Status" "Runtime overview"

    if is_runtime_alive; then
        success "Session is running"
        printf 'PID: %s\n' "$RUNTIME_PID"
        printf 'Output: %s\n' "$RUNTIME_OUTPUT"
        printf 'Main monitor: %s\n' "$RUNTIME_MAIN"
        printf 'Clip geometry: %s\n' "$RUNTIME_CLIP"
        printf 'Bind: %s:%s\n' "$RUNTIME_BIND" "$RUNTIME_PORT"
    else
        warn "Session is not running"
    fi

    printf '\nConfigured display: %sx%s\n' "$DISPLAY_WIDTH" "$DISPLAY_HEIGHT"
    printf 'Configured position: %s\n' "$DISPLAY_POSITION"
    printf 'Configured main monitor: %s\n' "$MAIN_MONITOR"
    printf 'Security mode: %s\n' "$SECURITY_MODE"
    printf 'Quality profile: %s\n' "$QUALITY_PROFILE"
    printf 'Config file: %s\n' "$CONFIG_FILE"
    printf 'Log file: %s\n' "$LOG_FILE"
}

update_self() {
    banner
    section "Update" "Safe update guidance"
    cat <<EOF
Automatic self-update is intentionally disabled in this release train.

Why:
  - This project should not execute mutable remote scripts silently.
  - Update flows should use tagged releases or package-manager channels.

Recommended update paths:
  1. Re-run the installer from a tagged release once releases are published.
  2. Pull the repo locally and run the maintained installer from source.
  3. Follow the changelog for release notes: $CHANGELOG_URL
EOF
}

install_vnc_help() {
    banner
    section "Android" "VNC client setup"
    cat <<EOF
1. Install a VNC client on Android. RealVNC Viewer and MultiVNC are common choices.
2. Start the Linux side with: display-extend start
3. Use the host and port printed by the command.
4. If security mode is 'password', use the password from:
   $PASSWORD_HINT_FILE
5. Rotate the password at any time with: display-extend set-password
EOF
}

start_extended() {
    local geometry disconnected_output modeline_raw mode_name connection_ip clip_x clip_y xrandr_side
    local listen_args pass_args quality_args

    load_config
    parse_start_options "$@"
    validate_loaded_config
    ensure_runtime_requirements
    ensure_password_file
    choose_main_monitor

    if is_runtime_alive; then
        die "A display-extend session is already running. Use 'display-extend stop' or 'display-extend restart'."
    fi

    mkdir -p "$STATE_DIR"
    if ! mkdir "$LOCK_DIR" 2>/dev/null; then
        die "Another start operation appears to be in progress"
    fi
    trap cleanup_failed_start EXIT

    geometry="$(get_output_geometry "$MAIN_MONITOR")"
    [[ -n "$geometry" ]] || die "Could not read geometry for main monitor '$MAIN_MONITOR'"
    split_geometry "$geometry"
    debug "Main geometry: ${GEOM_W}x${GEOM_H}+${GEOM_X}+${GEOM_Y}"

    disconnected_output="$(find_target_output)"
    STARTED_OUTPUT="$disconnected_output"

    modeline_raw="$(cvt "$DISPLAY_WIDTH" "$DISPLAY_HEIGHT" 60 | awk -F'Modeline ' '/Modeline / { print $2 }')"
    [[ -n "$modeline_raw" ]] || die "Failed to generate a modeline for ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}"
    mode_name="$(awk '{print $1}' <<< "$modeline_raw" | tr -d '"')"
    STARTED_MODE="$mode_name"

    case "$DISPLAY_POSITION" in
        right)
            clip_x=$((GEOM_X + GEOM_W))
            clip_y=$GEOM_Y
            xrandr_side="--right-of"
            ;;
        left)
            clip_x=$((GEOM_X - DISPLAY_WIDTH))
            clip_y=$GEOM_Y
            xrandr_side="--left-of"
            ;;
        above)
            clip_x=$GEOM_X
            clip_y=$((GEOM_Y - DISPLAY_HEIGHT))
            xrandr_side="--above"
            ;;
        below)
            clip_x=$GEOM_X
            clip_y=$((GEOM_Y + GEOM_H))
            xrandr_side="--below"
            ;;
    esac

    STARTED_CLIP="${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}+${clip_x}+${clip_y}"
    connection_ip="$(resolve_connection_ip)"

    xrandr --newmode ${modeline_raw} >/dev/null 2>&1 || true
    xrandr --addmode "$disconnected_output" "$mode_name" >/dev/null 2>&1 || true
    xrandr --output "$disconnected_output" --mode "$mode_name" "$xrandr_side" "$MAIN_MONITOR"

    section "Start" "Launching display session"
    info "Main monitor: $MAIN_MONITOR"
    info "Target output: $disconnected_output"
    info "Layout: ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT} $DISPLAY_POSITION of $MAIN_MONITOR"
    info "Clip geometry: $STARTED_CLIP"

    listen_args=(-rfbport "$VNC_PORT" -listen "$BIND_ADDRESS")
    quality_args=($(quality_flags))
    pass_args=()

    if [[ "$SECURITY_MODE" == "password" ]]; then
        pass_args=(-rfbauth "$PASSWORD_FILE")
    else
        warn "Running without VNC authentication because --insecure-lan was requested"
        pass_args=(-nopw)
    fi

    nohup x11vnc \
        -display "${DISPLAY:-:0}" \
        -clip "$STARTED_CLIP" \
        -forever \
        -shared \
        -cursor most \
        -cursorpos \
        -xwarppointer \
        -arrow 6 \
        "${listen_args[@]}" \
        "${pass_args[@]}" \
        "${quality_args[@]}" \
        >>"$LOG_FILE" 2>&1 &

    STARTED_PID="$!"
    sleep 1

    if ! kill -0 "$STARTED_PID" >/dev/null 2>&1; then
        die "x11vnc exited during startup. Check the log file at $LOG_FILE"
    fi

    write_runtime_state "$STARTED_PID" "$disconnected_output" "$mode_name" "$STARTED_CLIP" "$MAIN_MONITOR" "$BIND_ADDRESS" "$VNC_PORT"
    START_SUCCESS=1
    trap - EXIT
    remove_lock

    banner
    section "Live" "Extended display is ready"
    printf 'Connect from Android to: %s:%s\n' "$connection_ip" "$VNC_PORT"
    printf 'Bind address: %s\n' "$BIND_ADDRESS"
    printf 'Security mode: %s\n' "$SECURITY_MODE"
    if [[ -f "$PASSWORD_HINT_FILE" && "$SECURITY_MODE" == "password" ]]; then
        printf 'Password file hint: %s\n' "$PASSWORD_HINT_FILE"
    fi
    printf 'PID: %s\n' "$STARTED_PID"
    printf 'Logs: %s\n' "$LOG_FILE"
}

stop_extended() {
    load_runtime_state

    if [[ -z "${RUNTIME_PID:-}" && -z "${RUNTIME_OUTPUT:-}" ]]; then
        warn "No owned runtime state was found"
        return 0
    fi

    section "Stop" "Tearing down the owned session"

    if [[ -n "${RUNTIME_PID:-}" ]] && kill -0 "$RUNTIME_PID" >/dev/null 2>&1; then
        kill "$RUNTIME_PID" >/dev/null 2>&1 || true
        success "Stopped VNC server process $RUNTIME_PID"
    else
        warn "Tracked VNC process is not running"
    fi

    if [[ -n "${RUNTIME_OUTPUT:-}" ]]; then
        xrandr --output "$RUNTIME_OUTPUT" --off >/dev/null 2>&1 || true
        success "Disabled output $RUNTIME_OUTPUT"
    fi

    rm -f "$RUNTIME_FILE"
    remove_lock
}

restart_extended() {
    stop_extended
    start_extended "$@"
}

main() {
    local command="${1:-help}"
    shift || true
    ensure_dirs
    resolve_version

    case "$command" in
        start)
            start_extended "$@"
            ;;
        stop)
            stop_extended
            ;;
        restart)
            restart_extended "$@"
            ;;
        status)
            show_status
            ;;
        config)
            configure
            ;;
        doctor)
            doctor
            ;;
        install-deps|install-dependencies)
            install_dependencies
            ;;
        logs)
            show_logs
            ;;
        set-password)
            set_password
            ;;
        install-vnc)
            install_vnc_help
            ;;
        update)
            update_self
            ;;
        --version|-v)
            show_version
            ;;
        --help|-h|help|"")
            show_help
            ;;
        *)
            die "Unknown command: $command"
            ;;
    esac
}

main "$@"
