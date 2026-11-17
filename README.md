# Debian 13 + Windows 11 на HONOR FMB-P

**Состояние: Debian установлен и загружается сам. Осталось: сеть, KDE, запись Windows в GRUB.**
Подробная история проекта — в `archive\2026-11-16\` (там старый план, PDF и журнал экспериментов).

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
отличаются семью байтами (шесть NVS-адресов). Нашей машине подходит **китайская**:
`acpi\dsdt-chinese-WORKING.aml`. Глобальная и таблица от denis-bb — не подходят.

**3. В установленной системе таблица запечена в ранний initrd**: `/boot/acpi-dsdt.cpio` +
`GRUB_EARLY_INITRD_LINUX_CUSTOM="acpi-dsdt.cpio"` в `/etc/default/grub`. Поэтому система
грузится сама, без ручных параметров.

**4. Secure Boot должен остаться выключенным.** Подмена ACPI через `acpi`/initrd блокируется
kernel lockdown, который включается при Secure Boot.

**5. Пункты меню на флешке не работают.** У загрузчика из ISO встроенный конфиг: он читает
`grub.cfg` из ISO9660 и игнорирует файлы на EFI-разделе флешки. Правки `L:\efi\*\grub.cfg`
бесполезны — нужен либо ручной `e` в GRUB, либо пересборка ISO.

**6. Не запускать `W:` (WIN11BOOT).** Это заводское восстановление Honor: `convert gpt` и
создание разделов с нуля — стирает весь диск.

## Разметка сейчас

```
p1  EFI          200 МБ   (общий, Windows + Debian)
p2  MSR           16 МБ
p3  C: Windows    300 ГБ  NTFS
p4  D: данные     300 ГБ  NTFS
p5  WinRE           1 ГБ
p6  OneKey         26 ГБ  заводской образ Honor
p7  WINPE           1 ГБ
p8  /             93 ГБ   ext4
p9  /home        232 ГБ   ext4
```

Debian 13.7, ядро 6.12.107. Установка **минимальная** (без графики), потому что не было сети.

## Что осталось

### 1. Сеть через USB-модем телефона (Android)

Телефон уже определяется как `enxXXXXXXXXXXXX`, но в системе нет ни одного DHCP-клиента.
`systemd-networkd` умеет сам:

```sh
sudo tee /etc/systemd/network/20-usb-tether.network >/dev/null <<'EOF'
[Match]
Name=enx*
[Network]
DHCP=yes
EOF
sudo systemctl enable --now systemd-networkd
sleep 3
ip -4 a show enxXXXXXXXXXXXX
sudo sh -c 'echo "nameserver 1.1.1.1" > /etc/resolv.conf'
ping -c 3 1.1.1.1
```

Если DHCP не отдал адрес — статикой (Android: сеть `192.168.42.0/24`, шлюз `.129`;
Samsung: `192.168.43.0/24`, шлюз `.1`):

```sh
sudo ip addr add 192.168.42.100/24 dev enxXXXXXXXXXXXX
sudo ip route add default via 192.168.42.129
```

### 2. Утилиты и Wi-Fi

```sh
sudo apt update
sudo apt install -y wpasupplicant iw rfkill network-manager
sudo rfkill unblock all
sudo ip link set wlp0s20f3 up
sudo nmcli device wifi list
sudo nmcli device wifi connect "SSID" password "PASS"
```

**Если сети нет совсем** — на флешке `G:` лежит офлайн-набор (21 пакет, 8,5 МБ):

```sh
sudo mkdir -p /mnt/u && sudo mount /dev/sdX1 /mnt/u
sudo sh /mnt/u/install-offline.sh
```

Ставит `wpasupplicant`, `iw`, `rfkill`, `network-manager` с зависимостями
через локальный apt-репозиторий `file:/mnt/u/debs` (не `dpkg -i`, поэтому
зависимости разрешаются штатно).

Прошивка Wi-Fi уже стоит (`firmware-iwlwifi 20261019-1`), в `dmesg` видно
`loaded firmware version 93 … op_mode iwlmvm`. Мешают только отсутствующие утилиты.

### 3. Графика

```sh
sudo apt install task-kde-desktop
```

### 4. Windows в меню GRUB

```sh
sudo apt install os-prober
sudo sed -i 's/^#\?GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
sudo update-grub
grep -i windows /boot/grub/grub.cfg
```

### 5. По желанию, позже

- Второй образ Windows (внешний диск `X:`, Hasleo).
- Вернуть Яндекс.Диск: копия папки лежит на `X:\Archive\Yandex.Disk` (диск отключён).
- Проверить, что данные `D:` целы (перенос 5985 файлов прошёл побайтово).

## Файлы проекта

```
honor-magicbook-pro-14-dualboot\
├── README.md                      этот файл
├── .gitignore
├── acpi\                          таблицы DSDT и патчи
│   ├── dsdt-chinese-WORKING.aml   рабочая таблица (она же в ESP и /boot)
│   ├── dsdt.global.aml            глобальная ревизия (не подошла)
│   └── *.patch                    что именно правится
├── usb\
│   ├── fix-acpi.sh                запекает DSDT в initrd установленной системы
│   ├── collect-logs.sh            снимает диагностику на флешку
│   ├── install-offline.sh         ставит сетевые пакеты из локального репозитория
│   └── install-cheatsheet.md      шпаргалка по установке (ASCII, для консоли)
├── iso\                           netinst 13.7.0 и live-KDE 13.7.0 (вне git)
└── private\                       локальные данные, в git не попадают
    ├── state\                     дампы Windows (серийник, ключ, BCD, разделы)
    ├── log\                       журналы операций
    └── archive\2026-11-16\        старые документы и отброшенные варианты
```

Дубли файлов, которые нужны загрузчику: `D:\dsdt-cn.aml`, `D:\dsdt.aml`, `D:\dsdt2.aml`,
а также копии на EFI-разделе ноутбука (`\dsdt-cn.aml`, `\fix-acpi.sh`).
## Внешние диски

| Диск | Что там |
|---|---|
| `W:` WIN11BOOT | заводское восстановление Honor. **Не запускать** |
| `X:` WIN11-BACKUP | образ Windows 80,64 ГБ, журналы, копия документов (сейчас отключён) |
| флешка Verbatim | установщик Debian (dd), на EFI-разделе `fix-acpi.sh` и таблицы |

## Репозиторий

Git (`main`). В репозитории только публично-безопасное: README, `acpi\`, `usb\`.

**Вне репозитория:**

| Исключено | Почему |
|---|---|
| `iso\` | образы Debian, 4,6 ГБ; воспроизводятся скачиванием |
| `private\` | данные этой машины: серийный номер, ключ Windows из BIOS, имя пользователя, BCD, журналы |

Имена устройства в публичных файлах обезличены (`enxXXXXXXXXXXXX`).

```sh
git log --oneline
git status
```
## Источники

- [denis-bb/honor-fmb-p-dsdt](https://github.com/denis-bb/honor-fmb-p-dsdt) — первый патч DSDT для этой модели
- [drphilth/honor-magicbook-pro-14-ubuntu](https://github.com/drphilth/honor-magicbook-pro-14-ubuntu) — разбор первопричины, рабочая таблица, пакеты для Ubuntu 26.04
- [askubuntu 1556825](https://askubuntu.com/questions/1556825/) — та же проблема на другом экземпляре

## Грабли на будущее

- Обновление BIOS может изменить DSDT → таблицу придётся пересобрать.
- Обновление ядра не ломает фикс: `acpi-dsdt.cpio` подключается через `grub.cfg` заново при `update-grub`.
- Восстановление полного образа Windows затрёт EFI и убьёт GRUB — восстанавливать только раздел Windows.
