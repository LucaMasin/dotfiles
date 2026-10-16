# OpenCode remote access on rpi5 (v2)

Set up 2026-10-16 with OpenCode v2.0.31. Replaces the pre-v2 setup, which no longer exists.

## Design

- The OpenCode v2 background service listens on loopback only: `http://127.0.0.1:49374`.
- `tailscale serve` publishes it as `https://rpi5.tail89cabe.ts.net` (tailnet only, not public).
- The server password still applies. It is stored in `~/.config/opencode/service.json`.
- A systemd user unit starts the service at boot (lingering enabled).

Rejected alternatives:
- `opencode pair --remote` (OpenTunnel): exposes the server to the internet.
- `opencode service set hostname 0.0.0.0`: exposes the server on the LAN.

## Setup steps

1. Publish the loopback port on the tailnet (needs sudo, once). The rule persists in tailscaled state:

   ```sh
   sudo tailscale serve --bg --https=443 http://127.0.0.1:49374
   tailscale serve status
   ```

   Optional, to avoid sudo for later `tailscale serve` changes: `sudo tailscale set --operator=$USER`.

2. Start the OpenCode service at boot with `~/.config/systemd/user/opencode.service`:

   ```ini
   [Unit]
   Description=OpenCode background service
   After=network-online.target

   [Service]
   Type=oneshot
   RemainAfterExit=yes
   Environment=PATH=/home/luca/.npm-global/bin:/usr/local/bin:/usr/bin:/bin
   ExecStart=/home/luca/.npm-global/bin/opencode service start
   ExecStop=/home/luca/.npm-global/bin/opencode service stop

   [Install]
   WantedBy=default.target
   ```

   ```sh
   systemctl --user daemon-reload
   systemctl --user enable opencode.service
   loginctl enable-linger luca   # start user services at boot without a login
   ```

## Connecting

From a device on the tailnet:

- Browser or app: run `opencode pair --url https://rpi5.tail89cabe.ts.net` on the Pi. Open the printed link or scan the QR code. Links work once and expire after 5 minutes. Sessions last 30 days. Changing the server password signs every session out.
- Terminal: `opencode --server https://rpi5.tail89cabe.ts.net`. It prompts for the server password.

## Verify

```sh
tailscale serve status                                   # shows the proxy to 127.0.0.1:49374
curl -s -o /dev/null -w "%{http_code}\n" https://rpi5.tail89cabe.ts.net/api/info   # 401 without credentials is expected
systemctl --user is-enabled opencode.service             # enabled
loginctl show-user luca -p Linger                        # Linger=yes
opencode service status                                  # http://127.0.0.1:49374
```

## Maintenance

- Restart the service: `opencode service restart`.
- Change the password: `opencode service set password "<secret>"`, then `opencode service start`. This signs out all sessions.
- Changing any service setting stops the service. Run `opencode service start` to apply it.
- If the default port 49374 ever changes, update the serve rule:
  `sudo tailscale serve --bg --https=443 http://127.0.0.1:<port>`.
- Remove the tailnet exposure: `sudo tailscale serve --https=443 off`.
- Logs: `~/.local/share/opencode/log/opencode.log`.
- Docs: https://opencode.ai/v2/docs/cli/web/ and https://opencode.ai/v2/docs/troubleshooting/

## Not yet tested

A full reboot. After the next one, confirm the verify commands above still pass.
