#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
UNIT_NAME="opencode2-web.service"
LEGACY_UNIT="opencode-web.service"
LEGACY_LINK="$HOME/.config/systemd/user/opencode-web.service"
ENV_FILE="$HOME/.config/opencode/server.env"
SERVE_PORT=443
SERVE_TARGET="http://127.0.0.1:4097"
LOCAL_PORT=4097
# Retired dual-stack endpoints cleaned up on enable/disable.
LEGACY_V1_TARGET="http://127.0.0.1:4096"
LEGACY_V2_PORT=8443
DRY_RUN=false

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<EOF_USAGE
Usage:
  ${0##*/} [--dry-run] enable|disable|status

Commands:
  enable   Install and start the tailnet-only OpenCode V2 web service.
  disable  Stop the service and remove its Tailscale Serve endpoint.
  status   Show service, Serve, and access status.

Options:
  --dry-run  Print actions without changing the system.
  -h, --help Show this help.
EOF_USAGE
}

run() {
  if [[ $DRY_RUN == true ]]; then
    printf 'dry-run:'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

require_cmds() {
  local cmd
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || die "$cmd not found on PATH"
  done
}

tailnet_url() {
  local url
  url="$(set +o pipefail; tailscale status --json 2>/dev/null | sed -n 's/.*"DNSName"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)"
  printf '%s\n' "${url%.}"
}

write_env_file() {
  local password password_count password_line password_value

  [[ ! -L $ENV_FILE ]] || die "$ENV_FILE is a symlink; refusing to use it for credentials"
  if [[ -f $ENV_FILE ]]; then
    run chmod 600 "$ENV_FILE"
    password_count="$(grep -c '^OPENCODE_SERVER_PASSWORD=' "$ENV_FILE" || true)"
    [[ $password_count == 1 ]] ||
      die "$ENV_FILE must contain exactly one OPENCODE_SERVER_PASSWORD assignment"
    password_line="$(grep '^OPENCODE_SERVER_PASSWORD=' "$ENV_FILE")"
    password_value="${password_line#*=}"
    password_value="${password_value#"${password_value%%[![:space:]]*}"}"
    password_value="${password_value%"${password_value##*[![:space:]]}"}"
    [[ -n $password_value && $password_value != '""' && $password_value != "''" ]] ||
      die "$ENV_FILE has an empty OPENCODE_SERVER_PASSWORD; refusing to run unsecured"
    printf 'Keeping existing %s\n' "$ENV_FILE"
    return 0
  fi

  run mkdir -p "$(dirname -- "$ENV_FILE")"
  if [[ $DRY_RUN == true ]]; then
    printf 'dry-run: write %s with a random OPENCODE_SERVER_PASSWORD\n' "$ENV_FILE"
    return 0
  fi

  if command -v openssl >/dev/null 2>&1; then
    password="$(openssl rand -hex 32)"
  else
    password="$(set +o pipefail; LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 64)"
  fi
  if ! (umask 077; set -o noclobber; {
    printf 'OPENCODE_SERVER_USERNAME=opencode\n'
    printf 'OPENCODE_SERVER_PASSWORD=%s\n' "$password"
  } >"$ENV_FILE"); then
    die "could not securely create $ENV_FILE"
  fi
  chmod 600 "$ENV_FILE"
  printf 'Wrote %s with a generated password (mode 600)\n' "$ENV_FILE"
}

install_unit() {
  local args=()
  [[ $DRY_RUN == true ]] && args+=(--dry-run)
  "$DOTFILES_DIR/scripts/dotfiles.sh" "${args[@]}" --force-disabled install opencode2-web
  run systemctl --user daemon-reload
}

serve_status() {
  local status
  if ! status="$(tailscale serve status 2>&1)"; then
    printf '%s\n' "$status" >&2
    die "could not read Tailscale Serve status"
  fi
  printf '%s\n' "$status"
}

root_handler() {
  local status=$1 url=$2

  awk -v url="$url" '
    index($0, url) == 1 && (length($0) == length(url) || substr($0, length(url) + 1, 1) == " ") {
      endpoint = 1; next
    }
    endpoint && index($0, "|-- / ") == 1 { print; exit }
    endpoint && /^[a-z]+:\/\// { exit }
  ' <<<"$status"
}

remove_serve_endpoint() {
  local https_port=$1 target=$2 keep_foreign=${3:-false}
  local handler status url

  status="$(serve_status)"
  url="https://$(tailnet_url)"
  [[ $https_port == 443 ]] || url+=":$https_port"
  handler="$(root_handler "$status" "$url")"

  if [[ $handler == "|-- / proxy $target" ]]; then
    run tailscale serve --https="$https_port" "$target" off
    printf 'Removed the Tailscale Serve endpoint on HTTPS %s for %s\n' "$https_port" "$target"
  elif [[ -n $handler ]]; then
    if [[ $keep_foreign == true ]]; then
      printf 'Keeping unrelated Tailscale Serve root handler on HTTPS %s\n' "$https_port"
    else
      die "Tailscale Serve root handler on HTTPS $https_port is not $target; refusing to remove it"
    fi
  else
    printf 'No Tailscale Serve root endpoint is configured on HTTPS %s\n' "$https_port"
  fi
}

configure_serve() {
  local handler out status url

  status="$(serve_status)"
  url="https://$(tailnet_url)"
  handler="$(root_handler "$status" "$url")"
  if [[ $handler == "|-- / proxy $SERVE_TARGET" ]]; then
    printf 'Tailscale Serve on HTTPS %s already proxies / to %s\n' "$SERVE_PORT" "$SERVE_TARGET"
    return 0
  fi
  if [[ -n $handler && $handler != "|-- / proxy $LEGACY_V1_TARGET" ]]; then
    die "Tailscale Serve on HTTPS $SERVE_PORT already has a root handler; refusing to replace it"
  fi

  if [[ $DRY_RUN == true ]]; then
    printf 'dry-run: tailscale serve --https=%s --bg %s\n' "$SERVE_PORT" "$SERVE_TARGET"
    return 0
  fi

  if ! out="$(timeout 60 tailscale serve --https="$SERVE_PORT" --bg "$SERVE_TARGET" </dev/null 2>&1)"; then
    printf '%s\n' "$out"
    if [[ $out == *"Serve is not enabled"* ]]; then
      url="$(printf '%s\n' "$out" | grep -o 'https://login.tailscale.com/f/serve?node=[^ ]*' | head -n 1 || true)"
      printf '\nOne-time tailnet step: enable Serve for this node at:\n  %s\n' "${url:-https://login.tailscale.com/f/serve}"
      printf 'Then rerun: %s enable\n' "$0"
    fi
    return 1
  fi
  printf '%s\n' "$out"
}

cleanup_legacy() {
  local link_target

  # Stop the retired V1 unit; not an error when it was never installed.
  if [[ $DRY_RUN == true ]]; then
    printf 'dry-run: systemctl --user disable --now %s\n' "$LEGACY_UNIT"
  elif ! systemctl --user disable --now "$LEGACY_UNIT" 2>/dev/null; then
    printf 'Legacy %s not active; skipping\n' "$LEGACY_UNIT"
  else
    printf 'Disabled legacy %s\n' "$LEGACY_UNIT"
  fi

  # Remove the retired V1 symlink when it points into this repo or dangles.
  if [[ -L $LEGACY_LINK ]]; then
    link_target="$(readlink -- "$LEGACY_LINK")"
    if [[ $link_target == "$DOTFILES_DIR"* || ! -e $LEGACY_LINK ]]; then
      run rm -- "$LEGACY_LINK"
      printf 'Removed legacy %s\n' "$LEGACY_LINK"
    else
      printf 'Keeping foreign %s -> %s; remove manually if unwanted\n' "$LEGACY_LINK" "$link_target"
    fi
  fi

  # Remove the retired V2 endpoint without disturbing unrelated use of 8443.
  remove_serve_endpoint "$LEGACY_V2_PORT" "$SERVE_TARGET" true
  run systemctl --user daemon-reload
}

cmd_enable() {
  require_cmds opencode2 tailscale systemctl loginctl timeout id
  write_env_file
  install_unit
  enable_linger
  run systemctl --user enable --now "$UNIT_NAME"
  configure_serve
  cleanup_legacy
  cmd_status
}

cmd_disable() {
  require_cmds tailscale systemctl
  remove_serve_endpoint "$SERVE_PORT" "$SERVE_TARGET"
  remove_serve_endpoint "$LEGACY_V2_PORT" "$SERVE_TARGET" true
  run systemctl --user disable --now "$UNIT_NAME"
  if [[ $DRY_RUN == true ]]; then
    printf 'dry-run: systemctl --user disable --now %s\n' "$LEGACY_UNIT"
  else
    systemctl --user disable --now "$LEGACY_UNIT" 2>/dev/null || true
  fi
  printf 'Kept %s and systemd linger; remove manually if unwanted.\n' "$ENV_FILE"
}

cmd_status() {
  local url
  url="$(tailnet_url)"

  printf 'Service:\n'
  printf '  %-24s enabled=%-8s active=%s\n' "$UNIT_NAME" \
    "$(systemctl --user is-enabled "$UNIT_NAME" 2>/dev/null || :)" \
    "$(systemctl --user is-active "$UNIT_NAME" 2>/dev/null || :)"
  if [[ -L $LEGACY_LINK ]] || systemctl --user cat "$LEGACY_UNIT" >/dev/null 2>&1; then
    printf '  %-24s enabled=%-8s active=%s (legacy V1, retired)\n' "$LEGACY_UNIT" \
      "$(systemctl --user is-enabled "$LEGACY_UNIT" 2>/dev/null || :)" \
      "$(systemctl --user is-active "$LEGACY_UNIT" 2>/dev/null || :)"
  fi
  printf '\nTailscale Serve:\n'
  tailscale serve status
  printf '\nAccess (tailnet only):\n'
  printf '  V2: https://%s\n' "$url"
  printf '\nLocal diagnostics:\n'
  printf '  V2: http://127.0.0.1:%s\n' "$LOCAL_PORT"
  printf 'Credentials: %s\n' "$ENV_FILE"
  printf 'Logs: journalctl --user -u %s\n' "$UNIT_NAME"
}

enable_linger() {
  local user
  user="$(id -un)"

  if [[ $DRY_RUN == true ]]; then
    printf 'dry-run: loginctl enable-linger %s\n' "$user"
    return 0
  fi

  if ! loginctl enable-linger "$user" 2>/dev/null; then
    sudo loginctl enable-linger "$user"
  fi
}

main() {
  local command=""

  while (($#)); do
    case "$1" in
      --dry-run) DRY_RUN=true ;;
      -h|--help) usage; exit 0 ;;
      enable|disable|status) command="$1" ;;
      *) usage; exit 1 ;;
    esac
    shift
  done

  case "$command" in
    enable) cmd_enable ;;
    disable) cmd_disable ;;
    status) cmd_status ;;
    *) usage; exit 1 ;;
  esac
}

main "$@"
