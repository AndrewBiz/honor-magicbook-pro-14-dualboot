#!/bin/sh
# Build dotool from source and install it to /usr/local/bin/dotool.
#
# dotool is not packaged in Debian 13. Handy uses it on Wayland to send the
# paste key combination to native Wayland apps (Konsole, Kate, Dolphin, ...).
#
# Usage (as root, after installing the build dependencies):
#   sudo apt install golang-go libxkbcommon-dev git
#   sudo sh build-dotool.sh
set -eu

REPO=${DOTOOL_REPO:-https://git.sr.ht/~geb/dotool}

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: run as root: sudo sh $0" >&2
    exit 1
fi
if ! command -v go >/dev/null 2>&1; then
    echo "ERROR: go not found; install it: sudo apt install golang-go" >&2
    exit 1
fi
if ! [ -f /usr/include/xkbcommon/xkbcommon.h ]; then
    echo "ERROR: libxkbcommon headers not found; install libxkbcommon-dev" >&2
    exit 1
fi

WORK=$(mktemp -d "${TMPDIR:-/tmp}/dotool.XXXXXX")
trap 'rm -rf "$WORK"' EXIT INT TERM HUP

echo "==> cloning $REPO"
git clone --depth 1 "$REPO" "$WORK/src"

echo "==> building (Go $(go version | awk '{print $3}'))"
cd "$WORK/src"
VERSION=$(git describe --tags --always 2>/dev/null || echo unknown)
go build -ldflags "-X main.Version=$VERSION" -o "$WORK/dotool"

echo "==> installing /usr/local/bin/dotool"
install -Dm755 "$WORK/dotool" /usr/local/bin/dotool
/usr/local/bin/dotool --version

echo
echo "==> next: sudo sh setup-uinput.sh"
