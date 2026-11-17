#!/bin/sh
# Install networking tools offline from the ./debs folder on this stick.
#
#   sudo sh /mnt/u/install-offline.sh
#
# Installs: wpasupplicant, iw, rfkill, network-manager (+ dependencies).
set -e

HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
LIST=/etc/apt/sources.list.d/offline-debs.list
APTOPTS="-o Dir::Etc::sourcelist=$LIST -o Dir::Etc::sourceparts=- -o APT::Get::List-Cleanup=0"

echo "== offline install =="
echo "repo: $HERE/debs"

if [ "$(id -u)" != "0" ]; then
    echo "ERROR: run with sudo"
    exit 1
fi

if [ ! -f "$HERE/debs/Packages" ]; then
    echo "ERROR: $HERE/debs/Packages not found (is the stick mounted read-only?)"
    exit 1
fi

case "$HERE" in
    *" "*) echo "ERROR: mount path contains a space: $HERE"
           echo "Mount it elsewhere, e.g.: sudo mount /dev/sdX1 /mnt/u"
           exit 1 ;;
esac

echo "deb [trusted=yes] file:$HERE/debs ./" > "$LIST"

echo "--- apt update (local repo only) ---"
apt-get update $APTOPTS

echo "--- install ---"
apt-get install $APTOPTS -y --no-install-recommends wpasupplicant iw rfkill network-manager

echo "--- optional: os-prober (adds Windows to GRUB) ---"
apt-get install $APTOPTS -y --no-install-recommends os-prober || echo "WARN: os-prober skipped"

rm -f "$LIST"

echo "--- verify ---"
for c in iw wpa_supplicant wpa_cli nmcli rfkill os-prober; do
    printf "%-16s %s\n" "$c" "$(command -v "$c" 2>/dev/null || echo missing)"
done

echo
echo "== done =="
echo "next:"
echo "  sudo rfkill unblock all"
echo "  sudo nmcli device wifi list"
echo "  sudo nmcli device wifi connect \"SSID\" password \"PASS\""
