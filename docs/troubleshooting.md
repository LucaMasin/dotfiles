# Repair setup problems

## Find the problem

```bash
./dot doctor
```

Doctor reports missing tools, incorrect default config links, invalid shell source blocks, missing TPM, and PATH conflicts. It does not make changes.

## Make the command available

```bash
cd ~/dotfiles
./dot link
export PATH="$HOME/.local/bin:$PATH"
dot help
```

Restart your configured shell afterward. If `~/.local/bin/dot` belongs to another program or checkout, inspect and move it yourself before linking.

If Graphviz's `dot` runs instead, inspect `command -v dot` and choose your PATH ordering. Use `~/dotfiles/dot` to address this CLI directly.

## Repair selected configs

```bash
dot apply nvim tmux --dry-run
dot apply nvim tmux
```

Existing conflicts are backed up. Inspect the reported backup path before manually restoring anything.

## Repair a shell source block

Inspect `~/.zshrc` for the `dotfiles managed: zsh` markers. Correct missing or duplicate marker pairs without deleting unrelated settings, then run:

```bash
dot apply zsh --dry-run
dot apply zsh
```

If `.zshrc` is a symlink, decide whether to keep that arrangement or replace it manually. The installer refuses to make that decision for you.

## Handle a failed update

`dot update` does not merge diverged branches or discard local changes. Inspect `git status` and resolve the Git issue manually. Use `dot apply` to apply the current checkout without pulling.

## Install missing tools

Preview machine setup before running it:

```bash
dot init --dry-run
dot init
```

Tools still use their existing platform installers. Brew does not install or take ownership of anything in this implementation.
