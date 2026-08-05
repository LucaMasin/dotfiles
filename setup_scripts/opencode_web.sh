#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
UNIT_NAME="opencode-web.service"
ENV_FILE="$HOME/.config/opencode/server.env"
SERVE_TARGET="http://127.0.0.1:4096"
PORT=4096
DRY_RUN=false

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<EOF
Usage:
  ${0##*/} [--dry-run] enable|disable|status

Commands:
  enable   Install and start the tailnet-only OpenCode web service.
  disable  Stop the service and remove its Tailscale Serve endpoint.
  status   Show service, Serve, and access status.

Options:
  --dry-run  Print actions without changing the system.
  -h, --help Show this help.
EOF
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
  "$DOTFILES_DIR/scripts/dotfiles.sh" "${args[@]}" --force-disabled install opencode-web
  run systemctl --user daemon-reload
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

serve_status() {
  local status
  if ! status="$(tailscale serve status 2>&1)"; then
    printf '%s\n' "$status" >&2
    die "could not read Tailscale Serve status"
  fi
  printf '%s\n' "$status"
}

configure_serve() {
  local out status url

  status="$(serve_status)"
  if grep -Fq "|-- / proxy $SERVE_TARGET" <<<"$status"; then
    printf 'Tailscale Serve already proxies / to %s\n' "$SERVE_TARGET"
    return 0
  fi
  if grep -Fq '|-- / ' <<<"$status"; then
    die "Tailscale Serve already has a root handler; refusing to replace it"
  fi

  if [[ $DRY_RUN == true ]]; then
    printf 'dry-run: tailscale serve --bg %s\n' "$SERVE_TARGET"
    return 0
  fi

  if ! out="$(timeout 60 tailscale serve --bg "$SERVE_TARGET" </dev/null 2>&1)"; then
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

remove_serve() {
  local status
  status="$(serve_status)"

  if grep -Fq "|-- / proxy $SERVE_TARGET" <<<"$status"; then
    run tailscale serve --https=443 "$SERVE_TARGET" off
    printf 'Removed the Tailscale Serve endpoint for %s\n' "$SERVE_TARGET"
  elif grep -Fq '|-- / ' <<<"$status"; then
    die "Tailscale Serve root handler is not $SERVE_TARGET; refusing to remove it"
  else
    printf 'No Tailscale Serve root endpoint is configured\n'
  fi
}

cmd_enable() {
  require_cmds opencode tailscale systemctl loginctl timeout id
  write_env_file
  install_unit
  enable_linger
  run systemctl --user enable --now "$UNIT_NAME"
  configure_serve
  cmd_status
}

cmd_disable() {
  require_cmds tailscale systemctl
  remove_serve
  run systemctl --user disable --now "$UNIT_NAME"
  printf 'Kept %s and systemd linger; remove manually if unwanted.\n' "$ENV_FILE"
}

cmd_status() {
  local url
  url="$(tailnet_url)"

  printf 'Service:\n'
  printf '  enabled:  %s\n' "$(systemctl --user is-enabled "$UNIT_NAME" 2>/dev/null || printf 'unknown')"
  printf '  active:   %s\n' "$(systemctl --user is-active "$UNIT_NAME" 2>/dev/null || printf 'unknown')"
  printf '\nTailscale Serve:\n'
  tailscale serve status
  printf '\nAccess (tailnet only):\n'
  printf '  %s\n' "https://$url"
  printf '\nLocal diagnostics: http://127.0.0.1:%s\n' "$PORT"
  printf 'Credentials: %s\n' "$ENV_FILE"
  printf 'Logs: journalctl --user -u %s\n' "$UNIT_NAME"
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
