#!/bin/sh
# Collect Debian diagnostics into a folder on the stick this script runs from.
#
# Usage (from the installed Debian or from any root shell):
#   sudo sh /mnt/u/collect-logs.sh
#
# Result: <stick>/debian-logs-YYYYmmdd-HHMMSS/ with plain text files.

HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
STAMP=$(date +%Y%m%d-%H%M%S)
OUT="${OUT:-$HERE/debian-logs-$STAMP}"

echo "== collecting diagnostics =="
echo "script dir : $HERE"
echo "output dir : $OUT"

if [ "$(id -u)" != "0" ]; then
    echo "WARN: not running as root, some files will be missing (use sudo)"
fi

mkdir -p "$OUT" 2>/dev/null || {
    echo "ERROR: cannot write to $HERE"
    echo "Mount the stick somewhere writable and run: OUT=/mnt/u sh $0"
    exit 1
}

run() {
    name="$1"; shift
    out="$OUT/$name.txt"
    echo "--- $name" 
    {
        echo "# command: $*"
        echo "# date: $(date)"
        "$@"
    } > "$out" 2>&1 || echo "(exit code $?)" >> "$out"
}

# --- basic identity ---
run uname uname -a
run debian-version cat /etc/debian_version
run cmdline cat /proc/cmdline
run os-release cat /etc/os-release

# --- hardware ---
run lspci lspci -nnk
run lspci-wifi sh -c 'lspci -nnk -s 00:14.3'
run partitions cat /proc/partitions
run blockdevices sh -c 'command -v lsblk >/dev/null && lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT || echo "lsblk not installed"'
run network-interfaces sh -c 'command -v ip >/dev/null && ip a || ifconfig -a'
run net-class ls /sys/class/net

# --- wireless state ---
run rfkill sh -c 'command -v rfkill >/dev/null && rfkill list || echo "rfkill not installed"'
run iwlwifi-modinfo sh -c 'command -v modinfo >/dev/null && modinfo iwlwifi | head -25 || echo "modinfo not installed"'
run firmware-files sh -c 'ls /lib/firmware 2>/dev/null | grep -i "iwlwifi-bz" || echo "no iwlwifi-bz files"'
run firmware-packages sh -c 'dpkg -l 2>/dev/null | grep -iE "firmware|iwlwifi" || echo "no matching packages"'
run network-tools sh -c 'for c in iw wpa_supplicant wpa_cli nmcli nmtui dhclient ifup ifconfig; do printf "%-16s %s\n" "$c" "$(command -v $c || echo missing)"; done'
run wpa-config sh -c 'cat /etc/wpa_supplicant/wpa_supplicant.conf 2>/dev/null || echo "no wpa_supplicant.conf"'
run interfaces-config sh -c 'cat /etc/network/interfaces 2>/dev/null; echo "---"; cat /etc/network/interfaces.d/* 2>/dev/null'
run resolv sh -c 'cat /etc/resolv.conf 2>/dev/null'
run wifi-scan sh -c 'command -v iw >/dev/null && iw dev 2>/dev/null || echo "iw not installed"'

# --- kernel messages ---
run dmesg sh -c 'dmesg'
run dmesg-wifi sh -c 'dmesg | grep -iE "iwlwifi|iwl|wifi|80211" | tail -60'
run dmesg-acpi sh -c 'dmesg | grep -iE "GINF|AE_AML|_CRS|ACPI Error" | head -40'

# --- logs ---
run journal-boot sh -c 'command -v journalctl >/dev/null && journalctl -b --no-pager || echo "journalctl not installed"'
run journal-wifi sh -c 'command -v journalctl >/dev/null && journalctl -b --no-pager | grep -iE "iwlwifi|wpa|NetworkManager|wlan" | tail -80 || echo "journalctl not installed"'
run failed-units sh -c 'command -v systemctl >/dev/null && systemctl --no-pager --failed || echo "systemctl not installed"'

# --- our ACPI fix state ---
run acpi-fix sh -c 'ls -l /boot/dsdt-cn.aml /boot/acpi-dsdt.cpio 2>&1; echo "---"; grep -n "acpi-dsdt" /boot/grub/grub.cfg 2>/dev/null | head -5; echo "---"; grep -n "GRUB_EARLY_INITRD" /etc/default/grub 2>/dev/null'

sync
echo
echo "== done =="
echo "files: $(ls -1 "$OUT" | wc -l)"
echo "path : $OUT"
