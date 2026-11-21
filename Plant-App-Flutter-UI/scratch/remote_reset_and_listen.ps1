Write-Output ">>> 1. Creating Firestore string pendingCommand for SmartPlant-20FB3F..."
python scratch/send_string_command.py

Write-Output ">>> 2. Listening on COM3 for ESP32 to poll command and factory reset..."
$port = New-Object System.IO.Ports.SerialPort 'COM3', 115200, 'None', 8, 'One'
$port.DtrEnable = $false
$port.RtsEnable = $false
$port.ReadTimeout = 2000

$wiped = $false
$softApReady = $false

try {
    $port.Open()
    $start = Get-Date
    while ((Get-Date) - $start -lt [TimeSpan]::FromSeconds(15)) {
        try {
            $line = $port.ReadLine()
            Write-Output $line
            if ($line -match "FACTORY_RESET|Wiping non-volatile memory") {
                $wiped = $true
                Write-Output ">>> [MATCH] Factory reset executed by ESP32!"
            }
            if ($line -match "Launching SoftAP setup mode|SoftAP Active at SSID: ESP32_Plant_Irrigation") {
                $softApReady = $true
                Write-Output ">>> [CONFIRMED] Hotspot ESP32_Plant_Irrigation is now broadcasting!"
                break
            }
        } catch [TimeoutException] {}
    }
} catch {
    Write-Output "Error: $($_.Exception.Message)"
} finally {
    if ($port.IsOpen) { $port.Close() }
}

Write-Output ">>> 3. Deleting SmartPlant-20FB3F from Firestore..."
python scratch/delete_test_doc.py
