#!/usr/bin/env bash
# Rename the focused workspace via a fuzzel prompt.
# Empty input clears the name. Names persist to ~/.config/niri/workspace-names.json.
set -euo pipefail

STATE="$HOME/.config/niri/workspace-names.json"
mkdir -p "$(dirname "$STATE")"
[ -f "$STATE" ] || echo '{}' > "$STATE"

idx=$(niri msg --json workspaces | jq -r '.[] | select(.is_focused) | .idx')
new=$(printf '' | fuzzel --dmenu --prompt "rename ws ${idx}: " --lines 0 || true)

if [ -z "$new" ]; then
    niri msg action unset-workspace-name
    jq --arg k "$idx" 'del(.[$k])' "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
else
    niri msg action set-workspace-name "$new"
    jq --arg k "$idx" --arg v "$new" '.[$k] = $v' "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
fi
