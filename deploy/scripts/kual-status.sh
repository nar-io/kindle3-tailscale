#!/bin/sh
# KUAL action: show a two-line summary at the bottom of the screen.
# Full output is written to logs/kual-status.txt for inspection over SSH.
PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
export PATH
D=/mnt/us/extensions/tailscale
TS="$D/bin/tailscale"
SOCK=/tmp/tailscaled.sock
EIPS=/usr/sbin/eips
OUT="$D/logs/kual-status.txt"

mkdir -p "$D/logs"
"$D/scripts/status.sh" >"$OUT" 2>&1

show_line() {
    text="$2"
    while [ ${#text} -lt 50 ]; do
        text="$text "
    done
    "$EIPS" 0 "$1" "$text" >/dev/null 2>&1
}

pid=""
state="down"
if [ -f "$D/run/tailscaled.pid" ]; then
    pid=$(cat "$D/run/tailscaled.pid" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        state="up"
    fi
fi

ip=$("$TS" --socket="$SOCK" ip -4 2>/dev/null | head -1)
[ -z "$ip" ] && ip="-"

peers="-"
if [ "$state" = "up" ]; then
    total=$("$TS" --socket="$SOCK" status 2>/dev/null | wc -l)
    total=$((total - 1))
    if [ "$total" -lt 0 ]; then
        total=0
    fi
    offline=$("$TS" --socket="$SOCK" status 2>/dev/null | grep -c offline)
    peers="$((total - offline))/$total online"
fi

show_line 36 "Tailscale $state  IP $ip"
show_line 37 "Peers $peers  SOCKS5 1055"
exit 0
