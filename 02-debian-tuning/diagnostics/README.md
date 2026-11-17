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
| `dmesg-acpi.txt` | ошибки `GINF`, `AE_AML`, `_CRS` |
| `blockdevices.txt` | виден ли `nvme0n1` и разделы |
| `dmesg-wifi.txt` | загрузилась ли прошивка `iwlmvm` |
| `network-tools.txt` | какие клиенты Wi-Fi установлены |
| `acpi-fix.txt` | на месте ли `acpi-dsdt.cpio` и запись в GRUB |
