#!/usr/bin/env bash

# =============================================================================
# Integration tests for Linux Display Extend
# Requires: Xvfb, x11vnc, xrandr, cvt (install via: apt install xvfb x11vnc
#           x11-xserver-utils xserver-xorg-video-dummy)
#
# These tests create a virtual X11 session with Xvfb and exercise the full
# start/status/stop lifecycle against real xrandr and x11vnc binaries.
# =============================================================================

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME="$ROOT_DIR/scripts/display-extend.sh"
TMP_HOME="$(mktemp -d)"
XVFB_PID=""

trap 'cleanup' EXIT

cleanup() {
    # Stop any running session
    "$RUNTIME" stop >/dev/null 2>&1 || true
    # Kill Xvfb
    if [[ -n "$XVFB_PID" ]] && kill -0 "$XVFB_PID" >/dev/null 2>&1; then
        kill "$XVFB_PID" 2>/dev/null || true
        wait "$XVFB_PID" 2>/dev/null || true
    fi
    rm -rf "$TMP_HOME"
}

export HOME="$TMP_HOME"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

pass() {
    PASS_COUNT=$((PASS_COUNT + 1))
    printf '  \033[32mPASS\033[0m %s\n' "$1"
}

fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf '  \033[31mFAIL\033[0m %s\n' "$1"
}

skip() {
    SKIP_COUNT=$((SKIP_COUNT + 1))
    printf '  \033[33mSKIP\033[0m %s\n' "$1"
}

# =============================================================================
# Pre-flight: check required tools
# =============================================================================

printf '\033[1m[Integration Test Pre-flight]\033[0m\n'

missing=0
for cmd in Xvfb xrandr x11vnc cvt; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        printf '  Missing: %s\n' "$cmd"
        missing=$((missing + 1))
    fi
done

if (( missing > 0 )); then
    printf 'Install missing tools: sudo apt install xvfb x11vnc x11-xserver-utils xserver-xorg-video-dummy\n'
    printf 'Skipping integration tests.\n'
    exit 0
fi

# =============================================================================
# Start Xvfb with a virtual display
# =============================================================================

printf '\n\033[1m[Starting Xvfb]\033[0m\n'

# Use display :99 to avoid conflicts
XVFB_DISPLAY=":99"

# Start Xvfb with a screen and a dummy output configuration
Xvfb "$XVFB_DISPLAY" -screen 0 1920x1080x24 +extension RANDR &
XVFB_PID=$!
sleep 1

if ! kill -0 "$XVFB_PID" >/dev/null 2>&1; then
    printf '  Xvfb failed to start. Skipping integration tests.\n'
    exit 0
fi

export DISPLAY="$XVFB_DISPLAY"
export XDG_SESSION_TYPE="x11"
pass "Xvfb running on $XVFB_DISPLAY (PID $XVFB_PID)"

# Verify xrandr works with our display
xrandr_output="$(xrandr --query 2>&1)"
if [[ $? -eq 0 ]]; then
    pass "xrandr --query works"
else
    fail "xrandr --query failed"
    printf '%s\n' "$xrandr_output"
    exit 1
fi

# =============================================================================
printf '\n\033[1m[Doctor on Xvfb]\033[0m\n'
# =============================================================================

doctor_output="$("$RUNTIME" doctor 2>&1)"
if echo "$doctor_output" | grep -q "Environment looks ready\|issue(s)"; then
    pass "doctor runs on Xvfb session"
else
    fail "doctor did not produce expected output"
    printf '%s\n' "$doctor_output"
fi

# =============================================================================
printf '\n\033[1m[Status before start]\033[0m\n'
# =============================================================================

status_output="$("$RUNTIME" status 2>&1)"
if echo "$status_output" | grep -q "Session is not running"; then
    pass "status reports no running session"
else
    fail "status shows unexpected state before start"
fi

# =============================================================================
printf '\n\033[1m[Start on Xvfb]\033[0m\n'
# =============================================================================

# Check if we have a disconnected output to use
disconnected="$(xrandr --query | awk '$2 == "disconnected" { print $1; exit }')"
if [[ -z "$disconnected" ]]; then
    skip "Start test -- no disconnected output in Xvfb (need dummy driver loaded)"
    skip "Status while running"
    skip "Double-start protection"
    skip "Stop and mode cleanup"
    skip "Restart cycle"
else
    # Test start with --insecure-lan to avoid needing x11vnc password setup
    start_output="$("$RUNTIME" start --insecure-lan --debug 2>&1)"
    start_exit=$?

    if [[ $start_exit -eq 0 ]]; then
        pass "start succeeded on Xvfb"

        # Verify mode was created
        if echo "$start_output" | grep -q "Mode name:"; then
            pass "start created xrandr mode"
        else
            fail "start did not report mode creation"
        fi

        # Verify clip geometry
        if echo "$start_output" | grep -q "Clip geometry:"; then
            pass "start reports clip geometry"
        else
            fail "start missing clip geometry"
        fi

        # Status while running
        status_running="$("$RUNTIME" status 2>&1)"
        if echo "$status_running" | grep -q "Session is running"; then
            pass "status shows running session"
        else
            fail "status does not show running session"
        fi

        if echo "$status_running" | grep -q "PID:"; then
            pass "status shows PID"
        else
            fail "status missing PID"
        fi

        # Double-start protection
        double_start="$("$RUNTIME" start --insecure-lan 2>&1 || true)"
        if echo "$double_start" | grep -q "already running"; then
            pass "double-start correctly rejected"
        else
            fail "double-start not rejected"
        fi

        # Stop
        stop_output="$("$RUNTIME" stop 2>&1)"
        if echo "$stop_output" | grep -q "Stopped VNC server"; then
            pass "stop killed VNC process"
        else
            fail "stop did not kill VNC"
        fi

        if echo "$stop_output" | grep -q "Disabled output"; then
            pass "stop disabled xrandr output"
        else
            fail "stop did not disable output"
        fi

        # Verify mode was cleaned up
        sleep 0.5
        remaining_modes="$(xrandr --query 2>/dev/null)"
        # The mode name from cvt for 1280x720 is typically "1280x720_60.00"
        # After stop, it should be removed
        if echo "$remaining_modes" | grep -q "1280x720_60\.00"; then
            fail "xrandr mode not cleaned up after stop"
        else
            pass "xrandr mode cleaned up after stop"
        fi

        # Verify session is gone
        status_after="$("$RUNTIME" status 2>&1)"
        if echo "$status_after" | grep -q "Session is not running"; then
            pass "session confirmed stopped"
        else
            fail "session still appears running after stop"
        fi

        # Restart cycle
        start2="$("$RUNTIME" start --insecure-lan 2>&1 || true)"
        if [[ $? -eq 0 ]] || echo "$start2" | grep -q "Extended display is ready"; then
            restart_output="$("$RUNTIME" restart --insecure-lan 2>&1 || true)"
            if echo "$restart_output" | grep -q "Extended display is ready"; then
                pass "restart completed successfully"
            else
                fail "restart did not complete"
            fi
            "$RUNTIME" stop >/dev/null 2>&1 || true
        else
            skip "restart test (second start failed)"
        fi
    else
        fail "start failed on Xvfb (exit $start_exit)"
        printf '%s\n' "$start_output" | head -20
    fi
fi

# =============================================================================
printf '\n\033[1m[Error handling]\033[0m\n'
# =============================================================================

# Stop with no session
stop_empty="$("$RUNTIME" stop 2>&1)"
if echo "$stop_empty" | grep -q "No owned runtime state"; then
    pass "stop with no session warns cleanly"
else
    fail "stop with no session did not warn"
fi

# Fake monitor error
fake_output="$("$RUNTIME" start --monitor FAKE-XYZ-99 --insecure-lan 2>&1 || true)"
if echo "$fake_output" | grep -q "is not connected"; then
    pass "stale monitor error triggered"
else
    fail "stale monitor error not triggered"
fi

if echo "$fake_output" | grep -q "Currently connected outputs:"; then
    pass "stale monitor error lists available outputs"
else
    fail "stale monitor error missing output list"
fi

# =============================================================================
printf '\n\033[1m[Structured logging]\033[0m\n'
# =============================================================================

log_file="$XDG_STATE_HOME/linux-display-extend/display-extend.log"
if [[ -f "$log_file" ]]; then
    if grep -q '^\[.*\] \[' "$log_file"; then
        pass "Log file contains structured entries"
    else
        skip "Log file exists but no structured entries (may not have started successfully)"
    fi
else
    skip "No log file created (start may have been skipped)"
fi

# =============================================================================
printf '\n\033[1m[Summary]\033[0m\n'
# =============================================================================

total=$((PASS_COUNT + FAIL_COUNT + SKIP_COUNT))
printf 'Results: \033[32m%d passed\033[0m, \033[31m%d failed\033[0m, \033[33m%d skipped\033[0m\n' \
    "$PASS_COUNT" "$FAIL_COUNT" "$SKIP_COUNT"

if (( FAIL_COUNT > 0 )); then
    printf 'Integration tests FAILED.\n'
    exit 1
fi

printf 'Integration tests passed.\n'
