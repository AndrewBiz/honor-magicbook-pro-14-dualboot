# Сбор диагностики

[collect-logs.sh](collect-logs.sh) собирает состояние Debian в текстовые файлы: ядро, ACPI,
NVMe, Wi-Fi, rfkill, firmware, сетевые утилиты, `dmesg`, journal и состояние ACPI-фикса.

Запуск от root; результат пишется рядом со скриптом:

```sh
sudo sh /mnt/u/collect-logs.sh
```

Если скрипт запускается из репозитория, лучше задать отдельный каталог, чтобы не засорять
рабочее дерево:

```sh
sudo OUT=/tmp/debian-logs sh collect-logs.sh
```

Итог: `debian-logs-YYYYmmdd-HHMMSS/` с файлами `uname.txt`, `dmesg.txt`, `journal-boot.txt`,
`acpi-fix.txt` и другими. Каталоги `debian-logs-*/` исключены из git.

Скрипт рассчитан на POSIX `sh` и не требует установленных `lsblk`, `iw`, `journalctl` — при их
отсутствии в файл попадёт пометка.

## Что смотреть первым

| Файл | Зачем |
|---|---|
| `dmesg-acpi.txt` | ошибки `GINF`, `AE_AML`, `_CRS`; штатный шум `TPD0`/`TPL1` — см. ниже |
| `blockdevices.txt` | виден ли `nvme0n1` и разделы |
| `dmesg-wifi.txt` | загрузилась ли прошивка `iwlmvm` |
| `network-tools.txt` | какие клиенты Wi-Fi установлены |
| `acpi-fix.txt` | на месте ли `acpi-dsdt.cpio` и запись в GRUB |

## Известный безвредный шум при загрузке

Проверено 2026-11-20, ядро 6.12.117, прошивка 1.13. Эти строки вылезают каждую загрузку,
выглядят как ошибки, но действий не требуют. Главное — не путать их с настоящим
`GINF` / `AE_AML_PACKAGE_LIMIT`: без исправленной DSDT ядро валилось именно на них.

| Строка в `dmesg` | Причина | Опасность |
|---|---|---|
| `ACPI BIOS Error (bug): Could not resolve symbol [\_SB.PC00.I2C3.TPD0], AE_NOT_FOUND` и то же для `I2C4.TPL1`, `I2C5.TPL1`, плюс `Skipping parse of AML opcode` | DSDT объявляет тачпады/перо на I2C3, I2C4, I2C5, которых на этом SKU нет: тачпад — Goodix `27C6:01E0` на `00:15.1` (`i2c-2`). Строки есть и в стоковом `dsdt.global.aml`, то есть это не следствие патча. ACPICA пропускает битые ссылки и грузит остальные 27 таблиц | нет |
| `i915: Port A asks to use VBT vswing/preemph tables` + `WARNING: ... intel_bios.c:2718 intel_bios_init` | VBT от BIOS объявляет DVO-таблицы vswing/preemph для порта A, Meteor Lake их не поддерживает; вместо тихого игнора стоит `WARN_ON` | нет |
| `iwlwifi: firmware: failed to load iwl-debug-yoyo.bin (-2)` | необязательная отладочная прошивка, её нет в `linux-firmware`; `-2` = файл не найден | нет |
| `hpet_acpi_add: no address or irqs in _CRS` | прошивка включила HPET без `_CRS`; ядро считает время по TSC | нет |
| `i915: Selective fetch area calculation failed in pipe A` | логгер PSR (panel self refresh) на MTL | нет |
| `i915: PHY A failed to request refclk after 1us.` | DP/PHY на MTL, шумит и без подключённого внешнего экрана | нет |
| `input input30: Unknown key pressed, code: 0x02e5` / `0x02e6` | `input30` — это `Huawei WMI hotkeys`; некоторые Fn-комбинации драйвер не маппит | клавиша ничего не делает |

Что действительно надо проверять после смены ядра или прошивки — что фикс ACPI на месте:

```sh
sudo journalctl -b -k --no-pager | grep -c GINF          # ожидается 0
sudo journalctl -b -k --no-pager | grep "DSDT ACPI table found in initrd"
```

Вторая команда должна показать `[kernel/firmware/acpi/dsdt.aml][0x7fa95]`: `0x7fa95` = 522901
байт, ровно размер `01-windows-prep/acpi/dsdt-chinese-WORKING.aml`.

### Как читать лог, не подпрыгивая к экрану

При `quiet` в cmdline на консоль попадают только ошибки, и они улетают за долю секунды.
Читать их потом:

```sh
sudo journalctl -b -k -p warning --no-pager     # проблемы текущей загрузки
sudo journalctl -b -1 -k -p warning --no-pager  # предыдущая загрузка
```

Без sudo journal читается, если пользователь в группе `systemd-journal`:

```sh
sudo usermod -aG systemd-journal "$USER"   # вступит в силу после перелогина
```

Отдельно про время: первая строка ядра идёт не с `0.00`, а примерно с `6.1` — в метку
попадает часть времени до старта ядра (`systemd-analyze`: `6.3s firmware`). Сообщения при этом
не потеряны, `Linux version` и есть самое начало.

### Если понадобится убрать шум с экрана

`quiet` уже стоит; `loglevel=3` в `GRUB_CMDLINE_LINUX_DEFAULT` скроет и `KERN_ERR`, то есть
заодно и будущие настоящие ошибки. Делать это не рекомендуется: шум дешевле, чем пропущенный
`GINF`.
