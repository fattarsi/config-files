#!/usr/bin/env bash
# Open kitty in the focused terminal's last-active cwd. Falls back to $HOME
# if the focused window isn't a terminal or has no walkable child shell.
#
# Logic: walk the focused window's child PIDs, find ones with an open PTY on
# fd 0, sort by the PTY's most-recent access time, take the topmost cwd.
# This lands us in the directory of whichever shell pane was used last.
set -euo pipefail

pid=$(niri msg --json focused-window 2>/dev/null | jq -r '.pid // empty')
dir=""

if [ -n "$pid" ]; then
    dir=$(for child in $(pgrep -P "$pid" 2>/dev/null); do
        pty=$(readlink "/proc/$child/fd/0" 2>/dev/null || true)
        cwd=$(readlink "/proc/$child/cwd" 2>/dev/null || true)
        if [ -n "$pty" ] && [ -n "$cwd" ]; then
            echo "$(stat -c %X "$pty" 2>/dev/null || echo 0) $cwd"
        fi
    done | sort -rn | head -1 | cut -d' ' -f2-)
fi

if [ -n "$dir" ] && [ -d "$dir" ]; then
    exec kitty --directory="$dir"
else
    exec kitty
fi
