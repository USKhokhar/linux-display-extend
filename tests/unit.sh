#!/usr/bin/env bash

# Unit tests for display-extend.sh pure functions.
# These tests source the runtime script and exercise validators, config parsing,
# geometry helpers, and CLI option parsing without requiring X11.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/display-extend.sh"
TMP_HOME="$(mktemp -d)"
trap 'rm -rf "$TMP_HOME"' EXIT

export HOME="$TMP_HOME"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"

PASS_COUNT=0
FAIL_COUNT=0

pass() {
    PASS_COUNT=$((PASS_COUNT + 1))
    printf '  \033[32mPASS\033[0m %s\n' "$1"
}

fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf '  \033[31mFAIL\033[0m %s\n' "$1"
}

assert_eq() {
    local label="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        pass "$label"
    else
        fail "$label (expected '$expected', got '$actual')"
    fi
}

assert_success() {
    local label="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        pass "$label"
    else
        fail "$label (command failed)"
    fi
}

assert_fail() {
    local label="$1"
    shift
    # Run in an explicit subshell to catch exit calls from die()
    if ( "$@" ) >/dev/null 2>&1; then
        fail "$label (command succeeded, expected failure)"
    else
        pass "$label"
    fi
}

# Source the shared library first, then the runtime functions (without main).
SCRIPT_DIR="$ROOT_DIR/scripts"
source "$ROOT_DIR/scripts/lib.sh"

# Source only the functions from display-extend.sh without running main().
# Strip the shebang, set options, the lib-resolution block, and the final main call.
eval "$(
    sed -e '/^#!/d' \
        -e '/^set -/d' \
        -e '/^SCRIPT_DIR=/d' \
        -e '/^_LDE_LIB=/d' \
        -e '/^for _candidate/,/^done$/d' \
        -e '/\[.*_LDE_LIB.*\]/d' \
        -e '/^# shellcheck source/d' \
        -e '/^source /d' \
        -e '/^unset /d' \
        -e '$ d' "$SCRIPT"
)"

# ============================================================
printf '\n\033[1m[Validation functions]\033[0m\n'
# ============================================================

# is_integer
assert_success "is_integer: positive number" is_integer 42
assert_success "is_integer: zero" is_integer 0
assert_fail "is_integer: negative" is_integer -1
assert_fail "is_integer: float" is_integer 3.14
assert_fail "is_integer: alpha" is_integer abc
assert_fail "is_integer: empty" is_integer ""

# validate_position
assert_success "validate_position: right" validate_position right
assert_success "validate_position: left" validate_position left
assert_success "validate_position: above" validate_position above
assert_success "validate_position: below" validate_position below
assert_fail "validate_position: invalid" validate_position center
assert_fail "validate_position: empty" validate_position ""

# validate_quality
assert_success "validate_quality: low-bandwidth" validate_quality low-bandwidth
assert_success "validate_quality: balanced" validate_quality balanced
assert_success "validate_quality: high-quality" validate_quality high-quality
assert_fail "validate_quality: invalid" validate_quality ultra
assert_fail "validate_quality: empty" validate_quality ""

# validate_security_mode
assert_success "validate_security_mode: password" validate_security_mode password
assert_success "validate_security_mode: none" validate_security_mode none
assert_fail "validate_security_mode: invalid" validate_security_mode tls
assert_fail "validate_security_mode: empty" validate_security_mode ""

# validate_port
assert_success "validate_port: 5900" validate_port 5900
assert_success "validate_port: 1" validate_port 1
assert_success "validate_port: 65535" validate_port 65535
assert_fail "validate_port: 0" validate_port 0
assert_fail "validate_port: 65536" validate_port 65536
assert_fail "validate_port: negative" validate_port -1
assert_fail "validate_port: non-integer" validate_port abc

# validate_resolution (uses global DISPLAY_WIDTH/DISPLAY_HEIGHT)
DISPLAY_WIDTH=1280; DISPLAY_HEIGHT=720
assert_success "validate_resolution: 1280x720" validate_resolution
DISPLAY_WIDTH=320; DISPLAY_HEIGHT=240
assert_success "validate_resolution: minimum 320x240" validate_resolution
DISPLAY_WIDTH=7680; DISPLAY_HEIGHT=4320
assert_success "validate_resolution: maximum 7680x4320" validate_resolution
DISPLAY_WIDTH=319; DISPLAY_HEIGHT=720
assert_fail "validate_resolution: width too small" validate_resolution
DISPLAY_WIDTH=1280; DISPLAY_HEIGHT=239
assert_fail "validate_resolution: height too small" validate_resolution
DISPLAY_WIDTH=7681; DISPLAY_HEIGHT=720
assert_fail "validate_resolution: width too large" validate_resolution
DISPLAY_WIDTH=1280; DISPLAY_HEIGHT=4321
assert_fail "validate_resolution: height too large" validate_resolution
DISPLAY_WIDTH=abc; DISPLAY_HEIGHT=720
assert_fail "validate_resolution: non-integer width" validate_resolution

# ============================================================
printf '\n\033[1m[Geometry helpers]\033[0m\n'
# ============================================================

# split_geometry
split_geometry "1920x1080+0+0"
assert_eq "split_geometry: W" "1920" "$GEOM_W"
assert_eq "split_geometry: H" "1080" "$GEOM_H"
assert_eq "split_geometry: X" "0" "$GEOM_X"
assert_eq "split_geometry: Y" "0" "$GEOM_Y"

split_geometry "1280x720+1920+0"
assert_eq "split_geometry offset: W" "1280" "$GEOM_W"
assert_eq "split_geometry offset: H" "720" "$GEOM_H"
assert_eq "split_geometry offset: X" "1920" "$GEOM_X"
assert_eq "split_geometry offset: Y" "0" "$GEOM_Y"

split_geometry "800x600+100+200"
assert_eq "split_geometry multi-offset: W" "800" "$GEOM_W"
assert_eq "split_geometry multi-offset: H" "600" "$GEOM_H"
assert_eq "split_geometry multi-offset: X" "100" "$GEOM_X"
assert_eq "split_geometry multi-offset: Y" "200" "$GEOM_Y"

# ============================================================
printf '\n\033[1m[Clip coordinate calculation]\033[0m\n'
# ============================================================

# Test clip coordinate math for all four positions.
# We set the globals that start_extended() uses, then replicate the math.
GEOM_X=0; GEOM_Y=0; GEOM_W=1920; GEOM_H=1080
DISPLAY_WIDTH=1280; DISPLAY_HEIGHT=720

# right: extended display goes to the right of main
clip_x=$((GEOM_X + GEOM_W)); clip_y=$GEOM_Y
assert_eq "clip right: x" "1920" "$clip_x"
assert_eq "clip right: y" "0" "$clip_y"

# left: extended display goes to the left (negative when at origin)
clip_x=$((GEOM_X - DISPLAY_WIDTH)); clip_y=$GEOM_Y
assert_eq "clip left at origin: x" "-1280" "$clip_x"
assert_eq "clip left at origin: y" "0" "$clip_y"

# above: extended display goes above (negative when at origin)
clip_x=$GEOM_X; clip_y=$((GEOM_Y - DISPLAY_HEIGHT))
assert_eq "clip above at origin: x" "0" "$clip_x"
assert_eq "clip above at origin: y" "-720" "$clip_y"

# below: extended display goes below main
clip_x=$GEOM_X; clip_y=$((GEOM_Y + GEOM_H))
assert_eq "clip below: x" "0" "$clip_x"
assert_eq "clip below: y" "1080" "$clip_y"

# With a non-zero offset main monitor
GEOM_X=1920; GEOM_Y=0; GEOM_W=1280; GEOM_H=720
clip_x=$((GEOM_X - DISPLAY_WIDTH)); clip_y=$GEOM_Y
assert_eq "clip left with offset: x" "640" "$clip_x"
assert_eq "clip left with offset: y" "0" "$clip_y"

# ============================================================
printf '\n\033[1m[Config file parsing]\033[0m\n'
# ============================================================

mkdir -p "$XDG_CONFIG_HOME/linux-display-extend"
CONFIG_FILE="$XDG_CONFIG_HOME/linux-display-extend/config"

# Test default config creation
ensure_dirs
set_defaults
create_default_config
assert_success "create_default_config: file exists" test -f "$CONFIG_FILE"

# Parse and verify defaults
set_defaults
parse_config_file
assert_eq "default config: DISPLAY_WIDTH" "1280" "$DISPLAY_WIDTH"
assert_eq "default config: DISPLAY_HEIGHT" "720" "$DISPLAY_HEIGHT"
assert_eq "default config: DISPLAY_POSITION" "right" "$DISPLAY_POSITION"
assert_eq "default config: MAIN_MONITOR" "auto" "$MAIN_MONITOR"
assert_eq "default config: VNC_PORT" "5900" "$VNC_PORT"
assert_eq "default config: SECURITY_MODE" "password" "$SECURITY_MODE"

# Test custom config
cat > "$CONFIG_FILE" <<'EOF'
DISPLAY_WIDTH=1920
DISPLAY_HEIGHT=1080
DISPLAY_POSITION=left
MAIN_MONITOR=HDMI-1
VNC_PORT=5901
BIND_ADDRESS=127.0.0.1
SECURITY_MODE=none
QUALITY_PROFILE=high-quality
EOF
set_defaults
parse_config_file
assert_eq "custom config: DISPLAY_WIDTH" "1920" "$DISPLAY_WIDTH"
assert_eq "custom config: DISPLAY_HEIGHT" "1080" "$DISPLAY_HEIGHT"
assert_eq "custom config: DISPLAY_POSITION" "left" "$DISPLAY_POSITION"
assert_eq "custom config: MAIN_MONITOR" "HDMI-1" "$MAIN_MONITOR"
assert_eq "custom config: VNC_PORT" "5901" "$VNC_PORT"
assert_eq "custom config: BIND_ADDRESS" "127.0.0.1" "$BIND_ADDRESS"
assert_eq "custom config: SECURITY_MODE" "none" "$SECURITY_MODE"
assert_eq "custom config: QUALITY_PROFILE" "high-quality" "$QUALITY_PROFILE"

# Test config with comments and blank lines
cat > "$CONFIG_FILE" <<'EOF'
# This is a comment
DISPLAY_WIDTH=800

DISPLAY_HEIGHT=600
# Another comment
DISPLAY_POSITION=above
EOF
set_defaults
parse_config_file
assert_eq "commented config: DISPLAY_WIDTH" "800" "$DISPLAY_WIDTH"
assert_eq "commented config: DISPLAY_HEIGHT" "600" "$DISPLAY_HEIGHT"
assert_eq "commented config: DISPLAY_POSITION" "above" "$DISPLAY_POSITION"
assert_eq "commented config: VNC_PORT (default)" "5900" "$VNC_PORT"

# Test config with quoted values
cat > "$CONFIG_FILE" <<'EOF'
DISPLAY_WIDTH="1024"
DISPLAY_HEIGHT='768'
MAIN_MONITOR="DP-1"
EOF
set_defaults
parse_config_file
assert_eq "quoted config: DISPLAY_WIDTH" "1024" "$DISPLAY_WIDTH"
assert_eq "quoted config: DISPLAY_HEIGHT" "768" "$DISPLAY_HEIGHT"
assert_eq "quoted config: MAIN_MONITOR" "DP-1" "$MAIN_MONITOR"

# ============================================================
printf '\n\033[1m[CLI option parsing]\033[0m\n'
# ============================================================

# parse_start_options sets globals from CLI flags
set_defaults
SECURITY_MODE="password"
parse_start_options --resolution 1920x1080
assert_eq "parse --resolution: width" "1920" "$DISPLAY_WIDTH"
assert_eq "parse --resolution: height" "1080" "$DISPLAY_HEIGHT"

set_defaults
parse_start_options --position left
assert_eq "parse --position" "left" "$DISPLAY_POSITION"

set_defaults
parse_start_options --port 5901
assert_eq "parse --port" "5901" "$VNC_PORT"

set_defaults
parse_start_options --bind 127.0.0.1
assert_eq "parse --bind" "127.0.0.1" "$BIND_ADDRESS"

set_defaults
parse_start_options --quality high-quality
assert_eq "parse --quality" "high-quality" "$QUALITY_PROFILE"

set_defaults
SECURITY_MODE="password"
parse_start_options --insecure-lan
assert_eq "parse --insecure-lan" "none" "$SECURITY_MODE"

set_defaults
parse_start_options --debug
assert_eq "parse --debug" "1" "$DEBUG"

# Multiple options combined
set_defaults
SECURITY_MODE="password"
parse_start_options --resolution 800x600 --position above --port 5950 --debug
assert_eq "multi-option: width" "800" "$DISPLAY_WIDTH"
assert_eq "multi-option: height" "600" "$DISPLAY_HEIGHT"
assert_eq "multi-option: position" "above" "$DISPLAY_POSITION"
assert_eq "multi-option: port" "5950" "$VNC_PORT"
assert_eq "multi-option: debug" "1" "$DEBUG"

# Invalid options should fail
assert_fail "parse invalid --resolution" parse_start_options --resolution bad
assert_fail "parse invalid --position" parse_start_options --position center
assert_fail "parse invalid --port" parse_start_options --port 99999
assert_fail "parse unknown option" parse_start_options --foobar

# ============================================================
printf '\n\033[1m[Utility functions]\033[0m\n'
# ============================================================

# trim
assert_eq "trim: leading spaces" "hello" "$(trim '   hello')"
assert_eq "trim: trailing spaces" "hello" "$(trim 'hello   ')"
assert_eq "trim: both sides" "hello" "$(trim '   hello   ')"
assert_eq "trim: no spaces" "hello" "$(trim 'hello')"
assert_eq "trim: empty string" "" "$(trim '')"
assert_eq "trim: tabs" "hello" "$(trim '	hello	')"

# quality_flags (one arg per line, designed for mapfile/readarray)
QUALITY_PROFILE="low-bandwidth"
_qf_raw="$(quality_flags)"
assert_eq "quality_flags: low-bandwidth has -wait" "true" "$([[ "$_qf_raw" == *"-wait"* ]] && echo true || echo false)"
assert_eq "quality_flags: low-bandwidth has 40" "true" "$([[ "$_qf_raw" == *"40"* ]] && echo true || echo false)"
assert_eq "quality_flags: low-bandwidth has -noxdamage" "true" "$([[ "$_qf_raw" == *"-noxdamage"* ]] && echo true || echo false)"
QUALITY_PROFILE="high-quality"
_qf_raw="$(quality_flags)"
assert_eq "quality_flags: high-quality has -wait" "true" "$([[ "$_qf_raw" == *"-wait"* ]] && echo true || echo false)"
assert_eq "quality_flags: high-quality has 5" "true" "$([[ "$_qf_raw" == *"5"* ]] && echo true || echo false)"
QUALITY_PROFILE="balanced"
_qf_raw="$(quality_flags)"
assert_eq "quality_flags: balanced has -wait" "true" "$([[ "$_qf_raw" == *"-wait"* ]] && echo true || echo false)"
assert_eq "quality_flags: balanced has 15" "true" "$([[ "$_qf_raw" == *"15"* ]] && echo true || echo false)"

# ============================================================
printf '\n\033[1m[Summary]\033[0m\n'
# ============================================================
printf 'Results: \033[32m%d passed\033[0m, \033[31m%d failed\033[0m\n' "$PASS_COUNT" "$FAIL_COUNT"

if (( FAIL_COUNT > 0 )); then
    exit 1
fi

printf 'Unit tests passed.\n'
