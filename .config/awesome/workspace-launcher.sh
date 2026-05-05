#!/usr/bin/env bash
set -e

profile_list=$(awesome-client 'local n={}; for k in pairs(workspace_profiles) do table.insert(n,k) end; table.sort(n); return table.concat(n,"\n")' 2>/dev/null | sed -E 's/^[[:space:]]+string "//; s/"$//')
profile=$(printf '%s' "$profile_list" | rofi -dmenu -p "workspace")
[ -z "$profile" ] && exit 0

suffix=$(rofi -dmenu -p "$profile name" -l 0 </dev/null || true)

awesome-client "create_workspace([==[$profile]==], [==[$suffix]==])"
