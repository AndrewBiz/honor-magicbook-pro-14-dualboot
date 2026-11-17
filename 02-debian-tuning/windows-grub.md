# Windows в меню GRUB

**Статус: не выполнено.** На 2026-11-17 `os-prober` и `ntfs-3g` установлены,
`GRUB_DISABLE_OS_PROBER=false` задан, но записи Windows в `/boot/grub/grub.cfg` ещё нет.

## Команды

```sh
sudo apt install os-prober ntfs-3g
grep '^GRUB_DISABLE_OS_PROBER=false' /etc/default/grub
sudo os-prober
sudo update-grub
grep -in windows /boot/grub/grub.cfg
```

`os-prober` должен вывести строку вида
`/dev/nvme0n1p3:Windows:Windows:ntfs`. После `update-grub` в меню появится пункт Windows Boot
Manager.

## Если `os-prober` ничего не нашёл

1. Проверить, что разделы Windows на месте: `lsblk -f`; обычно это `nvme0n1p3` (C:) и
   `nvme0n1p4` (D:).
2. Убедиться, что быстрый запуск и гибернация Windows выключены: после них NTFS остаётся
   «грязной», и os-prober может пропустить раздел.
3. Отмонтировать разделы Windows, если они смонтированы вручную:
   `mount | grep nvme0n1p`.
4. Смонтировать C: только на чтение и проверить файлы загрузчика:

```sh
sudo mkdir -p /mnt/win
sudo mount -o ro /dev/nvme0n1p3 /mnt/win
ls /mnt/win          # должны быть bootmgr, Windows, Boot
sudo umount /mnt/win
```

5. Повторить `sudo os-prober` и `sudo update-grub`.

Если Windows всё равно не находится, можно добавить ручной пункт в
`/etc/grub.d/40_custom`, но сначала стоит разобраться, почему os-prober не видит загрузчик.

## Важно

- Не восстанавливать полный образ Windows: он перезапишет общий EFI-раздел и сломает GRUB.
  Восстанавливать только раздел Windows.
- После обновления Windows или GRUB проверить меню ещё раз:
  `grep -in windows /boot/grub/grub.cfg`.
