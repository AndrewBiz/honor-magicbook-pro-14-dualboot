#!/bin/sh
# Make /dev/uinput usable by virtual-keyboard injectors (dotool, used by Handy).
#
# Loads the uinput module at boot, creates the "uinput" group, and installs a
# udev rule so members of that group can create virtual keyboards. A dedicated
# group is used instead of "input": the latter also grants read access to every
# keyboard and event device.
#
# Usage (as root, from sudo so the desktop user can be detected):
#   sudo sh setup-uinput.sh
#   sudo USER_TO_ADD=<user> sh setup-uinput.sh
set -eu

GROUP=uinput
RULE=/etc/udev/rules.d/80-uinput.rules
LOAD=/etc/modules-load.d/uinput.conf
TARGET=${USER_TO_ADD:-${SUDO_USER:-}}

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: run as root: sudo sh $0" >&2
    exit 1
fi
if [ -z "$TARGET" ] || [ "$TARGET" = root ]; then
    echo "ERROR: cannot detect the desktop user; run via sudo or set USER_TO_ADD" >&2
    exit 1
fi

echo "==> loading uinput module"
MODPROBE=$(command -v modprobe || echo /usr/sbin/modprobe)
"$MODPROBE" uinput

echo "==> enabling uinput at boot ($LOAD)"
if [ -f "$LOAD" ] && grep -qx uinput "$LOAD"; then
    echo "    already enabled"
else
    printf '%s\n' uinput > "$LOAD"
    echo "    enabled"
fi

echo "==> group $GROUP"
if getent group "$GROUP" >/dev/null; then
    echo "    group already exists"
else
    groupadd -r "$GROUP"
    echo "    group created"
fi
if id -nG "$TARGET" | tr ' ' '\n' | grep -qx "$GROUP"; then
    echo "    $TARGET is already a member"
else
    usermod -aG "$GROUP" "$TARGET"
    echo "    added $TARGET (effective after re-login)"
fi

echo "==> udev rule $RULE"
cat > "$RULE" <<'EOF'
# Allow members of the "uinput" group to create virtual input devices (dotool/Handy).
KERNEL=="uinput", SUBSYSTEM=="misc", GROUP="uinput", MODE="0660", OPTIONS+="static_node=uinput"
EOF
udevadm control --reload-rules
udevadm trigger --action=change --sysname-match=uinput
udevadm settle || true

# Processes of the current session started before usermod, so they are not in
# the new group yet. A per-device ACL covers the session without a re-login.
if command -v setfacl >/dev/null 2>&1; then
    echo "==> ACL for $TARGET (current session only)"
    setfacl -m "u:$TARGET:rw" /dev/uinput || true
fi

echo
echo "==> verify"
ls -l /dev/uinput
getent group "$GROUP"
if command -v getfacl >/dev/null 2>&1; then
    getfacl -p /dev/uinput 2>/dev/null | sed -n '1,8p'
fi
