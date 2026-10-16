# Dotfiles documentation

- [Set up a machine](setup.md): bootstrap, platforms, and desktop options.
- [Command reference](commands.md): commands, options, and shell completions.
- [Config installer](configs.md): manifest, defaults, source blocks, and backups.
- [Troubleshooting](troubleshooting.md): diagnostics and repairs.
- [OpenCode web service](opencode-web.md): optional tailnet access.
- [OpenCode v2 remote access](opencode-remote-access.md): manual tailnet setup using the v2 shared service.
- [VNC over Tailscale](vnc.md): tailnet-only desktop access for Raspberry Pi OS.
- [Brew migration plan](brew-migration.md): a future opt-in change, not implemented.

Run the isolated command checks with `python3 -m unittest discover -s tests -v`. They use temporary homes and mocked installers, not your real config or package managers.
