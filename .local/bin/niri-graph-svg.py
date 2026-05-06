#!/usr/bin/env python3
"""Render a small filled-area history graph as SVG for use as an eww image source.

Usage: niri-graph-svg.py <cpu|mem|net>

Each call:
  - samples the metric (delta-based for cpu/net, snapshot for mem)
  - appends to a rolling history file (last 60 samples)
  - writes an SVG to $XDG_RUNTIME_DIR/niri-graph-svg/<metric>.<ms>.svg
  - prints the path on stdout (eww image widget reloads on path change)

Old SVGs are cleaned up so the runtime dir stays small.
"""
import os
import sys
import time
from pathlib import Path

W, H = 77, 36
HIST_LEN = 60
COLORS = {"cpu": "#ff6e67", "mem": "#5af78e", "net": "#57c7ff"}

state_dir = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "niri-graph-svg"
state_dir.mkdir(parents=True, exist_ok=True)


def sample_cpu():
    """CPU % since last invocation (from /proc/stat deltas)."""
    last = state_dir / "cpu.last"
    with open("/proc/stat") as f:
        parts = f.readline().split()
    user, nice, sysv, idle, iowait, irq, softirq, steal = (int(x) for x in parts[1:9])
    idle_total = idle + iowait
    total = user + nice + sysv + idle + iowait + irq + softirq + steal
    pct = 0.0
    if last.exists():
        prev_idle, prev_total = (int(x) for x in last.read_text().split())
        d_idle = idle_total - prev_idle
        d_total = total - prev_total
        if d_total > 0:
            pct = 100.0 * (1 - d_idle / d_total)
    last.write_text(f"{idle_total} {total}")
    return max(0.0, min(100.0, pct))


def sample_mem():
    info = {}
    with open("/proc/meminfo") as f:
        for line in f:
            k, _, v = line.partition(":")
            info[k] = int(v.strip().split()[0])
    return max(0.0, min(100.0, 100.0 * (1 - info["MemAvailable"] / info["MemTotal"])))


def sample_net_kbps():
    """Network rate in KB/s (max of rx and tx, summed across non-loopback ifaces)."""
    last = state_dir / "net.last"
    rx = tx = 0
    with open("/proc/net/dev") as f:
        for line in f.readlines()[2:]:
            iface, _, rest = line.partition(":")
            if iface.strip() == "lo":
                continue
            cols = rest.split()
            rx += int(cols[0])
            tx += int(cols[8])
    now = time.time_ns()
    kbps = 0.0
    if last.exists():
        try:
            prev_rx, prev_tx, prev_t = (int(x) for x in last.read_text().split())
            dt_ns = now - prev_t
            if dt_ns > 0:
                bps = max(rx - prev_rx, tx - prev_tx) * 1_000_000_000 / dt_ns
                kbps = max(0.0, bps / 1024.0)
        except Exception:
            pass
    last.write_text(f"{rx} {tx} {now}")
    return kbps


SAMPLERS = {"cpu": sample_cpu, "mem": sample_mem, "net": sample_net_kbps}


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in SAMPLERS:
        print("usage: niri-graph-svg.py <cpu|mem|net>", file=sys.stderr)
        sys.exit(2)
    metric = sys.argv[1]
    val = SAMPLERS[metric]()

    # Append to history
    hist_path = state_dir / f"{metric}.hist"
    hist = []
    if hist_path.exists():
        try:
            hist = [float(l) for l in hist_path.read_text().splitlines() if l.strip()]
        except Exception:
            hist = []
    hist.append(val)
    hist = hist[-HIST_LEN:]
    hist_path.write_text("\n".join(f"{v:.3f}" for v in hist))

    # Y-axis range: percentages use 0..100 fixed; net auto-scales to recent peak.
    if metric in ("cpu", "mem"):
        y_min, y_max = 0.0, 100.0
    else:
        peak = max(hist) if hist else 1.0
        y_min, y_max = 0.0, max(peak * 1.1, 16.0)  # ≥16 KB/s floor

    span = max(y_max - y_min, 1e-6)

    # Build points (anchored to right edge so newest sample is on the right)
    n = len(hist)
    pts = []
    for i, v in enumerate(hist):
        x = (W - 1) * (1 - (n - 1 - i) / max(HIST_LEN - 1, 1))
        y = H - (v - y_min) / span * H
        pts.append((x, y))

    color = COLORS[metric]
    poly = " ".join(f"{x:.1f},{y:.1f}" for x, y in pts)
    if pts:
        fill = f"{pts[0][0]:.1f},{H} " + poly + f" {pts[-1][0]:.1f},{H}"
    else:
        fill = ""

    svg = (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
        f'viewBox="0 0 {W} {H}">'
        f'<rect width="{W}" height="{H}" fill="#000" fill-opacity="0.45"/>'
        f'<polygon points="{fill}" fill="{color}" fill-opacity="0.30"/>'
        f'<polyline points="{poly}" fill="none" stroke="{color}" stroke-width="1.5" '
        f'stroke-linejoin="round" stroke-linecap="round"/>'
        f'</svg>'
    )

    ms = int(time.time() * 1000)
    out = state_dir / f"{metric}.{ms}.svg"
    out.write_text(svg)

    # Keep only the 4 most recent for this metric
    olds = sorted(state_dir.glob(f"{metric}.*.svg"), reverse=True)[4:]
    for p in olds:
        try:
            p.unlink()
        except Exception:
            pass

    print(out)


if __name__ == "__main__":
    main()
