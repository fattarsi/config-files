#!/bin/bash
# Double-tap Home → End
# Monitors keyboard via xinput; if Home is pressed twice within 300ms, sends End.

DOUBLE_TAP_MS=300
HOME_KEYCODE=110
LAST_FILE=/tmp/double-tap-home-$$

trap 'rm -f "$LAST_FILE"' EXIT
echo 0 > "$LAST_FILE"

# Find keyboard xinput ID
KB_ID=$(xinput list | grep -i "keychron.*keyboard" | grep "slave  keyboard" | grep -oP 'id=\K\d+' | head -1)
[ -z "$KB_ID" ] && exit 1

xinput test "$KB_ID" | while read -r type action keycode; do
    if [ "$type" = "key" ] && [ "$action" = "press" ] && [ "$keycode" = "$HOME_KEYCODE" ]; then
        now_ms=$(date +%s%3N)
        last_home=$(cat "$LAST_FILE")
        if [ "$last_home" -gt 0 ] && [ $((now_ms - last_home)) -lt $DOUBLE_TAP_MS ]; then
            xdotool key End
            echo 0 > "$LAST_FILE"
        else
            echo "$now_ms" > "$LAST_FILE"
        fi
    fi
done
