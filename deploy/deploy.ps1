# Deploy the built ARMv6 Tailscale binaries and scripts to a <PEER_8> over SSH.
#
# The <PEER_8> has no sftp-server, so OpenSSH scp/sftp cannot be used. Text files
# are streamed through ssh stdin; binaries are streamed with cmd.exe "type"
# (byte-exact, verified with MD5 below).
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File deploy\deploy.ps1
#   powershell -ExecutionPolicy Bypass -File deploy\deploy.ps1 -Restart
#
# -Restart stops a running daemon, installs, then starts it again.

param(
    [string]$<PEER_8> = "<KINDLE_IP>",
    [string]$User = "root",
    [string]$Dist = "dist\1.28.0-armv6",
    [switch]$Restart
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
if (-not $root) { $root = (Get-Location).Path }
$target = "$User@$<PEER_8>"
$sshOpts = @("-o", "BatchMode=yes", "-o", "ConnectTimeout=10")
$remote = "/mnt/us/extensions/tailscale"

function Invoke-Remote([string]$Command) {
    & ssh @sshOpts $target $Command
    if ($LASTEXITCODE -ne 0) { throw "remote command failed: $Command" }
}

function Send-Text([string]$Local, [string]$Remote) {
    $text = [IO.File]::ReadAllText($Local) -replace "`r`n", "`n"
    # PowerShell appends CRLF to native-pipeline input; strip CRs on the device
    # so shell scripts never end with a stray "\r" command.
    $text | & ssh @sshOpts $target "cat > '$Remote.new' && tr -d '\r' < '$Remote.new' > '$Remote' && rm -f '$Remote.new'"
    if ($LASTEXITCODE -ne 0) { throw "send failed: $Local" }
}

function Send-Binary([string]$Local, [string]$Remote) {
    $line = 'type "{0}" | ssh -o BatchMode=yes -o ConnectTimeout=10 {1} "cat > ''{2}.new''"' -f $Local, $target, $Remote
    & cmd.exe /c $line
    if ($LASTEXITCODE -ne 0) { throw "send failed: $Local" }
    Invoke-Remote "mv -f '$Remote.new' '$Remote'"
}

$daemon = Join-Path $root "$Dist\tailscaled"
$cli = Join-Path $root "$Dist\tailscale"
foreach ($f in @($daemon, $cli)) {
    if (-not (Test-Path -LiteralPath $f)) { throw "missing build output: $f" }
}

Write-Host "target: $target"
Invoke-Remote "mkdir -p '$remote/bin' '$remote/scripts' '$remote/logs' '$remote/run'"

if ($Restart) {
    Write-Host "stopping daemon (if running)..."
    Invoke-Remote "if [ -x '$remote/scripts/stop.sh' ]; then '$remote/scripts/stop.sh'; fi"
}

Write-Host "installing binaries..."
Send-Binary $daemon "$remote/bin/tailscaled"
Send-Binary $cli "$remote/bin/tailscale"
Invoke-Remote "chmod 755 '$remote/bin/tailscaled' '$remote/bin/tailscale'"

Write-Host "installing scripts..."
Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot "scripts") -File |
    Where-Object { $_.Extension -in @(".sh", ".py") } |
    ForEach-Object {
        Send-Text $_.FullName "$remote/scripts/$($_.Name)"
    }
Invoke-Remote "chmod 755 '$remote/scripts/'*.sh '$remote/scripts/'*.py 2>/dev/null"

Write-Host "installing KUAL entry..."
Send-Text (Join-Path $PSScriptRoot "kual\config.xml") "$remote/config.xml"
Send-Text (Join-Path $PSScriptRoot "kual\menu.json") "$remote/menu.json"

Write-Host "verifying binary checksums..."
$localMd5 = (Get-FileHash -LiteralPath $daemon -Algorithm MD5).Hash.ToLower()
$remoteMd5 = (& ssh @sshOpts $target "md5sum '$remote/bin/tailscaled' | cut -d' ' -f1").Trim()
if ($LASTEXITCODE -ne 0 -or $localMd5 -ne $remoteMd5) {
    throw "tailscaled checksum mismatch (local $localMd5, remote $remoteMd5)"
}
Write-Host "  tailscaled md5 $localMd5 OK"

Write-Host "version on device:"
Invoke-Remote "'$remote/bin/tailscale' --version"

if ($Restart) {
    Write-Host "starting daemon..."
    Invoke-Remote "'$remote/scripts/start.sh'"
}

Write-Host ""
Write-Host "Deployed. Next:"
Write-Host "  ssh $target '$remote/scripts/status.sh'"
Write-Host "  ssh $target '$remote/scripts/login.sh'   # only if not authenticated"

