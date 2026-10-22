#!/bin/sh
# KUAL action: stop tailscaled and report on the bottom line of the screen.
PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
export PATH
D=/mnt/us/extensions/tailscale
EIPS=/usr/sbin/eips
OUT="$D/logs/kual.log"

mkdir -p "$D/logs"

show_line() {
    text="$2"
    while [ ${#text} -lt 50 ]; do
        text="$text "
    done
    "$EIPS" 0 "$1" "$text" >/dev/null 2>&1
}

res=$("$D/scripts/stop.sh" 2>&1)
rc=$?
echo "--- kual-stop $(date) rc=$rc ---" >> "$OUT"
echo "$res" >> "$OUT"

show_line 36 "Tailscale stopped"
exit 0
