#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/LucaMasin/dotfiles.git"
DOTFILES_DIR="$HOME/dotfiles"

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

detect_platform() {
  if command -v omarchy >/dev/null 2>&1; then
    printf 'omarchy\n'
    return 0
  fi

  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    case "${ID:-}" in
      ubuntu) printf 'ubuntu\n'; return 0 ;;
    esac
  fi

  if is_supported_raspberrypi; then
    printf 'raspberrypi\n'
    return 0
  fi

  return 1
}

is_supported_raspberrypi() {
  local model codename
  local VERSION_CODENAME=""
  local DEBIAN_CODENAME=""

  [[ "$(uname -m)" == "aarch64" ]] || return 1
  [[ -r /proc/device-tree/model ]] || return 1

  model="$(tr -d '\0' </proc/device-tree/model 2>/dev/null || true)"
  case "$model" in
    "Raspberry Pi 4"*|"Raspberry Pi 5"*) ;;
    *) return 1 ;;
  esac

  [[ -r /etc/os-release ]] || return 1
  # shellcheck disable=SC1091
  source /etc/os-release
  codename="${VERSION_CODENAME:-$DEBIAN_CODENAME}"
  [[ $codename == trixie ]]
}

install_git() {
  local platform="$1"

  command -v git >/dev/null 2>&1 && return 0

  printf 'Installing git\n'
  case "$platform" in
    ubuntu|raspberrypi)
      sudo apt update
      sudo apt install -y git
      ;;
    omarchy)
      omarchy pkg add git
      ;;
    *)
      die "unsupported platform for bootstrap: $platform"
      ;;
  esac
}

main() {
  local platform

  platform="$(detect_platform)" || die 'could not detect platform; bootstrap supports ubuntu, omarchy, and raspberrypi'
  install_git "$platform"

  if [[ -d $DOTFILES_DIR/.git ]]; then
    printf 'Updating dotfiles in %s\n' "$DOTFILES_DIR"
    git -C "$DOTFILES_DIR" pull --ff-only
  elif [[ -e $DOTFILES_DIR ]]; then
    die "$DOTFILES_DIR exists but is not a git repository"
  else
    printf 'Cloning dotfiles into %s\n' "$DOTFILES_DIR"
    git clone "$REPO_URL" "$DOTFILES_DIR"
  fi

  printf 'Starting setup for %s\n' "$platform"
  "$DOTFILES_DIR/setup_scripts/setup.sh"
}

main "$@"
