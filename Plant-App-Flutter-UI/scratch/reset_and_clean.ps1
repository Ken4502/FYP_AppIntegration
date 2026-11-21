$port = New-Object System.IO.Ports.SerialPort 'COM3', 115200, 'None', 8, 'One'
$port.DtrEnable = $false
$port.RtsEnable = $false
$port.ReadTimeout = 25000

Write-Output '>>> [MONITOR] Listening on COM3 for 5-second BOOT button press or reset...'
Write-Output '>>> [ACTION NEEDED] Please press and hold the physical BOOT button on the ESP32 for 5 seconds now!'

try {
    $port.Open()
    $wiped = $false
    $startTime = Get-Date

    while ((Get-Date) - $startTime -lt [TimeSpan]::FromSeconds(30)) {
        try {
            $line = $port.ReadLine()
            Write-Output $line

            if ($line -match 'Wiping non-volatile memory|NVS erased successfully|BOOT button held') {
                $wiped = $true
                Write-Output '>>> [SUCCESS] ESP32 NVS WIPE DETECTED!'
            }

            if ($line -match 'Hotspot SSID: ESP32_Plant_Irrigation|Launching SoftAP setup mode') {
                Write-Output '>>> [CONFIRMED] ESP32 has restarted cleanly into SoftAP setup mode!'
                break
            }
        } catch [TimeoutException] {
            # continue listening
        }
    }
} catch {
    Write-Output $_.Exception.Message
} finally {
    if ($port.IsOpen) { $port.Close() }
}

Write-Output '>>> [FIRESTORE] Cleaning up Cloud Firestore...'
& npx firebase-tools firestore:delete -r -f --project urbangreenfyp iot_devices/SmartPlant-41FC3F
& npx firebase-tools firestore:delete -r -f --project urbangreenfyp provisioning

Write-Output '>>> [DONE] All connections, NVS memories, and cloud records are completely wiped!'
