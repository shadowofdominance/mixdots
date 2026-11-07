#!/usr/bin/env bash
# mixdots installer: installs packages and symlinks configs with GNU Stow.
# Usage: ./install.sh [options]   (see --help)

set -euo pipefail

# ----------------------------------------------------------------------------
# Settings you may want to edit
# ----------------------------------------------------------------------------
# Config folders in this repo (one GNU Stow package per folder).
COMMON_PKGS=(alacritty kitty rofi nvim fastfetch zsh scripts quickshell noctalia)
WM_LIST=(sway mango niri)

# Mango build pins (Debian/Ubuntu only). Check the Mango wiki for current versions:
# https://github.com/mangowm/mango/wiki/installation
WLROOTS_TAG="0.20.2"
SCENEFX_TAG="0.5"
WLROOTS_URL="https://gitlab.freedesktop.org/wlroots/wlroots.git"
SCENEFX_URL="https://github.com/wlrfx/scenefx.git"
MANGO_URL="https://github.com/mangowm/mango.git"

# ----------------------------------------------------------------------------
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
SELECTED_WMS=()
SKIP_PACKAGES=0
SKIP_BUILD=0
DRY_RUN=0
ASSUME_YES=0

c_red=$'\e[31m'; c_grn=$'\e[32m'; c_ylw=$'\e[33m'; c_blu=$'\e[34m'; c_off=$'\e[0m'
info() { echo "${c_blu}::${c_off} $*"; }
ok()   { echo "${c_grn}✓${c_off} $*"; }
warn() { echo "${c_ylw}!${c_off} $*" >&2; }
die()  { echo "${c_red}✗${c_off} $*" >&2; exit 1; }

usage() {
    cat <<EOF
mixdots installer

Usage: ./install.sh [options]

  --wm LIST          Comma-separated: sway,mango,niri or "all" (default: ask)
  --link-only        Only symlink configs (no package installs, no builds)
  --skip-packages    Don't install packages from your distro's repos
  --skip-build       Don't build Mango from source
  --dry-run          Print what would happen, change nothing
  -y, --yes          Don't ask questions
  -h, --help         Show this help

Existing configs that would be overwritten are moved to:
  ~/.dotfiles-backup/<timestamp>/
EOF
}

run() {
    if [[ $DRY_RUN -eq 1 ]]; then echo "   [dry-run] $*"; else "$@"; fi
}

ask() {
    [[ $ASSUME_YES -eq 1 ]] && return 0
    read -r -p "$1 [y/N] " reply
    [[ "$reply" =~ ^[Yy]$ ]]
}

# ----------------------------------------------------------------------------
# Argument parsing
# ----------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --wm)
            [[ $# -ge 2 ]] || die "--wm needs a value"
            if [[ "$2" == "all" ]]; then SELECTED_WMS=("${WM_LIST[@]}")
            else IFS=',' read -r -a SELECTED_WMS <<< "$2"; fi
            shift ;;
        --link-only)     SKIP_PACKAGES=1; SKIP_BUILD=1 ;;
        --skip-packages) SKIP_PACKAGES=1 ;;
        --skip-build)    SKIP_BUILD=1 ;;
        --dry-run)       DRY_RUN=1 ;;
        -y|--yes)        ASSUME_YES=1 ;;
        -h|--help)       usage; exit 0 ;;
        *) usage; die "Unknown option: $1" ;;
    esac
    shift
done

[[ $EUID -ne 0 ]] || die "Run this as your normal user, not root (it uses sudo when needed)."

# Ask which WMs if not given
if [[ ${#SELECTED_WMS[@]} -eq 0 ]]; then
    if [[ $ASSUME_YES -eq 1 ]]; then
        SELECTED_WMS=("${WM_LIST[@]}")
    else
        echo "Which window managers do you want? (sway, mango, niri, or all)"
        read -r -p "> " answer
        if [[ "$answer" == "all" || -z "$answer" ]]; then SELECTED_WMS=("${WM_LIST[@]}")
        else IFS=', ' read -r -a SELECTED_WMS <<< "$answer"; fi
    fi
fi
for wm in "${SELECTED_WMS[@]}"; do
    [[ " ${WM_LIST[*]} " == *" $wm "* ]] || die "Unknown WM: $wm (choose from: ${WM_LIST[*]})"
done
has_wm() { [[ " ${SELECTED_WMS[*]} " == *" $1 "* ]]; }

# ----------------------------------------------------------------------------
# Distro / package manager detection
# ----------------------------------------------------------------------------
if   command -v apt-get >/dev/null 2>&1; then PM=apt
elif command -v pacman  >/dev/null 2>&1; then PM=pacman
elif command -v dnf     >/dev/null 2>&1; then PM=dnf
else PM=unknown; fi

pkg_install() {
    # Install packages one at a time so one missing package doesn't abort the rest.
    local p
    for p in "$@"; do
        case "$PM" in
            apt)    run sudo apt-get install -y "$p" || warn "Could not install '$p' with apt" ;;
            pacman) run sudo pacman -S --needed --noconfirm "$p" || warn "Could not install '$p' with pacman" ;;
            dnf)    run sudo dnf install -y "$p" || warn "Could not install '$p' with dnf" ;;
        esac
    done
}

install_packages() {
    [[ "$PM" != "unknown" ]] || { warn "No supported package manager (apt/pacman/dnf). Install packages manually; see README."; return; }
    info "Installing base packages with $PM"
    [[ "$PM" == "apt" ]] && run sudo apt-get update

    case "$PM" in
        apt)    pkg_install git stow jq curl zsh neovim alacritty kitty rofi fastfetch thunar grim slurp wl-clipboard libnotify-bin wlr-randr ;;
        pacman) pkg_install git stow jq curl zsh neovim alacritty kitty rofi fastfetch thunar grim slurp wl-clipboard libnotify wlr-randr ;;
        dnf)    pkg_install git stow jq curl zsh neovim alacritty kitty rofi fastfetch thunar grim slurp wl-clipboard libnotify wlr-randr ;;
    esac

    if has_wm sway; then
        info "Installing Sway"
        case "$PM" in
            apt|pacman|dnf) pkg_install sway swaybg swayidle swaylock xdg-desktop-portal-wlr ;;
        esac
    fi

    if has_wm niri; then
        info "Installing Niri"
        case "$PM" in
            pacman|dnf) pkg_install niri ;;
            apt) warn "Niri isn't in Ubuntu/Debian repos. Build it yourself: https://github.com/YaLTeR/niri/wiki/Getting-Started" ;;
        esac
    fi
}

# ----------------------------------------------------------------------------
# Mango (built from source on Debian/Ubuntu)
# ----------------------------------------------------------------------------
build_mango() {
    has_wm mango || return 0
    if command -v mango >/dev/null 2>&1; then ok "Mango already installed, skipping build"; return; fi

    if [[ "$PM" != "apt" ]]; then
        warn "Automatic Mango build is only set up for Debian/Ubuntu."
        warn "See https://github.com/mangowm/mango/wiki/installation for your distro."
        return
    fi

    info "Building Mango from source (wlroots $WLROOTS_TAG, scenefx $SCENEFX_TAG)"
    pkg_install build-essential meson ninja-build pkg-config cmake \
        libwayland-dev wayland-protocols libinput-dev libdrm-dev libxkbcommon-dev \
        libpixman-1-dev libdisplay-info-dev libliftoff-dev hwdata libseat-dev \
        libpcre2-dev xwayland libxcb1-dev libxcb-composite0-dev libxcb-icccm4-dev \
        libxcb-render-util0-dev libxcb-xfixes0-dev libxcb-res0-dev libxcb-ewmh-dev \
        libxcb-errors-dev libvulkan-dev glslang-tools libegl-dev libgles-dev \
        libgbm-dev libudev-dev libffi-dev libpango1.0-dev libcjson-dev

    local build_root
    build_root="$(mktemp -d)"
    trap 'rm -rf "$build_root"' RETURN

    if ! pkg-config --exists "wlroots-${WLROOTS_TAG%.*}" 2>/dev/null; then
        run git clone --depth 1 --branch "$WLROOTS_TAG" "$WLROOTS_URL" "$build_root/wlroots"
        run meson setup "$build_root/wlroots/build" "$build_root/wlroots" -Dprefix=/usr
        run ninja -C "$build_root/wlroots/build"
        run sudo ninja -C "$build_root/wlroots/build" install
    else ok "wlroots ${WLROOTS_TAG%.*} already present"; fi

    if ! pkg-config --exists "scenefx-${SCENEFX_TAG}" 2>/dev/null; then
        run git clone --depth 1 --branch "$SCENEFX_TAG" "$SCENEFX_URL" "$build_root/scenefx"
        run meson setup "$build_root/scenefx/build" "$build_root/scenefx" -Dprefix=/usr
        run ninja -C "$build_root/scenefx/build"
        run sudo ninja -C "$build_root/scenefx/build" install
    else ok "scenefx $SCENEFX_TAG already present"; fi

    run git clone --depth 1 "$MANGO_URL" "$build_root/mango"
    run meson setup "$build_root/mango/build" "$build_root/mango" -Dprefix=/usr
    run sudo ninja -C "$build_root/mango/build" install
    ok "Mango installed"
}

# ----------------------------------------------------------------------------
# Oh My Zsh
# ----------------------------------------------------------------------------
install_ohmyzsh() {
    [[ -d "$HOME/.oh-my-zsh" ]] && { ok "Oh My Zsh already installed"; return; }
    command -v zsh >/dev/null 2>&1 || { warn "zsh not installed, skipping Oh My Zsh"; return; }
    info "Installing Oh My Zsh"
    if [[ $DRY_RUN -eq 1 ]]; then echo "   [dry-run] install Oh My Zsh"; return; fi
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c \
        "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended \
        || warn "Oh My Zsh install failed"
}

# ----------------------------------------------------------------------------
# Linking configs with GNU Stow
# ----------------------------------------------------------------------------
backup_conflicts() {
    # Move any existing file that would block a symlink into the backup folder.
    local pkg="$1" f rel target
    while IFS= read -r -d '' f; do
        rel="${f#"$REPO_DIR/$pkg/"}"
        target="$HOME/$rel"
        if [[ -e "$target" || -L "$target" ]]; then
            [[ "$(readlink -f "$target")" == "$(readlink -f "$f")" ]] && continue
            run mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
            run mv "$target" "$BACKUP_DIR/$rel"
            warn "Backed up ~/$rel"
        fi
    done < <(find "$REPO_DIR/$pkg" \( -type f -o -type l \) -print0)
}

link_configs() {
    command -v stow >/dev/null 2>&1 || die "GNU Stow is required. Install it (e.g. sudo apt install stow) and re-run."
    local pkgs=("${COMMON_PKGS[@]}") wm pkg
    for wm in "${SELECTED_WMS[@]}"; do pkgs+=("$wm"); done

    info "Linking configs from $REPO_DIR"
    for pkg in "${pkgs[@]}"; do
        if [[ ! -d "$REPO_DIR/$pkg" ]]; then
            warn "No '$pkg' folder in the repo, skipping"
            continue
        fi
        backup_conflicts "$pkg"
        run stow -d "$REPO_DIR" -t "$HOME" -R "$pkg"
        ok "Linked $pkg"
    done
}

make_scripts_executable() {
    local d="$REPO_DIR/scripts/.local/bin"
    [[ -d "$d" ]] && run chmod +x "$d"/* 2>/dev/null || true
}

set_default_shell() {
    command -v zsh >/dev/null 2>&1 || return 0
    [[ "$(basename "${SHELL:-}")" == "zsh" ]] && return 0
    if [[ $ASSUME_YES -eq 1 ]]; then
        info "Skipping default shell change (run: chsh -s \"$(command -v zsh)\")"
    elif ask "Make zsh your default shell?"; then
        run chsh -s "$(command -v zsh)" || warn "chsh failed; run it manually"
    fi
}

# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------
info "WMs selected: ${SELECTED_WMS[*]}"
[[ $DRY_RUN -eq 1 ]] && warn "Dry run: nothing will be changed."

if [[ $SKIP_PACKAGES -eq 0 ]]; then
    install_packages
    [[ $SKIP_BUILD -eq 0 ]] && build_mango
fi

install_ohmyzsh
link_configs
make_scripts_executable
set_default_shell

echo
ok "Done."
[[ -d "$BACKUP_DIR" ]] && info "Your old configs were saved in $BACKUP_DIR"
cat <<EOF

Next steps:
  - Quickshell and Noctalia are NOT installed by this script. Follow their
    official install docs, then restart your session.
  - Keybinds are personal! Review them before first use:
      Sway : ~/.config/sway/config
      Mango: ~/.config/mango/config.conf
      Niri : ~/.config/niri/config.kdl
  - Set up your monitors (run 'wlr-randr' inside a session to see names).
  - Log out and pick Sway / Mango / Niri from your display manager.
EOF
