# Changelog

## 1.3.0 - 2026-05-28

**Architecture overhaul.** Extracted `scripts/lib.sh` as a shared library sourced by both the runtime and installer. Zero duplicated logic remains. The runtime now resolves `lib.sh` via well-known installed paths at startup, eliminating the sed-based patching that was needed before. xrandr output is cached once per command invocation. All mutating xrandr calls go through a `run_xrandr()` helper with consistent error handling.

**Security improvements.** The installer verifies SHA256 checksums on remote downloads when available. Both the runtime and installer now show the package list and prompt for confirmation before running sudo. VNC password tradeoffs, unencrypted traffic, and SSH tunneling are documented in `docs/SECURITY.md` and the `install-vnc` help output.

**Reliability fixes.** `stop` now cleans up xrandr modes to prevent accumulation after repeated start/stop cycles. Stale lock files from crashed processes are auto-detected and cleaned. The fixed 1-second startup sleep is replaced with a port-polling loop that adapts to available tools (ss, netstat, or timed fallback) and sleep granularity (fractional or whole-second).

**Structured logging.** Start, stop, config changes, and security events now write timestamped entries to the log file alongside x11vnc output.

**Testing.** Added Xvfb-based integration tests exercising the full lifecycle in CI. Added installer fallback tests verifying the remote-download path. Unit tests at 110. CI runs lint, unit, smoke, integration, and installer fallback checks in parallel jobs.

**Packaging.** The Debian package builder now includes `lib.sh`.

## 1.2.1 - 2026-05-28

**Bug fixes.** Fixed xrandr mode collision when the requested resolution matches an existing system mode (fixes #11). Fixed clip coordinates for left/above positioning when the main monitor is at the origin by re-reading actual geometry after xrandr applies the layout.

**Better error messages.** The "no disconnected output" and "stale monitor config" errors now list available outputs and suggest specific fixes. xrandr failures surface the actual error instead of failing silently.

**Doctor improvements.** Warns about no disconnected outputs, stale monitor config, and gives Wayland-to-X11 switching instructions. Prints a summary verdict.

**Testing.** Added 106 unit tests for validators, config parsing, geometry math, and CLI options. Fixed smoke test paths.

## 1.2.0 - 2026-04-03

Major rewrite of the runtime around safe config parsing (no more sourcing config as shell). Added `doctor`, `install-deps`, `logs`, `set-password`, and `install-vnc` commands. Made start/stop stateful with PID tracking in XDG state directories. Changed the default VNC posture to password-based auth. Consolidated the installer and package builder at the repo root with `installer/` as thin wrappers. Removed the stale committed Debian package. Added CI, contributor docs, and architecture documentation.
