#!/usr/bin/env bash
# Adjust niri's overview.zoom in 0.05 steps, clamped to [0, 0.75].
# Usage: niri-overview-zoom.sh in|out
#   in  → zoom IN  (workspaces appear larger, less zoomed-out)
#   out → zoom OUT (workspaces appear smaller, more zoomed-out)
set -euo pipefail

CONFIG="$HOME/.config/niri/config.kdl"
STEP=0.05
direction="${1:?usage: $0 in|out}"

current=$(awk '/^[[:space:]]*zoom [0-9]/ {print $2; exit}' "$CONFIG")
if [ -z "$current" ]; then
    echo "no overview.zoom line found in $CONFIG" >&2
    exit 1
fi

new=$(awk -v c="$current" -v s="$STEP" -v d="$direction" '
    BEGIN {
        v = (d == "in") ? c + s : c - s
        if (v > 0.75) v = 0.75
        if (v < 0)    v = 0
        printf "%.2f", v
    }')

# Replace the zoom value (preserve indentation).
sed -i -E "s|^([[:space:]]*)zoom [0-9.]+|\\1zoom ${new}|" "$CONFIG"

# Niri reloads on file save automatically, but issue an explicit reload to be safe.
niri msg action load-config-file 2>/dev/null || true
