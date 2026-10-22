$ErrorActionPreference = "Stop"
$root = "C:\Users\user\Downloads\tail"
$probe = Join-Path $root "probe"
$build = Join-Path $root "build"
New-Item -ItemType Directory -Force -Path $build | Out-Null

$versions = @("1.17.13", "1.19.13", "1.21.13", "1.23.12")
foreach ($v in $versions) {
    $goroot = Join-Path $root "toolchains\go$v"
    $env:GOROOT = $goroot
    $env:GOOS = "linux"
    $env:GOARCH = "arm"
    $env:GOARM = "6"
    $env:CGO_ENABLED = "0"
    $env:GOCACHE = Join-Path $root "build\gocache-$v"
    $env:GOMODCACHE = Join-Path $root "build\gomodcache-$v"
    $out = Join-Path $build "probe-go$v"
    Push-Location $probe
    & (Join-Path $goroot "bin\go.exe") build -trimpath -ldflags "-s -w" -o $out .
    $code = $LASTEXITCODE
    Pop-Location
    if ($code -ne 0) { throw "build failed for go$v" }
    $size = (Get-Item $out).Length
    Write-Host "built $out ($size bytes)"
}
