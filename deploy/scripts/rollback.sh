#!/bin/sh
# Roll back the runtime footprint without deleting the installation.
#
# Stops tailscaled, removes the tmpfs socket and stale pid files, and leaves
# the binaries, scripts, logs, KUAL entry and node identity in place. This is
# the safe "make the device behave as it did before" action.
#
# Usage: rollback.sh [--purge-state] [--yes]
#   --purge-state  also delete /var/local/tailscale (next start needs a new login)
#   --yes          skip the confirmation for --purge-state
PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
export PATH
D=/mnt/us/extensions/tailscale
STATE=/var/local/tailscale
SOCK=/tmp/tailscaled.sock

PURGE=no
YES=no
for a in "$@"; do
    case "$a" in
        --purge-state) PURGE=yes ;;
        --yes) YES=yes ;;
        -h|--help)
            echo "usage: $0 [--purge-state] [--yes]"
            exit 0
            ;;
        *) echo "unknown option: $a"; exit 2 ;;
    esac
done

if [ "$PURGE" = "yes" ] && [ "$YES" != "yes" ]; then
    printf "Delete node identity in %s? Type 'yes': " "$STATE"
    ans=""
    read ans
    if [ "$ans" != "yes" ]; then
        echo "aborted"
        exit 1
    fi
fi

echo "=== stopping daemon ==="
if [ -x "$D/scripts/stop.sh" ]; then
    "$D/scripts/stop.sh"
else
    echo "stop.sh not found; nothing to stop"
fi

echo "=== removing runtime socket and pid files ==="
rm -f "$SOCK"
rm -f "$D/run/"*.pid
echo "removed $SOCK"

if [ "$PURGE" = "yes" ]; then
    echo "=== removing node state ==="
    chmod -R u+rwx "$STATE" 2>/dev/null
    rm -rf "$STATE"
    echo "removed $STATE (re-authentication required on next start)"
else
    echo "=== node state kept ==="
    ls -ld "$STATE" 2>/dev/null
    ls -l "$STATE/tailscaled.state" 2>/dev/null
fi

echo "=== verification ==="
if ps | grep tailscaled | grep -v grep >/dev/null 2>&1; then
    echo "WARNING: a tailscaled process is still running"
else
    echo "no tailscaled process running"
fi
[ -S "$SOCK" ] && echo "WARNING: socket still present" || echo "socket absent"

echo
echo "Runtime rolled back. Installed files remain under $D."
echo "Kernel, libc and system files were not modified."
