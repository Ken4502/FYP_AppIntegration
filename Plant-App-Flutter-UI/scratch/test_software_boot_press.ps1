$port = New-Object System.IO.Ports.SerialPort 'COM3', 115200, 'None', 8, 'One'
$port.ReadTimeout = 1000

try {
    $port.Open()
    Write-Output "Opened COM3. Letting ESP32 stabilize for 3 seconds..."
    $port.DtrEnable = $false
    $port.RtsEnable = $false
    Start-Sleep -Seconds 3

    Write-Output "Pulling BOOT (GPIO0) LOW via RTS=true, DTR=false for 6 seconds..."
    $port.DtrEnable = $false
    $port.RtsEnable = $true

    $start = Get-Date
    while ((Get-Date) - $start -lt [TimeSpan]::FromSeconds(8)) {
        try {
            $line = $port.ReadLine()
            Write-Output $line
        } catch [TimeoutException] {}
    }

    $port.RtsEnable = $false
    Write-Output "Released RTS. Monitoring serial for 5 seconds..."
    $start2 = Get-Date
    while ((Get-Date) - $start2 -lt [TimeSpan]::FromSeconds(5)) {
        try {
            $line = $port.ReadLine()
            Write-Output $line
        } catch [TimeoutException] {}
    }
} catch {
    Write-Output "Error: $($_.Exception.Message)"
} finally {
    if ($port.IsOpen) { $port.Close() }
}
