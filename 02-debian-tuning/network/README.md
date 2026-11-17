# Сеть и Wi-Fi

**Статус: выполнено на этой машине.** Интерфейс `wlp0s20f3` поднят, работает NetworkManager,
прошивка `iwlwifi` загружается. Документ нужен для повторной установки и для случаев, когда
сеть пропала.

## Если сеть уже есть

```sh
nmcli device status
nmcli device wifi list
nmcli device wifi connect "SSID" password "PASS"
```

Проверка:

```sh
ip -brief a
ip route
cat /etc/resolv.conf
ping -c 3 1.1.1.1
```

## Свежая минимальная установка: три варианта

### A. Android USB-тетеринг

1. На телефоне включить **USB tethering**.
2. На ноутбуке:

```sh
ip link                       # телефон появится как enx... (rndis_host)
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

Если DHCP не выдал адрес, настроить статикой (Android: `192.168.42.0/24`, шлюз `.129`;
Samsung: `192.168.43.0/24`, шлюз `.1`):

```sh
sudo ip addr add 192.168.42.100/24 dev enxXXXXXXXXXXXX
sudo ip route add default via 192.168.42.129
```

### B. USB Ethernet

Подключить адаптер и проверить `ip link`. Если DHCP-клиента нет — рецепт из варианта A, но
`Name=*` вместо `Name=enx*`.

### C. Офлайн-пакеты с флешки

На флешке рядом со скриптом должен лежать каталог `debs/` с `Packages` (21 пакет, ~8,5 МБ).
В репозитории этих пакетов нет.

```sh
sudo mkdir -p /mnt/u
sudo mount /dev/sdX1 /mnt/u
sudo sh /mnt/u/install-offline.sh
```

Скрипт [install-offline.sh](install-offline.sh) регистрирует локальный apt-репозиторий
`file:/mnt/u/debs` (не `dpkg -i`) и ставит `wpasupplicant`, `iw`, `rfkill`, `network-manager`,
при возможности `os-prober`. Путь монтирования не должен содержать пробелов.

## Wi-Fi: прошивка и интерфейс

Прошивка уже стоит (`firmware-iwlwifi`). Если `wlp0s20f3` не появился:

```sh
dmesg | grep -i iwlwifi | tail -20
```

Хорошо: `loaded firmware version ... op_mode iwlmvm`. Плохо: `failed to load ... .ucode` —
пакет прошивки не установлен. Если `.deb` лежит на флешке:

```sh
sudo dpkg -i /mnt/u/firmware-iwlwifi_*.deb
sudo modprobe -r iwlwifi
sudo modprobe iwlwifi
ip link
```

Если интерфейс есть, но `DOWN`, сначала проверить rfkill — порядок важен:

```sh
sudo rfkill list
sudo rfkill unblock all
sudo rfkill unblock wifi
sudo ip link set wlp0s20f3 up
ip a show wlp0s20f3
```

`Operation not possible due to RF-kill` означает, что радио заблокировано: сначала rfkill,
потом `ip link set`.

## Подключение без NetworkManager

```sh
sudo wpa_passphrase "SSID" "PASSWORD" | sudo tee /etc/wpa_supplicant/wpa.conf
sudo wpa_supplicant -B -i wlp0s20f3 -c /etc/wpa_supplicant/wpa.conf
sudo dhclient -v wlp0s20f3
ping -c 3 1.1.1.1
```

Пароль в `wpa.conf` хранится в открытом виде; `wpa_passphrase` без аргумента-пароля умеет
генерировать хешированный PSK.

## Полезные проверки

```sh
for c in iw wpa_supplicant wpa_cli nmcli rfkill dhclient; do
    printf '%-16s %s\n' "$c" "$(command -v "$c" || echo missing)"
done
sudo iw dev wlp0s20f3 scan | head -30
```

Если сеть не поднимается, снять диагностику: [../diagnostics/README.md](../diagnostics/README.md).
