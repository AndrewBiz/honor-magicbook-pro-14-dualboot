#!/bin/sh
# Install the evdev-based mic-mute handler: script, udev ACL rule, user unit.
# Idempotent.
#
# Usage (as root):
#   sh setup-micmute.sh
set -eu

DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
LIBDIR=/usr/local/lib/honor-fmbp
RULE=99-honor-fmbp-micmute.rules
UNIT=mic-mute-key.service

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: run as root: sudo sh $0" >&2
    exit 1
fi

if ! command -v evtest >/dev/null 2>&1; then
    echo "ERROR: evtest is not installed: sudo apt install evtest" >&2
    exit 1
fi

echo "==> installing handler"
install -d "$LIBDIR"
install -m 0755 "$DIR/mic-mute-key.sh" "$LIBDIR/mic-mute-key.sh"

echo "==> installing udev rule (uaccess ACL on the hotkey event device)"
install -m 0644 "$DIR/$RULE" "/etc/udev/rules.d/$RULE"

echo "==> installing user unit"
install -m 0644 "$DIR/$UNIT" "/etc/systemd/user/$UNIT"

echo "==> reloading udev"
udevadm control --reload
udevadm trigger --action=change --subsystem-match=input

echo
echo "==> done. Remaining steps, as your desktop user (not root):"
echo "    systemctl --user daemon-reload"
echo "    systemctl --user enable --now $UNIT"
echo
echo "    Then unbind KDE's own handler, otherwise you get a third toggle:"
echo "    System Settings -> Shortcuts -> Audio Volume -> Mute Microphone -> none"
echo
echo "==> verify: press Fn+F7 three times, the mic must flip exactly once per press."
echo "    journalctl --user -u $UNIT -n 20    # handler log, no errors expected"
