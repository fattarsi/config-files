#!/usr/bin/env bash
# Pick a tag color for the focused window via fuzzel.

TAGS_FILE="${XDG_RUNTIME_DIR:-/run/user/$UID}/niri-window-tags.json"
[ -f "$TAGS_FILE" ] || echo '{}' > "$TAGS_FILE"

wid=$(niri msg --json focused-window | jq -r '.id // empty')
[ -z "$wid" ] && exit 0

# Pango-styled menu so each entry shows a colored sample
choice=$(printf '%s\n' \
    '<span color="#888">none</span>' \
    '<span color="#cc3333">red</span>' \
    '<span color="#3366cc">blue</span>' \
    '<span color="#33aa55">green</span>' \
    '<span color="#9933cc">purple</span>' \
    '<span color="#ccaa33">yellow</span>' \
    | fuzzel --dmenu --prompt "color: " --lines 6 || true)

[ -z "$choice" ] && exit 0

# Strip pango markup to get the bare name
name=$(printf '%s' "$choice" | sed -E 's/<[^>]+>//g')

case "$name" in
    none)   color="none" ;;
    red)    color="#cc3333" ;;
    blue)   color="#3366cc" ;;
    green)  color="#33aa55" ;;
    purple) color="#9933cc" ;;
    yellow) color="#ccaa33" ;;
    *) exit 0 ;;
esac

if [ "$color" = "none" ]; then
    jq --arg w "$wid" 'del(.[$w])' "$TAGS_FILE" > "$TAGS_FILE.tmp" && mv "$TAGS_FILE.tmp" "$TAGS_FILE"
else
    jq --arg w "$wid" --arg c "$color" '.[$w] = $c' "$TAGS_FILE" > "$TAGS_FILE.tmp" && mv "$TAGS_FILE.tmp" "$TAGS_FILE"
fi

pid_file="${XDG_RUNTIME_DIR:-/run/user/$UID}/niri-minimap.pid"
[ -f "$pid_file" ] && kill -USR1 "$(cat "$pid_file")" 2>/dev/null
