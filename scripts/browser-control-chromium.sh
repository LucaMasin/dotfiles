#!/usr/bin/env bash
set -euo pipefail

# Launch the Browser Control automation Chromium with the unpacked extension
# pre-loaded and an isolated profile, so agents never drive a personal browser.
# Usage: browser-control-chromium.sh [--foreground]

profile_dir="${BROWSER_CONTROL_PROFILE:-$HOME/.browser-control/chromium}"
extension_dir="${BROWSER_CONTROL_EXTENSION:-$HOME/repos/browser-control/extension/dist}"
log_file="${BROWSER_CONTROL_LOG:-/tmp/browser-control-chromium.log}"

foreground=false

for arg in "$@"; do
  case $arg in
    --foreground) foreground=true ;;
    *)
      printf 'error: unknown argument: %s\n' "$arg" >&2
      exit 2
      ;;
  esac
done

resolve_chrome() {
  local candidate
  # Prefer a Playwright Chromium when one is installed, then system browsers.
  candidate="$(ls -d "$HOME"/.cache/ms-playwright/chromium-*/chrome-linux*/chrome 2>/dev/null | sort -V | tail -n 1)"
  if [[ -n $candidate ]]; then
    printf '%s\n' "$candidate"
    return 0
  fi
  for candidate in chromium chromium-browser google-chrome-stable google-chrome brave-browser; do
    if command -v "$candidate" >/dev/null 2>&1; then
      command -v "$candidate"
      return 0
    fi
  done
  printf 'error: no Chromium-family browser found; install chromium or set BROWSER_CONTROL_CHROME\n' >&2
  return 1
}

if pgrep -f "user-data-dir=$profile_dir" >/dev/null 2>&1; then
  printf 'automation Chromium already running (profile %s)\n' "$profile_dir"
  exit 0
fi

chrome="${BROWSER_CONTROL_CHROME:-$(resolve_chrome)}"
if [[ ! -f $extension_dir/manifest.json ]]; then
  printf 'error: extension not built at %s (run pnpm build in ~/repos/browser-control)\n' "$extension_dir" >&2
  exit 1
fi
mkdir -p -- "$profile_dir"

chrome_flags=(
  --user-data-dir="$profile_dir"
  --load-extension="$extension_dir"
  --no-first-run
  --no-default-browser-check
  --disable-background-timer-throttling
  --disable-backgrounding-occluded-windows
  --disable-renderer-backgrounding
)

# WSL needs the sandbox disabled; native Linux keeps it on.
if grep -qi microsoft /proc/version 2>/dev/null; then
  chrome_flags+=(--no-sandbox)
fi

# Reach the desktop compositor from a plain login shell.
runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export XDG_RUNTIME_DIR="$runtime_dir"
if [[ -z ${WAYLAND_DISPLAY:-} && -S $runtime_dir/wayland-0 ]]; then
  export WAYLAND_DISPLAY=wayland-0
fi
if [[ -n ${WAYLAND_DISPLAY:-} && -z ${DISPLAY:-} ]]; then
  export XDG_SESSION_TYPE=wayland
  chrome_flags+=(--ozone-platform=wayland)
fi
if [[ -z ${WAYLAND_DISPLAY:-} && -z ${DISPLAY:-} ]]; then
  printf 'error: no graphical session found (set DISPLAY or WAYLAND_DISPLAY)\n' >&2
  exit 1
fi

printf 'chrome: %s\nextension: %s\nprofile: %s\ndisplay: %s\n' \
  "$chrome" "$extension_dir" "$profile_dir" "${WAYLAND_DISPLAY:-$DISPLAY}"

if $foreground; then
  exec env -u DBUS_SESSION_BUS_ADDRESS "$chrome" "${chrome_flags[@]}" about:blank
fi

# Chromium's network stack stalls on every request, loopback included, when it
# inherits the desktop session bus on this machine. The automation profile
# needs no portals, so drop the bus and keep networking usable.
nohup env -u DBUS_SESSION_BUS_ADDRESS "$chrome" "${chrome_flags[@]}" about:blank >"$log_file" 2>&1 &
disown
printf 'automation Chromium started (pid %s, log %s)\n' "$!" "$log_file"
