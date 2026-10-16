# VNC over Tailscale (Raspberry Pi OS)

Tailnet-only desktop access for Pi 4 / Pi 5 running 64-bit Raspberry Pi OS (Trixie) with the `labwc` Wayland desktop. No port forwarding; restrict the listener below if you do not want LAN access.

## Design

- Wayland uses `wayvnc` (`wayvnc.service`). `realvnc-vnc-server` is X11-only and does not capture the `labwc` desktop.
- `sudo raspi-config nonint do_vnc 0` enables and starts `wayvnc.service`. It stops and disables the RealVNC service mode unit when present.
- The server listens on `::` port `5900` (see `/etc/wayvnc/config`), so it is reachable via `tailscale0` as soon as it runs. No `tailscale serve` rule is needed.
- Authentication is the Pi system user/password (`enable_pam=true` in `/etc/wayvnc/config`) over TLS. Anyone with those credentials gets full desktop access.
- Tailscale provides the transport encryption. `dot init` already installs Tailscale and enables `tailscaled`; login stays manual.

## Prerequisites

```sh
sudo tailscale up
tailscale status
tailscale ip -4
```

Join the same tailnet on the viewer device. A local Wayland desktop session must be logged in on the Pi (LightDM auto-login satisfies this).

## Enable

```sh
sudo raspi-config nonint do_vnc 0
systemctl --no-pager status wayvnc.service
ss -tln | grep 5900
raspi-config nonint get_vnc   # 0 means enabled
```

Headless machines with no monitor should also set a fallback resolution:

```sh
sudo raspi-config nonint do_vnc_resolution 1920x1080
```

## Connect

From a device on the same tailnet, point a VNC client (TigerVNC, RealVNC Viewer, Remmina) at the Pi's Tailscale address:

```sh
tailscale ip -4   # run on the Pi, then connect to <that-ip>:5900
```

Accept the self-signed TLS certificate on first connect, then log in with the Pi username and Linux password.

## Disable

```sh
sudo raspi-config nonint do_vnc 1
```

This stops and disables both `wayvnc.service` and the RealVNC service mode unit.

## Optional: Tailscale-only listening

The default `address=::` also exposes VNC to the LAN. To restrict it, set the Tailscale IPv4 address in `/etc/wayvnc/config` and restart:

```sh
tailscale ip -4
sudoedit /etc/wayvnc/config   # address=100.x.y.z
sudo systemctl restart wayvnc.service
```
