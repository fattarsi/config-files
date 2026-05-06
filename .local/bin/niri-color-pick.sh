#!/usr/bin/env bash
# Pick a tag color for the focused window via a zenity color-chooser dialog.
# Cancel/empty result clears the tag.
set -euo pipefail

TAGS_FILE="${XDG_RUNTIME_DIR:-/run/user/$UID}/niri-window-tags.json"
[ -f "$TAGS_FILE" ] || echo '{}' > "$TAGS_FILE"

wid=$(niri msg --json focused-window | jq -r '.id // empty')
[ -z "$wid" ] && exit 0

current=$(jq -r --arg w "$wid" '.[$w] // "#888888"' "$TAGS_FILE")

raw=$(zenity --color-selection --title="Window tag color" --color="$current" 2>/dev/null || true)
[ -z "$raw" ] && exit 0  # Cancel = no change

# zenity returns either rgb(R,G,B) or rgba(R,G,B,A) or a hex.
hex=""
if [[ "$raw" =~ ^rgb\(([0-9]+),([0-9]+),([0-9]+)\)$ ]]; then
    hex=$(printf "#%02x%02x%02x" "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}")
elif [[ "$raw" =~ ^rgba\(([0-9]+),([0-9]+),([0-9]+),[0-9.]+\)$ ]]; then
    hex=$(printf "#%02x%02x%02x" "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}")
elif [[ "$raw" =~ ^#[0-9a-fA-F]{6}$ ]]; then
    hex="$raw"
fi
[ -z "$hex" ] && exit 0

jq --arg w "$wid" --arg c "$hex" '.[$w] = $c' "$TAGS_FILE" > "$TAGS_FILE.tmp" && mv "$TAGS_FILE.tmp" "$TAGS_FILE"

pid_file="${XDG_RUNTIME_DIR:-/run/user/$UID}/niri-minimap.pid"
[ -f "$pid_file" ] && kill -USR1 "$(cat "$pid_file")" 2>/dev/null
niri msg action focus-window --id "$wid" 2>/dev/null || true
