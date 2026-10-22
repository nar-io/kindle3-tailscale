# Convert a <PEER_8> 3 framebuffer dump (/dev/fb0, 600x800, 4bpp packed) to PNG.
# Usage: powershell -File tools\fb2png.ps1 -Raw diag\fb.raw -Out diag\fb.png
param(
    [string]$Raw = "diag\fb.raw",
    [string]$Out = "diag\fb.png",
    [int]$Width = 600,
    [int]$Height = 800
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$bytes = [IO.File]::ReadAllBytes((Resolve-Path $Raw))
$stride = [int]($Width / 2)
if ($bytes.Length -lt ($stride * $Height)) {
    throw "raw file too small: $($bytes.Length) bytes"
}
$bmp = New-Object System.Drawing.Bitmap($Width, $Height)
for ($y = 0; $y -lt $Height; $y++) {
    $row = $y * $stride
    for ($x = 0; $x -lt $Width; $x++) {
        $b = $bytes[$row + [int]($x / 2)]
        if (($x % 2) -eq 0) { $v = ($b -shr 4) -band 0x0f } else { $v = $b -band 0x0f }
        $g = $v * 17
        $bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($g, $g, $g))
    }
}
$bmp.Save((Join-Path (Get-Location) $Out), [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Host "wrote $Out"

