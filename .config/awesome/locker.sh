#!/bin/sh

exec xautolock -time 11 -locker "i3lock -d -f -c 000010" -notify 60 \
  -notifier "notify-send -u critical -t 50000 -- 'LOCKING screen in 60 seconds'"
