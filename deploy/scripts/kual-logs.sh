#!/bin/sh
# KUAL action: show the last lines of tailscaled.log full-screen for 20 s.
# The screen is restored by KUAL/the framework when the menu closes.
PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
export PATH
D=/mnt/us/extensions/tailscale
EIPS=/usr/sbin/eips
LOG="$D/logs/tailscaled.log"

"$EIPS" -c >/dev/null 2>&1
"$EIPS" 0 0 "Tailscale log (last 30 lines)" >/dev/null 2>&1

i=2
tail -30 "$LOG" 2>/dev/null | cut -c1-50 | while read line; do
    if [ "$i" -gt 37 ]; then
        break
    fi
    "$EIPS" 0 "$i" "$line" >/dev/null 2>&1
    i=$((i + 1))
done

sleep 20
