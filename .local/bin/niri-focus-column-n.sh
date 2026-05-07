#!/usr/bin/env bash
# Focus the Nth column in the current workspace (1-indexed, leftmost = 1).
# If N exceeds the column count, do nothing.
set -euo pipefail

n="${1:?usage: $0 N}"

ws_id=$(niri msg --json workspaces | jq -r '.[] | select(.is_focused) | .id')
[ -z "$ws_id" ] && exit 0

# Sorted unique column indices in the focused workspace.
mapfile -t cols < <(niri msg --json windows \
    | jq -r --argjson w "$ws_id" \
        '.[] | select(.workspace_id == $w) | .layout.pos_in_scrolling_layout[0]' \
    | sort -un)

target="${cols[$((n - 1))]:-}"
[ -z "$target" ] && exit 0

# Pick the first window in that column (consistent for stacked columns).
wid=$(niri msg --json windows \
    | jq -r --argjson w "$ws_id" --argjson c "$target" \
        '[.[] | select(.workspace_id == $w and .layout.pos_in_scrolling_layout[0] == $c)] | first | .id')

[ -z "$wid" ] && exit 0
niri msg action focus-window --id "$wid"
