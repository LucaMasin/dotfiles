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

Restart your shell after setup. `dot init` creates `~/.local/bin/dot`; the shared shell config adds that directory to PATH and loads completions.

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

Setup uses apt, the GitHub CLI and NodeSource repositories, Snap for Yazi, and user installers. Node.js 24 includes npm. Neovim is built from the latest stable release in `~/repos/neovim`.

The apt package list is in `setup_scripts/setup.sh`. It includes `libnspr4` and `libnss3` for Playwright Chromium. OpenCode uses npm, Herdr uses its official installer, and browser-control is built from source.

To install the optional i3 desktop and its configs:

```bash
dot init --platform ubuntu --desktop i3
```

The i3 option is Ubuntu-only. It applies `i3 polybar alacritty rofi picom` in addition to your selected configs.

## Omarchy

Setup installs native packages with `omarchy pkg add`, builds Neovim, and installs the shared user tools.

Setup also changes these machine settings:

- Sets zsh in `~/.config/uwsm/env` when that file exists.
- Selects Ghostty in `~/.config/xdg-terminals.list`, with Alacritty as fallback.
- Sets Ghostty font size to 10.
- Sets Hyprland monitor scale to 1 and enables the scrolling layout.
- Reloads Hyprland when `hyprctl` is available.

Use `dot apply` for config-only changes. Legacy i3 and Alacritty configs remain disabled by default.

## Raspberry Pi OS

Support requires a Pi 4 or Pi 5, architecture `aarch64`, and OS codename `trixie`.

Setup uses apt and the GitHub CLI and NodeSource repositories. It builds Neovim and installs Yazi using the upstream ARM64 `.deb` through apt. It installs uv, OpenCode, Herdr, and browser-control through their existing user installation paths.

## Browser automation

Use the WSL-local Playwright Chromium, not a personal Windows browser. Install its browser build using an environment with Playwright installed:

```bash
python -m playwright install chromium
~/scripts/browser-control-chromium.sh
browser-control doctor
```

Setup builds browser-control in `~/repos/browser-control` and exposes it through `bun link`. To update it:

```bash
git -C ~/repos/browser-control pull --ff-only
cd ~/repos/browser-control
pnpm install
pnpm build
```

Restart the automation browser afterward to load the rebuilt extension.
