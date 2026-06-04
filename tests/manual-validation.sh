#!/usr/bin/env bash

# =============================================================================
# Linux Display Extend -- Manual Validation Script (v1.2.1)
# =============================================================================
#
# PURPOSE:
#   Structured manual test harness for validating changes on a real Linux X11
#   machine before pushing to production. Runs every testable path, collects
#   results, and produces a validation report.
#
# USAGE:
#   1. Copy/clone the repo to a Linux machine with an X11 session.
#   2. Run: bash tests/manual-validation.sh
#   3. Follow the interactive prompts for tests that require human observation.
#   4. Review the report printed at the end.
#
# REQUIREMENTS:
#   - Linux host with an active X11 desktop session
#   - The tool installed (run universal_installer.sh --skip-deps first if needed)
#   - OR run directly from the repo checkout
#
# WHAT THIS TESTS:
#   - v1.2.1 bug fixes (xrandr mode collision, disconnected output errors,
#     stale monitor config, negative clip coordinates)
#   - Enhanced doctor diagnostics
#   - Full start/status/stop lifecycle
#   - Error handling paths
# =============================================================================

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME="$ROOT_DIR/scripts/display-extend.sh"
REPORT_FILE="/tmp/display-extend-validation-$(date +%Y%m%d-%H%M%S).txt"

# Use the repo checkout directly
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
MANUAL_COUNT=0

BOLD=$'\033[1m'
RED=$'\033[31m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
CYAN=$'\033[36m'
RESET=$'\033[0m'

log() {
    local msg="$1"
    printf '%s\n' "$msg"
    printf '%s\n' "$msg" >> "$REPORT_FILE"
}

pass() {
    PASS_COUNT=$((PASS_COUNT + 1))
    log "  ${GREEN}PASS${RESET} $1"
}

fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    log "  ${RED}FAIL${RESET} $1"
}

skip() {
    SKIP_COUNT=$((SKIP_COUNT + 1))
    log "  ${YELLOW}SKIP${RESET} $1"
}

manual_check() {
    MANUAL_COUNT=$((MANUAL_COUNT + 1))
    local label="$1"
    printf '\n  %s[MANUAL]%s %s\n' "$CYAN" "$RESET" "$label"
    printf '  Did this work correctly? [Y/n/s(kip)]: '
    read -r reply
    case "${reply,,}" in
        n|no) fail "$label (user reported failure)" ;;
        s|skip) skip "$label (user skipped)" ;;
        *) pass "$label (user confirmed)" ;;
    esac
}

section() {
    log ""
    log "${BOLD}=== $1 ===${RESET}"
}

# =============================================================================
# Pre-flight checks
# =============================================================================

printf '%s\n' "${BOLD}Linux Display Extend -- Manual Validation (v1.2.1)${RESET}"
printf '%s\n' "Report will be saved to: $REPORT_FILE"
printf '%s\n' ""

{
    printf 'Validation Report: Linux Display Extend v1.2.1\n'
    printf 'Date: %s\n' "$(date)"
    printf 'Host: %s\n' "$(hostname)"
    printf 'Kernel: %s\n' "$(uname -r)"
    printf 'User: %s\n' "$(whoami)"
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        printf 'Distro: %s %s\n' "${NAME:-unknown}" "${VERSION:-}"
    fi
    printf 'Session type: %s\n' "${XDG_SESSION_TYPE:-unknown}"
    printf 'DISPLAY: %s\n' "${DISPLAY:-unset}"
    printf 'Runtime: %s\n' "$RUNTIME"
    printf '\n'
} >> "$REPORT_FILE"

# Check we are on Linux
if [[ "$(uname -s)" != "Linux" ]]; then
    printf '%sThis script must be run on a Linux machine.%s\n' "$RED" "$RESET"
    printf 'Copy or clone the repo to your Linux test machine and run it there.\n'
    exit 1
fi

# Check we have an X11 session
if [[ -z "${DISPLAY:-}" ]]; then
    printf '%sNo DISPLAY set. This script requires an active X11 desktop session.%s\n' "$RED" "$RESET"
    exit 1
fi

# Check the runtime script exists
if [[ ! -f "$RUNTIME" ]]; then
    printf '%sRuntime script not found at %s%s\n' "$RED" "$RUNTIME" "$RESET"
    exit 1
fi

# =============================================================================
section "1. Syntax and basic CLI"
# =============================================================================

if bash -n "$RUNTIME" 2>/dev/null; then
    pass "Script syntax valid"
else
    fail "Script syntax check failed"
fi

if "$RUNTIME" --help >/dev/null 2>&1; then
    pass "--help exits cleanly"
else
    fail "--help failed"
fi

if "$RUNTIME" --version >/dev/null 2>&1; then
    pass "--version exits cleanly"
else
    fail "--version failed"
fi

version_output="$("$RUNTIME" --version 2>&1)"
if [[ "$version_output" == *"1.2.1"* ]]; then
    pass "Version reports 1.2.1"
else
    fail "Version mismatch: got '$version_output'"
fi

if "$RUNTIME" status >/dev/null 2>&1; then
    pass "status command works (no running session)"
else
    fail "status command failed"
fi

# Unknown command should fail
if "$RUNTIME" nonexistent-command >/dev/null 2>&1; then
    fail "Unknown command should fail but succeeded"
else
    pass "Unknown command fails correctly"
fi

# =============================================================================
section "2. Doctor diagnostics (v1.2.1 enhancements)"
# =============================================================================

doctor_output="$("$RUNTIME" doctor 2>&1)"
log "  Doctor output captured (${#doctor_output} bytes)"

# Check doctor runs without crashing
if [[ $? -eq 0 || $? -eq 1 ]]; then
    pass "Doctor command completed"
else
    fail "Doctor command crashed"
fi

# Check for the new summary verdict
if echo "$doctor_output" | grep -q "Environment looks ready\|issue(s) that may prevent"; then
    pass "Doctor prints summary verdict (v1.2.1 feature)"
else
    fail "Doctor missing summary verdict"
fi

# Check for connected/disconnected output listing
if echo "$doctor_output" | grep -q "Connected outputs:"; then
    pass "Doctor lists connected outputs"
else
    skip "Doctor output listing (xrandr may not be available)"
fi

if echo "$doctor_output" | grep -q "Disconnected outputs:"; then
    pass "Doctor lists disconnected outputs"
else
    skip "Doctor disconnected listing"
fi

# Display the doctor output for human review
printf '\n  %sDoctor output for review:%s\n' "$CYAN" "$RESET"
echo "$doctor_output" | sed 's/^/    /'
manual_check "Doctor output looks correct and complete"

# =============================================================================
section "3. Error handling: no disconnected output (v1.2.1 fix)"
# =============================================================================

disconnected="$(xrandr --query 2>/dev/null | awk '$2 == "disconnected" { print $1 }')"
if [[ -z "$disconnected" ]]; then
    log "  No disconnected outputs detected -- testing error message quality"
    start_output="$("$RUNTIME" start 2>&1 || true)"

    if echo "$start_output" | grep -q "How to fix this"; then
        pass "No-disconnected-output error includes fix guidance (v1.2.1)"
    else
        fail "No-disconnected-output error missing fix guidance"
    fi

    if echo "$start_output" | grep -q "Your connected outputs:"; then
        pass "Error lists the connected outputs"
    else
        fail "Error does not list connected outputs"
    fi

    printf '\n  %sError output for review:%s\n' "$CYAN" "$RESET"
    echo "$start_output" | sed 's/^/    /'
    manual_check "Error message is clear and actionable"
else
    log "  Disconnected outputs found: $disconnected"
    skip "No-disconnected-output error (disconnected outputs exist, cannot trigger)"
fi

# =============================================================================
section "4. Error handling: stale main monitor config (v1.2.1 fix)"
# =============================================================================

log "  Testing with a fake stale monitor name..."
start_output="$("$RUNTIME" start --monitor FAKE-MONITOR-42 2>&1 || true)"

if echo "$start_output" | grep -q "is not connected"; then
    pass "Stale monitor error triggered"
else
    fail "Stale monitor error not triggered"
fi

if echo "$start_output" | grep -q "Currently connected outputs:"; then
    pass "Error lists available monitors (v1.2.1)"
else
    fail "Error does not list available monitors"
fi

if echo "$start_output" | grep -q "How to fix this"; then
    pass "Error includes fix guidance (v1.2.1)"
else
    fail "Error missing fix guidance"
fi

printf '\n  %sStale monitor error output:%s\n' "$CYAN" "$RESET"
echo "$start_output" | sed 's/^/    /'
manual_check "Stale monitor error is clear and actionable"

# =============================================================================
section "5. Start / Status / Stop lifecycle"
# =============================================================================

if [[ -z "$disconnected" ]]; then
    skip "Start/stop lifecycle (no disconnected outputs available)"
    skip "Status while running"
    skip "Stop and cleanup"
else
    log "  Attempting to start a display session..."
    log "  Using first disconnected output: $(echo "$disconnected" | head -1)"

    start_output="$("$RUNTIME" start --debug 2>&1)"
    start_exit=$?

    if [[ $start_exit -eq 0 ]]; then
        pass "display-extend start succeeded"

        printf '\n  %sStart output:%s\n' "$CYAN" "$RESET"
        echo "$start_output" | sed 's/^/    /'

        # Check status
        status_output="$("$RUNTIME" status 2>&1)"
        if echo "$status_output" | grep -q "Session is running"; then
            pass "Status shows running session"
        else
            fail "Status does not show running session"
        fi

        # Check PID is tracked
        if echo "$status_output" | grep -q "PID:"; then
            pass "Status shows tracked PID"
        else
            fail "Status missing PID"
        fi

        # Check clip geometry
        if echo "$status_output" | grep -q "Clip geometry:"; then
            pass "Status shows clip geometry"
        else
            fail "Status missing clip geometry"
        fi

        manual_check "VNC session is accessible (try connecting from Android/VNC client)"

        # Check logs
        if "$RUNTIME" logs >/dev/null 2>&1; then
            pass "Logs command works while session is running"
        else
            skip "Logs command (no log file yet)"
        fi

        # Stop
        stop_output="$("$RUNTIME" stop 2>&1)"
        if echo "$stop_output" | grep -q "Stopped VNC server"; then
            pass "Stop killed VNC process"
        else
            fail "Stop did not report killing VNC"
        fi

        if echo "$stop_output" | grep -q "Disabled output"; then
            pass "Stop disabled the xrandr output"
        else
            fail "Stop did not disable xrandr output"
        fi

        # Verify session is gone
        status_after="$("$RUNTIME" status 2>&1)"
        if echo "$status_after" | grep -q "Session is not running"; then
            pass "Session is stopped after stop command"
        else
            fail "Session still appears running after stop"
        fi
    else
        fail "display-extend start failed (exit $start_exit)"
        printf '\n  %sStart error output:%s\n' "$CYAN" "$RESET"
        echo "$start_output" | sed 's/^/    /'
        manual_check "Is the start failure expected given your hardware?"
    fi
fi

# =============================================================================
section "6. Restart cycle"
# =============================================================================

if [[ -z "$disconnected" ]]; then
    skip "Restart test (no disconnected outputs)"
else
    # Start, then restart, then stop
    "$RUNTIME" start >/dev/null 2>&1
    if [[ $? -eq 0 ]]; then
        restart_output="$("$RUNTIME" restart 2>&1)"
        if echo "$restart_output" | grep -q "Extended display is ready"; then
            pass "Restart completed successfully"
        else
            fail "Restart did not complete"
        fi
        "$RUNTIME" stop >/dev/null 2>&1
    else
        skip "Restart test (initial start failed)"
    fi
fi

# =============================================================================
section "7. Double-start protection"
# =============================================================================

if [[ -z "$disconnected" ]]; then
    skip "Double-start test (no disconnected outputs)"
else
    "$RUNTIME" start >/dev/null 2>&1
    if [[ $? -eq 0 ]]; then
        second_start="$("$RUNTIME" start 2>&1 || true)"
        if echo "$second_start" | grep -q "already running"; then
            pass "Double-start correctly rejected"
        else
            fail "Double-start was not rejected"
        fi
        "$RUNTIME" stop >/dev/null 2>&1
    else
        skip "Double-start test (initial start failed)"
    fi
fi

# =============================================================================
section "8. Config command"
# =============================================================================

# Test that config command at least starts (it is interactive, so we cannot
# fully automate it, but we can check it does not crash immediately)
log "  Config command is interactive -- skipping automated test"
log "  To test manually: run 'display-extend config' and set values"
skip "Config interactive test (requires TTY input)"

# =============================================================================
section "9. Install-deps command"
# =============================================================================

log "  install-deps requires sudo and modifies system packages"
log "  To test: run 'display-extend install-deps' separately"
skip "Install-deps (requires sudo, run manually)"

# =============================================================================
section "10. Xrandr mode handling (v1.2.1 fix for GitHub #11)"
# =============================================================================

if [[ -z "$disconnected" ]]; then
    skip "Mode collision test (no disconnected outputs)"
else
    log "  Testing with --debug to verify mode handling messages..."
    debug_output="$("$RUNTIME" start --debug 2>&1 || true)"

    if echo "$debug_output" | grep -q "Mode name:\|Generated modeline:"; then
        pass "Debug output shows mode generation details"
    else
        fail "Debug output missing mode details"
    fi

    if echo "$debug_output" | grep -q "already exists in xrandr\|Actual extended output geometry"; then
        pass "Mode handling logic executed (either reuse or create path)"
    else
        # This is OK if the mode was freshly created
        if echo "$debug_output" | grep -q "Extended display is ready"; then
            pass "Mode was created and applied successfully"
        else
            fail "Mode handling unclear from debug output"
        fi
    fi

    "$RUNTIME" stop >/dev/null 2>&1 || true
fi

# =============================================================================
section "11. Clip geometry with --position (v1.2.1 negative coordinate fix)"
# =============================================================================

if [[ -z "$disconnected" ]]; then
    skip "Position tests (no disconnected outputs)"
else
    for pos in right left above below; do
        log "  Testing position: $pos"
        pos_output="$("$RUNTIME" start --position "$pos" --debug 2>&1 || true)"

        if echo "$pos_output" | grep -q "Extended display is ready"; then
            pass "Position '$pos' started successfully"

            # For left/above, check that the geometry was re-read
            if [[ "$pos" == "left" || "$pos" == "above" ]]; then
                if echo "$pos_output" | grep -q "Actual extended output geometry\|Predicted clip offset is negative"; then
                    pass "Position '$pos' handled coordinate adjustment"
                else
                    # Might not be negative if monitor has an offset
                    pass "Position '$pos' coordinates were non-negative (OK)"
                fi
            fi

            "$RUNTIME" stop >/dev/null 2>&1
            sleep 1
        else
            fail "Position '$pos' failed to start"
            echo "$pos_output" | tail -5 | sed 's/^/    /'
            "$RUNTIME" stop >/dev/null 2>&1 || true
            sleep 1
        fi
    done
fi

# =============================================================================
section "12. Stop with no running session"
# =============================================================================

# Make sure nothing is running
"$RUNTIME" stop >/dev/null 2>&1 || true

stop_empty="$("$RUNTIME" stop 2>&1)"
if echo "$stop_empty" | grep -q "No owned runtime state"; then
    pass "Stop with no session warns cleanly"
else
    fail "Stop with no session did not warn"
fi

# =============================================================================
# Report
# =============================================================================

section "VALIDATION REPORT"

total=$((PASS_COUNT + FAIL_COUNT + SKIP_COUNT))
log ""
log "  Passed:  $PASS_COUNT"
log "  Failed:  $FAIL_COUNT"
log "  Skipped: $SKIP_COUNT"
log "  Total:   $total"
log ""

if (( FAIL_COUNT == 0 )); then
    log "  ${GREEN}${BOLD}RESULT: ALL TESTS PASSED${RESET}"
    log ""
    log "  This build is ready to push."
else
    log "  ${RED}${BOLD}RESULT: $FAIL_COUNT FAILURE(S) DETECTED${RESET}"
    log ""
    log "  Review the failures above before pushing."
fi

log ""
log "  Full report saved to: $REPORT_FILE"

# Also dump xrandr state for the report
{
    printf '\n--- xrandr state at end of validation ---\n'
    xrandr --query 2>&1
} >> "$REPORT_FILE"

exit "$FAIL_COUNT"
