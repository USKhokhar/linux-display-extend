# Linux Distribution Support Matrix

`linux-display-extend` currently targets Linux hosts running an X11 session.

This matrix is intentionally conservative. It describes:

- which distributions are currently recognized by the installer
- where manual installation is likely to work
- where support is not currently claimed

Real runtime success depends on more than distro name alone. A machine still needs:

- an X11 desktop session
- required packages such as `xrandr`, `x11vnc`, and `cvt`
- at least one usable connected monitor
- a usable disconnected output path for the extended display workflow

## Support Status Legend

- `Supported by installer`: the distro is explicitly recognized by the current installer and dependency-install command
- `Manual install likely`: the distro is not explicitly listed, but may work with manual package installation and X11 validation
- `Not currently claimed`: we are not currently claiming support

## Support Matrix

| Distribution | Support Status | Notes |
| --- | --- | --- |
| Ubuntu | Supported by installer | `apt`-based path is implemented. Requires X11. Wayland is not supported. Runtime still depends on usable outputs and required packages. |
| Debian | Supported by installer | `apt`-based path is implemented. Requires X11. Wayland is not supported. Runtime still depends on usable outputs and required packages. |
| Linux Mint | Supported by installer | `apt`-based path is implemented. Requires X11. Wayland is not supported. Runtime still depends on usable outputs and required packages. |
| Pop!_OS | Supported by installer | `apt`-based path is implemented. Requires X11. Wayland is not supported. Runtime still depends on usable outputs and required packages. |
| Elementary OS | Supported by installer | `apt`-based path is implemented. Requires X11. Wayland is not supported. Runtime still depends on usable outputs and required packages. |
| Fedora | Supported by installer | `dnf`-based path is implemented. Requires X11. Wayland is not supported. Runtime still depends on usable outputs and required packages. |
| CentOS | Supported by installer | `yum`-based path is implemented. Requires X11. Wayland is not supported. Runtime still depends on usable outputs and required packages. |
| RHEL | Supported by installer | `yum`-based path is implemented. Requires X11. Wayland is not supported. Runtime still depends on usable outputs and required packages. |
| Rocky Linux | Supported by installer | `yum`-based path is implemented. Requires X11. Wayland is not supported. Runtime still depends on usable outputs and required packages. |
| AlmaLinux | Supported by installer | `yum`-based path is implemented. Requires X11. Wayland is not supported. Runtime still depends on usable outputs and required packages. |
| Arch Linux | Supported by installer | `pacman`-based path is implemented. Requires X11. Wayland is not supported. Runtime still depends on usable outputs and required packages. |
| Manjaro | Supported by installer | `pacman`-based path is implemented. Requires X11. Wayland is not supported. Runtime still depends on usable outputs and required packages. |
| EndeavourOS | Supported by installer | `pacman`-based path is implemented. Requires X11. Wayland is not supported. Runtime still depends on usable outputs and required packages. |
| openSUSE Leap | Supported by installer | `zypper`-based path is implemented. Requires X11. Wayland is not supported. Runtime still depends on usable outputs and required packages. |
| openSUSE Tumbleweed | Supported by installer | `zypper`-based path is implemented. Requires X11. Wayland is not supported. Runtime still depends on usable outputs and required packages. |

## Manual Install Likely

Some related distributions may also work if they are close to one of the supported package-manager families above, but we are not claiming them as officially supported until they are explicitly validated and added to the installer logic.

If you want to try a distro outside the table above:

1. install the required runtime packages manually
2. run `display-extend doctor`
3. run `display-extend install-deps` only if your distro is explicitly recognized
4. validate the full runtime flow on X11

## What Support Means

Installer support does not mean guaranteed success on every version, desktop environment, or hardware configuration.

It means:

- the installer recognizes the distro family
- the dependency-install path is defined
- the distro is in scope for X11-based testing and issue triage

It does not mean:

- Wayland support
- guaranteed success on every desktop environment
- guaranteed success on every graphics stack or monitor/output configuration

Before relying on a distro setup, run:

```bash
display-extend doctor
display-extend install-deps
```

Then follow the Linux validation steps in [docs/TESTING.md](docs/TESTING.md).

If you hit a distro-specific issue, please use the GitHub issue templates and include:

- distro and version
- whether the session is X11 or Wayland
- `display-extend doctor` output
- `display-extend status` output
- relevant `display-extend logs` output
- `xrandr --query` output for display-related problems
