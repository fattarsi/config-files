#!/usr/bin/env bash
# Mod+Left/Right behavior: focus column left/right within the workspace; if
# already at the edge column, fall through to the previous/next workspace.
# No wrap-around — at the first workspace, going left does nothing.
set -euo pipefail

dir="${1:?usage: $0 left|right}"

focused=$(niri msg --json focused-window | jq -r '.id // empty')
if [ -z "$focused" ]; then
    # No focused window — just move workspace.
    case "$dir" in
        left)  niri msg action focus-workspace-up   2>/dev/null ;;
        right) niri msg action focus-workspace-down 2>/dev/null ;;
    esac
    exit 0
fi

ws_id=$(niri msg --json focused-window | jq -r '.workspace_id')
wins=$(niri msg --json windows)
cur_col=$(echo "$wins" | jq -r --argjson f "$focused" '.[] | select(.id == $f) | .layout.pos_in_scrolling_layout[0]')
ws_cols=$(echo "$wins" | jq --argjson w "$ws_id" '[.[] | select(.workspace_id == $w) | .layout.pos_in_scrolling_layout[0]]')
min_col=$(echo "$ws_cols" | jq 'min // 0')
max_col=$(echo "$ws_cols" | jq 'max // 0')

ws_data=$(niri msg --json workspaces)
cur_idx=$(echo "$ws_data" | jq -r --argjson w "$ws_id" '.[] | select(.id == $w) | .idx')
total_ws=$(echo "$ws_data" | jq -r '. | length')

case "$dir" in
    left)
        if [ "$cur_col" -gt "$min_col" ]; then
            niri msg action focus-column-left
        elif [ "$cur_idx" -gt 1 ]; then
            niri msg action focus-workspace-up
        fi
        ;;
    right)
        if [ "$cur_col" -lt "$max_col" ]; then
            niri msg action focus-column-right
        elif [ "$cur_idx" -lt "$total_ws" ]; then
            niri msg action focus-workspace-down
        fi
        ;;
esac
