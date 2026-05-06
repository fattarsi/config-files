#!/usr/bin/env bash
# At niri startup, replay the saved workspace names.
# For each saved (idx, name) pair: focus that workspace (creates it under
# dynamic-workspaces) and apply the name. Then return focus to where you started.
set -euo pipefail

STATE="$HOME/.config/niri/workspace-names.json"
[ -f "$STATE" ] || exit 0

# Wait until niri IPC responds — startup spawns can race ahead of the compositor.
for _ in $(seq 1 20); do
    niri msg --json workspaces >/dev/null 2>&1 && break
    sleep 0.1
done

saved=$(niri msg --json workspaces | jq -r '.[] | select(.is_focused) | .idx' 2>/dev/null || echo 1)

# Apply names in ascending idx order so workspaces are created in sequence.
jq -r 'to_entries[] | "\(.key)\t\(.value)"' "$STATE" \
    | sort -n -t$'\t' -k1 \
    | while IFS=$'\t' read -r idx name; do
        niri msg action focus-workspace "$idx" 2>/dev/null || continue
        niri msg action set-workspace-name "$name" 2>/dev/null || continue
    done

# Return focus to the originally-focused workspace (usually 1 at login).
niri msg action focus-workspace "$saved" 2>/dev/null || true
