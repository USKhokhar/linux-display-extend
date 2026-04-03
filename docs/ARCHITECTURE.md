# Architecture

## Current Shape

`linux-display-extend` is a Bash-based X11 utility with three canonical entrypoints:

- `scripts/display-extend.sh`
- `universal_installer.sh`
- `display_extend_package.sh`

Everything else should either support those files or document them.

## Runtime Overview

The runtime follows this sequence:

1. Read config from `~/.config/linux-display-extend/config`.
2. Validate the config without executing it as shell.
3. Validate the session and required commands.
4. Resolve the main connected monitor.
5. Find a disconnected output to use as the target extension.
6. Generate a mode using `cvt`.
7. Apply the output layout with `xrandr`.
8. Start `x11vnc` clipped to the newly extended region.
9. Record owned process and output state under XDG state directories.

## Directories

- config: `~/.config/linux-display-extend`
- state: `~/.local/state/linux-display-extend`
- cache: `~/.cache/linux-display-extend`

## Security Model

The tool now defaults to password-based VNC authentication.

Security notes:

- this is still LAN-oriented VNC, not end-to-end encrypted transport
- contributors should not reintroduce unauthenticated defaults
- contributors should not reintroduce self-updating remote script execution

## Release Model

- `VERSION` is the canonical version marker
- `universal_installer.sh` installs the runtime from local source or remote source
- `display_extend_package.sh` generates a Debian package tree under `build/package/`

## Known Constraints

- X11 only
- depends on `xrandr`, `x11vnc`, and `cvt`
- assumes a usable disconnected output exists
- does not currently support Wayland or multi-device layouts
