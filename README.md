# Dotfiles

Personal Linux dotfiles for shell, Neovim, tmux, helper scripts, agent skills, and desktop-specific config.

The repo has one setup flow with platform-specific package handling behind it:

```text
auto_install.sh          bootstrap: install git, clone/update repo, run setup
setup_scripts/setup.sh   platform setup: packages/tools, then config
setup_scripts/update.sh  update repo, then re-apply config without packages
scripts/dotfiles.sh      config only: links/sources dotfiles-manifest.conf entries
```

## Quick Start

Bootstrap a supported machine:

```bash
curl -Ss https://raw.githubusercontent.com/LucaMasin/dotfiles/refs/heads/main/auto_install.sh | bash
```

Or, after cloning manually:

```bash
~/dotfiles/setup_scripts/setup.sh
```

`setup.sh` auto-detects the platform when possible. Pass a platform only when you want to override detection:

```bash
~/dotfiles/setup_scripts/setup.sh --platform omarchy
~/dotfiles/setup_scripts/setup.sh --platform ubuntu
~/dotfiles/setup_scripts/setup.sh --platform raspberrypi
```

## Supported Platforms

Omarchy:

- Packages are installed through `omarchy pkg add`.
- Neovim is installed through Omarchy's package flow.
- GitHub CLI is installed as `github-cli`.
- Ghostty, Hyprland scrolling layout, and UWSM zsh preferences are applied when their config files exist.
- Legacy desktop configs such as i3, polybar, rofi, picom, and alacritty are not applied by default.

Ubuntu:

- Base dependencies are installed through apt.
- GitHub CLI is installed from GitHub's official Debian/Ubuntu apt repository.
- Node.js 24 LTS is installed from the NodeSource apt repository, which includes npm.
- Neovim is built from source under `~/repos/neovim` because Ubuntu packages are usually outdated.
- Yazi is installed from Snap with classic confinement.
- opencode2 is installed globally via npm.
- The old i3 desktop stack is opt-in with `--desktop i3`.

Raspberry Pi OS (64-bit, Trixie, Pi 4 or Pi 5):

- Base dependencies are installed through apt, including `starship`, `zoxide`, `tokei`, and `fd-find`.
- GitHub CLI is installed from GitHub's official apt repository.
- Node.js 24 is installed from the NodeSource apt repository, which includes npm.
- Neovim is built from source under `~/repos/neovim`.
- Yazi is installed from the upstream `aarch64` `.deb` release asset.
- `uv` is installed via the Astral installer script.
- opencode2 is installed globally via npm.
- Platform detection requires a Raspberry Pi 4 or Pi 5, `aarch64`, and `/etc/os-release` codename `trixie`.

## Common Commands

Preview the full setup:

```bash
~/dotfiles/setup_scripts/setup.sh --dry-run
```

Apply configs without installing packages:

```bash
~/dotfiles/setup_scripts/setup.sh --skip-packages
```

Pull the repo and re-apply config links/source blocks:

```bash
~/dotfiles/setup_scripts/update.sh
```

The repo does not use GNU stow anymore; `scripts/dotfiles.sh` manages symlinks from `dotfiles-manifest.conf`.

Install only selected config packages:

```bash
~/dotfiles/setup_scripts/setup.sh --skip-packages --configs zsh,nvim,tmux
```

Install the optional Ubuntu i3 desktop stack:

```bash
~/dotfiles/setup_scripts/setup.sh --platform ubuntu --desktop i3
```

## Config Installer

Use the config installer directly when packages are already handled:

```bash
~/dotfiles/scripts/dotfiles.sh list
~/dotfiles/scripts/dotfiles.sh --dry-run install zsh nvim tmux
~/dotfiles/scripts/dotfiles.sh install zsh nvim tmux scripts agents opencode
~/dotfiles/scripts/dotfiles.sh install all
```

Config packages are declared in `dotfiles-manifest.conf`:

```text
name|type|source|target|enabled|description
```

Supported types:

```text
link    symlink source to target, backing up an existing target first
source  insert a managed source block into an existing shell rc file
```

Backups go to:

```text
~/.local/state/dotfiles-backup/<timestamp>/
```

## Default Configs

The top-level setup applies these configs by default:

- `zsh`: sources `zsh_config` and `shell_config` from `~/.zshrc`.
- `nvim`: links `.config/nvim` to `~/.config/nvim`.
- `tmux`: links `.tmux.conf` and installs tmux plugins with TPM.
- `scripts`: links repo helper scripts to `~/scripts`.
- `agents`: links agent skills to `~/.agents`.

## Ubuntu and Raspberry Pi Neovim Build

On Ubuntu and Raspberry Pi OS, setup installs build dependencies, then clones or updates Neovim in `~/repos/neovim` and runs:

```bash
make -C ~/repos/neovim CMAKE_BUILD_TYPE=Release
sudo make -C ~/repos/neovim install
```

## More Details

See `SETUP.md` for lower-level examples and manifest details.
