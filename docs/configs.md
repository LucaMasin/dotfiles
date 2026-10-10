# Config installer reference

## Manifest

`dotfiles-manifest.conf` declares each config:

```text
name|type|source|target|enabled|description
```

`link` creates a symlink. `source` manages a named block in a shell rc file. Sources without `/` or `~` are relative to the repo. Targets beginning with `~` resolve under the current home directory.

The default selection is `zsh nvim tmux herdr scripts agents opencode starship`, defined in `scripts/dotfiles.sh`. It is intentionally smaller than the set of enabled configs. `wezterm` remains enabled but is installed only when selected or included through `all`.

Disabled configs require explicit opt-in. `opencode-web` uses its dedicated service installer. The legacy desktop configs stay disabled unless you select Ubuntu i3 setup, enable their manifest entries, or explicitly use `--force-disabled`.

## Links

Already-correct links remain unchanged. Other existing targets are moved into backups before replacement. Linked file edits take effect in the target immediately; applications may still need a reload.

Config names and sources are validated before applying any selected config. Repeated names are applied once. Runtime failures such as disk errors can still leave a partially applied selection.

## Source blocks

The zsh config inserts this block without replacing unrelated rc content:

```text
# >>> dotfiles managed: zsh
... source commands for zsh_config and shell_config ...
# <<< dotfiles managed: zsh
```

An identical block is a no-op. An updated block stays in its existing position. Existing file permissions are preserved. A new rc file has private permissions from `mktemp`.

Missing, nested, duplicate, or unmatched markers prevent changes. A symlinked rc file is rejected rather than silently replaced. Resolve that conflict manually before applying zsh.

## Backups

Conflicting targets and changed rc files are backed up under:

```text
${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles-backup/<timestamp>.<unique-suffix>/
```

Each installer invocation allocates a unique directory only when a backup is needed. Backups preserve target paths relative to home. Existing entries are never overwritten. Concurrent installers should not write the same home directory.

## Tmux

The installer links `~/.config/tmux/tmux.conf`, clones TPM into `~/.config/tmux/plugins/tpm` if missing, and runs TPM's plugin installer.

Tmux configuration reload is manual. Use prefix + `r` inside tmux, or restart the server when no sessions need to remain running.
