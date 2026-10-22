#!/bin/sh
PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
export PATH
# Start tailscaled in userspace-networking mode (no TUN required).
# <PEER_8> 3 Keyboard / ARMv6 / kernel 2.6.26

DIR=/mnt/us/extensions/tailscale
DAEMON="$DIR/bin/tailscaled"
# /mnt/us is FUSE; it does not permit bind(2) on Unix sockets.
# Keep the transient control socket on tmpfs.
SOCK="/tmp/tailscaled.sock"
PIDFILE="$DIR/run/tailscaled.pid"
STATE="/var/local/tailscale/tailscaled.state"
LOG="$DIR/logs/tailscaled.log"
SOCKS="127.0.0.1:1055"
HTTPPROXY="127.0.0.1:1056"

mkdir -p "$DIR/run" "$DIR/logs" /var/local/tailscale
chmod 700 /var/local/tailscale 2>/dev/null
if [ -f "$STATE" ]; then
    chmod 600 "$STATE" 2>/dev/null
fi

if [ -f "$PIDFILE" ]; then
    pid=$(cat "$PIDFILE" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        echo "tailscaled already running (pid $pid)"
        exit 0
    fi
    rm -f "$PIDFILE"
fi
rm -f "$SOCK"

# Tailscale TLS requires a roughly correct clock. NTP is used only to set
# the system clock; no Tailscale state or credentials are involved.
echo "--- start $(date) ---" >> "$LOG"
echo "syncing clock via ntpdate" >> "$LOG"
ntpdate -u -t 5 time.google.com >> "$LOG" 2>&1
echo "clock now: $(date -u)" >> "$LOG"

# The <PEER_8> has no nohup/setsid. Ignore SIGHUP in the child, then exec so
# $! is the real tailscaled PID.
sh -c 'trap "" HUP; exec "$0" "$@"' "$DAEMON" \
    --tun=userspace-networking \
    --state="$STATE" \
    --socket="$SOCK" \
    --socks5-server="$SOCKS" \
    --outbound-http-proxy-listen="$HTTPPROXY" \
    --port=0 \
    --verbose=0 \
    </dev/null >>"$LOG" 2>&1 &
echo $! > "$PIDFILE"

i=0
while [ "$i" -lt 30 ]; do
    if [ -S "$SOCK" ]; then
        break
    fi
    sleep 1
    i=$((i + 1))
done

# Upstream safesocket creates the control socket as 0666 and relies on peer
# credentials for authorization (non-root peers get read-only LocalAPI).
# This device has no need for that; restrict the socket to root.
if [ -S "$SOCK" ]; then
    chmod 600 "$SOCK" 2>/dev/null
fi

pid=$(cat "$PIDFILE" 2>/dev/null)
if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    echo "tailscaled started (pid $pid)"
    echo "SOCKS5 proxy:   $SOCKS"
    echo "HTTP proxy:     $HTTPPROXY"
    echo "socket:         $SOCK"
    echo "state:          $STATE"
    echo "log:            $LOG"
else
    echo "ERROR: tailscaled failed to start; last log lines:"
    tail -30 "$LOG"
    exit 1
fi

