#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=setup.sh
source "$SCRIPT_DIR/setup.sh"

DEFAULT_TOOLS=(opencode pi claude herdr starship zoxide uv tokei browser-control)
OPT_IN_TOOLS=(neovim)

usage() {
  cat <<EOF
Usage: dot upgrade [tool...] [--with tool[,tool...]] [--dry-run]

Upgrade tools that this repo installs outside the system package manager.
Without tool names, upgrades: ${DEFAULT_TOOLS[*]}.
Opt-in tools (never upgraded by default): ${OPT_IN_TOOLS[*]}.

Options:
  --with       Add opt-in tools to the default set (e.g. --with neovim).
  --dry-run    Print actions without changing the system.
  -h, --help   Show this help.

Missing tools are skipped; use 'dot init' to install them. Tools provided by
the system package manager (apt, snap, pacman) are skipped; upgrade those with it.
EOF
}

is_known_tool() {
  local tool="$1" known
  for known in "${DEFAULT_TOOLS[@]}" "${OPT_IN_TOOLS[@]}"; do
    [[ $tool != "$known" ]] || return 0
  done
  return 1
}

# True when the command resolves under $HOME, i.e. this repo installed it.
user_installed() {
  local path
  path="$(command -v "$1" 2>/dev/null)" || return 1
  [[ $(readlink -f -- "$path") == "$HOME"/* ]]
}

upgrade_browser_control() {
  local repo_dir="$HOME/repos/browser-control"
  if [[ ! -d $repo_dir/.git ]]; then
    printf 'browser-control: repo not found in %s, skipping\n' "$repo_dir"
    return 0
  fi
  run_shell 'update browser-control repo' "git -C '$repo_dir' pull --ff-only"
  run_shell 'install browser-control dependencies' "(cd '$repo_dir' && pnpm install)"
  run_shell 'build browser-control' "(cd '$repo_dir' && pnpm build)"
  run_shell 'link browser-control globally' "(cd '$repo_dir' && bun link)"
}

upgrade_tool() {
  local tool="$1" command_name="$1"

  if [[ $tool == neovim ]]; then
    if ! command -v nvim >/dev/null 2>&1; then
      printf 'neovim: not installed, skipping (use dot init)\n'
      return 0
    fi
    install_neovim_from_source
    return 0
  fi

  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf '%s: not installed, skipping (use dot init)\n' "$tool"
    return 0
  fi
  if ! user_installed "$command_name"; then
    printf '%s: managed by the system package manager, skipping\n' "$tool"
    return 0
  fi

  printf 'Upgrading %s\n' "$tool"
  case "$tool" in
    opencode) run npm install -g @opencode/cli@latest ;;
    pi) run npm install -g @earendil-works/pi-coding-agent@latest --ignore-scripts ;;
    claude) run npm install -g @anthropic-ai/claude-code@latest ;;
    herdr) run_shell 'upgrade Herdr' 'curl -fsSL https://herdr.dev/install.sh | sh' ;;
    starship) run_shell 'upgrade Starship' 'curl -sS https://starship.rs/install.sh | sh -s -- -y' ;;
    zoxide) run_shell 'upgrade zoxide' 'curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh' ;;
    uv) run uv self update ;;
    tokei) run_shell 'upgrade tokei with cargo' 'source "$HOME/.cargo/env" 2>/dev/null || true; cargo install --locked tokei' ;;
    browser-control) upgrade_browser_control ;;
  esac
}

main() {
  local tools=() with=() items=() item raw
  while (($#)); do
    case "$1" in
      --dry-run) DRY_RUN=true ;;
      -h|--help) usage; return 0 ;;
      --with)
        (($# > 1)) || die '--with requires a value'
        raw="$2"
        [[ -n $raw && $raw != ,* && $raw != *, && $raw != *,,* ]] || die 'invalid --with list'
        IFS=',' read -r -a items <<<"$raw"
        with+=("${items[@]}")
        shift
        ;;
      -*) die "unknown option: $1" ;;
      *) tools+=("$1") ;;
    esac
    shift
  done

  ((${#tools[@]} > 0)) || tools=("${DEFAULT_TOOLS[@]}")
  tools+=("${with[@]}")
  for item in "${tools[@]}"; do
    is_known_tool "$item" || die "unknown tool: $item (known: ${DEFAULT_TOOLS[*]} ${OPT_IN_TOOLS[*]})"
  done

  for item in "${tools[@]}"; do
    upgrade_tool "$item"
  done
}

main "$@"
