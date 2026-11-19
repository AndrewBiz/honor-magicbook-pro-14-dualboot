#!/bin/sh
# Install udev rule + hwdb entry for HONOR FMB-P input quirks and apply them now.
# Idempotent.
#
# Usage (as root):
#   sh setup-input.sh
set -eu

DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
RULE=99-honor-fmbp-input.rules
HWD=61-honor-fmbp-keyboard.hwdb
QUIRK_NAME="FTSC1000:00 2808:5662 UNKNOWN"

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: run as root: sudo sh $0" >&2
    exit 1
fi

for f in "$DIR/$RULE" "$DIR/$HWD"; do
    if [ ! -f "$f" ]; then
        echo "ERROR: missing $f" >&2
        exit 1
    fi
done

echo "==> installing udev rule"
install -m 0644 "$DIR/$RULE" "/etc/udev/rules.d/$RULE"

echo "==> installing hwdb entry"
install -m 0644 "$DIR/$HWD" "/etc/udev/hwdb.d/$HWD"

echo "==> reloading udev and hwdb"
systemd-hwdb update
udevadm control --reload
udevadm trigger --action=change --subsystem-match=input

echo "==> inhibiting the phantom touchscreen collection"
found=0
for d in /sys/class/input/input*; do
    [ -f "$d/name" ] || continue
    if [ "$(cat "$d/name")" = "$QUIRK_NAME" ]; then
        found=1
        echo 1 > "$d/inhibited"
        echo "    $(basename "$d"): inhibited=$(cat "$d/inhibited")"
    fi
done
if [ "$found" -eq 0 ]; then
    echo "    NOTE: '$QUIRK_NAME' not present now; the rule applies on next boot"
fi

echo
echo "==> verify (input devices with the inhibit attribute)"
for d in /sys/class/input/input*; do
    [ -f "$d/inhibited" ] || continue
    printf '%s  inhibited=%s  %s\n' \
        "$(basename "$d")" "$(cat "$d/inhibited")" "$(cat "$d/name")"
done

echo
echo "Expected: 'FTSC1000:00 2808:5662 UNKNOWN' shows inhibited=1."
echo "Then press F7 (or Fn+F7): the mic-mute OSD should toggle once and stay put."
