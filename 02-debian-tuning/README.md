# Часть 2 — тюнинг установленной Debian

Все шаги выполняются из уже загруженной Debian. Установка описана в
[../01-windows-prep/README.md](../01-windows-prep/README.md).

**Состояние на 2026-11-19:** Debian 13.7, ядро 6.12.117, KDE Plasma + SDDM, Wi-Fi
`wlp0s20f3` через NetworkManager, swap-файл 8 ГиБ, фантомный mute микрофона от тачскрина
отключён, диктовка Handy вставляет текст в Konsole; по двойному переключению `Fn+F7` решение
не принято.

## Чеклист

- [x] Сеть и Wi-Fi — [network/README.md](network/README.md)
- [ ] Быстрые зеркала apt — [apt/README.md](apt/README.md)
- [x] Графика KDE — команды ниже
- [x] Swap-файл и `vm.swappiness` — [swap/README.md](swap/README.md)
- [x] Фантомный mute микрофона от тачскрина — [input/README.md](input/README.md)
- [ ] `Fn+F7` переключает микрофон дважды: выбрать вариант A или B — [input/README.md](input/README.md#второй-симптом-fnf7-переключает-дважды)
- [x] Вставка диктовки Handy в Wayland-приложения — [handy/README.md](handy/README.md)
- [ ] Windows в меню GRUB — [windows-grub.md](windows-grub.md)
- [x] Сбор диагностики — [diagnostics/README.md](diagnostics/README.md)
- [ ] Дальнейший тюнинг — новые пункты добавлять сюда и в корневой `README.md`

## Графика

На этой машине уже установлены KDE Plasma и SDDM, система стартует в `graphical.target`.
Повторить на минимальной установке:

```sh
sudo apt update
sudo apt install task-kde-desktop
sudo systemctl set-default graphical.target
```

Проверка:

```sh
systemctl get-default
cat /etc/X11/default-display-manager
```

## Правила добавления шага

1. Создать каталог `02-debian-tuning/<тема>/` с `README.md`.
2. Положить рядом скрипты, если шаг автоматизируется; скрипты — POSIX `sh`, идемпотентные
   (кроме сборщиков логов, которые создают новый каталог), запуск от root.
3. Добавить пункт в чеклист этого файла и в корневой `README.md`.
4. Записать проверку результата и команду отката в `README.md` шага.
