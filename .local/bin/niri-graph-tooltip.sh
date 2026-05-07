#!/usr/bin/env bash
# Tooltip text for an eww graph hover. One metric per call.
# Usage: niri-graph-tooltip.sh <cpu|mem|net>
metric="${1:?usage: $0 cpu|mem|net}"

case "$metric" in
    cpu)
        printf "CPU — top processes:\n"
        ps -eo comm,%cpu --sort=-%cpu --no-headers 2>/dev/null \
            | head -5 \
            | awk '{printf "  %-22s %5s%%\n", $1, $2}'
        ;;
    mem)
        printf "Memory — top processes:\n"
        ps -eo comm,%mem --sort=-%mem --no-headers 2>/dev/null \
            | head -5 \
            | awk '{printf "  %-22s %5s%%\n", $1, $2}'
        ;;
    net)
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
        # Read-then-sleep-then-read to compute rate over 1s
        sleep 0.5
        rx2=0; tx2=0
        while read -r line; do
            case "$line" in
                *:*)
                    iface="${line%%:*}"; iface="${iface// /}"
                    [ "$iface" = "lo" ] && continue
                    rest="${line#*:}"
                    set -- $rest
                    rx2=$((rx2 + $1)); tx2=$((tx2 + $9))
                    ;;
            esac
        done < /proc/net/dev
        d_rx=$(( (rx2 - rx) * 2 ))   # bytes per second (×2 for 0.5s sample)
        d_tx=$(( (tx2 - tx) * 2 ))
        fmt() {
            awk -v b="$1" 'BEGIN {
                if (b >= 1048576)   printf "%.1f MB/s", b/1048576
                else if (b >= 1024) printf "%.0f KB/s", b/1024
                else                printf "%d B/s", b
            }'
        }
        printf "Network rates:\n  ↓ down  %s\n  ↑ up    %s" "$(fmt "$d_rx")" "$(fmt "$d_tx")"
        ;;
esac
