## Windows tooling

This machine runs Windows, and the installed skills were written for Linux. Adjust as follows.

- Use PowerShell syntax. CLI tools come from Scoop (`scoop list`, `scoop install <app>`).
- `bash` on PATH is the WSL launcher. Run `.sh` skill scripts with Git Bash: `& "C:\Program Files\Git\bin\bash.exe" <script>`.
- Shebangs and `/bin/sh` launchers do not run here. Start skill scripts with their interpreter, where `<skill>` is `$HOME\.agents\skills\<name>`:
  - statechart: `node <skill>\scripts\statechart.ts <args>`
  - poteto-mode watch-pr: `bun <skill>\scripts\watch-pr\watch-pr <args>`
  - poteto-mode check-plan: `node <skill>\scripts\check-plan.mjs <plan.md>`
  - impeccable: `<skill>\scripts\impeccable.cmd <args>`
  - skill-creator: `uv run python <script>`
- statechart installs Java and TLC with mise on first run and needs the network.
- The browser-control and diagnose-crash skills are not installed on Windows.
