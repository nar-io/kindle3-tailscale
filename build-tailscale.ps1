param(
    [string]$Version = "1.28.0",
    [string]$GoVersion = "1.18.10",
    [string]$GOARM = "6"
)
$ErrorActionPreference = "Stop"
$root = "<PROJECT_ROOT>"
$src = Join-Path $root "src\tailscale-$Version"
$goroot = Join-Path $root "toolchains\go$GoVersion"
$outdir = Join-Path $root "dist\$Version-armv$GOARM"
New-Item -ItemType Directory -Force -Path $outdir | Out-Null

$env:GOROOT = $goroot
$env:GOOS = "linux"
$env:GOARCH = "arm"
$env:GOARM = $GOARM
$env:CGO_ENABLED = "0"
$env:GOCACHE = Join-Path $root "build\gocache-ts$Version-$GoVersion-$GOARM"
$env:GOMODCACHE = Join-Path $root "build\gomodcache-ts$Version-$GoVersion-$GOARM"
$env:GOFLAGS = "-mod=mod"
$env:GOPROXY = "https://proxy.golang.org,direct"

Push-Location $src
try {
    foreach ($cmd in @("tailscaled", "tailscale")) {
        $out = Join-Path $outdir $cmd
        Write-Host "building $cmd ..."
        & (Join-Path $goroot "bin\go.exe") build `
            -trimpath `
            -tags "osusergo,netgo" `
            -ldflags "-s -w -X tailscale.com/version.Long=$Version-t<PEER_8> -X tailscale.com/version.Short=$Version" `
            -o $out `
            "./cmd/$cmd"
        if ($LASTEXITCODE -ne 0) { throw "build failed: $cmd" }
        Write-Host ("  {0} ({1:N0} bytes)" -f $out, (Get-Item $out).Length)
    }
} finally {
    Pop-Location
}


