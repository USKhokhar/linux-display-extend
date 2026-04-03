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

## Security Expectations For Contributors

Contributors should preserve and improve the current security posture:

- do not reintroduce config sourcing as executable shell
- do not restore unauthenticated VNC as the default path
- do not add remote self-update execution from mutable branch state
- validate all user-supplied values before using them in shell commands
- prefer least privilege and explicit opt-in for insecure behavior
