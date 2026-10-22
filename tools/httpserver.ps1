$ErrorActionPreference = "Stop"
$ip = [System.Net.IPAddress]::Parse("<PEER_8_IP>")
$listener = New-Object System.Net.Sockets.TcpListener($ip, 18080)
$listener.Start()
$deadline = (Get-Date).AddSeconds(180)
while ((Get-Date) -lt $deadline) {
    if (-not $listener.Pending()) { Start-Sleep -Milliseconds 200; continue }
    $client = $listener.AcceptTcpClient()
    try {
        $stream = $client.GetStream()
        $buf = New-Object byte[] 2048
        $null = $stream.Read($buf, 0, $buf.Length)
        $body = "<PEER_8>TailOK"
        $resp = "HTTP/1.1 200 OK`r`nContent-Type: text/plain`r`nContent-Length: $($body.Length)`r`nConnection: close`r`n`r`n$body"
        $bytes = [System.Text.Encoding]::ASCII.GetBytes($resp)
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush()
    } catch {
    } finally {
        $client.Close()
    }
}
$listener.Stop()

