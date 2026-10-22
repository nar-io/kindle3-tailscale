#!/bin/sh
PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
export PATH
# Stop tailscaled cleanly.
DIR=/mnt/us/extensions/tailscale
PIDFILE="$DIR/run/tailscaled.pid"
SOCK="/tmp/tailscaled.sock"

if [ -f "$PIDFILE" ]; then
    pid=$(cat "$PIDFILE" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        echo "stopping tailscaled (pid $pid)"
        kill "$pid" 2>/dev/null
        i=0
        while kill -0 "$pid" 2>/dev/null && [ "$i" -lt 20 ]; do
            sleep 1
            i=$((i + 1))
        done
        if kill -0 "$pid" 2>/dev/null; then
            echo "forcing kill"
            kill -9 "$pid" 2>/dev/null
        fi
    else
        echo "tailscaled not running (stale pidfile)"
    fi
else
    echo "tailscaled not running (no pidfile)"
fi
rm -f "$PIDFILE" "$SOCK"
echo "stopped"
