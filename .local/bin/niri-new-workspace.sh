#!/usr/bin/env bash
# Mod+Shift+A flow: fuzzel prompts for a workspace name, then creates the
# next empty workspace at the end of the list, applies the name, and persists
# it in ~/.config/niri/workspace-names.json so the name survives logout.
# Empty input creates the workspace without naming it.
set -euo pipefail

STATE="$HOME/.config/niri/workspace-names.json"
mkdir -p "$(dirname "$STATE")"
[ -f "$STATE" ] || echo '{}' > "$STATE"

new_name=$(printf '' | fuzzel --dmenu --prompt "new workspace: " --lines 0 || true)

# Move to the empty workspace at the end (count + 1).
target=$(( $(niri msg --json workspaces | jq 'length') + 1 ))
niri msg action focus-workspace "$target" 2>/dev/null || exit 0

# After focus, the new workspace's idx is whatever niri ends up landing on.
new_idx=$(niri msg --json workspaces | jq -r '.[] | select(.is_focused) | .idx')

if [ -n "$new_name" ]; then
    niri msg action set-workspace-name "$new_name"
    jq --arg k "$new_idx" --arg v "$new_name" '.[$k] = $v' "$STATE" > "$STATE.tmp" \
        && mv "$STATE.tmp" "$STATE"
fi
