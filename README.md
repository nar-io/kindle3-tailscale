# Tailscale on the Kindle 3 Keyboard (ARMv6)

A native ARMv6 build of the official Tailscale client, running directly on a
jailbroken Kindle 3 Keyboard (kernel 2.6.26) with no emulation, container, or
remote networking proxy.

**Status: working, but in userspace/proxy mode only.** The daemon joins the
tailnet, establishes real WireGuard paths to peers, and exposes SOCKS5 and HTTP
proxies on loopback. It does **not** provide transparent VPN routing: this
kernel has no TUN driver, so ordinary Kindle applications do not automatically
send traffic through the tailnet.

| Item | Value |
| --- | --- |
| Node name | `<NODE_NAME>` |
| Tailscale IP | `<TAILSCALE_IP>` |
| Tailscale version | v1.28.0 (unmodified upstream source) |
| Toolchain | Go 1.18.10, `GOOS=linux GOARCH=arm GOARM=6 CGO_ENABLED=0` |
| Backend | `--tun=userspace-networking` |
| Proxies | SOCKS5 `127.0.0.1:1055`, HTTP `127.0.0.1:1056` |
| Control socket | `/tmp/tailscaled.sock` (tmpfs) |
| Node state | `/var/local/tailscale/tailscaled.state` (mode 0600) |
| Install path | `/mnt/us/extensions/tailscale/` |

---

## 1. The device

Facts collected read-only in Phase 1 (full log: `diag/kindle_diag_raw.txt`):

| Property | Value |
| --- | --- |
| Model | Kindle 3 Keyboard (K3), serial prefix B008/B00A era |
| Kernel | `2.6.26-rt-lab126 #5 Sat Sep 1 14:28:26 PDT 2012` |
| Architecture | `armv6l`, ARMv6 + VFP, **no NEON** |
| CPU | 512 MHz single core (BogoMIPS 511.18) |
| RAM | 256 MB |
| libc | glibc 2.5 |
| Python | 2.7.18 (stock) |
| OpenSSL CLI | 0.9.8j; Python's `ssl` links OpenSSL 1.1.1l |
| IPv6 | **not present** (`CONFIG_IPV6 is not set`) |
| TUN | **not present** (`# CONFIG_TUN is not set`, no `tun.ko`) |
| `/mnt/us` | FUSE (`fuse.fsp`), vfat semantics, `exec` works |
| `/var/local` | ext3, 23 MB, persistent, POSIX permissions |
| `/tmp` | tmpfs, writable |
| Compiler | none on device |

This is a 2010-era e-reader: one slow core, 256 MB RAM, a vendor-patched
real-time kernel, and no package manager.

---

## Prerequisites

### Host (Build Machine)
- **OS:** Windows (PowerShell 5.1+), Linux, or macOS
- **Go toolchain:** Go 1.18.10 for `linux/arm` (ARMv6, `GOARM=6`)
  - Provided in `toolchains/go1.18.10/` or download from https://go.dev/dl/
- **Git:** For cloning Tailscale source
- **Network:** Internet access to download Go modules (`GOPROXY`)

### Target Device (Kindle 3 Keyboard)
- **Model:** Kindle 3 Keyboard (K3), serial prefix B008/B00A
- **Jailbreak:** Root shell access via SSH (tested with `usbnetwork` hack)
- **Kernel:** `2.6.26-rt-lab126` (stock)
- **Architecture:** `armv6l` (ARMv6 + VFP, no NEON)
- **Storage:** `/mnt/us` (vfat via FUSE, ~3 GB free) + `/var/local` (ext3, ~23 MB)
- **Network:** Wi-Fi connected, SSH accessible from build machine
- **Tools on device:** `busybox`, `ntpdate` (for clock sync), `python 2.7.18`

### Tailscale Account
- A Tailscale account (personal or organization)
- Access to admin console to approve the device
- No auth keys embedded — interactive login via URL

### Optional
- **KUAL:** For on-device menu integration (KUAL v2, `KUAL-KDK-1.0.azw2`)
- **eips:** For screen output in KUAL actions (`/usr/sbin/eips`)

---

## 2. Why userspace networking (Approach A vs Approach B)

### Approach A: kernel TUN â€” impossible without rebuilding the kernel

```
$ zcat /proc/config.gz | grep TUN
# CONFIG_TUN is not set

$ ls -l /dev/net/tun
crw-rw---- 1 root root 10, 200 /dev/net/tun

$ dd if=/dev/net/tun of=/dev/null
dd: /dev/net/tun: No such device        # errno 19

$ find /lib/modules/2.6.26-rt-lab126 -name 'tun*'
(nothing)
```

The character device node exists, but the driver is not compiled in and no
module ships with the device. Enabling it would require building and flashing a
new kernel. The project constraints explicitly rule that out (no kernel, libc,
or core-utility replacement), so Approach A was rejected on evidence, not
convenience.

### Approach B: `--tun=userspace-networking` â€” works, but is proxy-based

Tailscale's userspace backend implements the WireGuard and network stack in Go
and does not need a TUN device. It exposes:

- a SOCKS5 proxy (`--socks5-server`),
- an HTTP CONNECT proxy (`--outbound-http-proxy-listen`),
- optional DNS forwarding.

This is a genuine Tailscale/WireGuard data path: packets are encrypted and sent
to peers directly (or via DERP), and peer traffic was verified end to end. It is
**not** a transparent VPN. Applications must be told to use the proxy; there is
no default route capture and no per-application redirection.

**This is the honest limitation of the deployment.** On this hardware/kernel,
transparent tailnet routing would require a kernel rebuild, which was out of
scope.

---

## 3. Why Tailscale v1.28.0 with Go 1.18.10

The official release binary is ISA-compatible (`GOARM=5`) but not kernel
compatible. As of October 2026 the current release is v1.104.2, built with Go
1.27.3. Recent Go runtimes require kernel â‰¥ 3.2.

Runtime probes were cross-compiled for ARMv6 and executed on the device:

| Go | Result on kernel 2.6.26 |
| --- | --- |
| 1.17.13 | **Works** â€” goroutines, files, TCP, DNS, TLS all pass |
| 1.18.10 | **Works** â€” full probe pass, TLS 1.3 handshake OK (`diag/probe_go1.18.10.txt`) |
| 1.19.13 | Fails at startup: `runtime: pipe failed with 38` (`pipe2` = ENOSYS) |
| 1.21.13 | Fails: `runtime: epollcreate failed with 38` (`epoll_create1` = ENOSYS) |
| 1.23.12 | Fails: `runtime: epollcreate failed with 38` |
| 1.24+ | Officially requires Linux â‰¥ 3.2 |

The decisive failures are missing syscalls, not CPU instructions. A newer
binary cannot be patched around that at runtime.

Release requirements, from the upstream `go.mod` files:

- v1.28.0 (March 2023) â€” `go 1.18`
- v1.30.2 â€” `go 1.19` (would need `pipe2`, which this kernel lacks)

Therefore **v1.28.0 is the newest unmodified upstream release that can run
here**. Building a newer release with Go 1.18 is not supported by upstream and
was not attempted.

Built artifacts (SHA-256):

```
F7278A44CB3DA09463D544E1221D676DEE10C41EAFEC9F8BCB2BE334CE3A5FD6  tailscaled  (14,942,208 bytes)
873E99236335D932040965FB35A64A314BD21E289CB11F18218C992C72CB6663  tailscale   ( 8,847,360 bytes)
```

### Build

Source: official `tailscale/tailscale` v1.28.0 tag, unmodified, in
`src/tailscale-1.28.0`.

```powershell
# build-tailscale.ps1, abbreviated
$env:GOROOT      = "toolchains\go1.18.10"
$env:GOOS        = "linux"
$env:GOARCH      = "arm"
$env:GOARM       = "6"
$env:CGO_ENABLED = "0"
$env:GOFLAGS     = "-mod=mod"

go build -trimpath -tags "osusergo,netgo" `
  -ldflags "-s -w -X tailscale.com/version.Long=1.28.0-t<PEER_8> -X tailscale.com/version.Short=1.28.0" `
  -o dist\1.28.0-armv6\tailscaled .\cmd\tailscaled

go build -trimpath -tags "osusergo,netgo" `
  -ldflags "-s -w -X tailscale.com/version.Long=1.28.0-t<PEER_8> -X tailscale.com/version.Short=1.28.0" `
  -o dist\1.28.0-armv6\tailscale .\cmd\tailscale
```

`osusergo` avoids glibc NSS dependencies; `netgo` avoids cgo resolver issues on
glibc 2.5. `GOARM=6` matches the CPU (the official build is `GOARM=5`; both are
ISA-compatible here).

---

## 4. Installed layout

```
/mnt/us/extensions/tailscale/
â”œâ”€â”€ bin/
â”‚   â”œâ”€â”€ tailscaled              # 14.9 MB, ARMv6
â”‚   â””â”€â”€ tailscale               #  8.8 MB, ARMv6
â”œâ”€â”€ scripts/
â”‚   â”œâ”€â”€ start.sh  stop.sh  status.sh
â”‚   â”œâ”€â”€ login.sh  logs.sh  stats.sh
â”‚   â”œâ”€â”€ kual-start.sh  kual-stop.sh  kual-status.sh
â”‚   â”œâ”€â”€ kual-login.sh  kual-logs.sh
â”‚   â”œâ”€â”€ socks-test.py  test-http.sh  test-restart.sh
â”‚   â”œâ”€â”€ loadtest.sh  probe-ports.sh
â”‚   â”œâ”€â”€ migrate-state.sh        # one-time, already applied
â”‚   â”œâ”€â”€ rollback.sh
â”‚   â””â”€â”€ uninstall.sh
â”œâ”€â”€ logs/
â”‚   â”œâ”€â”€ tailscaled.log
â”‚   â””â”€â”€ auth.log
â”œâ”€â”€ run/tailscaled.pid
â”œâ”€â”€ config.xml                  # KUAL
â””â”€â”€ menu.json                   # KUAL

/var/local/tailscale/           # ext3, mode 0700
â””â”€â”€ tailscaled.state            # mode 0600, node key
```

Two location choices are deliberate:

1. **Control socket on tmpfs.** `/mnt/us` is FUSE; `bind(2)` on a Unix socket
   there fails with `EPERM`. `/tmp/tailscaled.sock` is used instead.
2. **State on ext3.** vfat cannot enforce `0600`, and the state file contains
   the node private key. Moving it to `/var/local/tailscale` was the only way
   to protect it without modifying system components. The old world-readable
   copy under `/mnt/us` was removed.

---

## 5. Install / deploy

### Option A: Standalone installer (recommended, runs on Kindle)

1. **Download the package** from [Releases](https://github.com/nar-io/kindle3-tailscale/releases) or build it:
   ```sh
   # On build machine (Linux/macOS/WSL):
   cd deploy && ./package.sh
   # Creates: dist/tailscale-kindle3-armv6.tar.gz
   ```

2. **Transfer to Kindle** (via USB to `/mnt/us/` or SSH):
   ```sh
   # Via SSH:
   scp dist/tailscale-kindle3-armv6.tar.gz root@<KINDLE_IP>:/mnt/us/
   ```

3. **Install on Kindle** (SSH as root):
   ```sh
   cd /mnt/us
   tar -xzf tailscale-kindle3-armv6.tar.gz
   cd tailscale-kindle3-armv6
   sh installer.sh
   ```

4. **Follow prompts** - the installer will:
   - Create directory structure
   - Install binaries and scripts
   - Configure KUAL integration
   - Verify checksums
   - Optionally start the daemon

### Option B: Manual installation

Copy these to the Kindle manually:
- `bin/tailscaled` and `bin/tailscale` → `/mnt/us/extensions/tailscale/bin/`
- `scripts/*.sh`, `scripts/*.py` → `/mnt/us/extensions/tailscale/scripts/`
- `kual/config.xml`, `kual/menu.json` → `/mnt/us/extensions/tailscale/`

Then run `/mnt/us/extensions/tailscale/scripts/start.sh`.

### Building the package yourself

```sh
# On Linux/macOS/WSL (requires Go 1.18.10 for linux/arm):
cd deploy
./package.sh
# Output: ../dist/tailscale-kindle3-armv6.tar.gz (~24 MB)
```

The package includes:
- Pre-built ARMv6 binaries (tailscaled, tailscale)
- All management scripts
- KUAL configuration
- Self-contained installer.sh (runs on Kindle, no PowerShell needed)

---

## 6. Usage

All commands are run on the <PEER_8> over SSH (or from KUAL).

> **No autostart.** Nothing was added to `/etc/init.d`, `rcS`, or any Amazon
> startup file. After a reboot the daemon is down until `start.sh` is run (or
> **Start** is chosen in KUAL). This is intentional: the device stays in its
> stock state unless Tailscale is explicitly started.

```sh
D=/mnt/us/extensions/tailscale

$D/scripts/start.sh      # sync clock, start daemon, wait for socket
$D/scripts/status.sh     # version, pid, RSS, tailnet status, IP, listeners
$D/scripts/stop.sh       # clean shutdown
$D/scripts/login.sh      # interactive login; prints URL to logs/auth.log
$D/scripts/logs.sh       # last 80 daemon lines + auth log
$D/scripts/stats.sh 60   # CPU/RSS sampling over 60 s
```

`start.sh` performs `ntpdate -u time.google.com` before launching the daemon.
This is required: the <PEER_8> clock was ~823 days slow, which makes the
control-plane certificate appear "not yet valid". NTP only sets the system
clock; it does not touch Tailscale credentials.

### Using the tailnet from the <PEER_8>

HTTP/HTTPS through the HTTP proxy:

```sh
export http_proxy=http://127.0.0.1:1056
export https_proxy=http://127.0.0.1:1056
curl http://peer-a:18080/
```

SOCKS5 (including remote DNS, so MagicDNS names work):

```sh
curl --socks5-hostname 127.0.0.1:1055 http://peer-a:18080/
python /mnt/us/extensions/tailscale/scripts/socks-test.py \
    127.0.0.1 1055 peer-b 22
```

The proxy is loopback-only. Any process on the <PEER_8> can use it, which is the
intended behavior; there is no proxy authentication.

### KUAL

The extension appears as **Tailscale** in KUAL with:

- **Start** / **Stop** â€” run the daemon, report on the bottom screen line.
- **Status** â€” two lines: state + IP, peers online + proxy port. Full output is
  saved to `logs/kual-status.txt`.
- **Login / Show URL** â€” starts the interactive flow and prints the login URL
  on screen.
- **View Log** â€” last 30 lines full-screen for 20 seconds.

The menu uses the same `config.xml` + `menu.json` schema as the other
extensions on this device (KUAL v2, `KUAL-KDK-1.0.azw2`). Screen output uses
`/usr/sbin/eips` at 50 columns Ã— 40 lines (600Ã—800, 12Ã—20 glyphs). Rendering was
verified by dumping `/dev/fb0` and converting it (`tools/fb2png.ps1`,
`diag/fb-status.png`).

Note: drawing with `eips` does not perform a full e-ink refresh. Text can look
faint until the next UI refresh; pressing Home or opening KUAL clears it.

---

## 7. Authentication and state

No auth key is embedded or stored. `login.sh` runs:

```sh
tailscale --socket=/tmp/tailscaled.sock up \
  --accept-dns=false \
  --accept-routes=false \
  --host-routes=true \
  --netfilter-mode=off \
  --hostname=<NODE_NAME>
```

and prints an interactive `https://login.tailscale.com/a/...` URL. The user
approves the device in a browser. Subsequent restarts reuse the node key and do
not require re-authentication.

Flag rationale:

- `--accept-dns=false` â€” the <PEER_8>'s resolver is left untouched (MagicDNS
  names still resolve through the SOCKS5 proxy's remote DNS).
- `--accept-routes=false` â€” no subnet routes; there is no TUN to install them.
- `--host-routes=true` â€” **required** in userspace mode. Setting it to false
  strips peer IPs from the WireGuard config and breaks SOCKS5.
- `--netfilter-mode=off` â€” there is no TUN and no NAT to manage; avoids
  touching iptables.
- `--port=0` (start.sh) â€” random source port for NAT traversal.

State is a single file, `tailscaled.state`, mode `0600`, directory `0700`, on
ext3. Losing it means re-authentication; it is not backed up anywhere else.
Treat it like a private key.

---

## 8. Measurements

All numbers from the actual device, October 2026.

### Idle

| Metric | Value |
| --- | --- |
| CPU (120 s sample) | 0.125 % (15 ticks / 120 s, `--verbose=0`) |
| RSS after restart | 15.6 MB |
| RSS after a 16 MB transfer | 27â€“29 MB (buffers, then drops back) |
| Threads | 6â€“8 |
| VmSize | ~810 MB virtual (Go reserves address space; not resident) |
| `--verbose=1` | 2.77 % idle CPU â€” do not use in production |

Context-switch counters (`voluntary` 328, `nonvoluntary` 1512) did not advance
during a 60 s idle sample. On this vendor RT kernel these counters appear not
to update reliably; the CPU tick measurement is the trustworthy figure.

### Throughput over the HTTP proxy

16 MiB (16,777,216 bytes) from a tailnet peer, twice:

| Run | Time | Rate | tailscaled CPU |
| --- | --- | --- | --- |
| 1 | 23.750 s | 0.71 MB/s (5.7 Mbit/s) | 72.5 % of one core |
| 2 | 24.663 s | 0.68 MB/s (5.4 Mbit/s) | 67.7 % of one core |

The 512 MHz ARMv6 core is the bottleneck: WireGuard encryption and the Go
network stack consume most of it at ~5 Mbit/s. This is expected, not a
misconfiguration.

### Connectivity checks

```
pong from peer-a (<PEER_A_IP>) via <EXAMPLE_IP_3>:41641 in 54ms
pong from peer-b (<PEER_B_IP>) via <EXAMPLE_IP_1>:41641 in 212ms

netcheck (one run):
  UDP: true
  IPv4: <EXAMPLE_IP_2>:59491 (UPnP port mapping; port varies per session)
  Nearest DERP: Frankfurt, 65 ms (Paris/Warsaw ~67 ms)
  IPv6: false
```

Verified application traffic:

- SOCKS5 to `<PEER_B_IP>:22`, `<PEER_A_IP>:445`
- SOCKS5 with MagicDNS: `peer-a:445`, `peer-b:22`
- HTTP proxy to `http://<PEER_A_IP>:18080/` â†’ `200 OK`, body `<PEER_8>TailOK`
- HTTP proxy with MagicDNS: `http://peer-a:18080/` â†’ `200 OK`

Inbound path: a Python listener on the <PEER_8> (`0.0.0.0:18099`) accepted a
connection to `<TAILSCALE_IP>:18099`, sent `HELLO-FROM-KINDLE`, and logged the
peer as `127.0.0.1` â€” the netstack forwards inbound TCP to loopback. The
<PEER_8>'s SSH server likewise answered on `<TAILSCALE_IP>:22`.

A daemon that is merely running is not a connected node. These checks confirm
the data path, not just process liveness.

---

## 9. Security notes and limitations

**Old software.** Tailscale v1.28.0 (March 2023) and Go 1.18.10 are end-of-life
and contain publicly known vulnerabilities fixed in later releases. No newer
unmodified release runs on kernel 2.6.26. Mitigations in this deployment:

- the daemon is not exposed to the internet;
- proxies bind to `127.0.0.1` only;
- the control socket is a Unix socket that `start.sh` restricts to mode 0600
  (upstream creates it 0666 and uses peer credentials for read-only access);
- no auth keys or passwords are stored;
- TLS verification is never disabled;
- no kernel, libc, or system binary was replaced.

If the threat model does not tolerate an EOL client, the correct fix is a
kernel with TUN support (or newer hardware), not a patch to this build.

**Proxy, not VPN.** Only applications explicitly configured to use
`127.0.0.1:1055` or `127.0.0.1:1056` use the tailnet. The <PEER_8>'s browser and
system services do not.

**Inbound TCP works.** The userspace netstack accepts inbound tailnet
connections and forwards them to `127.0.0.1` on the <PEER_8>. A test listener on
port 18099 accepted a connection from `peer-a` and its server-side peer
address was `127.0.0.1`, confirming the forward. The stock SSH server also
answered on `<TAILSCALE_IP>:22` (it rejected the key offered, but the TCP
connection and banner prove reachability). Consequence: any service listening
on loopback or all interfaces can be reached from the tailnet, subject to
tailnet ACLs. Keep the ACL restrictive and do not run unneeded services.

**No subnet routes or exit node.** `--accept-routes=false` and no TUN.

**No IPv6.** The kernel has no IPv6 support.

**CPU cost.** Bulk transfers use most of the single core. Background syncing of
large files will make the device sluggish.

**Clock dependency.** A badly wrong clock breaks TLS. `start.sh` fixes it with
NTP; if the network blocks NTP, set the clock manually before starting.

---

## 10. Rollback and uninstall

Both scripts are on the device under `scripts/`.

**Rollback (safe, keeps files and identity):**

```sh
/mnt/us/extensions/tailscale/scripts/rollback.sh
```

Stops the daemon, removes `/tmp/tailscaled.sock` and stale pid files, verifies
no `tailscaled` process remains, and leaves binaries, logs, KUAL entry, and
node state in place. Add `--purge-state` to also delete the node identity
(requires confirmation).

**Uninstall (destructive):**

```sh
/mnt/us/extensions/tailscale/scripts/uninstall.sh --logout
```

Removes the extension directory, KUAL entry, runtime socket, and
`/var/local/tailscale`. `--logout` asks the control plane to remove the node
first; without it, remove the node manually in the admin console.
`--keep-state` preserves the node identity for a future reinstall. The script
requires `--yes` when stdin is not a terminal.

Neither script touches the kernel, libc, `/etc`, or Amazon system files. The
uninstaller re-execs itself from `/tmp` before deleting its own directory.

---

## 11. Troubleshooting

| Symptom | Cause / fix |
| --- | --- |
| `bind: operation not permitted` on socket | Socket placed on `/mnt/us` (FUSE). Use `/tmp`. |
| `x509: certificate ... not yet valid` | Clock is wrong. Run `ntpdate -u time.google.com`. |
| SOCKS5 connects but no data | `--host-routes=false` was used. Set it to `true`. |
| `runtime: epollcreate failed with 38` | Binary built with Go â‰¥ 1.21. Rebuild with 1.18.10. |
| `runtime: pipe failed with 38` | Binary built with Go 1.19. Rebuild with 1.18.10. |
| `Text file busy` when copying binaries | Daemon is running. Stop it, or install via `mv` (deploy.ps1 does). |
| KUAL action does nothing | Check `logs/kual.log`; scripts set `PATH` explicitly. |
| State file readable by others | It is on vfat. Move to `/var/local` (`migrate-state.sh`). |
| High idle CPU | `--verbose=1` was used. Restart with `--verbose=0`. |

Logs: `/mnt/us/extensions/tailscale/logs/tailscaled.log` and `auth.log`.

---

## 12. Evidence in this repository

| Path | Contents |
| --- | --- |
| `diag/kindle_diag_raw.txt` | Full Phase 1 read-only diagnostics |
| `diag/probe_results.txt` | Go 1.17/1.19/1.21/1.23 runtime probes |
| `diag/probe_go1.18.10.txt` | Go 1.18.10 full probe, including TLS 1.3 |
| `diag/fb-status.png` | Cropped framebuffer capture of KUAL status output |
| `build-tailscale.ps1` | Reproducible cross-build |
| `build-probes.ps1` | Runtime compatibility probes |
| `deploy/installer.sh` | Standalone installer (runs on Kindle) |
| `deploy/package.sh` | Creates distributable tarball |
| `deploy/scripts/` | Runtime scripts, KUAL actions, uninstall/rollback |
| `deploy/kual/` | KUAL `config.xml` and `menu.json` |
| `tools/fb2png.ps1` | <PEER_8> 4bpp framebuffer to PNG |
| `tools/httpserver*.ps1` | Test servers used for connectivity/throughput checks |

---

## 13. License

Tailscale is BSD-3-Clause. The binaries here are unmodified upstream builds;
the scripts and documentation in this repository are provided as-is, without
warranty. Installing this on a jailbroken device is your responsibility.


