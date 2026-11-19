#!/bin/sh
# Toggle the default microphone once per physical mic-mute key press.
#
# Why not just use KDE's "Mute Microphone" shortcut: the key input is clean
# (evtest shows exactly one KEY_MICMUTE per press), but a *mute* set on the USB
# capture source is reverted about a second later while KDE's audio service is
# running - reproduced with plain "pactl set-source-mute", so the key is not to
# blame. Volume changes do stick, so mute is implemented as volume 0 with the
# previous level remembered and restored on the next press.
set -u

SRC="@DEFAULT_AUDIO_SOURCE@"
STATE="${XDG_RUNTIME_DIR:-/tmp}/mic-mute-key.volume"

log() { echo "mic-mute-key: $*" >&2; }

find_device() {
    awk '/Name="Huawei WMI hotkeys"/ { found = 1 }
         found && /Handlers=/ {
             for (i = 1; i <= NF; i++)
                 if ($i ~ /^event/) { print $i; exit }
         }' /proc/bus/input/devices
}

volume() {
    wpctl get-volume "$SRC" 2>/dev/null | awk '$1 == "Volume:" { print $2; exit }'
}

osd() {
    gdbus call --session --dest org.kde.plasmashell \
        --object-path /org/kde/osdService \
        --method org.kde.osdService.microphoneVolumeChanged "$1" \
        >/dev/null 2>&1 || true
}

osd_percent() {
    awk -v v="$1" 'BEGIN { printf "%d", v * 100 }'
}

toggle() {
    vol=$(volume)
    if [ -z "$vol" ]; then
        log "cannot read the volume of $SRC (is PipeWire running?)"
        return
    fi

    if [ "$vol" = "0.00" ] || [ "$vol" = "0" ]; then
        target=$(cat "$STATE" 2>/dev/null) || target=1.00
        case "$target" in
            ''|0|0.00) target=1.00 ;;
        esac
    else
        target=0
        printf '%s\n' "$vol" > "$STATE" 2>/dev/null || true
    fi

    wpctl set-volume "$SRC" "$target" >/dev/null 2>&1
    sleep 0.3

    have=$(volume)
    if [ "$have" != "$target" ]; then
        log "volume $target did not stick (got ${have:-nothing}), re-applying"
        wpctl set-volume "$SRC" "$target" >/dev/null 2>&1
    fi

    if [ "$target" = 0 ]; then
        osd 0
    else
        osd "$(osd_percent "$target")"
    fi
}

while :; do
    ev=$(find_device)
    if [ -z "$ev" ]; then
        log "mic-mute hotkey device not found, retrying in 5 s"
        sleep 5
        continue
    fi

    log "watching /dev/input/$ev"
    if command -v stdbuf >/dev/null 2>&1; then
        stdbuf -oL evtest "/dev/input/$ev" 2>/dev/null | while IFS= read -r line; do
            case "$line" in
                *"KEY_MICMUTE), value 1"*) toggle ;;
            esac
        done
    else
        evtest "/dev/input/$ev" 2>/dev/null | while IFS= read -r line; do
            case "$line" in
                *"KEY_MICMUTE), value 1"*) toggle ;;
            esac
        done
    fi

    log "evtest exited, restarting in 2 s"
    sleep 2
done
