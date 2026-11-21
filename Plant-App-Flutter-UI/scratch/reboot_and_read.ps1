$port = New-Object System.IO.Ports.SerialPort 'COM3', 115200, 'None', 8, 'One'
$port.ReadTimeout = 3000

try {
    $port.Open()
    Write-Output "Resetting ESP32 via DTR/RTS pulse..."
    $port.DtrEnable = $false
    $port.RtsEnable = $true
    Start-Sleep -Milliseconds 150
    $port.DtrEnable = $false
    $port.RtsEnable = $false
    
    $start = Get-Date
    while ((Get-Date) - $start -lt [TimeSpan]::FromSeconds(8)) {
        try {
            $line = $port.ReadLine()
            Write-Output $line
        } catch [TimeoutException] {
            # timeout
        }
    }
} catch {
    Write-Output "Error: $($_.Exception.Message)"
} finally {
    if ($port.IsOpen) { $port.Close() }
}
