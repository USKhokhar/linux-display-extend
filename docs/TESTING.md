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

macOS is a valid development host, but not a valid final runtime host for this project. The runtime must be validated on Linux before opening a PR.

#### Recommended setup options

- a physical Linux laptop or desktop on your local network
- a dedicated Linux workstation you can access with SSH
- a VM only if it provides a real graphical Linux X11 session and usable display outputs

#### macOS-side preparation

1. Develop in your normal macOS editor or terminal.
2. Run the non-runtime checks locally when possible:
   - `make test`
   - `bash -n scripts/display-extend.sh universal_installer.sh display_extend_package.sh`
3. Confirm your changes are committed or otherwise easy to sync to Linux.

#### Syncing your work to Linux

Use one of these approaches:

- push your branch to your fork and pull it on Linux
- use `scp` or `rsync` to copy the repo to Linux
- use Remote SSH from your editor into the Linux machine and work there directly

If you use Git:

```bash
git push origin <your-branch>
```

Then on Linux:

```bash
git clone <your-fork-url>
cd linux-display-extend
git checkout <your-branch>
```

#### Linux-side validation flow

Once the code is on Linux:

1. Confirm the Linux session is X11, not Wayland.
2. Confirm the machine has the required tools or install them.
3. From the repo root, run:

```bash
make test
bash universal_installer.sh --skip-deps
display-extend doctor
display-extend start
display-extend status
display-extend logs
display-extend stop
```

4. Connect from an Android device or another client while the session is running.
5. If your change affects config or CLI behavior, also test:

```bash
display-extend config
display-extend --help
display-extend set-password
```

#### What to verify on Linux

- the tool clearly reports X11 requirements
- the chosen monitor and output are sensible
- the configured resolution and position are honored
- the VNC client can connect successfully
- the password/auth flow behaves as expected
- `status` reports the owned session correctly
- `stop` only stops the session created by this tool
- logs are written to the expected XDG state path

#### Useful macOS to Linux workflow notes

- If you are iterating quickly, Remote SSH into the Linux box is usually the smoothest option.
- If you are using a VM hosted on another system, make sure the VM really exposes a usable graphical desktop session before trusting the result.
- Do not mark runtime changes as tested if you only ran the smoke checks on macOS.

### Windows developer testing on Linux

Windows is also a valid development host, but the real runtime validation still has to happen on Linux.

#### Recommended setup options

- Windows editor plus a separate physical Linux machine
- WSL for local shell-based checks plus a separate Linux runtime target
- a Linux VM only if it provides a real X11 desktop session and usable display outputs

#### Windows-side preparation

You can develop in:

- your normal Windows editor
- Git Bash
- WSL

Before moving to Linux, run whichever local checks your environment supports:

```bash
make test
```

If you are using WSL or Git Bash, also run:

```bash
bash -n scripts/display-extend.sh universal_installer.sh display_extend_package.sh
```

These checks are useful, but they do not replace Linux runtime validation.

#### Syncing your work to Linux

Use one of these approaches:

- push your branch to your fork and pull it on Linux
- use WSL with SSH to sync to Linux
- use `scp` or `rsync` from WSL
- use Remote SSH from your editor into a Linux host

Typical Git flow:

```bash
git push origin <your-branch>
```

Then on Linux:

```bash
git clone <your-fork-url>
cd linux-display-extend
git checkout <your-branch>
```

#### Linux-side validation flow

After the code is on Linux:

1. Verify the target machine is in an X11 session.
2. Run the repo checks and install flow:

```bash
make test
bash universal_installer.sh --skip-deps
display-extend doctor
display-extend start
display-extend status
display-extend logs
display-extend stop
```

3. Connect from Android or another client to confirm the live display path works.
4. If your change touched configuration, install flow, or auth, also test:

```bash
display-extend config
display-extend set-password
display-extend --help
```

#### What to verify on Linux

- dependency and doctor output are clear
- the runtime starts cleanly on X11
- the chosen output and geometry make sense
- the client can authenticate and connect
- the session can be stopped cleanly without broad side effects
- the logs contain useful diagnostics if startup fails

#### Useful Windows to Linux workflow notes

- WSL is great for shell-quality checks, but it is not the final runtime target for this project.
- If you test through a Linux VM, make sure the VM is not hiding the real display/output behavior you need to verify.
- Do not consider a feature “tested” if it never ran on an actual Linux X11 environment.

## Manual Runtime Checklist

Regardless of whether you develop on Linux, macOS, or Windows, a good pre-PR manual validation should answer all of these:

- Did `display-extend doctor` correctly describe the environment?
- Did `display-extend start` succeed without unexpected errors?
- Could a client connect to the printed host and port?
- Did auth work the way the current config intended?
- Did `display-extend status` reflect the live session accurately?
- Did `display-extend stop` tear down only the owned session?
- If the run failed, did `display-extend logs` explain why?

## FAQ

### The tool says I am on Wayland. How do I switch back to X11 for testing?

This project currently requires an X11 desktop session for real runtime validation.

The exact steps depend on your distro, desktop environment, and display manager, but the common approach is:

1. Log out of your current desktop session.
2. On the login screen, look for a session selector such as a gear icon, desktop/session menu, or settings button.
3. Choose an X11-based session option before logging back in.

Common labels include:

- `GNOME on Xorg`
- `Plasma (X11)`
- `X11`
- `Ubuntu on Xorg`

After logging in again, confirm the session type:

```bash
echo $XDG_SESSION_TYPE
```

You want this to print:

```bash
x11
```

Notes:

- GNOME users on GDM often need to select `GNOME on Xorg` or `Ubuntu on Xorg` from the login screen gear icon.
- KDE Plasma users on SDDM often need to select `Plasma (X11)` from the session chooser.
- Some systems default back to Wayland after reboot or logout, so check again before testing.
- If your machine does not offer any X11 session at login, you may need to install the X11 session package for your desktop environment or test on another Linux machine that provides X11.

For this project, do not count a runtime change as fully tested unless `echo $XDG_SESSION_TYPE` reports `x11`.

## What To Record In A PR

- Linux distro and version
- whether the test session was X11
- command sequence used
- what device or client connected to the VNC stream
- any limitations or environment quirks noticed during testing
