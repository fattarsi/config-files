#!/usr/bin/env bash
# Emit JSON state for eww minimap on every niri event (and on SIGUSR1 from
# color-cycle/color-pick).
#
# Output: one JSON line per event. Array of workspaces with their columns,
# each column carrying the primary window id + resolved color.

COLORS_FILE="$HOME/.config/niri/app-colors.conf"
TAGS_FILE="${XDG_RUNTIME_DIR:-/run/user/$UID}/niri-window-tags.json"
PID_FILE="${XDG_RUNTIME_DIR:-/run/user/$UID}/niri-minimap.pid"

echo $$ > "$PID_FILE"
trap 'rm -f "$PID_FILE"' EXIT

load_colors() {
    [ -f "$COLORS_FILE" ] || { echo '{}'; return 0; }
    awk -F'=' '
        BEGIN { printf "{" }
        /^[[:space:]]*#/  { next }
        /^[[:space:]]*$/  { next }
        NF < 2            { next }
        {
            key = $1; val = $2
            for (i = 3; i <= NF; i++) val = val "=" $i
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", val)
            key = tolower(key)
            if (n++) printf ","
            printf "\"%s\":\"%s\"", key, val
        }
        END { printf "}" }
    ' "$COLORS_FILE"
}

load_tags() { [ -f "$TAGS_FILE" ] && cat "$TAGS_FILE" || echo '{}'; }

emit() {
    local ws_json win_json colors_json tags_json
    ws_json=$(niri msg --json workspaces 2>/dev/null) || return 0
    win_json=$(niri msg --json windows 2>/dev/null || echo '[]')
    colors_json=$(load_colors); [ -z "$colors_json" ] && colors_json='{}'
    tags_json=$(load_tags); [ -z "$tags_json" ] && tags_json='{}'

    jq -nc \
        --argjson ws "$ws_json" \
        --argjson wins "$win_json" \
        --argjson colors "$colors_json" \
        --argjson tags "$tags_json" '
        ($colors.default // "#888") as $default_color
        |
        ($wins | group_by(.workspace_id)
              | map({key: (.[0].workspace_id|tostring), value: .})
              | from_entries) as $by_ws
        |
        ($ws
        | sort_by(.idx)
        # Hide internal workspaces (names starting with "_", e.g., "_scratch"
        # used by niri-btop-toggle.sh) — they never belong in the minimap.
        | [.[] | select(((.name // "") | startswith("_")) | not)]
        | [.[] | select((($by_ws[(.id|tostring)] // []) | length) > 0 or .is_focused)]
        | to_entries
        | map(
            .key as $list_index
            | .value as $w
            | ($by_ws[($w.id|tostring)] // []) as $ws_wins
            | ($ws_wins | group_by(.layout.pos_in_scrolling_layout[0])
                        | sort_by(.[0].layout.pos_in_scrolling_layout[0])) as $cols
            | ($ws_wins | map(select(.is_focused) | .layout.pos_in_scrolling_layout[0]) | first // -1) as $focused_col_idx
            | (any($ws_wins[]; .is_urgent == true)) as $ws_has_urgent
            | {
                list_index: $list_index,
                idx: $w.idx,
                id: $w.id,
                name: ($w.name // ""),
                is_focused: $w.is_focused,
                has_urgent: $ws_has_urgent,
                columns: ($cols | map(
                    .[0].layout.pos_in_scrolling_layout[0] as $col_idx
                    | ((map(select(.is_focused)) | first) // .[0]) as $primary
                    | (any(.[]; .is_urgent == true)) as $col_urgent
                    | {
                        col_idx: $col_idx,
                        stack_size: length,
                        is_focused_col: ($col_idx == $focused_col_idx),
                        is_urgent: $col_urgent,
                        primary_window_id: $primary.id,
                        color: ($tags[($primary.id|tostring)] // $colors[(($primary.app_id // "") | ascii_downcase)] // $default_color)
                      }
                ))
              }
        )) as $workspaces
        | ($workspaces | length) as $total
        | ([$workspaces[] | select(.is_focused) | .list_index] | first // 0) as $focused
        # Windowed view centered on the focused workspace so it always stays
        # visible as the user navigates. Window size kept modest; tuned from
        # the bar width cap (~1100px) and observed label widths.
        | 4 as $radius
        | (($radius * 2) + 1) as $win
        | ([0, ($focused - $radius)] | max) as $s0
        | ([$s0, ($total - $win)] | min) as $s1
        | ([0, $s1] | max) as $start
        | ([($start + $win), $total] | min) as $end
        | {
            ws: $workspaces[$start:$end],
            focused_li: $focused,
            total: $total,
            start: $start,
            end: $end,
            more_left: $start,
            more_right: ($total - $end)
          }
    ' 2>/dev/null
}

trap 'emit' USR1
emit

# Process substitution (not a pipe) so the while loop runs in the SAME shell
# as the trap. With a pipe, the loop runs in a subshell that doesn't receive
# SIGUSR1 — color-cycle/pick wouldn't refresh until a real niri event came in.
while IFS= read -r line; do
    case "$line" in
        *Workspace*|*Window*) emit ;;
    esac
done < <(niri msg event-stream 2>/dev/null)
