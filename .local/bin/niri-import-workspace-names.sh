#!/usr/bin/env bash
# One-shot: snapshot the currently-named workspaces from the running niri
# instance into ~/.config/niri/workspace-names.json.
# Existing entries in the file are merged (not overwritten).
set -euo pipefail

STATE="$HOME/.config/niri/workspace-names.json"
mkdir -p "$(dirname "$STATE")"
[ -f "$STATE" ] || echo '{}' > "$STATE"

# Build a {"idx": "name"} object from current niri workspaces with non-empty names.
current=$(niri msg --json workspaces | jq '[.[] | select(.name != null and .name != "") | {key: (.idx|tostring), value: .name}] | from_entries')

# Merge: file values stay, but new ones from niri get added.
# (Use file-first merge so any saved name you've already changed isn't overwritten.)
jq --argjson cur "$current" '. * $cur' "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"

echo "Saved to: $STATE"
jq . "$STATE"
