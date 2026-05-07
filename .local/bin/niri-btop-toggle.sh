#!/usr/bin/env bash
# Persistent btop scratchpad via tmux. btop runs inside a detached tmux
# session so its in-process history graphs accumulate across show/hide
# cycles AND survive niri restarts. Closing the kitty window detaches the
# tmux client; the server (with btop) lives on independently of niri.
set -euo pipefail

APP_ID="niri-btop"
SESSION="btop"
# Custom socket isolates this tmux instance from the user's normal tmux
# usage so they don't see "btop" in the regular session list.
SOCKET="btop-scratchpad"

wins=$(niri msg --json windows 2>/dev/null)
btop_id=$(echo "$wins" | jq -r --arg a "$APP_ID" '[.[] | select(.app_id == $a)] | first | .id // empty')

if [ -n "$btop_id" ]; then
    # Visible — close the kitty window. The tmux client detaches gracefully
    # on its pty's HUP; the server (and btop) keep running in the background.
    niri msg action close-window --id "$btop_id" 2>/dev/null
else
    # Hidden — open a kitty attached to the (existing or new) tmux session.
    # The inline set-options ensure tmux advertises truecolor + 256-color
    # support so btop's gradients render properly inside the multiplexer.
    setsid -f kitty --class "$APP_ID" -e \
        tmux -L "$SOCKET" \
            set-option -g default-terminal "tmux-256color" \; \
            set-option -ag terminal-overrides ",*:Tc" \; \
            new-session -A -s "$SESSION" btop \
        >/dev/null 2>&1 &
    disown
fi
