# Dotfiles Setup

Use these scripts to set up this dotfiles repo on Ubuntu, Omarchy, or Raspberry Pi OS without duplicating config logic.

There are two layers:

```text
setup_scripts/setup.sh      installs platform packages, then applies config
setup_scripts/update.sh     pulls the repo, then reapplies config only
scripts/dotfiles.sh         applies selected dotfiles config only
```

## Platform Setup

Run setup after cloning the repo. The platform is detected automatically when possible:

```bash
~/dotfiles/setup_scripts/setup.sh
```

Or pass the platform explicitly:

```bash
~/dotfiles/setup_scripts/setup.sh --platform ubuntu
~/dotfiles/setup_scripts/setup.sh --platform omarchy
~/dotfiles/setup_scripts/setup.sh --platform raspberrypi
```

The setup script installs platform packages, then runs the default config install:

```bash
~/dotfiles/scripts/dotfiles.sh install zsh nvim tmux herdr scripts agents opencode starship
```

On Ubuntu, base packages are installed through apt. Node.js 24 LTS is installed from the NodeSource apt repository, which includes npm. Neovim is built from the latest stable source release under `~/repos/neovim` instead of installed from apt. Yazi is installed from Snap with classic confinement. opencode2 is installed globally via npm; if the default npm prefix points outside `$HOME`, setup switches to a user-owned `~/.npm-global` so the install does not need sudo. Herdr is installed via `https://herdr.dev/install.sh`.

On Raspberry Pi OS (64-bit Trixie, Pi 4 or Pi 5), base packages are installed through apt, including `starship`, `zoxide`, `tokei`, and `fd-find`. Node.js 24 is installed from the NodeSource apt repository. Neovim is built from the latest stable source release under `~/repos/neovim`. Yazi is installed from the upstream `aarch64` `.deb` release asset through apt so its dependencies are resolved. `uv` is installed via the Astral installer script. opencode2 is installed globally via npm; if the default npm prefix points outside `$HOME`, setup switches to a user-owned `~/.npm-global` so the install does not need sudo. Herdr is installed via `https://herdr.dev/install.sh`.

On Omarchy, Neovim is built from the latest stable source release under `~/repos/neovim`. Herdr is installed via `https://herdr.dev/install.sh`. Setup configures Ghostty as the default terminal for `xdg-terminal-exec`, with Alacritty kept as a fallback in `~/.config/xdg-terminals.list`, sets Ghostty's font size to 10, and sets the Hyprland monitor scale to 1x.

It also enables Hyprland's scrolling layout as the default by adding this to `~/.config/hypr/looknfeel.lua`:

```lua
hl.config({
  general = {
    layout = "scrolling",
  },
})
```

Omarchy packages:

```text
zsh tmux git fzf ripgrep btop zoxide starship yazi tokei uv python-pipx github-cli ghostty nodejs npm base-devel cmake ninja gettext unzip
```

Raspberry Pi OS packages (apt, plus curl-installed `uv` and apt-installed upstream Yazi `.deb`):

```text
zsh tmux git fzf ripgrep btop net-tools pipx curl wget unzip ninja-build gettext cmake build-essential python3-venv fd-find starship zoxide tokei gh nodejs
```

Preview without changing the system:

```bash
~/dotfiles/setup_scripts/setup.sh --dry-run
```

If packages are already installed and you only want to apply config:

```bash
~/dotfiles/setup_scripts/setup.sh --skip-packages
```

To install or refresh Neovim while applying only its configuration:

```bash
~/dotfiles/setup_scripts/setup.sh --configs nvim
```

This installs the platform packages required for the Neovim build; omit `--skip-packages`.

Combine both flags to preview config changes without checking packages:

```bash
~/dotfiles/setup_scripts/setup.sh --dry-run --skip-packages
```

Pull the repo and reapply config links/source blocks:

```bash
~/dotfiles/setup_scripts/update.sh
```

Preview the update flow:

```bash
~/dotfiles/setup_scripts/update.sh --dry-run
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

## Tailnet-only OpenCode Web

Optional and per-machine: exposes the OpenCode web UI over HTTPS to devices in your Tailscale tailnet. Run once per machine you want it on:

```bash
~/dotfiles/setup_scripts/opencode_web.sh enable
```

What it does:

- Writes `~/.config/opencode/server.env` (mode 600) with a generated password, preserving an existing file.
- Installs the `opencode-web` systemd user unit from `dotfiles-manifest.conf` (disabled by default; installed with `--force-disabled`).
- Enables and starts `opencode-web.service`, which runs `opencode serve` bound to `127.0.0.1:4096` only.
- Enables systemd lingering for the current user, so the service starts at boot, before login.
- Runs `tailscale serve --bg http://127.0.0.1:4096` for tailnet-only HTTPS.
- Refuses to replace an existing Tailscale Serve root handler that points somewhere else.

One-time tailnet step: the first `enable` may print a link to the Tailscale admin console asking you to enable Serve for the node. Do that, then rerun `enable`.

Access:

```text
Tailnet only:     https://<hostname>.<tailnet>.ts.net
Local diagnostics: http://127.0.0.1:4096
Not exposed:       LAN interfaces and the raw Tailscale IP
```

The Basic-auth password protects the web UI, but anyone holding it can operate OpenCode as your user. Rotate it by editing `~/.config/opencode/server.env` and restarting:

```bash
systemctl --user restart opencode-web
```

Removal:

```bash
~/dotfiles/setup_scripts/opencode_web.sh disable
```

This removes the Tailscale Serve endpoint first, then stops and disables the unit. Failures are reported instead of being treated as success, and an unrelated Serve root handler is never removed. It keeps `~/.config/opencode/server.env` and systemd lingering, so other user services are unaffected.

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
