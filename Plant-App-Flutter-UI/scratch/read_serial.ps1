$port = New-Object System.IO.Ports.SerialPort 'COM3', 115200, 'None', 8, 'One'
$port.DtrEnable = $false
$port.RtsEnable = $false
$port.ReadTimeout = 3000

try {
    $port.Open()
    Write-Output "Opened COM3 successfully."
    $start = Get-Date
    while ((Get-Date) - $start -lt [TimeSpan]::FromSeconds(6)) {
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
