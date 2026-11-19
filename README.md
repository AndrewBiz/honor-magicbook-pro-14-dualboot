# Debian 13 + Windows 11 на HONOR FMB-P

Краткий чеклист dual boot. Проект разделён на две части: подготовка, пока основной системой
остаётся Windows, и тюнинг уже установленной Debian. Сложные шаги вынесены в отдельные
каталоги с документацией и скриптами.

**Состояние на 2026-11-19:** Debian 13.7 установлен и загружается сам. Работают KDE, Wi-Fi,
swap, тачскрин и диктовка Handy; фантомный mute микрофона от тачскрина отключён. Осталось
добавить Windows в меню GRUB, решить по `Fn+F7` и продолжать тюнинг.

## Часть 1 — подготовка (Windows основная)

- [x] Windows: выключить Secure Boot, быстрый запуск и гибернацию.
- [x] Сохранить машинные данные (ключ Windows, BCD, разделы) в `private/`.
- [x] Найти рабочую DSDT (китайская ревизия) и подготовить флешку установщика.
- [x] Установить Debian в свободное место, не трогая разделы Windows.
- [x] Запечь DSDT в early initrd до первого reboot.
- [x] Проверить первый запуск: нет ошибок `GINF`, виден NVMe.

Подробный runbook: [01-windows-prep/README.md](01-windows-prep/README.md) ·
шпаргалка установщика: [01-windows-prep/usb/install-cheatsheet.md](01-windows-prep/usb/install-cheatsheet.md).

## Часть 2 — тюнинг Debian

- [x] Wi-Fi и сеть: [02-debian-tuning/network/README.md](02-debian-tuning/network/README.md)
- [ ] Быстрые зеркала apt: [02-debian-tuning/apt/README.md](02-debian-tuning/apt/README.md)
- [x] KDE Plasma: [02-debian-tuning/README.md](02-debian-tuning/README.md#графика)
- [x] Swap-файл 8 ГиБ и `vm.swappiness=10`: [02-debian-tuning/swap/README.md](02-debian-tuning/swap/README.md)
- [x] Фантомный mute микрофона от тачскрина: [02-debian-tuning/input/README.md](02-debian-tuning/input/README.md)
- [ ] `Fn+F7` переключает микрофон дважды: выбрать вариант A или B — [02-debian-tuning/input/README.md](02-debian-tuning/input/README.md#второй-симптом-fnf7-переключает-дважды)
- [x] Диктовка Handy вставляет текст в Wayland-приложения: [02-debian-tuning/handy/README.md](02-debian-tuning/handy/README.md)
- [ ] Windows в меню GRUB: [02-debian-tuning/windows-grub.md](02-debian-tuning/windows-grub.md)
- [x] Сбор диагностики: [02-debian-tuning/diagnostics/README.md](02-debian-tuning/diagnostics/README.md)
- [ ] Дальнейший тюнинг — добавлять сюда новыми пунктами.

Индекс и правила добавления шагов: [02-debian-tuning/README.md](02-debian-tuning/README.md).

## Критично помнить

- **Secure Boot должен оставаться выключенным**: иначе kernel lockdown блокирует подмену ACPI.
- **Не запускать `W:` / `WIN11BOOT`**: заводское восстановление Honor переразметит весь диск.
- **Не восстанавливать полный образ Windows**: он затрёт общий EFI и сломает GRUB. Восстанавливать
  только раздел Windows.
- В публичный репозиторий не попадают `private/` и `iso/`; имена устройств обезличиваются.

## Структура

```
01-windows-prep/     подготовка и установка, пока Windows основная
  acpi/              DSDT и патчи
  usb/               шпаргалка установщика и fix-acpi.sh
02-debian-tuning/    шаги из уже установленной Debian
  apt/               быстрые зеркала пакетов
  swap/              swap-файл
  input/             клавиши и тачскрин (фантомный mute)
  handy/             диктовка Handy: dotool + uinput
  network/           Wi-Fi, USB-тетеринг, офлайн-пакеты
  diagnostics/       сбор логов
iso/                 образы Debian (вне git)
private/             машинные данные (вне git)
```
