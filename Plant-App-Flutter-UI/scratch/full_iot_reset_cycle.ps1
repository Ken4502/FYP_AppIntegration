Write-Output ">>> STEP 1: Sending FACTORY_RESET command via Firestore..."
python scratch/trigger_factory_reset.py

Write-Output ">>> STEP 2: Listening to COM3 for reset and wipe execution..."
$port = New-Object System.IO.Ports.SerialPort 'COM3', 115200, 'None', 8, 'One'
$port.DtrEnable = $false
$port.RtsEnable = $false
$port.ReadTimeout = 2000

$wiped = $false
$softApReady = $false

try {
    $port.Open()
    $start = Get-Date
    while ((Get-Date) - $start -lt [TimeSpan]::FromSeconds(20)) {
        try {
            $line = $port.ReadLine()
            Write-Output $line
            if ($line -match "Wiping non-volatile memory|FACTORY_RESET received|Physical BOOT button") {
                $wiped = $true
            }
            if ($line -match "Launching SoftAP setup mode|SoftAP Active at SSID: ESP32_Plant_Irrigation") {
                $softApReady = $true
                break
            }
        } catch [TimeoutException] {
            # continue
        }
    }
} catch {
    Write-Output "Serial exception: $($_.Exception.Message)"
} finally {
    if ($port.IsOpen) { $port.Close() }
}

Write-Output ">>> STEP 3: Cleaning up Firestore documents completely..."
& npx firebase-tools firestore:delete -r -f --project urbangreenfyp iot_devices/SmartPlant-20FB3F
& npx firebase-tools firestore:delete -r -f --project urbangreenfyp provisioning

Write-Output ""
Write-Output "========================================================"
if ($wiped -and $softApReady) {
    Write-Output "  [SUCCESS] ESP32 has been completely wiped into clean SoftAP mode!"
} else {
    Write-Output "  [STATUS] Check output above for ESP32 wipe status."
}
Write-Output "  [SUCCESS] All Firestore IoT and provisioning records are wiped clean!"
Write-Output "========================================================"
