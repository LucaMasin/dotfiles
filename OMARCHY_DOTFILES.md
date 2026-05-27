# Omarchy Dotfiles

Use `scripts/omarchy-dotfiles.sh` to selectively apply dotfiles on Omarchy without overwriting the full Omarchy setup.

The script is driven by `dotfiles-manifest.conf`. To add a new package later, add one line to that manifest instead of changing the script.

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
