#!/bin/sh
# KUAL action: trigger interactive login and print the URL on screen.
# No auth key is used or stored; the URL must be approved in a browser.
PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
export PATH
D=/mnt/us/extensions/tailscale
TS="$D/bin/tailscale"
SOCK=/tmp/tailscaled.sock
EIPS=/usr/sbin/eips

show_line() {
    text="$2"
    while [ ${#text} -lt 50 ]; do
        text="$text "
    done
    "$EIPS" 0 "$1" "$text" >/dev/null 2>&1
}

if [ ! -S "$SOCK" ]; then
    show_line 36 "Not running - start Tailscale first"
    exit 1
fi

ip=$("$TS" --socket="$SOCK" ip -4 2>/dev/null | head -1)
if [ -n "$ip" ]; then
    show_line 36 "Already logged in"
    show_line 37 "Node IP: $ip"
    exit 0
fi

"$D/scripts/login.sh" >/dev/null 2>&1

url=$(grep -o "https://login.tailscale.com/a/[A-Za-z0-9]*" "$D/logs/auth.log" 2>/dev/null | tail -1)
if [ -n "$url" ]; then
    show_line 36 "Open in a browser, then approve:"
    show_line 37 "$url"
else
    ip=$("$TS" --socket="$SOCK" ip -4 2>/dev/null | head -1)
    if [ -n "$ip" ]; then
        show_line 36 "Login completed"
        show_line 37 "Node IP: $ip"
    else
        show_line 36 "No URL yet - see logs/auth.log"
    fi
fi
exit 0
