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
        $ws | sort_by(.idx) | map(
            . as $w
            | ($by_ws[($w.id|tostring)] // []) as $ws_wins
            | ($ws_wins | length) as $n
            | select($n > 0 or $w.is_focused)
            | ($ws_wins | group_by(.layout.pos_in_scrolling_layout[0])
                        | sort_by(.[0].layout.pos_in_scrolling_layout[0])) as $cols
            | ($ws_wins | map(select(.is_focused) | .layout.pos_in_scrolling_layout[0]) | first // -1) as $focused_col_idx
            | (any($ws_wins[]; .is_urgent == true)) as $ws_has_urgent
            | {
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
        )
    ' 2>/dev/null
}

trap 'emit' USR1
emit
niri msg event-stream 2>/dev/null | while IFS= read -r line; do
    case "$line" in
        *Workspace*|*Window*) emit ;;
    esac
done
