#!/usr/bin/env bash
# ~/bin/volume-hotkeys.sh

PIDFILE=/tmp/volume-hotkeys.pid

# Kill old instance if exists
if [ -f "$PIDFILE" ] && kill -0 $(cat "$PIDFILE") 2>/dev/null; then
    kill $(cat "$PIDFILE")
fi

echo $$ > "$PIDFILE"

acpi_listen | while read line; do
    case "$line" in
        button/volumeup*)
            pactl set-sink-volume @DEFAULT_SINK@ +5%
            vol=$(pactl get-sink-volume @DEFAULT_SINK@ | grep -Po '[0-9]+%' | head -1)
            #notify-send "Volume Up" "$vol"
            dunstify -r 1 -u low "Volume Up" "$vol"
            ;;
        button/volumedown*)
            pactl set-sink-volume @DEFAULT_SINK@ -5%
            vol=$(pactl get-sink-volume @DEFAULT_SINK@ | grep -Po '[0-9]+%' | head -1)
            #notify-send "Volume Down" "$vol"
            dunstify -r 1 -u low "Volume Down" "$vol"
            ;;
        button/mute*)
            pactl set-sink-mute @DEFAULT_SINK@ toggle
            mute=$(pactl get-sink-mute @DEFAULT_SINK@ | awk '{print $2}')
            #notify-send "Mute" "$mute"
            dunstify -r 1 -u low "Mute" "$mute"
            ;;
    esac
done

