# Security Policy

## Supported Security Scope

Security-sensitive areas of this project include:

- installer behavior
- update behavior
- config parsing
- shell command construction
- network exposure of the VNC service
- process ownership and cleanup

## Reporting A Vulnerability

Please do not open a public GitHub issue for a suspected security vulnerability.

Instead, report it privately to the maintainer via [mail](contact.uskhokhar@gmail.com). Include:

- a description of the issue
- affected files or commands
- reproduction steps
- impact assessment
- any suggested mitigation

## Known Security Tradeoffs

### VNC password storage

When the tool generates or sets a VNC password, two files are created:

- `~/.config/linux-display-extend/vnc.pass` -- DES-encrypted by x11vnc (used for authentication)
- `~/.config/linux-display-extend/connection.secret` -- plaintext copy (used for password recovery)

Both files are created with mode 600 (owner-only read/write). The plaintext file exists because x11vnc's DES encryption is one-way and there is no built-in recovery mechanism. On shared machines, any process running as the same user can read the plaintext file.

This is a conscious UX tradeoff for a LAN-oriented tool. If you need stronger guarantees, delete `connection.secret` after noting the password, or use `--insecure-lan` with network-level access controls instead.

### VNC traffic is not encrypted

x11vnc transmits display content and input events in the clear over the network. The "password" mode authenticates the initial connection but does not encrypt the stream.

For untrusted networks, tunnel VNC through SSH:

```bash
# On the client machine:
ssh -L 5900:localhost:5900 user@linux-host
# Then connect your VNC client to localhost:5900
```

### Installer integrity

When the installer downloads from GitHub (remote install), it verifies SHA256 checksums against a `SHA256SUMS` file if one is available at the same URL path. If the checksum file is missing (pre-release branches), verification is skipped with a warning.

For maximum security, clone the repository and install from a local checkout:

```bash
git clone https://github.com/USKhokhar/linux-display-extend
cd linux-display-extend
bash universal_installer.sh
```

## Security Expectations For Contributors

Contributors should preserve and improve the current security posture:

- do not reintroduce config sourcing as executable shell
- do not restore unauthenticated VNC as the default path
- do not add remote self-update execution from mutable branch state
- validate all user-supplied values before using them in shell commands
- prefer least privilege and explicit opt-in for insecure behavior
