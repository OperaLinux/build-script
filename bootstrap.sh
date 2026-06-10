#!/usr/bin/env bash
set -euo pipefail

BUILD_REPO="${BUILD_REPO:-https://github.com/OperaLinux/build.git}"
BUILD_BRANCH="${BUILD_BRANCH:-main}"
WORKDIR="${WORKDIR:-${PWD}/operalinux-build}"
ISO_NAME="${ISO_NAME:-OperaLinux-1.0.0-lynx-x86_64.iso}"
CHANGE_HOST_REPOS="${OPERALINUX_CHANGE_HOST_REPOS:-0}"
ARTIX_MIRROR="${ARTIX_MIRROR:-https://mirror1.artixlinux.org}"
BACKUP_ROOT="/var/backups/operalinux-build-script"

log() {
    printf '[%s] %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*"
}

die() {
    log "ERROR: $*"
    exit 1
}

have() {
    command -v "$1" >/dev/null 2>&1
}

require_root() {
    [[ "${EUID}" -eq 0 ]] || die "Run this script with sudo"
}

require_pacman_host() {
    have pacman || die "This bootstrap requires an Arch/Artix host with pacman"
}

backup_pacman_config() {
    BACKUP_DIR="${BACKUP_ROOT}/$(date -u '+%Y%m%d%H%M%S')"
    mkdir -p "$BACKUP_DIR"
    cp -a /etc/pacman.conf "$BACKUP_DIR/pacman.conf" 2>/dev/null || true
    cp -a /etc/pacman.d "$BACKUP_DIR/pacman.d" 2>/dev/null || true
    log "Pacman backup saved in $BACKUP_DIR"
}

install_host_dependencies() {
    log "Installing host dependencies"
    pacman -Sy --needed --noconfirm \
        git base-devel arch-install-scripts grub libisoburn mtools \
        squashfs-tools zstd curl jq tar gawk sed grep coreutils findutils util-linux psmisc
}

latest_artix_pkg_url() {
    local pkg_prefix="$1"
    curl -fsSL "${ARTIX_MIRROR}/repos/system/os/x86_64/" |
        grep -Eo "href=\"${pkg_prefix}-[^\"]+-any\\.pkg\\.tar\\.(zst|xz)\"" |
        sed -E 's/^href="([^"]+)"/\1/' |
        sort -V |
        tail -n 1 |
        sed "s#^#${ARTIX_MIRROR}/repos/system/os/x86_64/#"
}

install_artix_keyring() {
    if pacman -Q artix-keyring >/dev/null 2>&1; then
        log "artix-keyring is already installed"
        pacman-key --populate artix archlinux >/dev/null 2>&1 || true
        return
    fi

    log "Bootstrap artix-keyring"
    local tmp keyring_url temp_conf
    tmp="$(mktemp -d)"

    keyring_url="$(latest_artix_pkg_url artix-keyring)"
    [[ -n "$keyring_url" ]] || die "Could not find artix-keyring on ${ARTIX_MIRROR}"

    curl -fL "$keyring_url" -o "$tmp/${keyring_url##*/}"

    temp_conf="$tmp/pacman-bootstrap.conf"
    cat > "$temp_conf" <<'EOF_CONF'
[options]
Architecture = auto
SigLevel = Never
LocalFileSigLevel = Never
EOF_CONF

    pacman -U --config "$temp_conf" --noconfirm --nodeps "$tmp/${keyring_url##*/}"
    pacman-key --init
    pacman-key --populate archlinux artix
    rm -rf "$tmp"
}

write_artix_host_repos() {
    log "Configuring host repositories as Artix-first"
    backup_pacman_config

    install -Dm644 /dev/stdin /etc/pacman.d/mirrorlist <<'EOF_MIRRORS'
Server = https://mirror1.artixlinux.org/repos/$repo/os/$arch
Server = https://mirrors.dotsrc.org/artix-linux/repos/$repo/os/$arch
Server = https://ftp.crifo.org/artix/repos/$repo/os/$arch
Server = https://artix.unixpeople.org/repos/$repo/os/$arch
EOF_MIRRORS

    install -Dm644 /dev/stdin /etc/pacman.d/mirrorlist-arch <<'EOF_ARCH'
Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch
Server = https://mirror.rackspace.com/archlinux/$repo/os/$arch
Server = https://mirrors.kernel.org/archlinux/$repo/os/$arch
EOF_ARCH

    cat > /etc/pacman.conf <<'EOF_PACMAN'
[options]
HoldPkg     = pacman glibc
Architecture = auto
Color
CheckSpace
ParallelDownloads = 5
SigLevel    = Required DatabaseOptional
LocalFileSigLevel = Optional

[system]
Include = /etc/pacman.d/mirrorlist

[world]
Include = /etc/pacman.d/mirrorlist

[galaxy]
Include = /etc/pacman.d/mirrorlist

[lib32]
Include = /etc/pacman.d/mirrorlist

[extra]
Include = /etc/pacman.d/mirrorlist-arch

[multilib]
Include = /etc/pacman.d/mirrorlist-arch
EOF_PACMAN

    pacman -Sy
    log "Host repositories updated. Manual restore is available from $BACKUP_DIR"
}

confirm_repo_change() {
    if [[ "$CHANGE_HOST_REPOS" != "1" ]]; then
        return
    fi

    printf '\nWARNING: this will replace /etc/pacman.conf with Artix-first repositories.\n'
    printf 'This is useful for building/testing OperaLinux, but it can turn your Arch host into a mixed system.\n'
    printf 'A backup will be created before any change is made.\n'
    printf 'Type CHANGE REPOS to continue: '
    local reply
    [[ -r /dev/tty ]] || die "An interactive terminal is required to confirm the repository change"
    read -r reply < /dev/tty
    [[ "$reply" == "CHANGE REPOS" ]] || die "Repository change cancelled"
}

clone_or_update_build_repo() {
    mkdir -p "$WORKDIR"
    if [[ -d "$WORKDIR/build/.git" ]]; then
        log "Updating build repository in $WORKDIR/build"
        git -C "$WORKDIR/build" fetch origin "$BUILD_BRANCH"
        git -C "$WORKDIR/build" checkout "$BUILD_BRANCH"
        git -C "$WORKDIR/build" pull --ff-only
    else
        log "Cloning $BUILD_REPO into $WORKDIR/build"
        rm -rf "$WORKDIR/build"
        git clone --branch "$BUILD_BRANCH" "$BUILD_REPO" "$WORKDIR/build"
    fi
}

run_build() {
    log "Starting OperaLinux build"
    chmod +x "$WORKDIR/build/build.sh"
    (
        cd "$WORKDIR/build"
        INSTALL_PROTON_GE="${INSTALL_PROTON_GE:-1}" ./build.sh
    )
}

copy_iso_to_caller() {
    local built_iso="$WORKDIR/build/output/$ISO_NAME"
    local dest="${OUTPUT_ISO:-${PWD}/${ISO_NAME}}"
    [[ -s "$built_iso" ]] || die "ISO not found: $built_iso"
    cp -f "$built_iso" "$dest"
    if [[ -n "${SUDO_UID:-}" && -n "${SUDO_GID:-}" ]]; then
        chown "$SUDO_UID:$SUDO_GID" "$dest" || true
    fi
    log "ISO ready: $dest"
}

main() {
    require_root
    require_pacman_host
    install_host_dependencies
    install_artix_keyring
    confirm_repo_change
    if [[ "$CHANGE_HOST_REPOS" == "1" ]]; then
        write_artix_host_repos
    fi
    clone_or_update_build_repo
    run_build
    copy_iso_to_caller
}

main "$@"
