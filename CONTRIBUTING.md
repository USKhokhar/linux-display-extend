# Contributing to Linux Display Extend

Thank you for contributing. This project is now maintained as an X11-first open source tool, and we want contributions to stay secure, testable, and easy for the next contributor to understand.

This guide focuses on three things:

1. how the project works
2. how to approach changes safely
3. how to test your work before it reaches GitHub

## Project Principles

Contributors should optimize for:

- one source of truth
- secure defaults
- X11 accuracy over vague platform promises
- small, reviewable changes
- open-source-friendly maintenance

Before making changes, read:

- `.agent/AGENT.md`
- `.agent/CAVEATS.md`
- `.agent/IMPROVEMENTS.md`
- `docs/ARCHITECTURE.md`
- `docs/TESTING.md`
- `CODE_OF_CONDUCT.md`
- `SECURITY.md`

## Support Model

This project currently supports:

- Linux hosts
- X11 desktop sessions
- `xrandr` plus `x11vnc`

This project does not currently support:

- Wayland sessions
- multi-device layouts
- broad distro claims without validation

Do not widen the project promise in code or docs unless the implementation and testing truly support it.

## Architecture Foundation

The current architecture is intentionally centered around one maintained runtime and two thin release entrypoints.

### Canonical files

- `scripts/display-extend.sh`
  The runtime source of truth. All CLI, config, diagnostics, state handling, and X11 orchestration should converge here or in modules created from here.

- `universal_installer.sh`
  The canonical installer. It is responsible for dependency installation, runtime installation, config bootstrap, and desktop entry creation.

- `display_extend_package.sh`
  The canonical package tree builder. It should generate package content from maintained source files, not from stale copied scripts.

### Compatibility wrappers

- `installer/universal_installer.sh`
- `installer/display_extend_package.sh`

These exist only as wrappers to preserve older paths. Do not add logic here unless it is wrapper-specific.

### Runtime flow

1. Load safe config values from `~/.config/linux-display-extend/config`.
2. Validate session, dependencies, and X11 assumptions.
3. Pick the main monitor and target disconnected output.
4. Generate a modeline and attach the virtual output with `xrandr`.
5. Calculate the correct clip geometry for the new display region.
6. Launch `x11vnc` with owned state files, logs, and authentication settings.
7. Stop only the process and output that this tool created.

### State model

The runtime uses XDG-style directories:

- config: `~/.config/linux-display-extend`
- state: `~/.local/state/linux-display-extend`
- logs: `~/.local/state/linux-display-extend/display-extend.log`

This is important. Do not regress back to broad `pkill` patterns or shell-sourced config files.

## Working Rules for Contributors

### Edit the right files

- Make runtime behavior changes in `scripts/display-extend.sh`.
- Make installation changes in `universal_installer.sh`.
- Make package generation changes in `display_extend_package.sh`.
- Treat `installer/` as wrappers.
- Do not reintroduce inline duplicate copies of the runtime script.

### Preserve secure defaults

- Password-authenticated VNC should remain the default.
- Do not restore silent remote self-update behavior.
- Do not source user config as shell.
- Do not kill unrelated processes.

### Keep X11 assumptions explicit

- If a feature is X11-only, say so clearly.
- If a change would require Wayland support, design it intentionally instead of slipping in partial behavior.

### Prefer maintainability over cleverness

- Use focused shell functions.
- Keep validation explicit.
- Keep user output actionable.
- Add comments only for non-obvious logic.

## Recommended Development Workflow

1. Fork the repository and create a branch such as `fix/<topic>` or `feature/<topic>`.
2. Read the architecture and testing docs before changing behavior.
3. Make the smallest coherent change that solves the problem.
4. Run formatting, linting, and tests locally.
5. Perform a real environment test on Linux before opening a PR.
6. Update docs in the same change when behavior changes.
7. Open a PR with a clear summary, test notes, and any known limitations.

## Local Quality Checks

Use the provided Make targets where possible:

```bash
make test
make package
```

If you have the tools installed locally, also run:

```bash
shellcheck scripts/display-extend.sh universal_installer.sh display_extend_package.sh
shfmt -w scripts/display-extend.sh universal_installer.sh display_extend_package.sh
```
## Testing Your Changes

Before opening a PR, run local quality checks and validate your changes on a real Linux X11 environment. See `docs/TESTING.md` for detailed testing procedures for your development platform (Linux, macOS, or Windows).

Quick checklist:

- Run `make test` locally
- Install and test on Linux with X11
- Verify with `display-extend doctor`, `start`, `status`, and `stop`
- Connect a VNC client to confirm display behavior
- Record your test environment and results in the PR description


## Pull Request Expectations

Your PR description should include:

- what problem you solved
- what files are the source of truth for the change
- how you tested it
- which Linux environment you tested on
- any known limitations or follow-up work

If your change affects user-facing behavior, update the docs in the same PR.

## Reporting Bugs and Requesting Features

Please use the GitHub issue templates and include:

- Linux distribution and version
- whether the session is X11 or Wayland
- output of `display-extend doctor`
- output of `display-extend status`
- relevant log excerpts from `display-extend logs`
- `xrandr --query` output when the issue is display-related

If the report is security-sensitive, follow `SECURITY.md` instead of opening a public issue.

## Community Standards

- Be respectful and constructive.
- Assume good intent.
- Prefer evidence over guesswork.
- Keep the project maintainable for people other than the original author.

Thank you for helping make Linux Display Extend stronger for both users and maintainers.
