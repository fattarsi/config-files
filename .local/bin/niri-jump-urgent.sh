#!/usr/bin/env bash
# Mod+U handler: jump to the urgent window, clear its urgency, dismiss notifications.
set -euo pipefail

wid=$(niri msg --json windows | jq -r '[.[] | select(.is_urgent == true)] | first | .id // empty')
if [ -z "$wid" ]; then
    # Nothing urgent — at least clear the notification panel
    makoctl dismiss --all 2>/dev/null || true
    exit 0
fi

niri msg action focus-window --id "$wid"
niri msg action unset-window-urgent --id "$wid" 2>/dev/null || true
makoctl dismiss --all 2>/dev/null || true
