# Debian 13 install - cheat sheet (part 1)

Console-safe: ASCII only, so `more` shows it correctly.
Post-install tuning is in `02-debian-tuning/` (see the project README).

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
- If it fails, answer **`<No>`** and continue without network. Wi-Fi is fixed after install
  (see `02-debian-tuning/network/`).

## 2. Installer screens

- Language, locale, keymap - your choice.
- Hostname, domain (may be empty), root password, user account.
- If asked **Force UEFI installation** -> yes.

## 3. Partitioning - "Manual"

Verify labels with the installer's partition list: on some units WINPE and WinRE are swapped.

| Device | Action |
|---|---|
| `nvme0n1p1` 200MB | use as **EFI System Partition**, mount `/boot/efi`, **format: NO** |
| free space ~325GB | create: ext4, `/`, ~100 GB |
| remaining space | create: ext4, `/home`, all the rest |
| `nvme0n1p2` 16MB | leave alone (MSR) |
| `nvme0n1p3` 300GB | leave alone (Windows C:) |
| `nvme0n1p4` 300GB | leave alone (data D:) |
| `nvme0n1p5` 1GB | leave alone (WINPE) |
| `nvme0n1p6` 26GB | leave alone (OneKey) |
| `nvme0n1p7` 1GB | leave alone (WinRE) |

Check: the "Format" column must say **no** for `nvme0n1p1`.

## 4. Bootloader and packages

- Device for boot loader: **`/dev/nvme0n1`** (whole disk, no partition number).
- Debian desktop environment: keep.
- **GNOME: uncheck**. **KDE Plasma: check**.
- standard system utilities: keep.
- Do NOT create a swap partition (a swap file is configured later).

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

The script looks for `dsdt-cn.aml` next to itself, then in `/mnt/esp/`. The repository file is
`01-windows-prep/acpi/dsdt-chinese-WORKING.aml`; copy it as `dsdt-cn.aml` beforehand.

The script auto-detects the root partition. If it prints `no Debian root found`:

```sh
ROOTDEV=/dev/nvme0n1p8 sh /mnt/esp/fix-acpi.sh
```

Pick the ~100 GB partition from the printed `/proc/partitions` list.

Without this step the installed system will not boot (no NVMe).

Back to installer: **Ctrl+Alt+F1** -> Continue -> reboot. Unplug the stick.

## 6. First boot

- GRUB appears, then SDDM/graphical login (KDE) or a text login.
- Verify:

```sh
dmesg | grep -i GINF          # must print nothing
lsblk 2>/dev/null || cat /proc/partitions
```

`nvme0n1` and its partitions must be present.

## 7. After install

Continue with the second part of the project:

- network and Wi-Fi: `02-debian-tuning/network/README.md`
- KDE and basics: `02-debian-tuning/README.md`
- swap file: `02-debian-tuning/swap/README.md`
- Windows in GRUB: `02-debian-tuning/windows-grub.md`
- diagnostics: `02-debian-tuning/diagnostics/README.md`

If the machine has no network, keep a copy of `02-debian-tuning/` on the stick.

## 8. Reading this file in the installer console

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
| `dsdt-cn.aml not found` | copy the working table next to `fix-acpi.sh` or to `/mnt/esp/` |
| Installer does not find firmware files | files must be in the root of the G: stick |
| System does not boot after install | repeat section 5 from the installer stick |
| Menu items on the stick do nothing | the ISO GRUB ignores the stick config; use manual `e` |
