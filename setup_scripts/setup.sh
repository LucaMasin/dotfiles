#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
PLATFORM=""
DRY_RUN=false
SKIP_PACKAGES=false
DESKTOP="none"
CONFIGS=(zsh nvim tmux scripts agents)
NODE_MAJOR=24

UBUNTU_PACKAGES=(
  zsh
  tmux
  git
  fzf
  ripgrep
  btop
  net-tools
  snapd
  pipx
  curl
  wget
  unzip
  ninja-build
  gettext
  cmake
  build-essential
  python3-venv
)

UBUNTU_I3_PACKAGES=(
  i3
  polybar
  alacritty
  rofi
  picom
)

OMARCHY_PACKAGES=(
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
  ${0##*/} [--platform ubuntu|omarchy] [--dry-run] [--skip-packages] [--desktop i3] [--configs list|all]

Options:
  --platform       Target platform. Auto-detected when omitted.
  --dry-run        Print actions without changing the system.
  --skip-packages  Apply configs without installing packages.
  --desktop i3     Install Ubuntu i3 desktop packages and configs.
  --configs        Comma-separated config packages, or all enabled packages.
  -h, --help       Show this help.
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
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

run_shell() {
  local description="$1"
  local command="$2"

  if [[ $DRY_RUN == true ]]; then
    printf 'dry-run: %s\n' "$description"
  else
    bash -c "$command"
  fi
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

  return 1
}

parse_configs() {
  local raw="$1"

  if [[ $raw == all ]]; then
    CONFIGS=(all)
    return 0
  fi

  IFS=',' read -r -a CONFIGS <<<"$raw"
}

configure_github_cli_apt_repo() {
  local keyring="/etc/apt/keyrings/githubcli-archive-keyring.gpg"
  local source_list="/etc/apt/sources.list.d/github-cli.list"

  if [[ -e $keyring && -e $source_list ]]; then
    printf 'GitHub CLI apt repository already configured\n'
    return 0
  fi

  printf 'Configuring GitHub CLI apt repository\n'
  if ! command -v wget >/dev/null 2>&1; then
    run sudo apt update
    run sudo apt install -y wget
  fi

  run sudo mkdir -p -m 755 /etc/apt/keyrings
  run_shell \
    'install GitHub CLI apt keyring' \
    'out="$(mktemp)" && wget -nv -O"$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg && cat "$out" | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null && rm -f "$out"'
  run sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  run sudo mkdir -p -m 755 /etc/apt/sources.list.d
  run_shell \
    'write GitHub CLI apt source list' \
    'printf "deb [arch=%s signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main\n" "$(dpkg --print-architecture)" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null'
}

configure_nodesource_apt_repo() {
  local keyring="/etc/apt/keyrings/nodesource.gpg"
  local source_list="/etc/apt/sources.list.d/nodesource.list"
  local repo_line="deb [signed-by=$keyring] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main"

  if [[ -e $keyring && -e $source_list ]] && grep -Fxq "$repo_line" "$source_list"; then
    printf 'NodeSource apt repository already configured\n'
    return 0
  fi

  printf 'Configuring NodeSource apt repository for Node.js %s\n' "$NODE_MAJOR"
  run sudo apt update
  run sudo apt install -y ca-certificates curl gnupg

  run sudo mkdir -p -m 755 /etc/apt/keyrings
  run_shell \
    'install NodeSource apt keyring' \
    'out="$(mktemp)" && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key -o"$out" && gpg --dearmor <"$out" | sudo tee /etc/apt/keyrings/nodesource.gpg >/dev/null && rm -f "$out"'
  run sudo chmod go+r /etc/apt/keyrings/nodesource.gpg
  run sudo mkdir -p -m 755 /etc/apt/sources.list.d
  run_shell \
    'write NodeSource apt source list' \
    "printf '%s\n' '$repo_line' | sudo tee /etc/apt/sources.list.d/nodesource.list >/dev/null"
}

install_ubuntu_packages() {
  local packages=("${UBUNTU_PACKAGES[@]}")

  [[ $SKIP_PACKAGES == false ]] || { printf 'Skipping package installation\n'; return 0; }

  if [[ $DESKTOP == i3 ]]; then
    packages+=("${UBUNTU_I3_PACKAGES[@]}")
  fi

  configure_github_cli_apt_repo
  configure_nodesource_apt_repo
  packages+=(gh nodejs)

  printf 'Installing Ubuntu packages\n'
  run sudo apt update
  run sudo apt install -y "${packages[@]}"

  install_neovim_from_source
  install_user_tools
}

install_neovim_from_source() {
  local repo_dir="$HOME/repos/neovim"

  printf 'Building Neovim from source\n'
  if [[ $DRY_RUN == true ]]; then
    printf 'dry-run: clone or update https://github.com/neovim/neovim in %s\n' "$repo_dir"
    printf 'dry-run: make CMAKE_BUILD_TYPE=Release && sudo make install\n'
    return 0
  fi

  mkdir -p -- "$HOME/repos"
  if [[ -d $repo_dir/.git ]]; then
    git -C "$repo_dir" pull --ff-only
  else
    git clone https://github.com/neovim/neovim "$repo_dir"
  fi

  make -C "$repo_dir" CMAKE_BUILD_TYPE=Release
  sudo make -C "$repo_dir" install
}

install_user_tools() {
  if ! command -v starship >/dev/null 2>&1; then
    run_shell 'install Starship' 'curl -sS https://starship.rs/install.sh | sh -s -- -y'
  else
    printf 'Starship already installed\n'
  fi

  if ! command -v zoxide >/dev/null 2>&1; then
    run_shell 'install zoxide' 'curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh'
  else
    printf 'zoxide already installed\n'
  fi

  if ! command -v uv >/dev/null 2>&1; then
    run_shell 'install uv' 'curl -LsSf https://astral.sh/uv/install.sh | sh'
  else
    printf 'uv already installed\n'
  fi

  install_yazi_from_snap

  if ! command -v cargo >/dev/null 2>&1; then
    run_shell 'install Rust toolchain' 'curl --proto "=https" --tlsv1.3 https://sh.rustup.rs -sSf | sh -s -- -y'
  else
    printf 'Rust toolchain already installed\n'
  fi

  install_cargo_tool tokei tokei

  if command -v pipx >/dev/null 2>&1 && ! command -v poetry >/dev/null 2>&1; then
    run pipx install poetry
  fi
}

install_yazi_from_snap() {
  if command -v yazi >/dev/null 2>&1; then
    printf 'yazi already installed\n'
    return 0
  fi

  run sudo snap install yazi --classic
}

install_cargo_tool() {
  local command_name="$1"
  shift

  if command -v "$command_name" >/dev/null 2>&1; then
    printf '%s already installed\n' "$command_name"
    return 0
  fi

  run_shell \
    "install $command_name with cargo" \
    "source \"$HOME/.cargo/env\" 2>/dev/null || true; cargo install --locked $*"
}

install_omarchy_packages() {
  [[ $SKIP_PACKAGES == false ]] || { printf 'Skipping package installation\n'; return 0; }

  command -v omarchy >/dev/null 2>&1 || die 'omarchy command not found'

  printf 'Installing Omarchy packages\n'
  run omarchy pkg add "${OMARCHY_PACKAGES[@]}"
}

configure_omarchy_zsh_shell() {
  local target="$HOME/.config/uwsm/env"
  local shell_line='export SHELL=/usr/bin/zsh'

  [[ -e $target ]] || return 0

  if grep -Fxq -- "$shell_line" "$target"; then
    printf 'Omarchy UWSM shell already configured in %s\n' "$target"
    return 0
  fi

  printf 'Configuring Omarchy UWSM shell in %s\n' "$target"
  if [[ $DRY_RUN == true ]]; then
    printf 'dry-run: append %s to %s\n' "$shell_line" "$target"
  else
    printf '\n%s\n' "$shell_line" >>"$target"
  fi
}

configure_default_terminal() {
  local target="$HOME/.config/xdg-terminals.list"

  [[ $PLATFORM == omarchy ]] || return 0

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

  [[ $PLATFORM == omarchy ]] || return 0
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
  [[ $PLATFORM == omarchy ]] || return 0
  command -v hyprctl >/dev/null 2>&1 || return 0

  if [[ $DRY_RUN == true ]]; then
    printf 'dry-run: hyprctl reload && hyprctl configerrors\n'
    return 0
  fi

  hyprctl reload
  hyprctl configerrors
}

apply_configs() {
  local args=()
  local configs=("${CONFIGS[@]}")

  if [[ $DRY_RUN == true ]]; then
    args+=(--dry-run)
  fi

  if [[ $DESKTOP == i3 ]]; then
    args+=(--force-disabled)
    configs+=(i3 polybar alacritty rofi picom)
  fi

  printf 'Applying dotfiles config\n'
  "$DOTFILES_DIR/scripts/dotfiles.sh" "${args[@]}" install "${configs[@]}"
}

parse_args() {
  while (($#)); do
    case "$1" in
      --platform)
        (($# > 1)) || die '--platform requires a value'
        PLATFORM="$2"
        shift
        ;;
      --dry-run) DRY_RUN=true ;;
      --skip-packages) SKIP_PACKAGES=true ;;
      --desktop)
        (($# > 1)) || die '--desktop requires a value'
        DESKTOP="$2"
        shift
        ;;
      --configs)
        (($# > 1)) || die '--configs requires a value'
        parse_configs "$2"
        shift
        ;;
      -h|--help) usage; exit 0 ;;
      *) usage; exit 1 ;;
    esac
    shift
  done

  if [[ -z $PLATFORM ]]; then
    PLATFORM="$(detect_platform)" || die 'could not detect platform; pass --platform ubuntu or --platform omarchy'
  fi

  case "$PLATFORM" in
    ubuntu|omarchy) ;;
    *) die "unsupported platform: $PLATFORM" ;;
  esac

  case "$DESKTOP" in
    none|i3) ;;
    *) die "unsupported desktop: $DESKTOP" ;;
  esac
}

main() {
  parse_args "$@"

  case "$PLATFORM" in
    ubuntu) install_ubuntu_packages ;;
    omarchy) install_omarchy_packages ;;
  esac

  apply_configs

  if [[ $PLATFORM == omarchy ]]; then
    configure_omarchy_zsh_shell
    configure_default_terminal
    configure_hyprland_scrolling_layout
    reload_hyprland
  fi
}

main "$@"
