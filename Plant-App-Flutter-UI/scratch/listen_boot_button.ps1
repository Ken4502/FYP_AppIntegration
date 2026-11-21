$port = New-Object System.IO.Ports.SerialPort 'COM3', 115200, 'None', 8, 'One'
$port.DtrEnable = $false
$port.RtsEnable = $false
$port.ReadTimeout = 2000

Write-Output "=================================================================="
Write-Output "  LISTENING ON COM3 FOR PHYSICAL BOOT BUTTON FACTORY RESET..."
Write-Output "  Please press and hold the physical BOOT button on the ESP32"
Write-Output "  for 5 seconds now!"
Write-Output "=================================================================="

try {
    $port.Open()
    $start = Get-Date
    while ((Get-Date) - $start -lt [TimeSpan]::FromSeconds(90)) {
        try {
            $line = $port.ReadLine()
            Write-Output $line
            if ($line -match "Physical BOOT button held|Wiping non-volatile memory") {
                Write-Output ">>> [CONFIRMED] Factory reset detected! Wiping in progress..."
            }
            if ($line -match "Launching SoftAP setup mode|SoftAP Active at SSID: ESP32_Plant_Irrigation") {
                Write-Output ""
                Write-Output "=================================================================="
                Write-Output "  >>> [SUCCESS] ESP32 has restarted cleanly into SoftAP setup mode!"
                Write-Output "  >>> Hotspot 'ESP32_Plant_Irrigation' is now broadcasting!"
                Write-Output "=================================================================="
                break
            }
        } catch [TimeoutException] {}
    }
} catch {
    Write-Output "Error: $($_.Exception.Message)"
} finally {
    if ($port.IsOpen) { $port.Close() }
}
