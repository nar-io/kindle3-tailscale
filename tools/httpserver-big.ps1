$ErrorActionPreference = "Stop"
$ip = [System.Net.IPAddress]::Parse("<PEER_8_IP>")
$listener = New-Object System.Net.Sockets.TcpListener($ip, 18081)
$listener.Start()
$size = 16 * 1024 * 1024
$body = New-Object byte[] $size
for ($i = 0; $i -lt $size; $i++) { $body[$i] = 65 }
$header = "HTTP/1.1 200 OK`r`nContent-Type: application/octet-stream`r`nContent-Length: $size`r`nConnection: close`r`n`r`n"
$hbytes = [System.Text.Encoding]::ASCII.GetBytes($header)
$deadline = (Get-Date).AddSeconds(900)
while ((Get-Date) -lt $deadline) {
    if (-not $listener.Pending()) { Start-Sleep -Milliseconds 100; continue }
    $client = $listener.AcceptTcpClient()
    try {
        $stream = $client.GetStream()
        $buf = New-Object byte[] 2048
        $null = $stream.Read($buf, 0, $buf.Length)
        $stream.Write($hbytes, 0, $hbytes.Length)
        $stream.Write($body, 0, $body.Length)
        $stream.Flush()
    } catch {
    } finally {
        $client.Close()
    }
}
$listener.Stop()

