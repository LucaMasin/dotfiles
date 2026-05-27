#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd -- "$SCRIPT_DIR/../../.." && pwd)"
DRY_RUN=false
SKIP_PACKAGES=false
DEFAULT_CONFIGS=(zsh nvim tmux)
PACKAGES=(
  zsh
  neovim
  tmux
  git
  fzf
  ripgrep
  btop
  zoxide
  starship
  yazi
  tokei
  uv
  python-pipx
  github-cli
)

usage() {
  cat <<EOF
Usage:
  ${0##*/} [--dry-run] [--skip-packages]

Installs Omarchy dotfiles dependencies, then applies the default config set.

Options:
  --dry-run        Print actions without changing the system
  --skip-packages  Apply configs without installing packages
EOF
}

run() {
  if [[ $DRY_RUN == true ]]; then
    printf 'dry-run: %s\n' "$*"
  else
    "$@"
  fi
}

install_packages() {
  if [[ $SKIP_PACKAGES == true ]]; then
    printf 'Skipping package installation\n'
    return 0
  fi

  command -v omarchy >/dev/null || {
    printf 'error: omarchy command not found\n' >&2
    return 1
  }

  printf 'Installing required Omarchy packages\n'
  run omarchy pkg add "${PACKAGES[@]}"
}

apply_configs() {
  local args=()

  if [[ $DRY_RUN == true ]]; then
    args+=(--dry-run)
  fi

  printf 'Applying Omarchy dotfiles config\n'
  "$DOTFILES_DIR/scripts/omarchy-dotfiles.sh" "${args[@]}" install "${DEFAULT_CONFIGS[@]}"
}

main() {
  while (($#)); do
    case "$1" in
      --dry-run) DRY_RUN=true ;;
      --skip-packages) SKIP_PACKAGES=true ;;
      -h|--help) usage; exit 0 ;;
      *) usage; exit 1 ;;
    esac
    shift
  done

  install_packages
  apply_configs
}

main "$@"
