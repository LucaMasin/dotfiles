#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
MANIFEST="$DOTFILES_DIR/dotfiles-manifest.conf"
BACKUP_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles-backup"
BACKUP_DIR=""
DRY_RUN=false
FORCE_DISABLED=false
DEFAULT_CONFIGS=(zsh nvim tmux herdr scripts agents opencode starship)

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<EOF
Usage:
  ${0##*/} list [--names]
  ${0##*/} [--dry-run] [--force-disabled] install [config...|all]
  ${0##*/} [--force-disabled] validate [config...|all]
  ${0##*/} check [config...|all]

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

  printf 'Available configs from %s:\n\n' "$MANIFEST"
  while IFS= read -r line || [[ -n $line ]]; do
    [[ -z $line || ${line:0:1} == '#' ]] && continue
    IFS='|' read -r name type source target enabled description <<<"$line"
    status="enabled"
    [[ $enabled == true ]] || status="disabled"
    printf '  %-10s %-8s %-8s %s -> %s\n' "$name" "$status" "$type" "$source" "$target"
    printf '  %s\n\n' "$description"
  done <"$MANIFEST"
}

backup_path() {
  local target="$1"

  if [[ -z $BACKUP_DIR ]]; then
    if [[ $DRY_RUN == true ]]; then
      BACKUP_DIR="$BACKUP_ROOT/<unique-run>"
    else
      mkdir -p -- "$BACKUP_ROOT"
      BACKUP_DIR="$(mktemp -d "$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S).XXXXXX")"
    fi
  fi
  BACKUP_PATH="$BACKUP_DIR${target#$HOME}"
  [[ ! -e $BACKUP_PATH && ! -L $BACKUP_PATH ]] || die "backup already exists: $BACKUP_PATH"
}

backup_target() {
  local target="$1"
  local target_parent

  [[ -e $target || -L $target ]] || return 0

  backup_path "$target"
  target_parent="$(dirname -- "$target")"

  run mkdir -p "$(dirname -- "$BACKUP_PATH")"
  printf 'Backing up %s to %s\n' "$target" "$BACKUP_PATH"
  run mv -- "$target" "$BACKUP_PATH"

  if [[ ! -e $target_parent ]]; then
    run mkdir -p "$target_parent"
  fi
}

backup_copy_target() {
  local target="$1"

  [[ -e $target || -L $target ]] || return 0

  backup_path "$target"

  run mkdir -p "$(dirname -- "$BACKUP_PATH")"
  printf 'Backing up %s to %s\n' "$target" "$BACKUP_PATH"
  run cp -a -- "$target" "$BACKUP_PATH"
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

validate_source_target() {
  local target="$1" line state=before
  local marker_start="# >>> dotfiles managed: $PACKAGE_NAME"
  local marker_end="# <<< dotfiles managed: $PACKAGE_NAME"

  [[ ! -L $target ]] || die "$target is a symlink; refusing to replace a shell rc symlink"
  [[ ! -e $target || -f $target ]] || die "$target is not a regular file"
  [[ -e $target ]] || return 0
  while IFS= read -r line || [[ -n $line ]]; do
    if [[ $line == "$marker_start" ]]; then
      [[ $state == before ]] || die "duplicate or nested managed block in $target"
      state=inside
    elif [[ $line == "$marker_end" ]]; then
      [[ $state == inside ]] || die "unmatched managed block end in $target"
      state=after
    fi
  done <"$target"
  [[ $state != inside ]] || die "missing managed block end in $target"
}

current_source_block() {
  local target="$1" line in_block=false
  [[ -f $target ]] || return 0
  while IFS= read -r line || [[ -n $line ]]; do
    [[ $line != "# >>> dotfiles managed: $PACKAGE_NAME" ]] || in_block=true
    [[ $in_block == false ]] || printf '%s\n' "$line"
    [[ $line != "# <<< dotfiles managed: $PACKAGE_NAME" ]] || in_block=false
  done <"$target"
}

install_source() {
  local target marker_start marker_end tmp_file line in_block

  target="$(expand_path "$PACKAGE_TARGET")"
  marker_start="# >>> dotfiles managed: $PACKAGE_NAME"
  marker_end="# <<< dotfiles managed: $PACKAGE_NAME"
  in_block=false

  IFS=',' read -ra SOURCES <<<"$PACKAGE_SOURCE"
  for line in "${SOURCES[@]}"; do
    [[ -e $(expand_path "$line") ]] || die "$PACKAGE_NAME source does not exist: $(expand_path "$line")"
  done

  validate_source_target "$target"
  if [[ $(current_source_block "$target") == "$(source_block "$PACKAGE_SOURCE")" ]]; then
    printf '%s already configured: %s\n' "$PACKAGE_NAME" "$target"
    return 0
  fi

  if [[ $DRY_RUN == true ]]; then
    backup_copy_target "$target"
    printf 'dry-run: write managed source block to %s\n' "$target"
    source_block "$PACKAGE_SOURCE"
    return 0
  fi

  mkdir -p "$(dirname -- "$target")"
  tmp_file="$(mktemp "$(dirname -- "$target")/.dotfiles-rc.XXXXXX")"
  trap "rm -f -- $(printf '%q' "$tmp_file")" EXIT
  if [[ -e $target ]]; then
    chmod --reference="$target" "$tmp_file"
    backup_copy_target "$target"
  fi

  if [[ -f $target ]]; then
    while IFS= read -r line || [[ -n $line ]]; do
      if [[ $line == "$marker_start" ]]; then
        source_block "$PACKAGE_SOURCE" >>"$tmp_file"
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
  fi

  if [[ -z $(current_source_block "$target") ]]; then
    [[ ! -s $tmp_file ]] || printf '\n' >>"$tmp_file"
    source_block "$PACKAGE_SOURCE"
  fi >>"$tmp_file"

  mv -- "$tmp_file" "$target"
  trap - EXIT
  printf 'Updated %s with %s sources\n' "$target" "$PACKAGE_NAME"
}

configure_tmux_plugins() {
  local tpm_dir="$HOME/.config/tmux/plugins/tpm"

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

  if [[ $PACKAGE_NAME == "tmux" ]]; then
    configure_tmux_plugins
  fi
}

validate_packages() {
  local package source item target sources=()
  for package in "$@"; do
    read_package "$package" || die "unknown config: $package"
    [[ $PACKAGE_ENABLED == true || $FORCE_DISABLED == true ]] || die "$package is disabled in the manifest"
    target="$(expand_path "$PACKAGE_TARGET")"
    case "$PACKAGE_TYPE" in
      link)
        source="$(expand_path "$PACKAGE_SOURCE")"
        [[ -e $source ]] || die "$package source does not exist: $source"
        ;;
      source)
        IFS=',' read -r -a sources <<<"$PACKAGE_SOURCE"
        for item in "${sources[@]}"; do
          source="$(expand_path "$item")"
          [[ -f $source ]] || die "$package source does not exist: $source"
        done
        validate_source_target "$target"
        ;;
      *) die "$package has unsupported type: $PACKAGE_TYPE" ;;
    esac
  done
}

check_packages() {
  local package target source issues=0
  for package in "$@"; do
    read_package "$package" || die "unknown config: $package"
    target="$(expand_path "$PACKAGE_TARGET")"
    if [[ $PACKAGE_TYPE == link ]]; then
      source="$(expand_path "$PACKAGE_SOURCE")"
      if [[ -e $source && -L $target && $(readlink -f -- "$target") == "$(readlink -f -- "$source")" ]]; then
        printf 'ok: %s\n' "$package"
      else
        printf 'error: %s link is missing, broken, or points elsewhere. Repair: dot apply %s\n' "$package" "$package"
        issues=$((issues + 1))
      fi
    elif [[ $PACKAGE_TYPE == source ]]; then
      if (validate_packages "$package") && [[ $(current_source_block "$target") == "$(source_block "$PACKAGE_SOURCE")" ]]; then
        printf 'ok: %s\n' "$package"
      else
        printf 'error: %s source block needs attention. Inspect %s, then run dot apply %s\n' "$package" "$target" "$package"
        issues=$((issues + 1))
      fi
    else
      die "$package has unsupported type: $PACKAGE_TYPE"
    fi
  done
  ((issues == 0))
}

main() {
  local command package names=false packages=() unique=()
  local -A seen=()

  while (($#)); do
    case "$1" in
      --dry-run) DRY_RUN=true ;;
      --force-disabled) FORCE_DISABLED=true ;;
      --names) names=true ;;
      -h|--help) usage; exit 0 ;;
      --*) die "unknown option: $1" ;;
      *) packages+=("$1") ;;
    esac
    shift
  done

  ((${#packages[@]} > 0)) || { usage; exit 1; }

  command="${packages[0]}"
  packages=("${packages[@]:1}")

  case "$command" in
    list)
      ((${#packages[@]} == 0)) || die 'list does not accept config names'
      [[ $DRY_RUN == false && $FORCE_DISABLED == false ]] || die 'list only accepts --names'
      if [[ $names == true ]]; then
        while IFS='|' read -r package _; do
          [[ -z $package || $package == \#* ]] || printf '%s\n' "$package"
        done <"$MANIFEST"
      else
        list_packages
      fi
      ;;
    install|validate|check)
      [[ $names == false ]] || die '--names is only valid for list'
      ((${#packages[@]} > 0)) || packages=("${DEFAULT_CONFIGS[@]}")
      for package in "${packages[@]}"; do
        [[ $package != all || ${#packages[@]} == 1 ]] || die 'all cannot be combined with config names'
      done
      if [[ ${packages[0]} == all ]]; then
        mapfile -t packages < <(enabled_packages)
      fi
      for package in "${packages[@]}"; do
        if [[ -z ${seen[$package]:-} ]]; then
          unique+=("$package")
          seen[$package]=true
        fi
      done
      packages=("${unique[@]}")
      if [[ $command == check ]]; then
        check_packages "${packages[@]}"
      else
        validate_packages "${packages[@]}"
        [[ $command != validate ]] || return 0
        for package in "${packages[@]}"; do
          install_package "$package"
        done
      fi
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
