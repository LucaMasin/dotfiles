# Dotfiles Setup

Use these scripts to set up this dotfiles repo on Ubuntu or Omarchy without duplicating config logic.

There are two layers:

```text
setup_scripts/setup.sh      installs platform packages, then applies config
scripts/dotfiles.sh         applies selected dotfiles config only
```

## Platform Setup

Run one of these after cloning the repo:

```bash
~/dotfiles/setup_scripts/setup.sh --platform ubuntu
~/dotfiles/setup_scripts/setup.sh --platform omarchy
```

The setup script installs platform packages, then runs the default config install:

```bash
~/dotfiles/scripts/dotfiles.sh install zsh nvim tmux scripts agents
```

On Ubuntu, Neovim is built from source under `~/repos/neovim` instead of installed from apt.

On Omarchy, setup also configures Ghostty as the default terminal for `xdg-terminal-exec`, with Alacritty kept as a fallback in `~/.config/xdg-terminals.list`.

It also enables Hyprland's scrolling layout as the default by setting this in `~/.config/hypr/looknfeel.conf`:

```text
layout = scrolling
```

Omarchy packages:

```text
zsh neovim tmux git fzf ripgrep btop zoxide starship yazi tokei uv python-pipx github-cli ghostty
```

Preview without changing the system:

```bash
~/dotfiles/setup_scripts/setup.sh --platform omarchy --dry-run
```

If packages are already installed and you only want to apply config:

```bash
~/dotfiles/setup_scripts/setup.sh --platform omarchy --skip-packages
```

Combine both flags to preview config changes without checking packages:

```bash
~/dotfiles/setup_scripts/setup.sh --platform omarchy --dry-run --skip-packages
```

Install the optional Ubuntu i3 desktop stack:

```bash
~/dotfiles/setup_scripts/setup.sh --platform ubuntu --desktop i3
```

## Config Installer

The config installer is driven by `dotfiles-manifest.conf`. To add a new config package later, add one line to that manifest instead of changing the script.

## List Packages

```bash
~/dotfiles/scripts/dotfiles.sh list
```

## Preview Changes

Always preview first:

```bash
~/dotfiles/scripts/dotfiles.sh --dry-run install zsh nvim tmux
```

## Install Selected Packages

```bash
~/dotfiles/scripts/dotfiles.sh install zsh nvim tmux
```

Install every enabled package:

```bash
~/dotfiles/scripts/dotfiles.sh install all
```

## Zsh Shortcuts

The `zsh` package does not replace `~/.zshrc`. It inserts a managed block that sources:

```zsh
~/dotfiles/zsh_config
~/dotfiles/shell_config
```

This enables your zsh plugins, keybindings, aliases, `zoxide`, and shell shortcuts.

## Tmux Plugins

The `tmux` package links `~/.config/tmux/tmux.conf`, installs Tmux Plugin Manager into:

```text
~/.tmux/plugins/tpm
```

Then it runs TPM's plugin installer so plugins from `~/.config/tmux/tmux.conf`, including the Tokyo Night theme, are installed automatically.

If a tmux server is already running, reload the config inside tmux with prefix + `r`, or restart tmux:

```bash
tmux kill-server
```

## Backups

Before replacing an existing real file, directory, or symlink, the script moves it to:

```text
~/.local/state/dotfiles-backup/<timestamp>/
```

## Omarchy Safety

Some packages are documented but disabled in `dotfiles-manifest.conf`, including `alacritty`.

Omarchy's current Alacritty config imports the active Omarchy theme. Replacing it with the old dotfile would bypass Omarchy theme integration, so it is disabled by default.

To enable a disabled package, change its manifest line from `false` to `true`. You can also force one install with `--force-disabled`, but prefer enabling it explicitly so the decision is documented.

## Manifest Format

Each non-comment line uses this format:

```text
name|type|source|target|enabled|description
```

Supported types:

```text
link    symlink source to target
source  add a managed source block to target
```

Example:

```text
ghostty|link|.config/ghostty|~/.config/ghostty|true|Ghostty terminal configuration
```
