# Testing

## Goal

Contributors should verify both code quality and real runtime behavior before sending changes upstream.

## Fast Local Checks

Run these first:

```bash
make test
```

If you have the tools installed:

```bash
shellcheck scripts/display-extend.sh universal_installer.sh display_extend_package.sh
shfmt -w scripts/display-extend.sh universal_installer.sh display_extend_package.sh
```

## Runtime Validation Matrix

### Linux developer on the same Linux machine

1. Confirm the session is X11.
2. Run `bash universal_installer.sh --skip-deps`.
3. Run `display-extend doctor`.
4. Run `display-extend start`.
5. Connect from Android or another client.
6. Run `display-extend status`.
7. Run `display-extend stop`.

### Linux developer testing on a second Linux machine

1. Push or copy the branch to the target Linux host.
2. Run the installer there.
3. Validate with `doctor`, `start`, `status`, `logs`, and `stop`.
4. Connect from Android or another Linux host.

### macOS developer testing on Linux

1. Develop locally on macOS.
2. Run syntax and smoke tests locally when possible.
3. Sync the branch to a Linux machine over Git or SSH.
4. Do all real display validation on Linux.

### Windows developer testing on Linux

1. Develop on Windows or WSL.
2. Run syntax and smoke tests locally when possible.
3. Push or copy the branch to Linux.
4. Do all real display validation on Linux.

## What To Record In A PR

- Linux distro and version
- whether the test session was X11
- command sequence used
- what device or client connected to the VNC stream
- any limitations or environment quirks noticed during testing
