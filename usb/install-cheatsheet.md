# Debian 13 install + first boot - cheat sheet

Console-safe: ASCII only, so `more` shows it correctly.

## 0. Boot the installer

1. Unplug external disk `X:` (and other sticks). Keep only the Verbatim stick.
2. Reboot -> F12 -> `UEFI: Verbatim STORE N GO`.
3. In GRUB select **Graphical install**, press **`e`**.
4. Insert these three lines BEFORE the `linux` line:

```
insmod acpi
search --no-floppy --file --set=dd /dsdt-cn.aml
acpi ($dd)/dsdt-cn.aml
```

5. **Ctrl+X** to boot.

Without this the kernel sees no USB and no NVMe at all.

## 1. Firmware dialog ("Detect network hardware")

- Answer **`<Yes>`** if the `G:` stick (DVR-Video) is plugged in - the iwlwifi files are in its root.
- If it fails, answer **`<No>`** and continue without network. Wi-Fi is fixed after install (section 7).

## 2. Installer screens

- Language, locale, keymap - your choice.
- Hostname, domain (may be empty), root password, user account.
- If asked **Force UEFI installation** -> yes.

## 3. Partitioning - "Manual"

| Device | Action |
|---|---|
| `nvme0n1p1` 200MB | use as **EFI System Partition**, mount `/boot/efi`, **format: NO** |
| free space 325.7GB | create: ext4, `/`, **100 GB** |
| remaining space | create: ext4, `/home`, all the rest |
| `nvme0n1p2` 16MB | leave alone (MSR) |
| `nvme0n1p3` 300GB | leave alone (Windows C:) |
| `nvme0n1p4` 300GB | leave alone (data D:) |
| `nvme0n1p5` 1GB | leave alone (WinRE) |
| `nvme0n1p6` 26GB | leave alone (OneKey) |
| `nvme0n1p7` 1GB | leave alone (WINPE) |

Check: the "Format" column must say **no** for `nvme0n1p1`.

## 4. Bootloader and packages

- Device for boot loader: **`/dev/nvme0n1`** (whole disk, no partition number).
- Debian desktop environment: keep.
- **GNOME: uncheck**. **KDE Plasma: check**.
- standard system utilities: keep.
- Do NOT create a swap partition.

## 5. BEFORE REBOOT - bake the DSDT (critical)

On the final screen do NOT press Continue. Press **Ctrl+Alt+F2** and run:

```sh
mkdir -p /mnt/esp
mount /dev/nvme0n1p1 /mnt/esp
sh /mnt/esp/fix-acpi.sh
```

Expected:

```
root: /dev/nvme0n1p8
early initrd: 523000 bytes
entries with early initrd: 2
RESULT: OK - DSDT baked into boot entries
```

The script auto-detects the root partition. If it prints `no Debian root found`:

```sh
ROOTDEV=/dev/nvme0n1p8 sh /mnt/esp/fix-acpi.sh
```

Pick the ~100 GB partition from the printed `/proc/partitions` list.

Without this step the installed system will not boot (no NVMe).

Back to installer: **Ctrl+Alt+F1** -> Continue -> reboot. Unplug the stick.

## 6. First boot

- GRUB appears, then a text login (install was minimal, no GUI yet).
- Verify:

```sh
dmesg | grep -i GINF          # must print nothing
lsblk 2>/dev/null || cat /proc/partitions
```

`nvme0n1` and its partitions must be present.

## 7. Network after install - pick one

### Option A: Wi-Fi firmware from the G: stick

```sh
mkdir -p /mnt/u
cat /proc/partitions          # find the G: stick, e.g. sdb1
mount /dev/sdb1 /mnt/u
dpkg -i /mnt/u/firmware-iwlwifi_*.deb
modprobe -r iwlwifi; modprobe iwlwifi
ip link                       # wlp0s20f3 should appear
```

Then connect. A minimal install may lack `wpa_supplicant`; if so, use option B first.

### Option B: Android USB tethering

1. Phone: plug the USB cable.
2. Phone: Settings -> Hotspot and tethering -> **USB tethering** ON.
3. Laptop:

```sh
ip link                       # phone appears as enx... (rndis_host)
cat > /tmp/20-usb.network <<EOF
[Match]
Name=enx*
[Network]
DHCP=yes
EOF
sudo cp /tmp/20-usb.network /etc/systemd/network/
sudo systemctl enable --now systemd-networkd
sleep 3
ip -4 a show enxXXXXXXXXXXXX
sudo sh -c 'echo "nameserver 1.1.1.1" > /etc/resolv.conf'
ping -c 3 1.1.1.1
```

If DHCP returns no address, configure by hand (Android: 192.168.42.0/24, gateway .129;
Samsung: 192.168.43.0/24, gateway .1):

```sh
sudo ip addr add 192.168.42.100/24 dev enxXXXXXXXXXXXX
sudo ip route add default via 192.168.42.129
```

### Option C: USB Ethernet adapter

Plug it in, then `ip link`. No DHCP client? Use the systemd-networkd recipe from option B with Name=* instead of Name=enx*.

## 7b. Wi-Fi bring-up (interface shows DOWN)

DOWN only means "not activated". Order matters - check rfkill first.

```sh
sudo rfkill list                 # look for "Soft blocked: yes"
sudo rfkill unblock all
sudo rfkill unblock wifi
sudo ip link set wlp0s20f3 up
ip a show wlp0s20f3                  # should show state UP now
```

If `ip link set` says "Operation not possible due to RF-kill", the radio is blocked:
fix rfkill first, then repeat.

Check that the driver actually loaded firmware:

```sh
dmesg | grep -i iwlwifi | tail -20
```

Good: `loaded firmware version ... op_mode iwlmvm`.
Bad: `failed to load ... .ucode` - the .deb was not installed (section 7A).

What client tools are available?

```sh
for c in iw wpa_supplicant nmcli nmtui dhclient; do
    printf "%-16s %s\n" "$c" "$(command -v $c || echo missing)"
done
```

### Connect with wpa_supplicant (works on a minimal install)

```sh
sudo wpa_passphrase "YOUR_SSID" "YOUR_PASSWORD" | sudo tee /etc/wpa_supplicant/wpa.conf
sudo wpa_supplicant -B -i wlp0s20f3 -c /etc/wpa_supplicant/wpa.conf
sudo dhclient -v wlp0s20f3
ping -c 3 1.1.1.1
```

Note: the password ends up in cleartext in /etc/wpa_supplicant/wpa.conf.
Run `wpa_passphrase` without the argument version to get a hashed PSK if needed.

### Connect with NetworkManager (if nmcli exists)

```sh
sudo nmcli device wifi list
sudo nmcli device wifi connect "YOUR_SSID" password "YOUR_PASSWORD"
```

### If neither tool exists

Offline bundle on this stick (21 packages, 8.5 MB):

```sh
sudo sh /mnt/u/install-offline.sh
```

It registers a local apt repo (file:/mnt/u/debs) and installs
wpasupplicant, iw, rfkill, network-manager with dependencies.
Without network at all, use option B (Android tethering) as well.

### Useful checks

```sh
sudo iw dev wlp0s20f3 scan | head -30        # SSIDs visible? (needs iw)
ip route                                 # default route after dhclient
cat /etc/resolv.conf                     # DNS servers present?
```

## 7c. Collect diagnostics onto the stick

A script is provided for this:

```sh
sudo sh /mnt/u/collect-logs.sh
```

It writes `debian-logs-YYYYmmdd-HHMMSS/` next to itself with dmesg, journal,
rfkill, lspci, firmware state and ACPI-fix state.

## 8. Desktop and firmware (once online)

```sh
apt update
apt install task-kde-desktop
apt install firmware-iwlwifi
```

## 9. Windows back into GRUB

```sh
apt install os-prober
sed -i 's/^#\?GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
update-grub
grep -i windows /boot/grub/grub.cfg
```

## 10. Reading this file in the installer console

```sh
mkdir -p /mnt/u && mount /dev/sdb1 /mnt/u
more /mnt/u/install-cheatsheet.md
```

- space = next page, `q` = quit
- scroll back: **Shift+PgUp**, forward: **Shift+PgDn**
- freeze output: **Ctrl+S**, resume: **Ctrl+Q**

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| No NVMe in the partitioner | forgot the `acpi` lines at boot (section 0) |
| `no Debian root found` in fix-acpi | pass `ROOTDEV=/dev/nvme0n1pN` |
| Installer does not find firmware files | files must be in the root of the G: stick (they are) |
| No `wlp0s20f3` after firmware install | `dmesg \| grep -i iwlwifi` - look for "loaded firmware version" |
| No network at all | option B (Android tethering) or C (USB Ethernet) |
| System does not boot after install | repeat section 5 from the installer stick |
