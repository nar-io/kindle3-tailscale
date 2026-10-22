#!/bin/sh
PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
export PATH
# Trigger interactive authentication. No auth key is stored.
# The login URL is written to logs/auth.log; open it in any browser and
# approve the device. This process exits once the node is authenticated.
DIR=/mnt/us/extensions/tailscale
TS="$DIR/bin/tailscale"
SOCK="/tmp/tailscaled.sock"
LOG="$DIR/logs/auth.log"
PIDFILE="$DIR/run/auth.pid"

if [ ! -S "$SOCK" ]; then
    echo "tailscaled is not running; run scripts/start.sh first"
    exit 1
fi

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "auth already in progress (pid $(cat "$PIDFILE")); see $LOG"
    exit 0
fi

echo "--- auth attempt $(date) ---" > "$LOG"
sh -c 'trap "" HUP; exec "$0" "$@"' "$TS" --socket="$SOCK" up \
    --accept-dns=false \
    --accept-routes=false \
    --host-routes=true \
    --netfilter-mode=off \
    --hostname=<NODE_NAME> \
    >>"$LOG" 2>&1 &
echo $! > "$PIDFILE"
sleep 6
echo "=== auth log ==="
cat "$LOG"
echo "=== end ==="
echo "If a URL is shown above, open it and approve the device."

