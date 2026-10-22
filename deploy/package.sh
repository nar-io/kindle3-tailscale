#!/bin/sh
# Create a standalone installation package for Kindle
# Run from the project root: ./deploy/package.sh
# Output: tailscale-kindle3-armv6.tar.gz

set -e

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist/1.28.0-armv6"
SCRIPTS_DIR="$ROOT_DIR/deploy/scripts"
KUAL_DIR="$ROOT_DIR/deploy/kual"
OUT_DIR="$ROOT_DIR/dist"
PKG_NAME="tailscale-kindle3-armv6"
PKG_DIR="/tmp/$PKG_NAME"
TARBALL="$OUT_DIR/$PKG_NAME.tar.gz"

log() { echo "[PACKAGE] $*"; }

# Check prerequisites
if [ ! -f "$DIST_DIR/tailscaled" ] || [ ! -f "$DIST_DIR/tailscale" ]; then
    echo "Error: Binaries not found in $DIST_DIR"
    echo "Run build-tailscale.ps1 first"
    exit 1
fi

if [ ! -d "$SCRIPTS_DIR" ]; then
    echo "Error: Scripts not found in $SCRIPTS_DIR"
    exit 1
fi

if [ ! -d "$KUAL_DIR" ]; then
    echo "Error: KUAL config not found in $KUAL_DIR"
    exit 1
fi

# Clean and create package directory
rm -rf "$PKG_DIR"
mkdir -p "$PKG_DIR/bin" "$PKG_DIR/scripts" "$PKG_DIR/kual"

# Copy binaries
log "Copying binaries..."
cp "$DIST_DIR/tailscaled" "$PKG_DIR/bin/"
cp "$DIST_DIR/tailscale" "$PKG_DIR/bin/"

# Copy scripts
log "Copying scripts..."
cp "$SCRIPTS_DIR"/*.sh "$PKG_DIR/scripts/" 2>/dev/null || true
cp "$SCRIPTS_DIR"/*.py "$PKG_DIR/scripts/" 2>/dev/null || true

# Copy KUAL config
log "Copying KUAL config..."
cp "$KUAL_DIR/config.xml" "$PKG_DIR/kual/"
cp "$KUAL_DIR/menu.json" "$PKG_DIR/kual/"

# Copy installer
log "Copying installer..."
cp "$ROOT_DIR/deploy/installer.sh" "$PKG_DIR/"

# Create README for package
cat > "$PKG_DIR/README-INSTALL.txt" << 'EOF'
Tailscale ARMv6 for Kindle 3 Keyboard - Installation Package
=============================================================

Contents:
  bin/tailscaled    - Tailscale daemon (14.9 MB, ARMv6)
  bin/tailscale     - Tailscale CLI (8.8 MB, ARMv6)
  scripts/          - Management scripts (start.sh, stop.sh, etc.)
  kual/             - KUAL integration (config.xml, menu.json)
  installer.sh      - Run this to install

Installation:
  1. Copy this entire directory to your Kindle (e.g., /mnt/us/tailscale-pkg/)
  2. SSH into Kindle as root
  3. Run: cd /mnt/us/tailscale-pkg && sh installer.sh
  4. Follow prompts

Requirements:
  - Kindle 3 Keyboard (ARMv6, kernel 2.6.26)
  - Jailbroken with root SSH access
  - /mnt/us writable (~3 GB free)
  - /var/local writable (~23 MB free)

After installation:
  - Binaries: /mnt/us/extensions/tailscale/bin/
  - Scripts:  /mnt/us/extensions/tailscale/scripts/
  - KUAL:     /mnt/us/extensions/tailscale/config.xml + menu.json
  - State:    /var/local/tailscale/tailscaled.state (protected, 0600)

Proxy endpoints (after start):
  - SOCKS5: 127.0.0.1:1055
  - HTTP:   127.0.0.1:1056

Verification:
  - Run: /mnt/us/extensions/tailscale/scripts/status.sh
  - Check KUAL: Extensions -> Tailscale -> Status
EOF

# Create tarball
log "Creating tarball..."
cd /tmp
tar -czf "$TARBALL" "$PKG_NAME"

# Show info
size=$(du -h "$TARBALL" | cut -f1)
log "Package created: $TARBALL ($size)"
log ""
log "To install on Kindle:"
log "  1. scp $TARBALL root@<kindle_ip>:/mnt/us/"
log "  2. ssh root@<kindle_ip> 'cd /mnt/us && tar -xzf $PKG_NAME.tar.gz && cd $PKG_NAME && sh installer.sh'"
log ""
log "Or copy via USB to /mnt/us/ and extract there."