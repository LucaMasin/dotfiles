#!/usr/bin/env bash
set -euo pipefail

# Launch the WSL-local automation Chromium for browser-control with the
# extension pre-loaded. No clicks, no personal browser profile.
# Usage: browser-control-chromium.sh [--foreground]

profile_dir="$HOME/.browser-control/wsl-chromium"
extension_dir="$HOME/repos/browser-control/extension/dist"

resolve_chrome() {
  local chrome
  chrome="$(ls -d "$HOME"/.cache/ms-playwright/chromium-*/chrome-linux64/chrome 2>/dev/null | sort -V | tail -n 1)"
  if [[ -z $chrome ]]; then
    printf 'error: no Playwright Chromium found under ~/.cache/ms-playwright\n' >&2
    return 1
  fi
  printf '%s\n' "$chrome"
}

if pgrep -f "user-data-dir=$profile_dir" >/dev/null 2>&1; then
  printf 'automation Chromium already running (profile %s)\n' "$profile_dir"
  exit 0
fi

chrome="$(resolve_chrome)"
if [[ ! -d $extension_dir ]]; then
  printf 'error: extension not built at %s (run pnpm build in ~/repos/browser-control)\n' "$extension_dir" >&2
  exit 1
fi
mkdir -p -- "$profile_dir"

chrome_flags=(
  --user-data-dir="$profile_dir"
  --load-extension="$extension_dir"
  --no-first-run
  --no-default-browser-check
  --no-sandbox
  --disable-background-timer-throttling
  --disable-backgrounding-occluded-windows
  --disable-renderer-backgrounding
)

if [[ ${1:-} == "--foreground" ]]; then
  exec "$chrome" "${chrome_flags[@]}" about:blank
fi

nohup "$chrome" "${chrome_flags[@]}" about:blank >/tmp/browser-control-chromium.log 2>&1 &
disown
printf 'automation Chromium started (pid %s, profile %s)\n' "$!" "$profile_dir"
