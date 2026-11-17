# AGENTS.md

This repo is a hardware runbook, not an application: Markdown docs, two DSDT dumps, and four
POSIX shell scripts for a Debian 13 + Windows 11 dual boot on an HONOR FMB-P (MagicBook Pro 14
2025). There is no build, test suite, linter, CI, or codegen.

## Layout and where changes go

- `01-windows-prep/` — phase 1, while Windows is still the primary OS: DSDT tables, USB installer
  notes, `fix-acpi.sh`.
- `02-debian-tuning/` — phase 2, run from installed Debian. Each step is a topic directory with a
  `README.md` and, when useful, an idempotent script. The phase index is
  `02-debian-tuning/README.md`.
- The root `README.md` is a short dual-boot checklist, not a tutorial. When adding a tuning step,
  add it to both the phase index and the root checklist, and keep the status/date current.
- A tuning step's README should cover: status, exact command, what it changes, verification, and
  rollback. Reuse the shape of `02-debian-tuning/swap/README.md`.
- `iso/` and `private/` are gitignored and absent in a fresh clone; README references to
  `private/archive/...` and `private/state|log` dangle by design.

## Working here

- Only local check: `find . -name '*.sh' -not -path './.git/*' -exec sh -n {} \;`
- Do not run the scripts locally to "test" them: they modify swap, fstab, boot files, or the
  installed system. Review the diff and use `sh -n`.
- Scripts are POSIX `sh`, run as root, and state-changing ones must be idempotent. The installer
  has no bash, so no bashisms even in scripts intended for the installed system.
- Script output and `01-windows-prep/usb/install-cheatsheet.md` are ASCII-only English because
  they are read in a console with `more`. The README files are Russian; keep each file in its
  existing language.
- The stick's `debs/` directory is not tracked. `02-debian-tuning/network/install-offline.sh`
  only works on the prepared stick with `debs/Packages` next to it; do not invent packages to
  make it run locally.
- `01-windows-prep/usb/fix-acpi.sh` hardcodes the disk as `/dev/nvme0n1`; override with
  `ROOTDEV=/dev/nvme0n1pN` or `ESPDEV=/dev/nvme0n1p1`. Root autodetection skips `p1`–`p7`, which
  is specific to this machine's partition layout.
- `collect-logs.sh` writes next to itself by default; use `OUT=/tmp/...` when running it from the
  repo. `debian-logs-*/` is gitignored.

## ACPI fix (the core of the project)

- The firmware DSDT is broken (`NFC0` → `GNUM()` → `GINF` fails with `AE_AML_PACKAGE_LIMIT`),
  hiding USB, NVMe, and the touchpad. Only the Chinese-SKU table works; the global revision and
  the denis-bb table do not.
- Filename mismatch to watch for: the tracked working table is
  `01-windows-prep/acpi/dsdt-chinese-WORKING.aml`, but `fix-acpi.sh` searches for `dsdt-cn.aml`
  next to itself, then `/run/acpi/esp/dsdt-cn.aml` and `/mnt/esp/dsdt-cn.aml`. Copy/rename it
  when deploying; keep the tracked name because the docs and patches refer to it.
- Secure Boot must stay disabled: kernel lockdown blocks ACPI table overrides from initrd.
- Success check on the installed system:
  `dmesg | grep -i GINF` (must be empty), `lsblk` shows `nvme0n1`, and
  `grep acpi-dsdt /boot/grub/grub.cfg` shows the entry from `GRUB_EARLY_INITRD_LINUX_CUSTOM`.
- `01-windows-prep/acpi/*.patch` are explanations of what was changed; the `.aml` is the source
  of truth baked into `/boot/acpi-dsdt.cpio`. Do not edit or regenerate the AML without `iasl`
  and a real hardware boot test. A BIOS update can change the DSDT and invalidate the fix.

## Safety and publication

- Never run or recommend `W:` / `WIN11BOOT`: it is Honor factory recovery and repartitions the
  whole disk (`convert gpt`), erasing both OSes.
- Never restore the full Windows backup image — it overwrites the shared EFI partition and kills
  GRUB. Restore only the Windows partition.
- Public repo: never commit `private/` or `iso/` content. Keep serial numbers, the BIOS Windows
  OEM key, BCD, usernames, and logs out of tracked files; anonymize network interfaces as
  `enxXXXXXXXXXXXX`.
- Remote: `main` on `github.com/AndrewBiz/honor-magicbook-pro-14-dualboot`.
