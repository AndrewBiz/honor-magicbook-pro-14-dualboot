# Диктовка Handy в Wayland-приложениях

**Статус: выполнено на этой машине (2026-11-19).** Handy 0.10.1, KDE Plasma 6.3.6
(Wayland), Konsole 25.04: текст из диктовки вставляется по `Ctrl+Shift+V`; в логе Handy
вместо `enigo::platform::x11` теперь `Using dotool for key combo`.

## Симптом

В настройках Handy выбран способ вставки через буфер обмена (`Ctrl+Shift+V`), но в Konsole
ничего не вставляется. Режим Direct работает, поэтому проблема выглядит как «неправильная
комбинация», хотя дело не в ней.

## Причина

Handy отправляет нажатие сочетания через `enigo`, то есть через X11/XTest, если не находит
Wayland-инструмент. Под XWayland такие события доставляются только X11-клиентам, а Konsole,
Kate и Dolphin — нативные Wayland-клиенты (у них загружен `libwayland-client`, в `xlsclients`
их нет). Поэтому сочетание уходит «в никуда».

В 0.10.1 для вставки на Wayland Handy пробует `wtype` (только не на KDE), `dotool` и
`ydotool`; `kwtype` задействован только в Direct. В Debian 13 нет ни `dotool`, ни `ydotool`,
а `wtype` на KWin бесполезен: композитор не реализует `zwp_virtual_keyboard_manager_v1`.
`xdotool` в Wayland-сессии Handy даже не рассматривает.

Смена `Ctrl+V` ↔ `Ctrl+Shift+V` ↔ `Shift+Insert` ничего не меняет: ломается не выбор
комбинации, а канал её доставки.

## Решение

`dotool` создаёт виртуальную клавиатуру через `/dev/uinput`. Композитор получает события как
от обычной клавиатуры, поэтому вставка работает в любом приложении, включая нативные
Wayland-клиенты. Handy находит `dotool` в `PATH` и использует его для комбинации.

Доступ к `/dev/uinput` по умолчанию есть только у root (`root:root 0600`), поэтому нужны
модуль `uinput`, udev-правило и группа `uinput`. Отдельная группа, а не стандартная `input`:
`input` даёт ещё и чтение всех клавиатур и event-устройств.

## Установка

Из каталога `02-debian-tuning/handy/`:

```sh
sudo apt install golang-go libxkbcommon-dev git
sudo sh build-dotool.sh
sudo sh setup-uinput.sh
```

Затем перезапустить Handy (трей → Quit → запустить снова). Скрипт `setup-uinput.sh` выдаёт ACL
на текущую сессию, поэтому перелогин для проверки не обязателен; членство в группе `uinput`
начнёт действовать после следующего входа в систему.

`build-dotool.sh` собирает `dotool` из исходников (`https://git.sr.ht/~geb/dotool`) и кладёт
бинарник в `/usr/local/bin`: в Debian 13 пакета нет. Сборке нужны сеть (модули Go) и
`libxkbcommon-dev`.

`setup-uinput.sh` идемпотентен:

1. загружает модуль `uinput` и прописывает его в `/etc/modules-load.d/uinput.conf`;
2. создаёт группу `uinput` и добавляет в неё пользователя, вызвавшего `sudo`;
3. пишет `/etc/udev/rules.d/80-uinput.rules` (`root:uinput 0660`) и перезагружает правила;
4. на текущую сессию выдаёт ACL `u:<user>:rw` на `/dev/uinput`.

## Настройки Handy

- Paste method: `Ctrl+Shift+V` — для терминалов (Konsole, Yakuake). Для GUI-приложений
  обычно нужен `Ctrl+V`, для части приложений подходит `Shift+Insert`; per-app правил у Handy
  нет, поэтому это всегда компромисс.
- `typing_tool` (`kwtype`) и режим Direct больше не нужны для вставки: Direct остаётся только
  для приложений, которые вообще не принимают вставку, и работает посимвольно.

## Проверка

```sh
echo 'key f24' | dotool; echo "rc=$?"
ls -l /dev/uinput
getent group uinput
grep -E 'Using (dotool|ydotool|wtype|xdotool) for key combo|Text pasted' \
    ~/.local/share/com.pais.handy/logs/handy.log | tail -5
```

Ожидается `rc=0`, `crw-rw----+ root uinput` и ACL `user:<user>:rw-`; в логе после диктовки —
`Using dotool for key combo`, затем `Text pasted successfully`.

Живой тест: поставить курсор в Konsole, зажать `Ctrl+Alt+Space`, сказать фразу, отпустить.

## Откат

```sh
sudo rm -f /etc/udev/rules.d/80-uinput.rules /etc/modules-load.d/uinput.conf
sudo gpasswd -d "$USER" uinput
sudo setfacl -b /dev/uinput 2>/dev/null || true
sudo rm -f /usr/local/bin/dotool
sudo udevadm control --reload-rules
sudo modprobe -r uinput        # если модуль больше никому не нужен
sudo groupdel uinput           # если группа опустела
```

После отката Handy снова отправляет сочетания через X11/XTest: в нативных Wayland-приложениях
вставки не будет, останется Direct через `kwtype` или ручная вставка из буфера обмена.

## Примечания

- Доступ к `/dev/uinput` позволяет инжектить ввод от имени пользователя — это цена любого
  Wayland-инструмента такого класса (`ydotool`, `dotool`). Поэтому группа отдельная и только
  для нужного пользователя.
- Если Handy обновится или переустановится система, проверить, что `dotool` на месте и виден
  в `PATH` процесса Handy (`tr '\0' '\n' < /proc/$(pgrep -x handy)/environ | grep ^PATH=`),
  и что в логе снова `Using dotool for key combo`.
- `wtype` (есть в Debian) и `xdotool` эту задачу не решают: первый не работает на KWin,
  второй — только для X11-клиентов.
