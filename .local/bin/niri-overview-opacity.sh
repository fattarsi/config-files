#!/usr/bin/env bash
# Toggle several niri config values based on overview state. Niri itself
# doesn't expose overview-specific styling, so we rewrite config.kdl when the
# overview opens/closes and reload via IPC.
#
# Markers (on the line *after* the value being toggled):
#   // OVERVIEW_TOGGLE_OPACITY      — unfocused-window opacity rule
#   // OVERVIEW_TOGGLE_RING_WIDTH   — focus-ring.width
#   // OVERVIEW_TOGGLE_RING_COLOR   — focus-ring.active-color
#
# Normal-mode values: thin blue ring, slightly faded inactive windows.
# Overview-mode values: thick red ring, no fade so windows render solid.
set -euo pipefail

CONFIG="$HOME/.config/niri/config.kdl"

apply() {
    local opacity="$1" ring_width="$2" ring_color="$3"
    awk \
        -v op="$opacity" -v rw="$ring_width" -v rc="$ring_color" '
        /\/\/ OVERVIEW_TOGGLE_OPACITY/ {
            sub(/opacity[[:space:]]+[0-9.]+/, "opacity " op, prev)
        }
        /\/\/ OVERVIEW_TOGGLE_RING_WIDTH/ {
            sub(/width[[:space:]]+[0-9]+/, "width " rw, prev)
        }
        /\/\/ OVERVIEW_TOGGLE_RING_COLOR/ {
            sub(/active-color[[:space:]]+"[^"]*"/, "active-color \"" rc "\"", prev)
        }
        NR > 1 { print prev }
        { prev = $0 }
        END { print prev }
    ' "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"
    niri msg action load-config-file 2>/dev/null || true
}

while IFS= read -r line; do
    case "$line" in
        *OverviewOpenedOrClosed*)
            if echo "$line" | grep -q '"is_open":true\|is_open: true\|is_open:true'; then
                apply "1.0" "6" "#ff6e67"
            else
                apply "0.75" "2" "#7fc8ff"
            fi
            ;;
    esac
done < <(niri msg event-stream 2>/dev/null)
