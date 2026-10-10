# Enable tailnet-only OpenCode web access

This service is optional per machine. Install Tailscale and log in before enabling it. OpenCode, systemd user services, and Tailscale Serve must be available.

```bash
~/dotfiles/setup_scripts/opencode_web.sh --dry-run enable
~/dotfiles/setup_scripts/opencode_web.sh enable
```

The installer creates a generated password in `~/.config/opencode/server.env` with mode 600, preserving a valid existing file. It installs the disabled `opencode-web` manifest entry, enables systemd lingering, and starts `opencode-web.service`.

OpenCode listens only on `127.0.0.1:4097`. Tailscale Serve proxies it on tailnet HTTPS port 443. The installer refuses to replace an unrelated Serve root handler and retires the old `opencode2-web` service and legacy endpoints.

If Serve is not enabled for your tailnet, follow the Tailscale admin link printed by the installer, then rerun `enable`.

## Check access

```bash
~/dotfiles/setup_scripts/opencode_web.sh status
```

The tailnet URL is `https://<hostname>.<tailnet>.ts.net`. Local diagnostics use `http://127.0.0.1:4097`. The service does not expose its raw port on LAN interfaces.

Anyone with the password can operate OpenCode as your user. To rotate it, edit `~/.config/opencode/server.env`, then restart:

```bash
systemctl --user restart opencode-web
```

## Disable access

```bash
~/dotfiles/setup_scripts/opencode_web.sh disable
```

Disable removes the managed Serve endpoints and stops the service. It preserves credentials and systemd lingering so other user services are unaffected.
