# AGENTS.md

Personal Linux dotfiles repo. There is no repo-wide build system, CI, or pre-commit config. Run focused shell checks and the isolated CLI tests after installer changes.

## High-Value Files

- `dot`: public CLI (`init`, `update`, `apply`, `list`, `doctor`, `edit`, `link`, `unlink`, `completions`). Resolves its owning checkout through the global symlink.
- `README.md`: lean quick start. `docs/`: setup, commands, config behavior, troubleshooting, and the optional web service. `SETUP.md` is a documentation redirect.
- `docs/brew-migration.md`: future opt-in migration plan. Brew is not implemented; preserve existing installers unless explicitly approved.
- `auto_install.sh`: bootstrap entrypoint for `curl | bash`; installs git, clones/updates `~/dotfiles`, then runs `dot init`. Supports setup flags and a no-write dry-run.
- `setup_scripts/setup.sh`: platform package install plus config application; supports `--platform ubuntu|omarchy|raspberrypi`, `--dry-run`, `--skip-packages`, `--desktop i3`, and `--configs <comma-list>|all`.
- `setup_scripts/update.sh`: delegates to `dot update`, which pulls with `git pull --ff-only` and applies configs without platform desktop changes or package upgrades.
- `scripts/dotfiles.sh`: config-only installer driven by `dotfiles-manifest.conf`; owns default config selection and validates all selections before writing.
- `tests/test_dot.py`: stdlib integration checks in temporary homes under `/tmp/opencode`, with mocked Git, sudo, npm, and Omarchy. No real package installation or home config changes.
- `.config/nvim/init.lua`: Neovim entrypoint; bootstraps `lazy.nvim`, then loads `lua/vim-options.lua` and `lua/plugins/**`.

## Safe Commands

- Preview setup without changing the system: `./dot init --dry-run`.
- Preview config-only install: `./dot apply zsh nvim tmux --dry-run`.
- List manifest configs: `./dot list`; inspect current setup with `./dot doctor` (read-only, nonzero when checks fail).
- Run isolated CLI tests: `python3 -m unittest discover -s tests -v`.
- Check shell syntax after editing scripts: `bash -n path/to/script.sh`.
- If available, lint shell scripts with `shellcheck path/to/script.sh`.
- Neovim sanity check after config edits: `nvim --headless "+qa"`.

## Do Not Run Without Explicit User Approval

- `dot init`, `dot update`, `dot apply`, `dot link`, or `dot unlink` without `--dry-run` against the real home; they modify the system, repo, or home. Isolated test fixtures are safe.
- `auto_install.sh`, `setup_scripts/setup.sh` without `--dry-run`, or `setup_scripts/update.sh` without `--dry-run`; they can install packages, pull the repo, modify home-directory config, or run `sudo`.
- `scripts/dotfiles.sh install ...` without `--dry-run`; it creates symlinks, edits shell rc files, backs up targets, and installs tmux plugins.
- `setup_scripts/generate_github_ssh.sh`; it touches SSH/GitHub credentials.
- `setup_scripts/opencode_web.sh enable` or `disable` without `--dry-run`; it writes credentials, installs/starts a user systemd service, enables systemd lingering, and configures Tailscale Serve.

## Config Installer Facts

- `dotfiles-manifest.conf` is the source of truth for installable config packages: `name|type|source|target|enabled|description`.
- Supported manifest types are `link` for symlinks and `source` for managed source blocks.
- Default setup applies `zsh nvim tmux herdr scripts agents opencode starship`; `dot apply all` installs enabled configs only. WezTerm stays enabled but outside defaults.
- Existing targets are backed up under `${XDG_STATE_HOME:-~/.local/state}/dotfiles-backup/<timestamp>.<unique-suffix>/` before replacement or source-block rewrite. Unchanged source blocks are no-ops; rc permissions are preserved. Symlinked rc files and malformed markers are rejected.
- TPM installs under `~/.config/tmux/plugins/tpm`; selecting tmux installs its plugins. Config application does not reload running applications.
- `dot init --skip-packages` still changes platform machine settings; `dot apply` and `dot update` do not. Dry-runs perform no writes or package installs.
- `dot link` refuses foreign targets in `~/.local/bin/dot`; PATH may still resolve another `dot` (such as Graphviz), which doctor reports.
- Disabled desktop configs (`alacritty`, `i3`, `polybar`, `picom`, `rofi`, `zathura`) are documented in the manifest; enable there or use `--force-disabled` only intentionally.
- `opencode-web` links the opt-in OpenCode web server user unit; it is disabled in the manifest and activated only via `setup_scripts/opencode_web.sh enable`, which force-installs it, writes credentials to `~/.config/opencode/server.env` (mode 600), enables linger, and configures a tailnet-only Tailscale Serve endpoint on HTTPS 443 (loopback bind `127.0.0.1:4097`). `enable` also retires the beta-era `opencode2-web` unit and legacy Serve endpoints.
- Ubuntu i3 setup is opt-in via `setup_scripts/setup.sh --platform ubuntu --desktop i3`, which force-installs the disabled legacy desktop configs.
- Agent skills under `.agents/skills/` are vendored from `https://github.com/backnotprop/pstack` (pinned at `157aae3`), the harness-neutral mirror of `cursor/plugins/pstack` with OpenCode support. 44 of its 45 skills are synced; `tdd` keeps the local dmmulroy version (`SKILL.md`, `agents/`, `mocking.md`, `tests.md`). Local-only skills (`browser-control`, `code-review`, `datastar`, `diagnose-crash`, `find-skills`, `frontend-design`, `handoff`, `python-design-patterns`, `research`, `show-me`, `skill-creator`, `uv`, `writing-for-agents`) are never deleted by a sync. Resync with `git clone --depth 1 https://github.com/backnotprop/pstack.git /tmp/opencode/pstack-upstream` then `rsync -a --delete` per skill except `tdd`, and record the new pin here.
- GPUI skills (`gpui-*`, 11 skills) are vendored from `https://github.com/cnwzhu/gpui-skills` (pinned at `393a3da`) directly into `.agents/skills/`, skipping its Claude-only `.claude-plugin/` metadata. They are harness-neutral (`name:`/`description:` frontmatter + `SKILL.md`) and load like any other skill. Never delete `gpui-*` during a pstack resync. Resync with `git clone --depth 1 https://github.com/cnwzhu/gpui-skills.git /tmp/opencode/gpui-skills-upstream` then copy `gpui-*/` dirs over, and record the new pin here.
- `setup-pstack` writes `~/.agents/pstack-models.md` outside Cursor (not `~/.cursor/rules/pstack-models.mdc`); pstack skills read it at task start.
- `.config/opencode/opencode.jsonc` adds a `poteto` primary agent beside `build`/`plan` with the same `subagent:implement` permission as `build`; agent models are V2 `provider/model#variant` references (`build`/`explore`/`scout`: `opencode-go/muse-spark-1.3-contributor#xhigh`, `poteto`/`plan`: `openai/gpt-6.1-sol#medium`, `general`/`implement`: `opencode-go/deepseek-v4.1-flash#max`), root default `opencode-go/muse-spark-1.3-contributor`.

## Platform Gotchas

- Platform detection is executable, not doc-only: Omarchy is detected by `command -v omarchy`; Ubuntu by `/etc/os-release` `ID=ubuntu`; Raspberry Pi by `/proc/device-tree/model` matching Pi 4 or Pi 5, `uname -m` equal to `aarch64`, and `/etc/os-release` codename `trixie`.
- Ubuntu setup installs apt packages including `libnspr4` and `libnss3` for Playwright Chromium, configures the GitHub CLI and NodeSource apt repos, builds Neovim from source in `~/repos/neovim`, installs Yazi via Snap, installs opencode via npm (`@opencode/cli`, switching to a user-owned `~/.npm-global` prefix if the default points outside `$HOME`, so the install does not need sudo), installs Herdr via `https://herdr.dev/install.sh`, installs other user tools via curl/cargo/pipx, then applies configs.
- Raspberry Pi OS setup (64-bit Trixie only, Pi 4 or Pi 5) installs apt packages including `starship`, `zoxide`, `tokei`, `fd-find`, `libnspr4`, and `libnss3`, configures the GitHub CLI and NodeSource apt repos, builds Neovim from source in `~/repos/neovim`, installs Yazi from the upstream `aarch64` `.deb` release asset through apt so dependencies resolve, installs opencode via npm (`@opencode/cli`, switching to a user-owned `~/.npm-global` prefix if the default points outside `$HOME`, so the install does not need sudo), installs Herdr via `https://herdr.dev/install.sh`, and installs `uv` via the Astral installer script.
- Omarchy setup uses `omarchy pkg add` (including `nodejs`/`npm` plus `nspr`/`nss` for Playwright Chromium), installs opencode via npm (`@opencode/cli`, switching to a user-owned `~/.npm-global` prefix if the default points outside `$HOME`, so the install does not need sudo), installs Herdr via `https://herdr.dev/install.sh`, then may update `~/.config/uwsm/env`, write `~/.config/xdg-terminals.list`, set Ghostty's font size, edit `~/.config/hypr/monitors.lua` and `looknfeel.lua`, and run `hyprctl reload`.
- Omarchy intentionally leaves legacy Alacritty/i3/polybar/rofi/picom configs disabled because Omarchy/Hyprland manages those defaults.
- Browser control drives the WSL-local Playwright Chromium only; never load its extension in the Windows browser or attach personal tabs. It is built from source in `~/repos/browser-control` (`bun link` into `~/.bun/bin`, on `PATH` via `shell_config`); start the automation browser click-free with `~/scripts/browser-control-chromium.sh`, and update with `git -C ~/repos/browser-control pull --ff-only` followed by `pnpm install && pnpm build` there, then restart the automation browser.

## Editing Conventions

- Keep diffs small and avoid mass-formatting personal config files.
- Keep `README.md` lean and point to `docs/README.md` for details. Update the relevant `docs/` pages and `AGENTS.md` when commands, platforms, or safety constraints change.
- For new bash scripts, match existing style: `#!/usr/bin/env bash`, `set -euo pipefail`, `snake_case` functions, quoted expansions, `[[ ... ]]` tests.
- For Neovim changes, keep plugin specs under `.config/nvim/lua/plugins/**`; respect `.config/nvim/lua/.luarc.json` (`vim` global).
- If adding a new config package, prefer one manifest line in `dotfiles-manifest.conf` over hard-coding installer logic.
