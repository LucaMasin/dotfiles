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
  ghostty
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

configure_default_terminal() {
  local target="$HOME/.config/xdg-terminals.list"

  printf 'Configuring Ghostty as the default terminal in %s\n' "$target"

  if [[ $DRY_RUN == true ]]; then
    printf 'dry-run: write Ghostty terminal preference to %s\n' "$target"
    return 0
  fi

  mkdir -p -- "${target%/*}"
  cat >"$target" <<'EOF'
# Terminal emulator preference order for xdg-terminal-exec
# The first found and valid terminal will be used
com.mitchellh.ghostty.desktop
Alacritty.desktop
EOF
}

configure_hyprland_scrolling_layout() {
  local target="$HOME/.config/hypr/looknfeel.conf"
  local tmp_file in_general found

  [[ -e $target ]] || return 0

  if grep -Eq '^[[:space:]]*layout[[:space:]]*=[[:space:]]*scrolling[[:space:]]*$' "$target"; then
    printf 'Hyprland scrolling layout already configured in %s\n' "$target"
    return 0
  fi

  printf 'Configuring Hyprland default layout as scrolling in %s\n' "$target"

  if [[ $DRY_RUN == true ]]; then
    printf 'dry-run: enable layout = scrolling in %s\n' "$target"
    return 0
  fi

  tmp_file="$(mktemp)"
  in_general=false
  found=false

  while IFS= read -r line || [[ -n $line ]]; do
    if [[ $line =~ ^[[:space:]]*general[[:space:]]*\{[[:space:]]*$ ]]; then
      in_general=true
    elif [[ $in_general == true && $line =~ ^[[:space:]]*#[[:space:]]*layout[[:space:]]*=[[:space:]]*scrolling[[:space:]]*$ ]]; then
      printf '    layout = scrolling\n' >>"$tmp_file"
      found=true
      continue
    elif [[ $in_general == true && $line =~ ^[[:space:]]*\}[[:space:]]*$ ]]; then
      if [[ $found == false ]]; then
        printf '    layout = scrolling\n' >>"$tmp_file"
        found=true
      fi
      in_general=false
    fi

    printf '%s\n' "$line" >>"$tmp_file"
  done <"$target"

  mv -- "$tmp_file" "$target"
}

reload_hyprland() {
  command -v hyprctl >/dev/null || return 0

  if [[ $DRY_RUN == true ]]; then
    printf 'dry-run: hyprctl reload && hyprctl configerrors\n'
    return 0
  fi

  hyprctl reload
  hyprctl configerrors
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
  configure_default_terminal
  configure_hyprland_scrolling_layout
  reload_hyprland
}

main "$@"
