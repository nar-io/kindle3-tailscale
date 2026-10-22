#!/bin/sh
# KUAL action: start tailscaled and report on the bottom line of the screen.
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

res=$("$D/scripts/start.sh" 2>&1)
rc=$?
echo "--- kual-start $(date) rc=$rc ---" >> "$OUT"
echo "$res" >> "$OUT"

if [ "$rc" -eq 0 ]; then
    show_line 36 "Tailscale started | SOCKS5 1055 | HTTP 1056"
else
    show_line 36 "Start FAILED - see logs/tailscaled.log"
fi
exit "$rc"
