# Часть 1 — подготовка и установка (Windows остаётся основной)

**Статус: выполнено.** Debian 13.7 установлен и загружается сам. Этот runbook сохранён, чтобы
повторить установку после переустановки Windows или на второй машине.

## Железо

| | |
|---|---|
| Ноутбук | HONOR FMB-P (MagicBook Pro 14 2025), BIOS 1.13 |
| CPU / RAM | Intel Core Ultra 5 225H / 32 ГБ |
| GPU | Intel Arc 130T |
| Диск | YMTC PC411 1 ТБ (NVMe), GPT, UEFI |
| Wi-Fi | Intel, `00:14.3`, драйвер `iwlwifi`, интерфейс **`wlp0s20f3`** |
| Windows | 11 build 26300, Secure Boot **выключен**, быстрый запуск и гибернация **выключены** |

## Главное, что надо знать

**1. У прошивки битый DSDT.** Устройство `NFC0` при загрузке вызывает `GNUM()` → `GINF` падает
с `AE_AML_PACKAGE_LIMIT` → namespace собирается не полностью. Симптомы: нет USB-контроллеров,
не виден NVMe, не работает тачпад.

**2. Лечится подменой DSDT на «китайскую» ревизию.** У Honor две прошивки (global / chinese),
нашей машине подходит **китайская**: `acpi/dsdt-chinese-WORKING.aml`. Глобальная ревизия и
таблица от denis-bb — не подходят.

**3. В установленной системе таблица запечена в ранний initrd**: `/boot/acpi-dsdt.cpio` +
`GRUB_EARLY_INITRD_LINUX_CUSTOM="acpi-dsdt.cpio"` в `/etc/default/grub`. Поэтому система
грузится сама, без ручных параметров.

**4. Secure Boot должен остаться выключенным.** Подмена ACPI через initrd блокируется kernel
lockdown, который включается при Secure Boot.

**5. Пункты меню на флешке не работают.** У загрузчика из ISO встроенный конфиг: он читает
`grub.cfg` из ISO9660 и игнорирует файлы на EFI-разделе флешки. Правки `L:\efi\*\grub.cfg`
бесполезны — нужен ручной `e` в GRUB (см. шпаргалку) либо пересборка ISO.

**6. Не запускать `W:` (WIN11BOOT).** Это заводское восстановление Honor: `convert gpt` и
создание разделов с нуля — стирает весь диск.

## Чеклист подготовки

- [x] В Windows выключить Secure Boot, быстрый запуск и гибернацию; проверить, что разделы
      Windows читаются из Linux.
- [x] Сохранить серийный номер, OEM-ключ Windows, BCD и таблицу разделов в `private/state/`.
- [x] Взять рабочую DSDT `acpi/dsdt-chinese-WORKING.aml` и положить её на флешку/ESP как
      `dsdt-cn.aml`.
- [x] Записать Debian netinst на флешку (dd), добавить `fix-acpi.sh`, `dsdt-cn.aml` и офлайн-
      пакеты для сети.
- [x] Загрузить установщик с ручными ACPI-строками (иначе не виден NVMe).
- [x] Разметить вручную: новый `/` и `/home` в свободном месте, разделы Windows не трогать.
- [x] До первого reboot запустить `fix-acpi.sh` из второго терминала установщика.
- [x] Проверить первый запуск: `dmesg | grep -i GINF` пусто, `nvme0n1` виден.

После фикса в `dmesg` остаётся штатный шум: `AE_NOT_FOUND` для `TPD0`/`TPL1` (ссылки на
несуществующие тачпады на I2C3–I2C5) и `WARNING` от `i915` про VBT порта A. Это не регрессия —
разбор в [../02-debian-tuning/diagnostics/README.md](../02-debian-tuning/diagnostics/README.md#известный-безвредный-шум-при-загрузке).

Пошагово, с экранами установщика: [usb/install-cheatsheet.md](usb/install-cheatsheet.md).

## Как устроен ACPI-фикс

Рабочая таблица лежит в [acpi/](acpi/):

| Файл | Назначение |
|---|---|
| `dsdt-chinese-WORKING.aml` | рабочая китайская таблица; она же запекается в initrd |
| `dsdt.global.aml` | глобальная ревизия, не подошла |
| `dsdt.chinese.patch`, `dsdt.global.patch` | что именно правится; `.aml` — источник истины |

Важно: скрипт ищет файл с именем **`dsdt-cn.aml`**, а в репозитории он называется
`dsdt-chinese-WORKING.aml`. При копировании на флешку/ESP переименовывайте. `fix-acpi.sh`
ищет таблицу рядом с собой, затем в `/run/acpi/esp/` и `/mnt/esp/`.

Запуск из установщика (до Continue):

```sh
mkdir -p /mnt/esp
mount /dev/nvme0n1p1 /mnt/esp
sh /mnt/esp/fix-acpi.sh
```

Если корень не определился автоматически:

```sh
ROOTDEV=/dev/nvme0n1p8 sh /mnt/esp/fix-acpi.sh
```

Ожидаемый результат:

```
root: /dev/nvme0n1p8
early initrd: 523000 bytes
entries with early initrd: 2
RESULT: OK - DSDT baked into boot entries
```

Скрипт создаёт `/boot/acpi-dsdt.cpio`, копирует таблицу в `/boot/dsdt-cn.aml`, добавляет
`GRUB_EARLY_INITRD_LINUX_CUSTOM` и пересобирает `grub.cfg`. Обновление ядра фикс не ломает:
initrd подключается заново при `update-grub`.

## Разметка после установки

```
p1  EFI          200 МБ   (общий, Windows + Debian)
p2  MSR           16 МБ
p3  C: Windows    300 ГБ  NTFS
p4  D: данные     300 ГБ  NTFS
p5  WINPE           1 ГБ  vfat
p6  OneKey         26 ГБ  ntfs (заводской образ Honor)
p7  WinRE           1 ГБ  ntfs
p8  /            93,1 ГБ  ext4
p9  /home       232,5 ГБ  ext4
```

Метки разделов `p5`–`p7` стоит сверять с `lsblk`: у разных экземпляров WinRE и WINPE могут быть
перепутаны. Ничего из `p1`–`p7`, кроме `p1`, при установке не форматировать.

## Внешние диски

| Диск | Что там |
|---|---|
| `W:` WIN11BOOT | заводское восстановление Honor. **Не запускать** |
| `X:` WIN11-BACKUP | образ Windows 80,64 ГБ, журналы, копия документов (может быть отключён) |
| флешка Verbatim | установщик Debian (dd), на EFI-разделе `fix-acpi.sh` и таблицы |

## Грабли на будущее

- Обновление BIOS может изменить DSDT → таблицу придётся пересобрать.
- Восстановление полного образа Windows затрёт EFI и убьёт GRUB — восстанавливать только раздел
  Windows.
- Если после обновления ядра пропали NVMe/USB, проверить `grep acpi-dsdt /boot/grub/grub.cfg`.
- Старые документы и отброшенные варианты лежат в `private/archive/` (вне git).

## Источники

- [denis-bb/honor-fmb-p-dsdt](https://github.com/denis-bb/honor-fmb-p-dsdt) — первый патч DSDT
  для этой модели
- [drphilth/honor-magicbook-pro-14-ubuntu](https://github.com/drphilth/honor-magicbook-pro-14-ubuntu)
  — разбор первопричины, рабочая таблица, пакеты для Ubuntu 26.04
- [askubuntu 1556825](https://askubuntu.com/questions/1556825/) — та же проблема на другом
  экземпляре
