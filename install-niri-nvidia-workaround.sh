#!/usr/bin/env bash
# One-shot: install the NVIDIA per-process profile that prevents niri from
# holding ~1 GiB VRAM unnecessarily. Reversible with:
#   sudo rm /etc/nvidia/nvidia-application-profiles-rc.d/50-limit-free-buffer-pool-in-wayland-compositors.json
# Source: https://github.com/YaLTeR/niri/wiki/Nvidia
set -euo pipefail

sudo mkdir -p /etc/nvidia/nvidia-application-profiles-rc.d
sudo tee /etc/nvidia/nvidia-application-profiles-rc.d/50-limit-free-buffer-pool-in-wayland-compositors.json > /dev/null <<'EOF'
{
    "rules": [
        {
            "pattern": {
                "feature": "procname",
                "matches": "niri"
            },
            "profile": "Limit Free Buffer Pool On Wayland Compositors"
        }
    ],
    "profiles": [
        {
            "name": "Limit Free Buffer Pool On Wayland Compositors",
            "settings": [
                {
                    "key": "GLVidHeapReuseRatio",
                    "value": 0
                }
            ]
        }
    ]
}
EOF

echo "installed: /etc/nvidia/nvidia-application-profiles-rc.d/50-limit-free-buffer-pool-in-wayland-compositors.json"
