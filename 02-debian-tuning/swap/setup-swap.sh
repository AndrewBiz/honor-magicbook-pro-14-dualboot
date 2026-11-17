#!/bin/sh
# Create/activate a swap file and tune vm.swappiness. Idempotent.
#
# Usage (as root):
#   sh setup-swap.sh          # 8G /swapfile
#   sh setup-swap.sh 16G      # other size; G or M suffix
set -eu

SIZE="${1:-8G}"
SWAPFILE=/swapfile

case "$SIZE" in
    *[Gg]) NUM=${SIZE%?}; MIB=$((NUM * 1024)) ;;
    *[Mm]) NUM=${SIZE%?}; MIB=$NUM ;;
    *) echo "ERROR: size must end with G or M (e.g. 8G, 512M)" >&2; exit 2 ;;
esac
case "$NUM" in
    ''|*[!0-9]*) echo "ERROR: invalid size: $SIZE" >&2; exit 2 ;;
esac
if [ "$NUM" -eq 0 ]; then
    echo "ERROR: size must be greater than zero" >&2
    exit 2
fi

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: run as root: sudo sh $0 $SIZE" >&2
    exit 1
fi

echo "==> RAM and current swap"
free -h

if [ -e "$SWAPFILE" ]; then
    echo "==> $SWAPFILE already exists, skipping creation"
else
    echo "==> creating $SWAPFILE ($SIZE)"
    if ! fallocate -l "$SIZE" "$SWAPFILE" 2>/dev/null; then
        echo "    fallocate failed, using dd (slower)"
        rm -f "$SWAPFILE"
        dd if=/dev/zero of="$SWAPFILE" bs=1M count="$MIB" status=progress
    fi
    chmod 600 "$SWAPFILE"
    chown root:root "$SWAPFILE"
    echo "==> mkswap"
    mkswap "$SWAPFILE"
fi

echo "==> swapon"
if grep -q "^$SWAPFILE[[:space:]]" /proc/swaps; then
    echo "    already active"
elif swapon "$SWAPFILE" 2>/dev/null; then
    echo "    activated"
else
    echo "    not formatted as swap, running mkswap"
    mkswap "$SWAPFILE"
    swapon "$SWAPFILE"
fi

echo "==> adding /etc/fstab entry if missing"
if ! grep -qE "^[[:space:]]*$SWAPFILE[[:space:]]" /etc/fstab; then
    cp -p /etc/fstab "/etc/fstab.bak.$(date +%Y%m%d%H%M%S)"
    printf '\n# swap file\n%s none swap sw 0 0\n' "$SWAPFILE" >> /etc/fstab
    echo "    added (backup: /etc/fstab.bak.*)"
else
    echo "    entry already present"
fi

echo "==> tuning vm.swappiness (10: swap only under real memory pressure)"
printf 'vm.swappiness = 10\n' > /etc/sysctl.d/99-swappiness.conf
sysctl -q -p /etc/sysctl.d/99-swappiness.conf

echo
echo "==> verify"
free -h
grep "^$SWAPFILE[[:space:]]" /proc/swaps || true
grep swap /etc/fstab
sysctl vm.swappiness
