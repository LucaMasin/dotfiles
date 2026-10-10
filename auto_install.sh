#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/LucaMasin/dotfiles.git"
DOTFILES_DIR="$HOME/dotfiles"
DRY_RUN=false
PLATFORM=""
DESKTOP="none"
SETUP_ARGS=()

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

  while (($#)); do
    case "$1" in
      --dry-run) DRY_RUN=true; SETUP_ARGS+=(--dry-run) ;;
      --platform|--desktop|--configs)
        (($# > 1)) || die "$1 requires a value"
        [[ -n $2 && $2 != -* ]] || die "$1 requires a value"
        case "$1" in
          --platform) PLATFORM="$2" ;;
          --desktop) DESKTOP="$2" ;;
          --configs)
            [[ $2 != ,* && $2 != *, && $2 != *,,* ]] || die 'invalid --configs list'
            ;;
        esac
        SETUP_ARGS+=("$1" "$2")
        shift
        ;;
      --skip-packages) SETUP_ARGS+=("$1") ;;
      -h|--help)
        printf 'Usage: auto_install.sh [--dry-run] [--platform ubuntu|omarchy|raspberrypi] [--desktop i3] [--configs comma-list|all] [--skip-packages]\n'
        return 0
        ;;
      *) die "unknown bootstrap option: $1" ;;
    esac
    shift
  done
  platform="$PLATFORM"
  [[ -n $platform ]] || platform="$(detect_platform)" || die 'could not detect platform; bootstrap supports ubuntu, omarchy, and raspberrypi'
  case "$platform" in
    ubuntu|omarchy|raspberrypi) ;;
    *) die "unsupported platform: $platform" ;;
  esac
  case "$DESKTOP" in
    none|i3) ;;
    *) die "unsupported desktop: $DESKTOP" ;;
  esac
  [[ $DESKTOP != i3 || $platform == ubuntu ]] || die '--desktop i3 is only supported on Ubuntu'
  if [[ $DRY_RUN == true ]]; then
    printf 'dry-run: install git if missing using %s\n' "$platform"
    printf 'dry-run: clone or fast-forward %s into %s\n' "$REPO_URL" "$DOTFILES_DIR"
    printf 'dry-run: %q init' "$DOTFILES_DIR/dot"
    printf ' %q' "${SETUP_ARGS[@]}"
    printf '\n'
    return 0
  fi
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
  "$DOTFILES_DIR/dot" init "${SETUP_ARGS[@]}"
}

main "$@"
