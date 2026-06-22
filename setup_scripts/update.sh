#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
DRY_RUN=false
SKIP_PULL=false

usage() {
  cat <<EOF
Usage:
  ${0##*/} [--dry-run] [--skip-pull] [setup options...]

Pulls the dotfiles repo, then reapplies config links and source blocks without
installing packages.

Options:
  --dry-run    Print actions without changing the system.
  --skip-pull  Reapply configs without pulling first.

Any remaining options are passed to setup_scripts/setup.sh.
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

main() {
  local setup_args=(--skip-packages)

  while (($#)); do
    case "$1" in
      --dry-run)
        DRY_RUN=true
        setup_args+=(--dry-run)
        ;;
      --skip-pull)
        SKIP_PULL=true
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        setup_args+=("$1")
        ;;
    esac
    shift
  done

  if [[ $SKIP_PULL == false ]]; then
    printf 'Updating dotfiles repo\n'
    run git -C "$DOTFILES_DIR" pull --ff-only
  fi

  printf 'Reapplying dotfiles config\n'
  "$DOTFILES_DIR/setup_scripts/setup.sh" "${setup_args[@]}"
}

main "$@"
