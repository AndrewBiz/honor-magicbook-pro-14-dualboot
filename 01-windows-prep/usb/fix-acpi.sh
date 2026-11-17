#!/bin/sh
# Bake the patched DSDT (Chinese SKU) into the installed Debian early initrd.
# Run from the installer environment BEFORE the first reboot.
#
#   mkdir -p /mnt/u && mount /dev/sdX1 /mnt/u && sh /mnt/u/fix-acpi.sh
#
# The script looks for dsdt-cn.aml next to itself, then on the internal ESP.
# Optional: ROOTDEV=/dev/nvme0n1p8 sh /mnt/u/fix-acpi.sh
set -e

HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
WORK=/run/acpi
ESPDEV="${ESPDEV:-/dev/nvme0n1p1}"
ROOTDEV="${ROOTDEV:-}"

echo "== ACPI fix for installed system =="
echo "script dir: ${HERE:-unknown}"

# --- source table ---
SRC=""
for c in "$HERE/dsdt-cn.aml" /run/acpi/esp/dsdt-cn.aml /mnt/esp/dsdt-cn.aml; do
    if [ -f "$c" ]; then SRC="$c"; break; fi
done
if [ -z "$SRC" ]; then
    echo "ERROR: dsdt-cn.aml not found."
    echo "Put it next to this script or mount the ESP at /mnt/esp"
    exit 1
fi
echo "table: $SRC ($(wc -c < "$SRC") bytes)"

# --- locate installed system ---
if [ -f /target/etc/debian_version ]; then
    R=/target
    echo "root: /target (already mounted)"
else
    if [ -n "$ROOTDEV" ]; then
        candidates="$ROOTDEV"
    else
        candidates=$(ls /dev/nvme0n1p* 2>/dev/null)
    fi
    echo "candidates: $candidates"
    mkdir -p "$WORK/t"
    found=""
    for p in $candidates; do
        case "$p" in
            *p1|*p2|*p3|*p4|*p5|*p6|*p7) continue ;;
        esac
        for opt in ro rw; do
            if mount -o "$opt" "$p" "$WORK/t" 2>/dev/null; then
                if [ -f "$WORK/t/etc/debian_version" ]; then
                    umount "$WORK/t" 2>/dev/null || true
                    found="$p"
                    break
                fi
                umount "$WORK/t" 2>/dev/null || true
            fi
        done
        [ -n "$found" ] && break
    done
    if [ -z "$found" ]; then
        echo "ERROR: no Debian root found on $candidates"
        echo "--- /proc/partitions ---"
        cat /proc/partitions
        echo "Retry with: ROOTDEV=/dev/nvme0n1pN sh $0"
        exit 1
    fi
    echo "root: $found"
    mkdir -p "$WORK/root"
    mount "$found" "$WORK/root"
    R="$WORK/root"
fi

[ -f "$R/etc/debian_version" ] || { echo "ERROR: $R is not a Debian root"; exit 1; }
echo "target: $R ($(cat "$R/etc/debian_version"))"

# --- build early cpio ---
rm -rf "$WORK/build"
mkdir -p "$WORK/build/kernel/firmware/acpi"
cp "$SRC" "$WORK/build/kernel/firmware/acpi/dsdt.aml"
( cd "$WORK/build" && find kernel -print | cpio -o -H newc ) > "$R/boot/acpi-dsdt.cpio" 2>/dev/null
SIZE=$(wc -c < "$R/boot/acpi-dsdt.cpio")
echo "early initrd: $SIZE bytes"
[ "$SIZE" -gt 1000 ] || { echo "ERROR: cpio looks empty"; exit 1; }

cp "$SRC" "$R/boot/dsdt-cn.aml"
echo "copied table to $R/boot/dsdt-cn.aml"

# --- grub config ---
if grep -q 'GRUB_EARLY_INITRD_LINUX_CUSTOM' "$R/etc/default/grub"; then
    echo "GRUB_EARLY_INITRD_LINUX_CUSTOM already set"
else
    echo 'GRUB_EARLY_INITRD_LINUX_CUSTOM="acpi-dsdt.cpio"' >> "$R/etc/default/grub"
    echo "added GRUB_EARLY_INITRD_LINUX_CUSTOM"
fi

# --- regenerate grub.cfg (EFI partition not required) ---
for d in dev proc sys; do
    mkdir -p "$R/$d"
    grep -q " $R/$d " /proc/mounts 2>/dev/null || mount --bind "/$d" "$R/$d" 2>/dev/null || true
done

echo "running update-grub..."
chroot "$R" update-grub || echo "WARN: update-grub returned non-zero"

echo "--- verify ---"
if grep -q 'acpi-dsdt.cpio' "$R/boot/grub/grub.cfg" 2>/dev/null; then
    grep -c 'acpi-dsdt.cpio' "$R/boot/grub/grub.cfg" | sed 's/^/entries with early initrd: /'
    echo "RESULT: OK - DSDT baked into boot entries"
else
    echo "RESULT: WARN - acpi-dsdt.cpio absent from grub.cfg"
    echo "Check: grep acpi-dsdt $R/boot/grub/grub.cfg"
fi

sync
echo "== done, safe to reboot =="
