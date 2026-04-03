# Changelog

## 1.2.0 - 2026-04-03

- rebuilt the main `display-extend` runtime around safe config parsing instead of sourcing user config as shell
- added X11-only session checks, `doctor`, `logs`, and `set-password` commands
- made start/stop stateful by tracking the owned PID, output, mode, and clip geometry in XDG state directories
- fixed runtime geometry handling so configured resolution and placement drive both `xrandr` and `x11vnc`
- changed the default VNC posture from unauthenticated LAN exposure to password-based authentication
- introduced a branded, more immersive CLI presentation across runtime and installer output
- made the repo-root installer and package builder the canonical release entrypoints
- converted `installer/` scripts into thin wrappers to remove duplicate maintenance paths
- removed the stale committed Debian package payload under `linux-display-extend-1.0/`
- added a changelog, build helpers, CI workflow, contributor architecture/testing guidance, and improved README content
