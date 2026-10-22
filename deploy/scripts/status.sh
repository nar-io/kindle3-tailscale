#!/bin/sh
PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
export PATH
# Show daemon + tailnet status, IP, and resource usage.
DIR=/mnt/us/extensions/tailscale
TS="$DIR/bin/tailscale"
SOCK="/tmp/tailscaled.sock"
PIDFILE="$DIR/run/tailscaled.pid"

echo "=== version ==="
"$TS" --socket="$SOCK" version 2>&1

echo "=== daemon ==="
if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    pid=$(cat "$PIDFILE")
    echo "tailscaled running pid=$pid"
    grep -e "VmRSS" -e "VmSize" -e "Threads" /proc/$pid/status 2>/dev/null
else
    echo "tailscaled NOT running"
fi

echo "=== status ==="
"$TS" --socket="$SOCK" status 2>&1

echo "=== ip ==="
"$TS" --socket="$SOCK" ip -4 2>&1

echo "=== proxy listeners ==="
cat /proc/net/tcp 2>/dev/null | grep -i -e ":041F" -e ":0420" || true
