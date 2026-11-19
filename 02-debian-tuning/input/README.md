# Клавиши: фантомный mute микрофона

**Статус: применено на этой машине 2026-11-18.** Мигание значка микрофона ушло.
Отдельный симптом — двойное переключение по `Fn+F7` — разобран ниже, решение по нему
**не принято** (2026-11-19).

## Симптом

После перезагрузки или посреди работы в центре экрана появляется значок микрофона и
быстро мигает, будто кто-то непрерывно включает-выключает mute. Ощущение «дребезга
клавиш». `Esc` просто закрывает OSD Plasma, переключения продолжаются.

При этом `Fn+F4` (mute звука) работает, а `Fn+F7` (mute микрофона) выглядит нерабочей.

## Причина

На панель тачскрина FocalTech FTSC1000 в firmware заведена **вторая, пустая HID-коллекция**
`FTSC1000:00 2808:5662 UNKNOWN`. Она объявляет единственную клавишу — `KEY_MICMUTE` — и, пока
панель касаются, выдаёт её пачками (~30 событий/с). Plasma честно реагирует на каждое событие
OSD и переключает mute источника. Настоящая `Fn+F7` при этом «не работает»: состояние
микрофона к моменту нажатия уже уехало, и визуально ничего не меняется.

Проверить, что источник именно тачскрин, а не клавиатура:

```sh
cat /sys/class/input/input*/name | grep -n UNKNOWN     # найти номер inputN
cat /sys/class/input/input16/modalias                  # ...kF8 = KEY_MICMUTE
cat /sys/class/input/input16/inhibited                 # 0 — коллекция активна
```

`kF8` в `modalias` — это keycode 248, `KEY_MICMUTE`. У клавиатуры и у `huawei-wmi`
(`Huawei WMI hotkeys`) та же клавиша тоже есть, поэтому «кто именно её шлёт» надо смотреть
по устройству, а не по имени клавиши.

Настоящие Fn-клавиши идут через `huawei-wmi` (устройство `Huawei WMI hotkeys`): `Fn+F4` →
`KEY_MUTE`, `Fn+F7` → `KEY_MICMUTE`. Драйвер исправен, ломает картину только фантомная
коллекция тачскрина.

## Запуск

```sh
sudo sh setup-input.sh
```

Скрипт идемпотентен: правила просто перезаписываются, повторный запуск безопасен.

Проверить фикс без перезагрузки, до запуска скрипта:

```sh
echo 1 | sudo tee /sys/class/input/input16/inhibited
```

Мигание должно прекратиться сразу; после перезагрузки вернётся, пока не установлено правило.

## Что делает скрипт

1. Копирует `99-honor-fmbp-input.rules` в `/etc/udev/rules.d/` — правило по имени устройства
   (номера `inputN`/`eventN` при загрузке меняются) выставляет `inhibited=1` фантомной
   коллекции. Сам тачскрин продолжает работать через настоящий multitouch-устройство.
2. Копирует `61-honor-fmbp-keyboard.hwdb` в `/etc/udev/hwdb.d/` — гасит в `dmesg` строки
   `atkbd serio0: Unknown key released ... code 0xf8`: EC шлёт лишний scancode `f8`
   вместе с Fn-клавишами, `atkbd` его всё равно отбрасывает (`EV_KEY` не появляется),
   так что запись косметическая.
3. Перезагружает правила и hwdb (`systemd-hwdb update`, `udevadm control --reload`,
   `udevadm trigger`), затем выставляет `inhibited=1` вручную — чтобы фикс начал работать
   без перезагрузки.

## Проверка

```sh
for d in /sys/class/input/input*; do
    [ -f "$d/inhibited" ] || continue
    printf '%s inhibited=%s %s\n' "$(basename "$d")" "$(cat "$d/inhibited")" "$(cat "$d/name")"
done
```

Ожидается `FTSC1000:00 2808:5662 UNKNOWN inhibited=1`, у остальных устройств — `0`.

Дальше руками:

1. Провести пальцем/ладонью по экрану — значок микрофона больше не мигает.
2. Нажать `Fn+F7` — клавиша снова доходит до системы (одно событие на нажатие). Двойное
   переключение, которое видно при этом, — отдельная история, см. ниже. На этой машине при
   `fn_lock_state = 1` мультимедиа-функции верхнего ряда требуют `Fn`, то есть mute
   микрофона — именно `Fn+F7` (`cat /sys/devices/platform/huawei-wmi/fn_lock_state`).

Если мигание осталось, источник другой — тогда смотреть, кто именно шлёт события:

```sh
sudo apt install evtest
grep -B4 'Huawei WMI hotkeys\|AT Translated' /proc/bus/input/devices
sudo evtest /dev/input/eventN        # по одному: клавиатура и Huawei WMI hotkeys
```

## Второй симптом: `Fn+F7` переключает дважды

**Статус на 2026-11-19: причина найдена, вариант фикса не выбран.** Ниже два варианта; ни один
на машине не применён, оба готовы к запуску.

После отключения фантомной коллекции `Fn+F7` снова управляет микрофоном, но одно нажатие даёт
**два** переключения: mute, а через ~0.5 с обратно. Итоговое состояние непредсказуемо, на
коротком тапе вообще кажется, что клавиша не работает.

### Причина

Замеры (2026-11-18/19):

- `evtest` на `AT Translated Set 2 keyboard` — на нажатие ровно одно `MSC_SCAN f8` **без**
  `EV_KEY`: клавиатура `KEY_MICMUTE` не шлёт, авто-повтора удержания там нет;
- `evtest` на `Huawei WMI hotkeys` — ровно одно событие `KEY_MICMUTE` на нажатие, удержание до
  3 с его не повторяет;
- `pactl set-source-mute @DEFAULT_SOURCE@ 1` **из командной строки** даёт `Mute: yes`, а через
  ~1 с состояние снова `Mute: no`; `amixer -c 0 cset numid=3 off` возвращается в `on` так же;
- при остановленном `plasma-kded6.service` mute держится и на USB-источнике, в том числе во
  время активной записи;
- у внутреннего HDA-микрофона (`pci-...skl_hda_dsp_generic`) mute держится, даже когда он
  источник по умолчанию;
- громкость на USB-источнике держится всегда.

То есть ввод исправен, а виноват не ярлык и не клавиша: **программный mute на USB-источнике
гарнитуры снимает KDE-сервис звука**; это воспроизводится без всякой клавиатуры, так что кнопка
«Mute» в апплете громкости ведёт себя так же.

Почему именно USB: у HDA mute — регистр кодека, состояние локальное; у USB Audio Class mute —
это Feature Unit самого устройства (`bmaControls(0)=0x03` в дескрипторе H340), а ALSA-микшер
лишь зеркало, и узел постоянно переоткрывается (засыпание/пробуждение). Снимает mute
KDE-сервис звука — вероятно, пере-применяя сохранённое у него `Muted=false` при обновлении
модели источника; у HDA-узла таких обновлений не происходит. Точное место в `plasma-pa` 6.3.4
не локализовано: отключить один модуль `audioshortcutsservice` не удалось (подгружается снова),
а гасить весь `kded6` нельзя — на нём клавиши громкости.

### Вариант A — обход через громкость (готов, не применён)

Ярлык `mic_mute` в Plasma отвязываем, а переключает микрофон свой обработчик: читает evdev (там
нажатие одно), ставит источнику громкость 0 с запоминанием прежней и возвращает её на следующее
нажатие.

Плюсы: работает с любой гарнитурой и любым источником. Минусы: для приложений это не «muted», а
нулевая громкость — обход, а не починка.

#### Запуск варианта A

```sh
cd 02-debian-tuning/input
sudo apt install evtest        # зависимость обработчика
sudo sh setup-micmute.sh
systemctl --user daemon-reload
systemctl --user enable --now mic-mute-key.service
```

И один ручной шаг: *Параметры системы → Клавиши → «Громкость звука» → «Выключить микрофон»* →
`none`. Без него будет третье переключение: свой обработчик плюс два от Plasma.

#### Что ставится

| Файл | Куда | Зачем |
|---|---|---|
| `99-honor-fmbp-micmute.rules` | `/etc/udev/rules.d/` | `TAG+="uaccess"` на event-устройство `Huawei WMI hotkeys`: сейчас на нём только `root:input`, ACL нет |
| `mic-mute-key.sh` | `/usr/local/lib/honor-fmbp/` | слушает `evtest`, на `KEY_MICMUTE), value 1` переключает `@DEFAULT_AUDIO_SOURCE@` через `wpctl` |
| `mic-mute-key.service` | `/etc/systemd/user/` | user-сервис с `Restart=always`: устройство пересоздаётся после reload udev |

Скрипт — POSIX `sh`; зависимости `evtest`, `wpctl`, и `gdbus` (только для OSD, ошибки
игнорируются).

#### Проверка варианта A

```sh
systemctl --user status mic-mute-key.service
journalctl --user -u mic-mute-key.service -n 20
```

В логе должно быть `watching /dev/input/eventN`. Дальше три нажатия `Fn+F7`: микрофон
переключается ровно один раз на нажатие.

Громкость источника — так переключение видно надёжнее, чем `Mute` (одна строка на нажатие):

```sh
prev=""
while sleep 0.05; do
  cur=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@)
  [ "$cur" != "$prev" ] && printf '%s  %s\n' "$(date +%s.%3N)" "$cur" && prev="$cur"
done
```

Ожидается `Volume: 0.00` на нажатие и возврат запомненного уровня на следующее.

#### Откат варианта A

```sh
systemctl --user disable --now mic-mute-key.service
sudo rm /etc/systemd/user/mic-mute-key.service
sudo rm /etc/udev/rules.d/99-honor-fmbp-micmute.rules
sudo rm -rf /usr/local/lib/honor-fmbp
sudo udevadm control --reload
```

И вернуть ярлык: *Параметры системы → Клавиши → «Громкость звука» → «Выключить микрофон»* →
`Microphone Mute`.

### Вариант B — включить внутренний микрофон (не применён)

Внутренний микрофон сейчас выключен целиком: карта `pci-...skl_hda_dsp_generic` в профиле
`off`, источников `Mic1`/`Mic2` в системе нет. В профиле `HiFi (HDMI1, HDMI2, HDMI3, Mic1,
Mic2, Speaker)` они появляются, и mute на них держится (проверено, в том числе когда такой
источник — по умолчанию).

```sh
pactl set-card-profile alsa_card.pci-0000_00_1f.3-platform-skl_hda_dsp_generic \
    'HiFi (HDMI1, HDMI2, HDMI3, Mic1, Mic2, Speaker)'
pactl set-default-source \
    alsa_input.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Mic2__source
```

Плюсы: `Fn+F7` работает штатно, без обходов и без правки ярлыка — Plasma просто переключает mute,
и он держится. Минусы: используется микрофон ноутбука, а не гарнитуры; меняется набор устройств
для всех приложений, и профиль карты надо будет закрепить (WirePlumber хранит активный профиль,
но проверить после перезагрузки стоит).

Проверка: `pactl set-source-mute @DEFAULT_SOURCE@ 1` держится (`Mute: yes` и через 3 с), `Fn+F7`
переключает один раз. Проверено на уровне mute; сквозной прогон с клавишей после включения этого
варианта ещё не делался.

Откат варианта B:

```sh
pactl set-default-source \
    alsa_input.usb-Logitech_Inc._Logi_USB_Headset_H340-00.stereo-fallback
pactl set-card-profile alsa_card.pci-0000_00_1f.3-platform-skl_hda_dsp_generic off
```

### Что выбрать

| | A: обход через громкость | B: внутренний микрофон |
|---|---|---|
| Что видят приложения | тишина, но статус «не muted» | настоящий mute |
| Чей микрофон работает | гарнитуры | ноутбука |
| Что меняется в системе | ярлык Plasma + user-сервис + udev-правило | профиль карты и источник по умолчанию |
| Откат | пять команд | две команды |
| Состояние | готов, не применён | готов, не применён |

## Откат первого фикса (фантомный mute)

```sh
sudo rm /etc/udev/rules.d/99-honor-fmbp-input.rules
sudo rm /etc/udev/hwdb.d/61-honor-fmbp-keyboard.hwdb
sudo udevadm control --reload
sudo systemd-hwdb update
for d in /sys/class/input/input*; do
    [ "$(cat "$d/name" 2>/dev/null)" = "FTSC1000:00 2808:5662 UNKNOWN" ] && \
        echo 0 | sudo tee "$d/inhibited"
done
```

Или просто перезагрузиться после удаления файлов — правило перестанет применяться.

## Источники

Найдено и проверено на такой же машине в соседних проектах:

- [drphilth/honor-magicbook-pro-14-cachy](https://github.com/drphilth/honor-magicbook-pro-14-cachy) —
  `honor-fmbp/config/udev/` (inhibit «phantom `KEY_MICMUTE`» + hwdb для scancode `e078`);
- [colorcube/Linux-on-Honor-Magicbook-14-Pro](https://github.com/colorcube/Linux-on-Honor-Magicbook-14-Pro) —
  тачскрин FTSC1000, обсуждение фантомных событий.
