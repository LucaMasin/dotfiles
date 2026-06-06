# Omarchy Dotfiles

Use these scripts to set up this dotfiles repo on Omarchy without overwriting the full Omarchy desktop setup.

There are two layers:

```text
setup_scripts/auto_setup/omarchy/setup.sh  installs required software, then applies config
scripts/omarchy-dotfiles.sh                applies selected dotfiles config only
```

## Auto Setup

Run this on an Omarchy machine after cloning the repo:

```bash
~/dotfiles/setup_scripts/auto_setup/omarchy/setup.sh
```

The auto setup script installs required packages with `omarchy pkg add`, then runs the default config install:

```bash
~/dotfiles/scripts/omarchy-dotfiles.sh install zsh nvim tmux
```

It also configures Ghostty as the default terminal for `xdg-terminal-exec`, with Alacritty kept as a fallback in `~/.config/xdg-terminals.list`.

It also enables Hyprland's scrolling layout as the default by setting this in `~/.config/hypr/looknfeel.conf`:

```text
layout = scrolling
```

Installed packages:

```text
zsh neovim tmux git fzf ripgrep btop zoxide starship yazi tokei uv python-pipx github-cli ghostty
```

Preview without changing the system:

```bash
~/dotfiles/setup_scripts/auto_setup/omarchy/setup.sh --dry-run
```

If packages are already installed and you only want to apply config:

```bash
~/dotfiles/setup_scripts/auto_setup/omarchy/setup.sh --skip-packages
```

Combine both flags to preview config changes without checking packages:

```bash
~/dotfiles/setup_scripts/auto_setup/omarchy/setup.sh --dry-run --skip-packages
```

## Config Installer

The config installer is driven by `dotfiles-manifest.conf`. To add a new config package later, add one line to that manifest instead of changing the script.

## List Packages

```bash
~/dotfiles/scripts/omarchy-dotfiles.sh list
```

## Preview Changes

Always preview first:

```bash
~/dotfiles/scripts/omarchy-dotfiles.sh --dry-run install zsh nvim tmux
```

## Install Selected Packages

```bash
~/dotfiles/scripts/omarchy-dotfiles.sh install zsh nvim tmux
```

Install every enabled package:

```bash
~/dotfiles/scripts/omarchy-dotfiles.sh install all
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
