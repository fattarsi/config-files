#!/usr/bin/env bash
# Cycle the focused window's tag color through the palette.
# Tags are session-only (cleared on logout).

TAGS_FILE="${XDG_RUNTIME_DIR:-/run/user/$UID}/niri-window-tags.json"
PALETTE=("none" "#cc3333" "#3366cc" "#33aa55" "#9933cc" "#ccaa33")

[ -f "$TAGS_FILE" ] || echo '{}' > "$TAGS_FILE"

wid=$(niri msg --json focused-window | jq -r '.id // empty')
[ -z "$wid" ] && exit 0

current=$(jq -r --arg w "$wid" '.[$w] // "none"' "$TAGS_FILE")

next_idx=0
for i in "${!PALETTE[@]}"; do
    if [ "${PALETTE[$i]}" = "$current" ]; then
        next_idx=$(( (i + 1) % ${#PALETTE[@]} ))
        break
    fi
done
next="${PALETTE[$next_idx]}"

if [ "$next" = "none" ]; then
    jq --arg w "$wid" 'del(.[$w])' "$TAGS_FILE" > "$TAGS_FILE.tmp" && mv "$TAGS_FILE.tmp" "$TAGS_FILE"
else
    jq --arg w "$wid" --arg c "$next" '.[$w] = $c' "$TAGS_FILE" > "$TAGS_FILE.tmp" && mv "$TAGS_FILE.tmp" "$TAGS_FILE"
fi

# Wake up the minimap so the bar updates immediately
pid_file="${XDG_RUNTIME_DIR:-/run/user/$UID}/niri-minimap.pid"
[ -f "$pid_file" ] && kill -USR1 "$(cat "$pid_file")" 2>/dev/null
