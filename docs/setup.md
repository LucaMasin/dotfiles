# Set up a machine

## Bootstrap

```bash
curl -fsSL https://raw.githubusercontent.com/LucaMasin/dotfiles/main/auto_install.sh | bash
```

Bootstrap installs Git if missing, clones or fast-forwards `~/dotfiles`, then runs `dot init`.

To pass options through bootstrap:

```bash
curl -fsSL https://raw.githubusercontent.com/LucaMasin/dotfiles/main/auto_install.sh | bash -s -- --platform ubuntu --dry-run
```

A bootstrap dry-run prints the clone and setup actions without fetching the repo or installing Git. Use `./dot init --dry-run` inside an existing clone for a detailed setup preview.

## Use an existing clone

```bash
cd ~/dotfiles
./dot init --dry-run
./dot init
```

Restart your shell after setup. `dot init` creates `~/.local/bin/dot`; the shared shell config adds that directory to PATH and loads completions. `dot init` also sets zsh as your login shell with `chsh` (you may be prompted for a password); log out and back in for it to take effect.

Use `--platform ubuntu`, `--platform omarchy`, or `--platform raspberrypi` only when detection needs an override.

## Select configs or skip packages

```bash
./dot init --skip-packages
./dot init --configs nvim,tmux
dot apply nvim tmux
```

`init --configs` selects configs, not system packages. It still installs the platform's full tool set unless you pass `--skip-packages`.

`init --skip-packages` still applies platform-specific machine settings. `apply` does not change those settings.

## Ubuntu

Setup uses apt, the GitHub CLI and NodeSource repositories, Snap for Yazi and Obsidian, and user installers. Node.js 24 includes npm. Neovim is built from the latest stable release in `~/repos/neovim`.

The apt package list is in `setup_scripts/setup.sh`. It includes `libnspr4` and `libnss3` for Playwright Chromium. OpenCode, Pi, and Claude Code use npm, Herdr and Tailscale use their official installers, and browser-control is built from source. Tailscale also enables `tailscaled` via systemd.

To install the optional i3 desktop and its configs:

```bash
dot init --platform ubuntu --desktop i3
```

The i3 option is Ubuntu-only. It applies `i3 polybar alacritty rofi picom` in addition to your selected configs.

## Omarchy

Setup installs native packages with `omarchy pkg add` (including `tailscale`), builds Neovim, and installs the shared user tools. It enables `tailscaled` via systemd.

Setup also changes these machine settings:

- Sets zsh in `~/.config/uwsm/env` when that file exists.
- Selects Ghostty in `~/.config/xdg-terminals.list`, with Alacritty as fallback.
- Sets Ghostty font size to 10.
- Sets Hyprland monitor scale to 1 and enables the scrolling layout.
- Reloads Hyprland when `hyprctl` is available.

Use `dot apply` for config-only changes. Legacy i3 and Alacritty configs remain disabled by default.

## Raspberry Pi OS

Support requires a Pi 4 or Pi 5, architecture `aarch64`, and OS codename `trixie`.

Setup uses apt and the GitHub CLI and NodeSource repositories. It builds Neovim and installs Yazi using the upstream ARM64 `.deb` through apt. It installs uv, OpenCode, Pi, Claude Code, Herdr, and browser-control through their shared user installation paths. It installs Tailscale with the official installer and enables `tailscaled` via systemd.

## AI coding tools

All supported platforms install OpenCode, the [Pi coding agent](https://github.com/earendil-works/pi), and Claude Code by default. Missing commands are installed with npm without sudo. A prefix outside your home is changed to `~/.npm-global`, which the shared shell config adds to PATH. Pi uses `--ignore-scripts`, as recommended upstream; OpenCode and Claude Code pass `--allow-scripts` for their own postinstall steps. Existing commands are left alone, and `--skip-packages` skips these installs.

The default `opencode` config includes [`@openchamber/opencode-claude@1.4.1`](https://github.com/openchamber/opencode-claude). OpenCode V2 loads the plugin and its Claude Agent SDK dependency. Requests go through the local `claude` CLI using your Claude subscription. Your existing OpenCode default and agent models do not change.

To roll this out after these changes have been pushed, run on each machine:

```bash
cd ~/dotfiles
git pull --ff-only
./dot init --dry-run
./dot init
```

`dot init` runs the full platform setup, including machine settings on Omarchy. `dot update` only pulls and applies configs; it does not install missing tools. If Pi and Claude Code are already installed, `dot update` is enough to deploy the plugin config.

### Authenticate after init

Restart your shell, then sign in on each machine:

```bash
pi --version
claude --version
claude auth login --claudeai
claude auth status
```

Restart OpenCode to load the plugin, then select a model under **Claude Code**. The model list comes from your local Claude CLI and account. In Pi, use `/login` to connect a provider.

Claude credentials and Pi credentials stay local. Do not copy them into this repo. The plugin requires a Claude plan; Console API keys, Bedrock, and Vertex are not supported. Use OpenCode's built-in Anthropic provider for API keys. Requests count toward your plan's limits. Keep the plugin's loopback proxy private; do not expose it through Tailscale Serve. See the upstream [terms and setup notes](https://github.com/openchamber/opencode-claude#terms-of-use-read-this-first).

## Tailscale

`dot init` installs Tailscale on all platforms (official installer on Ubuntu/Raspberry Pi OS, `omarchy pkg add tailscale` on Omarchy) and enables `tailscaled`. Login stays manual per machine:

```bash
sudo systemctl enable --now tailscaled
sudo tailscale up --ssh
tailscale status
tailscale ip -4
```

Approve the printed login URL in the browser. If it expires, run `sudo tailscale up --ssh` again. `dot doctor` checks for `tailscale`; upgrade it with the system package manager, not `dot upgrade`.

The `--ssh` flag advertises Tailscale SSH on the node. Access itself is granted in the admin console under Access controls (tailnet policy); then connect from another tailnet node with `tailscale ssh <user>@<host>`.

## GitHub CLI

`dot init` installs `gh` on all platforms (apt repo on Ubuntu/Raspberry Pi OS, `github-cli` package on Omarchy). Authentication stays manual per machine:

```bash
gh auth login
gh auth status
```

Use the interactive prompts (GitHub.com, HTTPS, browser login). Credentials stay local, never in this repo. If scopes expire, run `gh auth refresh` or `gh auth login` again.

## Browser automation

Use the WSL-local Playwright Chromium, not a personal Windows browser. Install its browser build using an environment with Playwright installed:

```bash
python -m playwright install chromium
~/scripts/browser-control-chromium.sh
browser-control doctor
```

Setup builds browser-control in `~/repos/browser-control` and exposes it through `bun link`. `dot upgrade browser-control` updates it, or do it manually:

```bash
git -C ~/repos/browser-control pull --ff-only
cd ~/repos/browser-control
pnpm install
pnpm build
```

Restart the automation browser afterward to load the rebuilt extension.
