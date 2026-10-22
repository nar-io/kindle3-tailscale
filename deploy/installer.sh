#!/bin/sh
# Tailscale ARMv6 Installer for Kindle 3 Keyboard
# Run this script ON the Kindle (via SSH or KUAL) to install Tailscale.
# Place this script and the binaries (tailscaled, tailscale) in the same directory.

set -e

# Configuration
EXT_DIR="/mnt/us/extensions/tailscale"
BIN_DIR="$EXT_DIR/bin"
SCRIPTS_DIR="$EXT_DIR/scripts"
LOGS_DIR="$EXT_DIR/logs"
RUN_DIR="$EXT_DIR/run"
STATE_DIR="/var/local/tailscale"
STATE_FILE="$STATE_DIR/tailscaled.state"
SOCKET="/tmp/tailscaled.sock"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() { echo "${GREEN}[INSTALL]${NC} $*"; }
warn() { echo "${YELLOW}[WARN]${NC} $*"; }
err() { echo "${RED}[ERROR]${NC} $*" >&2; }

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    err "This script must be run as root"
    exit 1
fi

# Find binaries (in same directory as script, or in ./dist)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TAILSCALED_BIN=""
TAILSCALE_BIN=""

for dir in "$SCRIPT_DIR" "$SCRIPT_DIR/dist/1.28.0-armv6" "$SCRIPT_DIR/.." "/mnt/us"; do
    if [ -f "$dir/tailscaled" ] && [ -f "$dir/tailscale" ]; then
        TAILSCALED_BIN="$dir/tailscaled"
        TAILSCALE_BIN="$dir/tailscale"
        log "Found binaries in $dir"
        break
    fi
done

if [ -z "$TAILSCALED_BIN" ]; then
    err "Could not find tailscaled and tailscale binaries."
    err "Place them in the same directory as this script, or in ./dist/1.28.0-armv6/"
    exit 1
fi

# Verify binaries are ARMv6 executables
log "Verifying binaries..."
if ! file "$TAILSCALED_BIN" | grep -q "ARM.*executable"; then
    warn "tailscaled may not be ARM binary: $(file "$TAILSCALED_BIN")"
fi
if ! file "$TAILSCALE_BIN" | grep -q "ARM.*executable"; then
    warn "tailscale may not be ARM binary: $(file "$TAILSCALE_BIN")"
fi

# Stop existing daemon if running
if [ -f "$RUN_DIR/tailscaled.pid" ]; then
    pid=$(cat "$RUN_DIR/tailscaled.pid" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        log "Stopping existing tailscaled (pid $pid)..."
        "$SCRIPTS_DIR/stop.sh" 2>/dev/null || true
    fi
fi
rm -f "$SOCKET"

# Create directory structure
log "Creating directory structure..."
mkdir -p "$BIN_DIR" "$SCRIPTS_DIR" "$LOGS_DIR" "$RUN_DIR" "$STATE_DIR"
chmod 700 "$STATE_DIR"
[ -f "$STATE_FILE" ] && chmod 600 "$STATE_FILE" 2>/dev/null

# Install binaries
log "Installing binaries..."
cp -f "$TAILSCALED_BIN" "$BIN_DIR/tailscaled"
cp -f "$TAILSCALE_BIN" "$BIN_DIR/tailscale"
chmod 755 "$BIN_DIR/tailscaled" "$BIN_DIR/tailscale"

# Install scripts
log "Installing scripts..."
SCRIPTS_SOURCE="$SCRIPT_DIR/../scripts"
if [ ! -d "$SCRIPTS_SOURCE" ]; then
    SCRIPTS_SOURCE="$SCRIPT_DIR/scripts"
fi

if [ -d "$SCRIPTS_SOURCE" ]; then
    cp -f "$SCRIPTS_SOURCE"/*.sh "$SCRIPTS_DIR/" 2>/dev/null || true
    cp -f "$SCRIPTS_SOURCE"/*.py "$SCRIPTS_DIR/" 2>/dev/null || true
    chmod 755 "$SCRIPTS_DIR"/*.sh "$SCRIPTS_DIR"/*.py 2>/dev/null || true
else
    warn "Scripts directory not found at $SCRIPTS_SOURCE"
fi

# Install KUAL config
log "Installing KUAL configuration..."
KUAL_SOURCE="$SCRIPT_DIR/../kual"
if [ ! -d "$KUAL_SOURCE" ]; then
    KUAL_SOURCE="$SCRIPT_DIR/kual"
fi

if [ -d "$KUAL_SOURCE" ]; then
    cp -f "$KUAL_SOURCE/config.xml" "$EXT_DIR/config.xml"
    cp -f "$KUAL_SOURCE/menu.json" "$EXT_DIR/menu.json"
else
    warn "KUAL directory not found at $KUAL_SOURCE"
fi

# Verify installation
log "Verifying installation..."
if [ ! -x "$BIN_DIR/tailscaled" ] || [ ! -x "$BIN_DIR/tailscale" ]; then
    err "Binaries not installed correctly"
    exit 1
fi

# Test binary runs
if ! "$BIN_DIR/tailscale" --version >/dev/null 2>&1; then
    err "tailscale binary failed to run (wrong architecture?)"
    exit 1
fi

# Verify MD5 if md5sum available
if command -v md5sum >/dev/null 2>&1; then
    local_md5=$(md5sum "$TAILSCALED_BIN" | cut -d' ' -f1)
    remote_md5=$(md5sum "$BIN_DIR/tailscaled" | cut -d' ' -f1)
    if [ "$local_md5" = "$remote_md5" ]; then
        log "Checksum verified: $local_md5"
    else
        err "Checksum mismatch! Local: $local_md5, Remote: $remote_md5"
        exit 1
    fi
fi

# Show version
version=$("$BIN_DIR/tailscale" --version 2>/dev/null | head -1)
log "Installed Tailscale version: $version"

# Final instructions
echo
log "Installation complete!"
echo
echo "Next steps:"
echo "  1. Start daemon:  $SCRIPTS_DIR/start.sh"
echo "  2. Check status:  $SCRIPTS_DIR/status.sh"
echo "  3. Login:         $SCRIPTS_DIR/login.sh"
echo "  4. View logs:     $SCRIPTS_DIR/logs.sh"
echo
echo "Or use KUAL: Extensions -> Tailscale -> Start"
echo
echo "Proxy endpoints (after start):"
echo "  SOCKS5: 127.0.0.1:1055"
echo "  HTTP:   127.0.0.1:1056"
echo

# Offer to start now
printf "Start Tailscale now? [y/N] "
read -r answer
if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
    "$SCRIPTS_DIR/start.sh"
fi