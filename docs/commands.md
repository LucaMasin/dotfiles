# Command reference

`dot` works from any directory after `dot init` or `./dot link`. Before installation, use `./dot` from the repo. The global symlink resolves back to its owning checkout.

## Help

`dot`, `dot help`, and `dot --help` print command help. Each command accepts `--help`.

## Init

`dot init` installs platform tools, applies configs and machine settings, and creates `~/.local/bin/dot`.

| Option | Meaning |
| --- | --- |
| `--platform ubuntu\|omarchy\|raspberrypi` | Override platform detection. |
| `--dry-run` | Preview without writes, installs, or network changes. |
| `--skip-packages` | Skip tool installation, but still apply configs and machine settings. |
| `--desktop i3` | Add Ubuntu's optional i3 packages and configs. |
| `--configs nvim,tmux` | Select comma-separated configs. |
| `--configs all` | Select all enabled configs. |

Config selections and managed source blocks are validated before package installation. An existing foreign `~/.local/bin/dot` prevents setup from starting.

## Apply

```bash
dot apply
dot apply nvim tmux
dot apply all --dry-run
dot apply i3 --force-disabled
```

No names selects the default configs. `all` selects every enabled config and cannot be combined with names. `--force-disabled` permits explicitly selected disabled configs; it does not add disabled configs to `all`.

`apply` does not pull Git changes, install system packages, or change platform desktop settings. Selecting tmux installs TPM and its plugins, which can require network access. Applying configs does not reload running applications.

## Update

```bash
dot update
dot update nvim
dot update --configs nvim,tmux
dot update --dry-run
```

Update runs `git pull --ff-only` in the owning checkout, then applies configs. It does not upgrade tools or reapply machine settings. `--skip-pull` skips Git and applies the local checkout.

A dry-run does not fetch incoming commits. Its config preview describes the current checkout. Config selections are validated before pulling and again before applying.

`--configs` cannot be repeated or combined with positional names. Disabled configs require a separate explicit `dot apply --force-disabled`.

## List and doctor

`dot list` lists manifest entries, their enabled state, sources, and targets. `dot list --names` prints names for completion scripts.

`dot doctor` checks default managed configs, required commands on PATH, command ownership, and TPM installation. It prints repair commands and returns a nonzero exit status when checks fail. It does not run shell configs, install plugins, or change files.

Doctor checks defaults, not every optional config. It checks tool availability, not tool versions or package-manager ownership.

## Edit

`dot edit` opens the repo in `$EDITOR`, defaulting to `nvim`. Whitespace-separated editor arguments are supported, such as `EDITOR='code --wait'`. Shell expressions and quoted executable paths are not evaluated.

## Link and unlink

`dot link` creates `~/.local/bin/dot` without sudo. It refuses to replace another file or another checkout's symlink.

`dot unlink` removes only the symlink owned by this checkout. Configs and backups remain unchanged. Both commands accept `--dry-run`.

Another command named `dot`, such as Graphviz, can take precedence on PATH. Doctor reports this conflict. Choose PATH ordering explicitly if you use both.

## Completions

```bash
eval "$(dot completions zsh)"
eval "$(dot completions bash)"
```

Run only the command for your current shell. Zsh requires `compinit`, which the repo's zsh config already runs. The shared shell config loads these completions automatically when `~/.local/bin/dot` exists.

## Existing script entrypoints

`setup_scripts/setup.sh` remains the machine setup implementation. `scripts/dotfiles.sh` remains the manifest installer, with `install`, `validate`, `check`, and `list` commands. The installer owns the default selection.

`setup_scripts/update.sh` delegates to `dot update`. Its old platform and desktop options no longer apply; use `dot init` for machine settings.
