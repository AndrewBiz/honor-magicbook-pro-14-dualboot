# Быстрые зеркала apt

**Статус: скрипт готов, на этой машине ещё не применён.** Исходные источники — стандартные
`deb.debian.org` и `security.debian.org`; из Москвы они отдают пакеты заметно медленнее
российских зеркал.

## Выбор зеркала

Замеры с этой машины (Москва, Ростелеком, 2026-11-17): скачивание
`dists/trixie/main/binary-amd64/Packages.xz` (~9,7 МБ), по три прогона.

| Зеркало | TTFB | Скорость |
|---|---|---|
| `https://mirror.neftm.ru/debian` | ~0,025 с | **~11 МБ/с** |
| `https://mirror.corbina.net/debian` | ~0,025 с | ~10 МБ/с |
| `http://ftp.ru.debian.org/debian` (MEPhI) | ~0,014 с | ~10 МБ/с, только HTTP |
| `https://mirror.yandex.ru/debian` | ~0,05–0,08 с | ~4–8 МБ/с |
| `https://deb.debian.org/debian` | ~0,16 с | ~0,4 МБ/с |

По умолчанию скрипт выбирает `mirror.neftm.ru`: он быстрее всех и поддерживает HTTPS вместе с
`/debian-security`. Проверочный `apt-get update` с него скачал 45,8 МБ за 5 секунд и успешно
проверил подписи всех suites.

## Запуск

```sh
sudo sh setup-apt-mirrors.sh
```

Скрипт:

1. Проверяет наличие `trixie` и `trixie-security` на выбранном зеркале.
2. Пишет `/etc/apt/sources.list.d/debian.sources` в формате deb822.
3. Комментирует старые Debian-строки в `/etc/apt/sources.list`, не трогая сторонние репозитории
   (например, GitHub CLI).
4. Делает бэкапы изменённых файлов: `*.bak.YYYYmmddHHMMSS`.
5. Запускает `apt-get update` и показывает активные источники.

Повторный запуск идемпотентен.

## Другое зеркало

```sh
sudo sh setup-apt-mirrors.sh https://mirror.corbina.net/debian
```

URI должен заканчиваться на `/debian`; security-архив получается заменой на `/debian-security`.
Можно передать его через переменную:

```sh
sudo MIRROR=https://mirror.yandex.ru/debian sh setup-apt-mirrors.sh
```

## Проверка

```sh
cat /etc/apt/sources.list.d/debian.sources
apt-get indextargets --format '$(SITE) $(SUITE)' | sort -u
apt-cache policy
```

В выводе `indextargets` должны быть только выбранное зеркало и его security-архив.

## Откат

```sh
ls -l /etc/apt/sources.list.d/debian.sources.bak.* /etc/apt/sources.list.bak.* 2>/dev/null
sudo rm /etc/apt/sources.list.d/debian.sources
sudo cp /etc/apt/sources.list.bak.YYYYmmddHHMMSS /etc/apt/sources.list
sudo apt-get update
```

Если бэкапа `sources.list` нет, вернуть три исходные строки вручную:

```sh
deb https://deb.debian.org/debian trixie main contrib non-free non-free-firmware
deb https://deb.debian.org/debian trixie-updates main contrib non-free non-free-firmware
deb https://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware
```

## Перепроверить зеркала

Если машина переехала или зеркало стало медленным:

```sh
for base in \
  https://mirror.neftm.ru/debian \
  https://mirror.corbina.net/debian \
  http://ftp.ru.debian.org/debian \
  https://mirror.yandex.ru/debian \
  https://deb.debian.org/debian; do
    printf '%-42s ' "$base"
    curl -4 -fsS -o /dev/null --max-time 30 \
      -w 'ttfb=%{time_starttransfer}s speed=%{speed_download}B/s\n' \
      "$base/dists/trixie/main/binary-amd64/Packages.xz" || echo FAIL
done
```

Список российских зеркал: <https://www.debian.org/mirror/list>.
