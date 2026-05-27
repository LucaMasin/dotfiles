#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
MANIFEST="$DOTFILES_DIR/dotfiles-manifest.conf"
BACKUP_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles-backup"
DRY_RUN=false
FORCE_DISABLED=false

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<EOF
Usage:
  ${0##*/} list
  ${0##*/} [--dry-run] [--force-disabled] install <package...|all>

Examples:
  ${0##*/} list
  ${0##*/} --dry-run install zsh nvim tmux
  ${0##*/} install zsh nvim tmux
  ${0##*/} install all
EOF
}

run() {
  if [[ $DRY_RUN == true ]]; then
    printf 'dry-run: %s\n' "$*"
  else
    "$@"
  fi
}

expand_path() {
  local path="$1"

  if [[ $path == "~" ]]; then
    printf '%s\n' "$HOME"
  elif [[ ${path:0:2} == "~/" ]]; then
    printf '%s/%s\n' "$HOME" "${path#\~/}"
  elif [[ $path == /* ]]; then
    printf '%s\n' "$path"
  else
    printf '%s/%s\n' "$DOTFILES_DIR" "$path"
  fi
}

read_package() {
  local wanted="$1"
  local line name type source target enabled description

  [[ -f $MANIFEST ]] || die "manifest not found: $MANIFEST"

  while IFS= read -r line || [[ -n $line ]]; do
    [[ -z $line || ${line:0:1} == '#' ]] && continue
    IFS='|' read -r name type source target enabled description <<<"$line"
    if [[ $name == "$wanted" ]]; then
      PACKAGE_NAME="$name"
      PACKAGE_TYPE="$type"
      PACKAGE_SOURCE="$source"
      PACKAGE_TARGET="$target"
      PACKAGE_ENABLED="$enabled"
      PACKAGE_DESCRIPTION="$description"
      return 0
    fi
  done <"$MANIFEST"

  return 1
}

list_packages() {
  local line name type source target enabled description status

  printf 'Available packages from %s:\n\n' "$MANIFEST"
  while IFS= read -r line || [[ -n $line ]]; do
    [[ -z $line || ${line:0:1} == '#' ]] && continue
    IFS='|' read -r name type source target enabled description <<<"$line"
    status="enabled"
    [[ $enabled == true ]] || status="disabled"
    printf '  %-10s %-8s %-8s %s -> %s\n' "$name" "$status" "$type" "$source" "$target"
    printf '  %s\n\n' "$description"
  done <"$MANIFEST"
}

backup_target() {
  local target="$1"
  local backup_dir backup_path target_parent

  [[ -e $target || -L $target ]] || return 0

  backup_dir="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)"
  target_parent="$(dirname -- "$target")"
  backup_path="$backup_dir${target#$HOME}"

  run mkdir -p "$(dirname -- "$backup_path")"
  printf 'Backing up %s to %s\n' "$target" "$backup_path"
  run mv -- "$target" "$backup_path"

  if [[ ! -e $target_parent ]]; then
    run mkdir -p "$target_parent"
  fi
}

backup_copy_target() {
  local target="$1"
  local backup_dir backup_path

  [[ -e $target || -L $target ]] || return 0

  backup_dir="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)"
  backup_path="$backup_dir${target#$HOME}"

  run mkdir -p "$(dirname -- "$backup_path")"
  printf 'Backing up %s to %s\n' "$target" "$backup_path"
  run cp -a -- "$target" "$backup_path"
}

install_link() {
  local source target parent current_link

  source="$(expand_path "$PACKAGE_SOURCE")"
  target="$(expand_path "$PACKAGE_TARGET")"
  parent="$(dirname -- "$target")"

  [[ -e $source ]] || die "$PACKAGE_NAME source does not exist: $source"

  if [[ -L $target ]]; then
    current_link="$(readlink -- "$target")"
    if [[ $current_link == "$source" ]]; then
      printf '%s already linked: %s -> %s\n' "$PACKAGE_NAME" "$target" "$source"
      return 0
    fi
  fi

  backup_target "$target"
  run mkdir -p "$parent"
  printf 'Linking %s: %s -> %s\n' "$PACKAGE_NAME" "$target" "$source"
  run ln -s -- "$source" "$target"
}

source_block() {
  local source_list="$1"
  local item source_path

  printf '# >>> dotfiles managed: %s\n' "$PACKAGE_NAME"
  IFS=',' read -ra SOURCES <<<"$source_list"
  for item in "${SOURCES[@]}"; do
    source_path="$(expand_path "$item")"
    printf '[[ -f "%s" ]] && source "%s"\n' "$source_path" "$source_path"
  done
  printf '# <<< dotfiles managed: %s\n' "$PACKAGE_NAME"
}

install_source() {
  local target marker_start marker_end tmp_file line in_block

  target="$(expand_path "$PACKAGE_TARGET")"
  marker_start="# >>> dotfiles managed: $PACKAGE_NAME"
  marker_end="# <<< dotfiles managed: $PACKAGE_NAME"
  tmp_file="$(mktemp)"
  in_block=false

  IFS=',' read -ra SOURCES <<<"$PACKAGE_SOURCE"
  for line in "${SOURCES[@]}"; do
    [[ -e $(expand_path "$line") ]] || die "$PACKAGE_NAME source does not exist: $(expand_path "$line")"
  done

  if [[ -e $target || -L $target ]]; then
    backup_copy_target "$target"
  fi

  if [[ $DRY_RUN == true ]]; then
    printf 'dry-run: write managed source block to %s\n' "$target"
    source_block "$PACKAGE_SOURCE"
    rm -f -- "$tmp_file"
    return 0
  fi

  mkdir -p "$(dirname -- "$target")"
  touch "$target"

  while IFS= read -r line || [[ -n $line ]]; do
    if [[ $line == "$marker_start" ]]; then
      in_block=true
      continue
    fi
    if [[ $line == "$marker_end" ]]; then
      in_block=false
      continue
    fi
    [[ $in_block == true ]] && continue
    printf '%s\n' "$line" >>"$tmp_file"
  done <"$target"

  {
    printf '\n'
    source_block "$PACKAGE_SOURCE"
  } >>"$tmp_file"

  mv -- "$tmp_file" "$target"
  printf 'Updated %s with %s sources\n' "$target" "$PACKAGE_NAME"
}

configure_omarchy_zsh_shell() {
  local target="$HOME/.config/uwsm/env"
  local shell_line="export SHELL=/usr/bin/zsh"

  [[ -e $target ]] || return 0

  if grep -Fxq -- "$shell_line" "$target"; then
    printf 'Omarchy UWSM shell already configured in %s\n' "$target"
    return 0
  fi

  backup_copy_target "$target"
  printf 'Configuring Omarchy UWSM shell in %s\n' "$target"

  if [[ $DRY_RUN == true ]]; then
    printf 'dry-run: append %s\n' "$shell_line"
    return 0
  fi

  printf '\n%s\n' "$shell_line" >>"$target"
}

configure_tmux_plugins() {
  local tpm_dir="$HOME/.tmux/plugins/tpm"

  if [[ -d $tpm_dir ]]; then
    printf 'Tmux Plugin Manager already installed: %s\n' "$tpm_dir"
  else
    printf 'Installing Tmux Plugin Manager: %s\n' "$tpm_dir"
    run mkdir -p "$(dirname -- "$tpm_dir")"
    run git clone https://github.com/tmux-plugins/tpm "$tpm_dir"
  fi

  if [[ $DRY_RUN == true ]]; then
    printf 'dry-run: install tmux plugins from %s\n' "$HOME/.config/tmux/tmux.conf"
    return 0
  fi

  "$tpm_dir/bin/install_plugins"
}

enabled_packages() {
  local line name type source target enabled description

  while IFS= read -r line || [[ -n $line ]]; do
    [[ -z $line || ${line:0:1} == '#' ]] && continue
    IFS='|' read -r name type source target enabled description <<<"$line"
    [[ $enabled == true ]] && printf '%s\n' "$name"
  done <"$MANIFEST"
}

install_package() {
  local package="$1"

  read_package "$package" || die "unknown package: $package"

  if [[ $PACKAGE_ENABLED != true && $FORCE_DISABLED != true ]]; then
    die "$PACKAGE_NAME is disabled in the manifest: $PACKAGE_DESCRIPTION"
  fi

  case "$PACKAGE_TYPE" in
    link) install_link ;;
    source) install_source ;;
    *) die "$PACKAGE_NAME has unsupported type: $PACKAGE_TYPE" ;;
  esac

  if [[ $PACKAGE_NAME == "zsh" ]]; then
    configure_omarchy_zsh_shell
  fi
  if [[ $PACKAGE_NAME == "tmux" ]]; then
    configure_tmux_plugins
  fi
}

main() {
  local command package packages=()

  while (($#)); do
    case "$1" in
      --dry-run) DRY_RUN=true ;;
      --force-disabled) FORCE_DISABLED=true ;;
      -h|--help) usage; exit 0 ;;
      *) packages+=("$1") ;;
    esac
    shift
  done

  ((${#packages[@]} > 0)) || { usage; exit 1; }

  command="${packages[0]}"
  packages=("${packages[@]:1}")

  case "$command" in
    list)
      list_packages
      ;;
    install)
      ((${#packages[@]} > 0)) || die "install requires at least one package or all"
      if [[ ${packages[0]} == all ]]; then
        mapfile -t packages < <(enabled_packages)
      fi
      for package in "${packages[@]}"; do
        install_package "$package"
      done
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
