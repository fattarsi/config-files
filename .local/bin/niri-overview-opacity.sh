#!/usr/bin/env bash
# Toggle the unfocused-window opacity rule based on overview state.
# When the overview opens we want windows fully solid (opacity 1.0); when it
# closes we restore the base value so unfocused windows fade slightly.
set -euo pipefail

CONFIG="$HOME/.config/niri/config.kdl"
BASE_OPACITY="0.92"

set_opacity() {
    local val="$1"
    # Replace only the line tagged OVERVIEW_TOGGLE in the config
    # The previous line "opacity X" is what we change.
    sed -i -E "/\/\/ OVERVIEW_TOGGLE/{
        x
        s|^.*$|    opacity ${val}|
        x
    }
    /\/\/ OVERVIEW_TOGGLE/!{
        H
    }" "$CONFIG"
    # The hold-buffer trick is fragile — fall back to a simpler form below.
    :
}

# Simpler set_opacity using awk: rewrite line N-1 where line N has the marker.
set_opacity() {
    local val="$1"
    awk -v val="$val" '
        /\/\/ OVERVIEW_TOGGLE/ {
            # The previous line is the opacity line; rewrite it.
            sub(/opacity[[:space:]]+[0-9.]+/, "opacity " val, prev)
        }
        NR > 1 { print prev }
        { prev = $0 }
        END { print prev }
    ' "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"
    niri msg action load-config-file 2>/dev/null || true
}

niri msg event-stream 2>/dev/null | while IFS= read -r line; do
    case "$line" in
        *OverviewOpenedOrClosed*)
            if echo "$line" | grep -q '"is_open":true\|is_open: true\|is_open:true'; then
                set_opacity "1.0"
            else
                set_opacity "$BASE_OPACITY"
            fi
            ;;
    esac
done
