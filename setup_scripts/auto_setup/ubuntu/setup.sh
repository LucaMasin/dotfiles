#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd -- "$SCRIPT_DIR/../../.." && pwd)"

exec "$DOTFILES_DIR/setup_scripts/setup.sh" --platform ubuntu "$@"
