#!/bin/sh
# Switch Debian apt to a fast mirror and refresh package lists.
# Idempotent. Usage:
#   sudo sh setup-apt-mirrors.sh
#   sudo sh setup-apt-mirrors.sh https://mirror.corbina.net/debian
#
# Default is the fastest mirror measured from Moscow on 2026-11-17.
set -eu

DEFAULT=https://mirror.neftm.ru/debian
BASE="${1:-${MIRROR:-$DEFAULT}}"
BASE="${BASE%/}"

case "$BASE" in
    */debian) SEC="${BASE%debian}debian-security" ;;
    *) echo "ERROR: URI must end with /debian: $BASE" >&2; exit 2 ;;
esac

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: run as root: sudo sh $0 $BASE" >&2
    exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
    echo "ERROR: curl is required (apt install curl)" >&2
    exit 1
fi

echo "==> checking main archive: $BASE"
if ! curl -4 -fsSI --max-time 15 "$BASE/dists/trixie/Release" >/dev/null; then
    echo "ERROR: no trixie Release at $BASE" >&2
    exit 1
fi

echo "==> checking security archive: $SEC"
if ! curl -4 -fsSI --max-time 15 "$SEC/dists/trixie-security/Release" >/dev/null; then
    echo "ERROR: no trixie-security Release at $SEC" >&2
    exit 1
fi

TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT HUP INT TERM
cat > "$TMP" <<EOF
Types: deb
URIs: $BASE
Suites: trixie trixie-updates
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: $SEC
Suites: trixie-security
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF

SOURCES=/etc/apt/sources.list.d/debian.sources
LEGACY=/etc/apt/sources.list
STAMP=$(date +%Y%m%d%H%M%S)

# Disable only the old Debian lines; leave unrelated repositories alone.
if [ -f "$LEGACY" ] && grep -qE '^[[:space:]]*deb[[:space:]].*/debian(-security)?[[:space:]]' "$LEGACY"; then
    cp -p "$LEGACY" "$LEGACY.bak.$STAMP"
    sed -i "s|^\([[:space:]]*deb[[:space:]].*/debian\(-security\)\{0,1\}[[:space:]].*\)$|# \1|" "$LEGACY"
    echo "==> disabled old Debian entries in $LEGACY"
    echo "    backup: $LEGACY.bak.$STAMP"
fi

if [ -f "$SOURCES" ] && cmp -s "$TMP" "$SOURCES"; then
    echo "==> $SOURCES already up to date"
else
    if [ -f "$SOURCES" ]; then
        cp -p "$SOURCES" "$SOURCES.bak.$STAMP"
        echo "==> backup: $SOURCES.bak.$STAMP"
    fi
    install -m 0644 "$TMP" "$SOURCES"
    echo "==> wrote $SOURCES"
fi

for f in /etc/apt/sources.list.d/*.list; do
    [ -e "$f" ] || continue
    if grep -qE '^[[:space:]]*deb[[:space:]].*/debian(-security)?[[:space:]]' "$f"; then
        echo "WARN: $f also defines a Debian repo; disable it to avoid duplicates" >&2
    fi
done

echo "==> apt-get update"
apt-get update

echo
echo "==> active Debian sources"
apt-get indextargets --format '$(SITE) $(SUITE)' | sort -u
echo
echo "==> done"
