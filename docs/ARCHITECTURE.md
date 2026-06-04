# Architecture

## Layout

`linux-display-extend` is a Bash-based X11 utility with four canonical files:

- `scripts/lib.sh` -- shared library (colors, output helpers, distro detection, dependency installation, config template, logging)
- `scripts/display-extend.sh` -- the runtime (all CLI commands, config, validation, xrandr orchestration, VNC launch)
- `universal_installer.sh` -- installer (dependency install, runtime placement, config bootstrap)
- `display_extend_package.sh` -- Debian package tree builder

`installer/` contains thin wrappers that delegate to the root-level scripts. `install.sh` wraps the installer for `curl | bash` usage.

The runtime finds `lib.sh` at startup by checking installed paths (`/usr/local/share/`, `~/.local/share/`) before falling back to the script directory. No post-install patching is needed.

## Runtime Flow

1. Source `lib.sh`.
2. Read config from `~/.config/linux-display-extend/config` (parsed, not sourced as shell).
3. Validate config, session type, and dependencies.
4. Cache `xrandr --query` output once, derive all display state from the cache.
5. Resolve the main monitor and find a disconnected output.
6. Generate a modeline with `cvt`, apply it with `xrandr`.
7. Calculate clip geometry; re-read actual coordinates from xrandr after layout.
8. Launch `x11vnc` clipped to the extended region; poll for port binding.
9. Record PID, output, mode, and geometry in `~/.local/state/linux-display-extend/runtime.env`.
10. On stop: kill VNC, disable output, clean up xrandr mode, remove state.

## Directories

- config: `~/.config/linux-display-extend`
- state: `~/.local/state/linux-display-extend`
- cache: `~/.cache/linux-display-extend`

## Security Model

Password-based VNC authentication is the default. Config is parsed safely (never sourced). Process tracking uses the owned PID only. Installer verifies SHA256 checksums on remote downloads. See `docs/SECURITY.md` for details.

## Release Model

- `VERSION` is the canonical version marker
- `universal_installer.sh` installs from local or remote source
- `display_extend_package.sh` generates a Debian package tree under `build/package/`
- `make checksums` generates `SHA256SUMS` for release integrity verification

## Constraints

- X11 only (Wayland is detected and rejected)
- Requires `xrandr`, `x11vnc`, `cvt`, and a usable disconnected output
- Single-session (one extended display at a time)
- LAN-oriented VNC (not encrypted; SSH tunneling documented for untrusted networks)
