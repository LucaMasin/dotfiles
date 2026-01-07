# AGENTS.md — repo-specific instructions for coding agents

This repository is a personal **dotfiles** repo (shell, Neovim, i3, polybar, etc.).
Most “build/test” workflows are *lint/format/sanity checks* rather than compiled builds.

If you add new tooling, keep it optional and documented here.

## Repo layout

- `README.md`: high-level usage.
- `auto_install.sh`: bootstrap script used by `curl | sh` install.
- `setup_scripts/`: scripts to install/configure packages.
- `.config/`: application configs (Neovim, i3, polybar, alacritty, etc.).
- `scripts/`: small helper scripts.

## Rules files

- Cursor rules: none found (`.cursor/rules/` and `.cursorrules` missing).
- Copilot rules: none found (`.github/copilot-instructions.md` missing).

If these get added later, *mirror the important constraints* into this file.

## Build / lint / test (practical)

This repo doesn’t have a unified build system. Use focused checks.

### Shell scripts

- Syntax check: `bash -n path/to/script.sh`
- Lint (if installed): `shellcheck path/to/script.sh`
- Format (if installed): `shfmt -w path/to/script.sh`

### Neovim config

- Headless start (sanity check): `nvim --headless "+qa"`
- Minimal Lua eval: `nvim --headless "+lua print('ok')" +qa`

### Repo hygiene

- Search: `rg "pattern"`
- Changes: `git diff` and `git status --porcelain=v1`

## Single-check equivalents

There’s no formal test suite; use these “single target” checks:

- Shell: `bash -n file.sh` (+ `shellcheck file.sh`)
- i3: reload on live system: `i3-msg reload`
- polybar: restart on live system

Only run system-modifying scripts (`setup_scripts/**`) if the user explicitly asks.

## Code style guidelines

### General principles

- Prefer **small, reviewable diffs**: change only what’s needed.
- Keep scripts **idempotent** where practical (safe to re-run).
- Avoid introducing new dependencies unless necessary.

### Shell (bash) conventions

- **Shebang:** use `#!/usr/bin/env bash` for bash scripts.
- **Strict mode (new scripts):** `set -euo pipefail`; add `IFS=$'\n\t'` only when splitting.
- **Quoting:** always quote expansions: `"$var"`.
- **Arrays:** prefer arrays over word-splitting; avoid `for x in $(...)`.
- **Functions:** `snake_case` names; keep functions small and single-purpose.
- **Naming:** `UPPER_SNAKE` for env/exported vars; `lower_snake` for locals.
- **Conditionals:** use `[[ ... ]]` over `[ ... ]` in bash.
- **Pipelines:** prefer explicit error checks if not using `pipefail`.
- **Exit early:** validate inputs at the start; return non-zero on error.

### Error handling

- Check command success explicitly or rely on `set -e`.
- Prefer informative messages to stderr:
  - `echo "error: message" >&2`
- Use helper functions for consistent failures in larger scripts:
  - `die() { echo "error: $*" >&2; exit 1; }`

### Naming & files

- Script files: `kebab-case.sh` or existing convention in that folder.
- Variables: `UPPER_SNAKE` for environment/exported vars; `lower_snake` for locals.
- Prefer consistent directory names already present (`setup_scripts`, `scripts`).

### Imports / sourcing

- Prefer explicit paths when sourcing:
  - `source "${BASH_SOURCE[0]%/*}/relative.sh"`
- Avoid sourcing user-local files unless required.

### Neovim / Lua conventions

- Keep Neovim config changes localized under `.config/nvim/**`.
- Prefer `require("...")` modules over `dofile`.
- Respect Lua LS settings in `.config/nvim/lua/.luarc.json`.
- Keep plugin config consistent with the existing style in `.config/nvim/lua/plugins/**`.

### Config files (i3/polybar/alacritty/etc.)

- Maintain existing indentation and ordering.
- Avoid mass reformatting; only touch lines needed for the requested change.

## Safety notes (important)

- **Do not** run scripts that use `sudo` unless asked.
- **Do not** assume a specific distro or package manager unless the script’s
  directory indicates it (e.g. `setup_scripts/auto_setup/ubuntu/**`).
- Avoid commands that alter user login shells, SSH keys, or system services
  unless explicitly requested.

## When adding new automation

If you add a repo-wide workflow, prefer one of:

- `Makefile` with `make lint`, `make fmt`, `make test`
- `justfile` with `just lint`, `just fmt`, `just test`

And update this file with exact commands, including a “single test” invocation.
