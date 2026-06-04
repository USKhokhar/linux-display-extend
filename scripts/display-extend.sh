#!/usr/bin/env bash
set -euo pipefail

# Find and source lib.sh from installed paths or the script directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LDE_LIB=""
for _candidate in \
    "/usr/local/share/linux-display-extend/lib.sh" \
    "$HOME/.local/share/linux-display-extend/lib.sh" \
    "$SCRIPT_DIR/lib.sh" \
    "$SCRIPT_DIR/../scripts/lib.sh"; do
    [[ -f "$_candidate" ]] && { _LDE_LIB="$_candidate"; break; }
done
[[ -n "$_LDE_LIB" ]] || { echo "[ERROR] Cannot find lib.sh. Reinstall or check your installation." >&2; exit 1; }
# shellcheck source=scripts/lib.sh
source "$_LDE_LIB"
unset _LDE_LIB _candidate

CHANGELOG_URL="$REPO_URL/blob/main/CHANGELOG.md"

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
LOCK_PID_FILE="$LOCK_DIR/pid"

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
STARTED_CLIP=""
STARTED_ORIGINAL_FB=""
START_SUCCESS=0
_XRANDR_CACHE=""

ensure_dirs() { mkdir -p "$CONFIG_DIR" "$STATE_DIR" "$CACHE_DIR"; }

resolve_version() {
    local repo_version share_version user_share_version
    repo_version="$(cd "$SCRIPT_DIR/.." 2>/dev/null && pwd)/VERSION"
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

banner() {
    printf '\n'
    paint "${CYAN}${BOLD}" "=============================================="
    paint "${CYAN}${BOLD}" "            LINUX DISPLAY EXTEND"
    paint "${MAGENTA}" "        Android-as-monitor for X11 rigs"
    paint "${CYAN}${BOLD}" "=============================================="
    printf '%bVersion:%b %s\n' "$DIM" "$RESET" "$VERSION"
}

# --- Config ---

set_defaults() {
    DISPLAY_WIDTH=1280; DISPLAY_HEIGHT=720
    DISPLAY_POSITION="right"; MAIN_MONITOR="auto"
    VNC_PORT=5900; BIND_ADDRESS="0.0.0.0"
    SECURITY_MODE="password"; QUALITY_PROFILE="balanced"
}

create_default_config() { write_default_config "$CONFIG_FILE"; }

parse_config_file() {
    local line key value
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="$(trim "${line%%#*}")"
        [[ -z "$line" || "$line" != *=* ]] && continue
        key="$(trim "${line%%=*}")"
        value="$(trim "${line#*=}")"
        value="${value%\"}"; value="${value#\"}"
        value="${value%\'}"; value="${value#\'}"
        case "$key" in
            DISPLAY_WIDTH)    DISPLAY_WIDTH="$value" ;;
            DISPLAY_HEIGHT)   DISPLAY_HEIGHT="$value" ;;
            DISPLAY_POSITION) DISPLAY_POSITION="$value" ;;
            MAIN_MONITOR)     MAIN_MONITOR="$value" ;;
            VNC_PORT)         VNC_PORT="$value" ;;
            BIND_ADDRESS)     BIND_ADDRESS="$value" ;;
            SECURITY_MODE)    SECURITY_MODE="$value" ;;
            QUALITY_PROFILE)  QUALITY_PROFILE="$value" ;;
            *) warn "Ignoring unknown config key: $key" ;;
        esac
    done < "$CONFIG_FILE"
}

load_config() {
    set_defaults
    ensure_dirs
    [[ -f "$CONFIG_FILE" ]] || create_default_config
    parse_config_file
}

save_config() {
    ensure_dirs
    cat > "$CONFIG_FILE" <<EOF
# Linux Display Extend configuration
DISPLAY_WIDTH="${DISPLAY_WIDTH}"
DISPLAY_HEIGHT="${DISPLAY_HEIGHT}"
DISPLAY_POSITION="${DISPLAY_POSITION}"
MAIN_MONITOR="${MAIN_MONITOR}"
VNC_PORT="${VNC_PORT}"
BIND_ADDRESS="${BIND_ADDRESS}"
SECURITY_MODE="${SECURITY_MODE}"
QUALITY_PROFILE="${QUALITY_PROFILE}"
EOF
}

# --- Validators ---

is_integer() { [[ "$1" =~ ^[0-9]+$ ]]; }

validate_position()      { case "$1" in right|left|above|below) return 0 ;; *) return 1 ;; esac; }
validate_quality()       { case "$1" in low-bandwidth|balanced|high-quality) return 0 ;; *) return 1 ;; esac; }
validate_security_mode() { case "$1" in password|none) return 0 ;; *) return 1 ;; esac; }
validate_port()          { is_integer "$1" && (( "$1" >= 1 && "$1" <= 65535 )); }

validate_resolution() {
    is_integer "$DISPLAY_WIDTH" && is_integer "$DISPLAY_HEIGHT" || return 1
    (( DISPLAY_WIDTH >= 320 && DISPLAY_WIDTH <= 7680 )) || return 1
    (( DISPLAY_HEIGHT >= 240 && DISPLAY_HEIGHT <= 4320 )) || return 1
}

validate_loaded_config() {
    validate_resolution      || die "Invalid resolution in config: ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}"
    validate_position "$DISPLAY_POSITION" || die "Invalid display position: $DISPLAY_POSITION"
    validate_port "$VNC_PORT"             || die "Invalid VNC port: $VNC_PORT"
    validate_security_mode "$SECURITY_MODE" || die "Invalid SECURITY_MODE: $SECURITY_MODE"
    validate_quality "$QUALITY_PROFILE"   || die "Invalid QUALITY_PROFILE: $QUALITY_PROFILE"
}

config_is_valid() {
    validate_resolution && validate_position "$DISPLAY_POSITION" &&
        validate_port "$VNC_PORT" && validate_security_mode "$SECURITY_MODE" &&
        validate_quality "$QUALITY_PROFILE"
}

# --- xrandr helpers ---

refresh_xrandr_cache() {
    _XRANDR_CACHE="$(xrandr --query 2>/dev/null)"
    debug "Refreshed xrandr cache (${#_XRANDR_CACHE} bytes)"
}

list_connected_outputs()    { awk '$2 == "connected" { print $1 }' <<< "$_XRANDR_CACHE"; }
list_disconnected_outputs() { awk '$2 == "disconnected" { print $1 }' <<< "$_XRANDR_CACHE"; }
detect_primary_output()     { awk '$2 == "connected" && $3 == "primary" { print $1; exit }' <<< "$_XRANDR_CACHE"; }

get_output_geometry() {
    awk -v target="$1" '
        $1 == target && $2 == "connected" {
            for (i = 1; i <= NF; i++)
                if ($i ~ /^[0-9]+x[0-9]+\+[0-9]+\+[0-9]+$/) { print $i; exit }
        }' <<< "$_XRANDR_CACHE"
}

# Get the current framebuffer (screen) size
get_screen_size() {
    awk '/^Screen 0:/ {
        for (i=1; i<=NF; i++) {
            if ($i == "current") { gsub(/,/,"",$(i+1)); print $(i+1) "x" $(i+3); exit }
        }
    }' <<< "$_XRANDR_CACHE"
}

# --- Monitor selection ---

choose_main_monitor() {
    local detected_primary first_connected available_list

    if [[ "$MAIN_MONITOR" != "auto" && -n "$MAIN_MONITOR" ]]; then
        list_connected_outputs | grep -Fxq "$MAIN_MONITOR" && return 0
        available_list="$(list_connected_outputs | tr '\n' ', ' | sed 's/,$//')"
        die "Configured main monitor '$MAIN_MONITOR' is not connected.

Currently connected outputs: ${available_list:-none detected}

How to fix this:
  1. Run 'display-extend config' and set MAIN_MONITOR to one of the above,
     or set it to 'auto' to let the tool pick automatically.
  2. Or pass --monitor <name> to override for this run only.
  3. If you recently unplugged '$MAIN_MONITOR', the config still references it.
     Edit $CONFIG_FILE or re-run 'display-extend config' to update."
    fi

    detected_primary="$(detect_primary_output || true)"
    if [[ -n "$detected_primary" ]]; then MAIN_MONITOR="$detected_primary"; return 0; fi

    first_connected="$(list_connected_outputs | head -n 1)"
    [[ -n "$first_connected" ]] || die "No connected X11 outputs found. Is an X11 session active?"
    MAIN_MONITOR="$first_connected"
}

split_geometry() {
    local geometry="$1" dims rest
    dims="${geometry%%+*}"; rest="${geometry#*+}"
    GEOM_W="${dims%x*}"; GEOM_H="${dims#*x}"
    GEOM_X="${rest%%+*}"; GEOM_Y="${rest#*+}"
}

# --- Session guards ---

ensure_x11_session() {
    if [[ "${XDG_SESSION_TYPE:-}" == "wayland" || -n "${WAYLAND_DISPLAY:-}" ]]; then
        die "Wayland sessions are not supported yet. Please use an X11 session."
    fi
    [[ -n "${DISPLAY:-}" ]] || die "DISPLAY is not set. Start this from an active X11 desktop session."
}

ensure_runtime_requirements() {
    ensure_x11_session
    for cmd in xrandr x11vnc hostname nohup; do require_command "$cmd"; done
}

# --- Password ---

generate_random_secret() { od -An -N16 -tx1 /dev/urandom | tr -d ' \n' | cut -c1-16; }

ensure_password_file() {
    [[ "$SECURITY_MODE" == "password" ]] || return 0
    [[ -f "$PASSWORD_FILE" ]] && return 0

    local pw
    pw="$(generate_random_secret)"
    mkdir -p "$CONFIG_DIR"
    x11vnc -storepasswd "$pw" "$PASSWORD_FILE" >/dev/null 2>&1
    chmod 600 "$PASSWORD_FILE"
    printf '%s\n' "$pw" > "$PASSWORD_HINT_FILE"
    chmod 600 "$PASSWORD_HINT_FILE"
    warn "Generated a first-run VNC password. Recovery copy: $PASSWORD_HINT_FILE"
    log_event "SECURITY" "Generated first-run VNC password"
}

# --- Runtime state and locking ---

load_runtime_state() {
    RUNTIME_PID="" RUNTIME_CLIP="" RUNTIME_ORIGINAL_FB=""
    RUNTIME_MAIN="" RUNTIME_BIND="" RUNTIME_PORT=""
    [[ -f "$RUNTIME_FILE" ]] || return 0

    local line key value
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="$(trim "${line%%#*}")"
        [[ -z "$line" || "$line" != *=* ]] && continue
        key="${line%%=*}"; value="${line#*=}"
        case "$key" in
            PID) RUNTIME_PID="$value" ;; CLIP_GEOMETRY) RUNTIME_CLIP="$value" ;;
            ORIGINAL_FB) RUNTIME_ORIGINAL_FB="$value" ;;
            MAIN_MONITOR) RUNTIME_MAIN="$value" ;; BIND_ADDRESS) RUNTIME_BIND="$value" ;;
            VNC_PORT) RUNTIME_PORT="$value" ;;
        esac
    done < "$RUNTIME_FILE"
}

write_runtime_state() {
    cat > "$RUNTIME_FILE" <<EOF
PID=$1
CLIP_GEOMETRY=$2
ORIGINAL_FB=$3
MAIN_MONITOR=$4
BIND_ADDRESS=$5
VNC_PORT=$6
EOF
}

is_runtime_alive() {
    load_runtime_state
    [[ -n "${RUNTIME_PID:-}" ]] && kill -0 "$RUNTIME_PID" >/dev/null 2>&1
}

acquire_lock() {
    if mkdir "$LOCK_DIR" 2>/dev/null; then
        printf '%s' "$$" > "$LOCK_PID_FILE"
        return 0
    fi
    # Check for stale lock from a dead process
    if [[ -f "$LOCK_PID_FILE" ]]; then
        local lock_pid
        lock_pid="$(cat "$LOCK_PID_FILE" 2>/dev/null)"
        if [[ -n "$lock_pid" ]] && ! kill -0 "$lock_pid" >/dev/null 2>&1; then
            warn "Removing stale lock from dead process $lock_pid"
            log_event "WARN" "Removed stale lock from PID $lock_pid"
            rm -rf "$LOCK_DIR"
            mkdir "$LOCK_DIR" 2>/dev/null || die "Failed to acquire lock after stale cleanup"
            printf '%s' "$$" > "$LOCK_PID_FILE"
            return 0
        fi
    fi
    die "Another start operation appears to be in progress (lock: $LOCK_DIR)"
}

remove_lock() { rm -rf "$LOCK_DIR"; }

cleanup_failed_start() {
    [[ "$START_SUCCESS" == "1" ]] && return 0
    [[ -n "$STARTED_PID" ]] && kill -0 "$STARTED_PID" >/dev/null 2>&1 && kill "$STARTED_PID" >/dev/null 2>&1 || true
    # Restore original framebuffer size
    [[ -n "$STARTED_ORIGINAL_FB" ]] && xrandr --fb "$STARTED_ORIGINAL_FB" >/dev/null 2>&1 || true
    remove_lock
}

# --- Network and quality ---

resolve_connection_ip() {
    local ip
    ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
    [[ -n "$ip" ]] && { printf '%s' "$ip"; return 0; }
    printf '%s' "127.0.0.1"
}

quality_flags() {
    case "$QUALITY_PROFILE" in
        low-bandwidth) printf '%s\n' "-wait" "40" "-noxdamage" ;;
        high-quality)  printf '%s\n' "-wait" "5" ;;
        *)             printf '%s\n' "-wait" "15" ;;
    esac
}

# --- CLI ---

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

show_version() { printf '%s v%s\n' "$APP_NAME" "$VERSION"; }

parse_start_options() {
    local option value
    while [[ $# -gt 0 ]]; do
        option="$1"
        case "$option" in
            --resolution) value="${2:-}"; [[ "$value" =~ ^([0-9]+)x([0-9]+)$ ]] || die "Resolution must look like 1280x720"
                          DISPLAY_WIDTH="${BASH_REMATCH[1]}"; DISPLAY_HEIGHT="${BASH_REMATCH[2]}"; shift 2 ;;
            --position)   value="${2:-}"; validate_position "$value" || die "Invalid position: $value"
                          DISPLAY_POSITION="$value"; shift 2 ;;
            --monitor)    value="${2:-}"; [[ -n "$value" ]] || die "Monitor name cannot be empty"
                          MAIN_MONITOR="$value"; shift 2 ;;
            --port)       value="${2:-}"; validate_port "$value" || die "Invalid port: $value"
                          VNC_PORT="$value"; shift 2 ;;
            --bind)       value="${2:-}"; [[ -n "$value" ]] || die "Bind address cannot be empty"
                          BIND_ADDRESS="$value"; shift 2 ;;
            --quality)    value="${2:-}"; validate_quality "$value" || die "Invalid quality profile: $value"
                          QUALITY_PROFILE="$value"; shift 2 ;;
            --insecure-lan) SECURITY_MODE="none"; shift ;;
            --debug)        DEBUG=1; shift ;;
            *) die "Unknown start option: $option" ;;
        esac
    done
}

# --- Commands ---

configure() {
    local width_input height_input position_input monitor_input port_input bind_input security_input quality_input
    load_config; validate_loaded_config; refresh_xrandr_cache

    banner
    section "Config" "Interactive configuration"
    printf 'Connected outputs: %s\n\n' "$(list_connected_outputs | tr '\n' ' ' | sed 's/[[:space:]]*$//')"

    read -r -p "Resolution width [$DISPLAY_WIDTH]: " width_input
    read -r -p "Resolution height [$DISPLAY_HEIGHT]: " height_input
    read -r -p "Position right|left|above|below [$DISPLAY_POSITION]: " position_input
    read -r -p "Main monitor name or auto [$MAIN_MONITOR]: " monitor_input
    read -r -p "VNC port [$VNC_PORT]: " port_input
    read -r -p "Bind address [$BIND_ADDRESS]: " bind_input
    read -r -p "Security mode password|none [$SECURITY_MODE]: " security_input
    read -r -p "Quality low-bandwidth|balanced|high-quality [$QUALITY_PROFILE]: " quality_input

    DISPLAY_WIDTH="${width_input:-$DISPLAY_WIDTH}"; DISPLAY_HEIGHT="${height_input:-$DISPLAY_HEIGHT}"
    DISPLAY_POSITION="${position_input:-$DISPLAY_POSITION}"; MAIN_MONITOR="${monitor_input:-$MAIN_MONITOR}"
    VNC_PORT="${port_input:-$VNC_PORT}"; BIND_ADDRESS="${bind_input:-$BIND_ADDRESS}"
    SECURITY_MODE="${security_input:-$SECURITY_MODE}"; QUALITY_PROFILE="${quality_input:-$QUALITY_PROFILE}"

    validate_loaded_config; choose_main_monitor; save_config
    log_event "CONFIG" "Configuration saved"
    success "Configuration saved to $CONFIG_FILE"
}

set_password() {
    local first second
    ensure_dirs; require_command x11vnc
    banner; section "Security" "Set VNC password"

    read -r -s -p "Enter new VNC password: " first; printf '\n'
    read -r -s -p "Confirm new VNC password: " second; printf '\n'
    [[ -n "$first" ]] || die "Password cannot be empty"
    [[ "$first" == "$second" ]] || die "Passwords did not match"

    x11vnc -storepasswd "$first" "$PASSWORD_FILE" >/dev/null 2>&1
    chmod 600 "$PASSWORD_FILE"
    printf '%s\n' "$first" > "$PASSWORD_HINT_FILE"
    chmod 600 "$PASSWORD_HINT_FILE"
    log_event "SECURITY" "VNC password updated"
    success "Password updated"
    info "Recovery copy written to $PASSWORD_HINT_FILE"
}

install_dependencies() {
    require_linux; detect_distro
    banner; section "Dependencies" "Installing runtime prerequisites"
    info "Detected distribution: $DISTRO"

    local pkg_list
    if pkg_list="$(distro_packages)"; then
        info "The following packages will be installed via sudo:"
        printf '%s\n' "$pkg_list" | sed 's/^/  - /'
        printf '\n'
        confirm_action "Proceed with installation?" || { info "Aborted."; return 0; }
        install_distro_packages
        log_event "INSTALL" "Dependencies installed for $DISTRO"
        success "Dependency installation completed"
        info "Run 'display-extend doctor' again to verify the environment"
    else
        warn "Unsupported distribution. Install these manually:"
        printf '  - curl\n  - x11vnc\n  - xrandr / x11-xserver-utils\n  - xserver dummy driver package\n'
        return 1
    fi
}

doctor() {
    local connected disconnected missing_count=0 issue_count=0
    load_config; refresh_xrandr_cache
    banner; section "Doctor" "Environment diagnostics"

    printf 'Session type: %s\n' "${XDG_SESSION_TYPE:-unknown}"
    printf 'DISPLAY: %s\n' "${DISPLAY:-unset}"

    for cmd in xrandr x11vnc hostname nohup; do
        if command -v "$cmd" >/dev/null 2>&1; then
            success "Found dependency: $cmd"
        else
            warn "Missing dependency: $cmd"; missing_count=$((missing_count + 1))
        fi
    done

    if [[ "${XDG_SESSION_TYPE:-}" == "wayland" || -n "${WAYLAND_DISPLAY:-}" ]]; then
        warn "Wayland detected. This tool requires an X11 session."
        printf '  To switch: log out, select Xorg/X11 on the login screen, log back in.\n'
        issue_count=$((issue_count + 1))
    else
        success "X11-compatible session detected"
    fi

    if [[ -n "$_XRANDR_CACHE" ]]; then
        connected="$(list_connected_outputs | tr '\n' ' ')"
        disconnected="$(list_disconnected_outputs | tr '\n' ' ')"
        printf 'Connected outputs: %s\n' "${connected:-none}"
        printf 'Disconnected outputs: %s\n' "${disconnected:-none}"

        success "Display outputs detected"

        if [[ "$MAIN_MONITOR" != "auto" && -n "$MAIN_MONITOR" ]]; then
            if ! list_connected_outputs | grep -Fxq "$MAIN_MONITOR"; then
                warn "Configured main monitor '$MAIN_MONITOR' is not currently connected."
                printf '  Available: %s\n' "${connected:-none}"
                issue_count=$((issue_count + 1))
            else
                success "Configured main monitor '$MAIN_MONITOR' is connected"
            fi
        fi
    fi

    if config_is_valid; then success "Config file is valid"
    else warn "Config file has invalid values"; issue_count=$((issue_count + 1)); fi

    if [[ -f "$PASSWORD_FILE" ]]; then success "VNC password file is present"
    else warn "VNC password file is missing; one will be generated on first secure start"; fi

    if [[ -d "$LOCK_DIR" && -f "$LOCK_PID_FILE" ]]; then
        local lock_pid; lock_pid="$(cat "$LOCK_PID_FILE" 2>/dev/null)"
        if [[ -n "$lock_pid" ]] && ! kill -0 "$lock_pid" >/dev/null 2>&1; then
            warn "Stale lock detected (dead process $lock_pid). Will auto-clean on next start."
            issue_count=$((issue_count + 1))
        fi
    fi

    (( missing_count > 0 )) && { printf '\n'; info "Run: display-extend install-deps"; }
    printf '\n'
    if (( issue_count == 0 && missing_count == 0 )); then
        success "Environment looks ready. Run 'display-extend start' to begin."
    else
        warn "Found $((issue_count + missing_count)) issue(s) that may prevent 'display-extend start' from working."
    fi
}

show_logs() {
    ensure_dirs
    [[ -f "$LOG_FILE" ]] || die "No log file exists yet at $LOG_FILE"
    tail -n 80 "$LOG_FILE"
}

show_status() {
    load_config; validate_loaded_config; load_runtime_state
    banner; section "Status" "Runtime overview"

    if is_runtime_alive; then
        success "Session is running"
        printf 'PID: %s\nMain monitor: %s\nClip region: %s\nBind: %s:%s\n' \
            "$RUNTIME_PID" "$RUNTIME_MAIN" "$RUNTIME_CLIP" "$RUNTIME_BIND" "$RUNTIME_PORT"
    else
        warn "Session is not running"
    fi
    printf '\nConfigured display: %sx%s\nConfigured position: %s\nConfigured main monitor: %s\n' \
        "$DISPLAY_WIDTH" "$DISPLAY_HEIGHT" "$DISPLAY_POSITION" "$MAIN_MONITOR"
    printf 'Security mode: %s\nQuality profile: %s\nConfig file: %s\nLog file: %s\n' \
        "$SECURITY_MODE" "$QUALITY_PROFILE" "$CONFIG_FILE" "$LOG_FILE"
}

update_self() {
    banner; section "Update" "Safe update guidance"
    cat <<EOF
Automatic self-update is intentionally disabled.

Recommended update paths:
  1. Re-run the installer from a tagged release.
  2. Pull the repo and run the installer from source.
  3. Follow the changelog: $CHANGELOG_URL
EOF
}

install_vnc_help() {
    banner; section "Android" "VNC client setup"
    cat <<EOF
1. Install a VNC client on Android (RealVNC Viewer, MultiVNC, etc).
2. Run: display-extend start
3. Connect to the host and port shown.
4. If security mode is 'password', the password is in:
   $PASSWORD_HINT_FILE
5. Rotate the password: display-extend set-password

Security note:
  VNC traffic is not encrypted. On untrusted networks, tunnel through SSH:
    ssh -L 5900:localhost:5900 user@linux-host
  Then connect your VNC client to localhost:5900.
EOF
}

# --- Core: start / stop / restart ---

start_extended() {
    local geometry connection_ip clip_x clip_y fb_w fb_h
    local listen_args pass_args quality_args

    load_config; parse_start_options "$@"; validate_loaded_config
    ensure_runtime_requirements; ensure_password_file
    refresh_xrandr_cache; choose_main_monitor

    is_runtime_alive && die "A session is already running. Use 'display-extend stop' or 'display-extend restart'."

    mkdir -p "$STATE_DIR"
    acquire_lock
    trap cleanup_failed_start EXIT

    geometry="$(get_output_geometry "$MAIN_MONITOR")"
    [[ -n "$geometry" ]] || die "Could not read geometry for main monitor '$MAIN_MONITOR'"
    split_geometry "$geometry"
    debug "Main: ${GEOM_W}x${GEOM_H}+${GEOM_X}+${GEOM_Y}"

    # Save original framebuffer size for restore on stop
    STARTED_ORIGINAL_FB="$(get_screen_size)"
    debug "Original framebuffer: $STARTED_ORIGINAL_FB"

    # Calculate where the extended display goes and the total framebuffer size
    case "$DISPLAY_POSITION" in
        right)
            clip_x=$((GEOM_X + GEOM_W)); clip_y=$GEOM_Y
            fb_w=$((clip_x + DISPLAY_WIDTH)); fb_h=$((GEOM_Y + GEOM_H))
            (( fb_h < clip_y + DISPLAY_HEIGHT )) && fb_h=$((clip_y + DISPLAY_HEIGHT))
            ;;
        left)
            clip_x=0; clip_y=$GEOM_Y
            fb_w=$((DISPLAY_WIDTH + GEOM_X + GEOM_W)); fb_h=$((GEOM_Y + GEOM_H))
            (( fb_h < clip_y + DISPLAY_HEIGHT )) && fb_h=$((clip_y + DISPLAY_HEIGHT))
            # Shift main monitor right to make room
            xrandr --output "$MAIN_MONITOR" --pos "${DISPLAY_WIDTH}x${GEOM_Y}" 2>/dev/null || true
            ;;
        below)
            clip_x=$GEOM_X; clip_y=$((GEOM_Y + GEOM_H))
            fb_w=$((GEOM_X + GEOM_W)); fb_h=$((clip_y + DISPLAY_HEIGHT))
            (( fb_w < clip_x + DISPLAY_WIDTH )) && fb_w=$((clip_x + DISPLAY_WIDTH))
            ;;
        above)
            clip_x=$GEOM_X; clip_y=0
            fb_w=$((GEOM_X + GEOM_W)); fb_h=$((DISPLAY_HEIGHT + GEOM_Y + GEOM_H))
            (( fb_w < clip_x + DISPLAY_WIDTH )) && fb_w=$((clip_x + DISPLAY_WIDTH))
            # Shift main monitor down to make room
            xrandr --output "$MAIN_MONITOR" --pos "${GEOM_X}x${DISPLAY_HEIGHT}" 2>/dev/null || true
            ;;
    esac

    STARTED_CLIP="${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}+${clip_x}+${clip_y}"
    debug "Extended region: $STARTED_CLIP"
    debug "New framebuffer: ${fb_w}x${fb_h}"

    # Extend the framebuffer to include the virtual region
    if ! xrandr --fb "${fb_w}x${fb_h}" 2>/dev/null; then
        die "Failed to resize framebuffer to ${fb_w}x${fb_h}.
Your GPU may not support a framebuffer this large."
    fi

    connection_ip="$(resolve_connection_ip)"

    section "Start" "Launching display session"
    info "Main monitor: $MAIN_MONITOR (${GEOM_W}x${GEOM_H})"
    info "Extended display: ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT} $DISPLAY_POSITION"
    info "Clip region: $STARTED_CLIP"

    listen_args=(-rfbport "$VNC_PORT" -listen "$BIND_ADDRESS")
    mapfile -t quality_args < <(quality_flags)
    pass_args=()
    if [[ "$SECURITY_MODE" == "password" ]]; then
        pass_args=(-rfbauth "$PASSWORD_FILE")
    else
        warn "Running without VNC authentication (--insecure-lan)"
        pass_args=(-nopw)
    fi

    log_event "START" "Launching x11vnc clip=$STARTED_CLIP port=$VNC_PORT fb=${fb_w}x${fb_h}"

    nohup x11vnc -display "${DISPLAY:-:0}" -clip "$STARTED_CLIP" \
        -forever -shared -cursor most -cursorpos -xwarppointer -arrow 6 \
        "${listen_args[@]}" "${pass_args[@]}" "${quality_args[@]}" \
        >>"$LOG_FILE" 2>&1 &
    STARTED_PID="$!"

    # Poll until x11vnc is listening
    local _port_checker="none"
    command -v ss >/dev/null 2>&1 && _port_checker="ss"
    [[ "$_port_checker" == "none" ]] && command -v netstat >/dev/null 2>&1 && _port_checker="netstat"
    debug "Startup poll: port checker=$_port_checker"

    local _sleep_interval=1
    sleep 0.1 2>/dev/null && _sleep_interval=0.1
    local wait_count=0 max_wait=50
    [[ "$_sleep_interval" == "1" ]] && max_wait=5

    while (( wait_count < max_wait )); do
        kill -0 "$STARTED_PID" >/dev/null 2>&1 || die "x11vnc exited during startup. Check $LOG_FILE"
        case "$_port_checker" in
            ss)      ss -tlnp 2>/dev/null | grep -q ":${VNC_PORT}\b" && { debug "Port $VNC_PORT open (ss)"; break; } ;;
            netstat) netstat -tlnp 2>/dev/null | grep -q ":${VNC_PORT}\b" && { debug "Port $VNC_PORT open (netstat)"; break; } ;;
            none)    debug "No port checker, using timed wait"; sleep 1; break ;;
        esac
        sleep "$_sleep_interval"; wait_count=$((wait_count + 1))
    done
    kill -0 "$STARTED_PID" >/dev/null 2>&1 || die "x11vnc exited during startup. Check $LOG_FILE"

    write_runtime_state "$STARTED_PID" "$STARTED_CLIP" "$STARTED_ORIGINAL_FB" "$MAIN_MONITOR" "$BIND_ADDRESS" "$VNC_PORT"
    START_SUCCESS=1; trap - EXIT; remove_lock
    log_event "START" "Session live pid=$STARTED_PID"

    banner; section "Live" "Extended display is ready"
    printf 'Connect from Android to: %s:%s\n' "$connection_ip" "$VNC_PORT"
    printf 'Bind address: %s\nSecurity mode: %s\n' "$BIND_ADDRESS" "$SECURITY_MODE"
    [[ -f "$PASSWORD_HINT_FILE" && "$SECURITY_MODE" == "password" ]] && printf 'Password hint: %s\n' "$PASSWORD_HINT_FILE"
    printf 'PID: %s\nLogs: %s\n' "$STARTED_PID" "$LOG_FILE"
}

stop_extended() {
    load_runtime_state
    [[ -z "${RUNTIME_PID:-}" ]] && { warn "No owned runtime state was found"; return 0; }

    section "Stop" "Tearing down the owned session"

    if kill -0 "$RUNTIME_PID" >/dev/null 2>&1; then
        kill "$RUNTIME_PID" >/dev/null 2>&1 || true
        success "Stopped VNC server (PID $RUNTIME_PID)"
        log_event "STOP" "Killed VNC process $RUNTIME_PID"
    else
        warn "Tracked VNC process is not running"
    fi

    # Restore the original framebuffer size
    if [[ -n "${RUNTIME_ORIGINAL_FB:-}" ]]; then
        # If main monitor was repositioned (left/above), reset it
        xrandr --output "$RUNTIME_MAIN" --pos 0x0 2>/dev/null || true
        xrandr --fb "$RUNTIME_ORIGINAL_FB" 2>/dev/null || true
        success "Restored framebuffer to $RUNTIME_ORIGINAL_FB"
        log_event "STOP" "Restored framebuffer to $RUNTIME_ORIGINAL_FB"
    fi

    rm -f "$RUNTIME_FILE"; remove_lock
    log_event "STOP" "Session stopped cleanly"
}

restart_extended() { stop_extended; start_extended "$@"; }

# --- Main ---

main() {
    local command="${1:-help}"; shift || true
    ensure_dirs; resolve_version

    case "$command" in
        start)   start_extended "$@" ;;
        stop)    stop_extended ;;
        restart) restart_extended "$@" ;;
        status)  show_status ;;
        config)  configure ;;
        doctor)  doctor ;;
        install-deps|install-dependencies) install_dependencies ;;
        logs)         show_logs ;;
        set-password) set_password ;;
        install-vnc)  install_vnc_help ;;
        update)       update_self ;;
        --version|-v) show_version ;;
        --help|-h|help|"") show_help ;;
        *) die "Unknown command: $command" ;;
    esac
}

main "$@"
