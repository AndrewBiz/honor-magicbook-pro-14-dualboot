# Swap-файл

**Статус: выполнено на этой машине.** `/swapfile` — 8 ГиБ, активен, запись в `/etc/fstab`
есть, `vm.swappiness=10`.

Swap-раздел при установке не создавался. Вместо него используется файл в корне ext4 — его
проще изменить или удалить без переразметки диска. При 32 ГБ RAM 8 ГиБ дают запас на пиковые
нагрузки, не отнимая много места у корня.

## Запуск

```sh
sudo sh setup-swap.sh          # 8G по умолчанию
sudo sh setup-swap.sh 16G      # другой размер, суффикс G или M
```

Скрипт идемпотентен: повторный запуск не пересоздаёт файл и не дублирует запись в `fstab`.

## Что делает скрипт

1. Показывает RAM и текущий swap.
2. Создаёт `/swapfile` через `fallocate`; если ФС не поддерживает — через `dd`.
3. Ставит права `600 root:root` и делает `mkswap`.
4. Включает swap, если он ещё не активен.
5. Добавляет `/swapfile none swap sw 0 0` в `/etc/fstab`, предварительно сохраняя
   `/etc/fstab.bak.YYYYmmddHHMMSS`.
6. Пишет `vm.swappiness = 10` в `/etc/sysctl.d/99-swappiness.conf` и применяет настройку.

`swappiness=10` означает «свопить только при реальной нехватке RAM», а не отключать swap.

## Проверка

```sh
free -h
grep '^/swapfile ' /proc/swaps
grep swap /etc/fstab
sysctl vm.swappiness
```

Ожидается `Swap: 8,0Gi`, активный `/swapfile` и `vm.swappiness = 10`.

## Изменить размер

Скрипт не изменяет существующий файл. Сначала откат, затем запуск с новым размером:

```sh
sudo swapoff /swapfile
# удалить строку /swapfile из /etc/fstab
sudo rm /swapfile
sudo sh setup-swap.sh 16G
```

## Откат

```sh
sudo swapoff /swapfile
# удалить строку /swapfile из /etc/fstab (бэкапы: /etc/fstab.bak.*)
sudo rm /swapfile
sudo rm /etc/sysctl.d/99-swappiness.conf
sudo sysctl -w vm.swappiness=60
```

Сначала убрать запись из `fstab`, потом удалять файл: иначе следующий boot будет ругаться на
отсутствующий swap.

Гибернация этим скриптом не настраивается — для неё нужен отдельный `resume`-параметр ядра.
