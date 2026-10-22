#!/bin/sh
# Uninstall Tailscale from this <PEER_8>.
#
# Removes:
#   /mnt/us/extensions/tailscale   binaries, scripts, logs, KUAL entry
#   /var/local/tailscale           node identity/state (unless --keep-state)
#   /tmp/tailscaled.sock           runtime socket
#
# Does NOT touch the kernel, libc, /etc, or any Amazon system file.
#
# Usage: uninstall.sh [--yes] [--logout] [--keep-state]
#   --yes         do not prompt (required when stdin is not a terminal)
#   --logout      ask the control plane to remove this node before deleting state
#   --keep-state  keep /var/local/tailscale so a reinstall keeps the same node
PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
export PATH
D=/mnt/us/extensions/tailscale
STATE=/var/local/tailscale
SOCK=/tmp/tailscaled.sock

# The uninstaller deletes its own directory. Re-exec from tmpfs first so the
# shell never loses the script file it is reading.
if [ -f "$0" ]; then
    case "$0" in
        /tmp/ts-uninstall.*) ;;
        *)
            tmp="/tmp/ts-uninstall.$$"
            if cp "$0" "$tmp"; then
                chmod 700 "$tmp"
                exec "$tmp" "$@"
            fi
            echo "WARNING: could not copy uninstaller to $tmp; continuing in place"
            ;;
    esac
fi

usage() {
    echo "usage: $0 [--yes] [--logout] [--keep-state]"
    echo "  --yes         do not prompt"
    echo "  --logout      remove this node from the tailnet before deleting state"
    echo "  --keep-state  keep /var/local/tailscale (node identity survives)"
}

YES=no
LOGOUT=no
KEEP=no
for a in "$@"; do
    case "$a" in
        --yes) YES=yes ;;
        --logout) LOGOUT=yes ;;
        --keep-state) KEEP=yes ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown option: $a"; usage; exit 2 ;;
    esac
done

if [ "$YES" != "yes" ]; then
    echo "This will remove:"
    echo "  $D"
    if [ "$KEEP" = "yes" ]; then
        echo "  (node state in $STATE will be kept)"
    else
        echo "  $STATE  (node identity - a future install must log in again)"
    fi
    printf "Type 'yes' to continue: "
    ans=""
    read ans
    if [ "$ans" != "yes" ]; then
        echo "aborted"
        rm -f "$0"
        exit 1
    fi
fi

if [ "$LOGOUT" = "yes" ] && [ -S "$SOCK" ]; then
    echo "logging out (removing this node from the tailnet)..."
    "$D/bin/tailscale" --socket="$SOCK" logout 2>&1 || true
fi

echo "stopping daemon..."
if [ -x "$D/scripts/stop.sh" ]; then
    "$D/scripts/stop.sh"
elif [ -f "$D/run/tailscaled.pid" ]; then
    pid=$(cat "$D/run/tailscaled.pid" 2>/dev/null)
    if [ -n "$pid" ]; then
        kill "$pid" 2>/dev/null
        sleep 2
        kill -9 "$pid" 2>/dev/null
    fi
fi

rm -f "$SOCK"

if [ "$KEEP" = "yes" ]; then
    echo "keeping node state: $STATE"
else
    chmod -R u+rwx "$STATE" 2>/dev/null
    rm -rf "$STATE"
    echo "removed node state: $STATE"
fi

echo "removing $D ..."
rm -rf "$D"
rm -f "$0"

echo
echo "Uninstalled."
echo "System files (kernel, libc, /etc, init scripts) were not modified."
if [ "$LOGOUT" != "yes" ]; then
    echo "Note: this node may still be listed in the Tailscale admin console."
    echo "      Remove it there, or use --logout next time."
fi

