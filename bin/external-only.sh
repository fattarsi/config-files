#!/bin/sh
HDMI_OUT=$(xrandr | grep -oP 'HDMI-\S+ connected' | head -1 | awk '{print $1}')
EDP_OUT=$(xrandr | grep -oP 'eDP-\S+ connected' | head -1 | awk '{print $1}')
xrandr --output "${EDP_OUT:-eDP-1}" --off --output "${HDMI_OUT:-HDMI-1-0}" --mode 3840x2160 --pos 0x0 --rotate normal
