#!/usr/bin/env bash
# Emit a 0-100 normalized network activity value for the eww graph.
# Uses an auto-decaying max so brief spikes don't peg the chart forever.
STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/niri-graph"
mkdir -p "$STATE_DIR"
LAST="$STATE_DIR/eww-net.last"
MAX_FILE="$STATE_DIR/eww-net.max"

rx=0; tx=0
while read -r line; do
    case "$line" in
        *:*)
            iface="${line%%:*}"; iface="${iface// /}"
            [ "$iface" = "lo" ] && continue
            rest="${line#*:}"
            set -- $rest
            rx=$((rx + $1)); tx=$((tx + $9))
            ;;
    esac
done < /proc/net/dev

cur_t=$(date +%s%N)
peak=0
if [ -f "$LAST" ]; then
    read -r prev_rx prev_tx prev_t < "$LAST"
    d_t_ns=$((cur_t - prev_t))
    if [ "$d_t_ns" -gt 0 ]; then
        d_rx=$(( (rx - prev_rx) * 1000000000 / d_t_ns ))
        d_tx=$(( (tx - prev_tx) * 1000000000 / d_t_ns ))
        [ "$d_rx" -lt 0 ] && d_rx=0
        [ "$d_tx" -lt 0 ] && d_tx=0
        peak=$(( d_rx > d_tx ? d_rx : d_tx ))
    fi
fi
echo "$rx $tx $cur_t" > "$LAST"

max=$(cat "$MAX_FILE" 2>/dev/null || echo 102400)
max=$(( max * 95 / 100 ))
[ "$max" -lt 1024 ] && max=1024
[ "$peak" -gt "$max" ] && max=$peak
echo "$max" > "$MAX_FILE"

if [ "$max" -gt 0 ]; then
    echo $(( peak * 100 / max ))
else
    echo 0
fi
