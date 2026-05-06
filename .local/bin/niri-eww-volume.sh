#!/usr/bin/env bash
# Emit current default-sink volume to stdout, then re-emit on every PulseAudio
# sink change. Used by eww deflisten — instant updates, no polling lag.

emit() {
    wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null \
        | awk '{ if ($0 ~ /MUTED/) printf "%d M\n", $2*100; else printf "%d\n", $2*100 }'
}

emit
pactl subscribe 2>/dev/null | while IFS= read -r line; do
    case "$line" in
        *"on sink"*|*"on server"*) emit ;;
    esac
done
