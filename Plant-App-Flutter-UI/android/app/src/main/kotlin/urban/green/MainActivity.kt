package urban.green

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.net.wifi.WifiInfo
import android.net.wifi.WifiManager
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "urban.green/bluetooth"
    private val NOTIF_PERMISSION_CODE = 2001
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var methodChannel: MethodChannel? = null
    private var pendingPayload: Map<String, String>? = null

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleNotificationIntent(intent)
    }

    private fun handleNotificationIntent(intent: Intent?) {
        val action = intent?.getStringExtra("notification_action")
        if (action == "low_moisture_decision") {
            val deviceId = intent.getStringExtra("deviceId") ?: ""
            val plantId = intent.getStringExtra("plantId") ?: ""
            val payload = mapOf("action" to action, "deviceId" to deviceId, "plantId" to plantId)
            pendingPayload = payload
            methodChannel?.invokeMethod("onNotificationTapped", payload)
        }
    }

    private fun hasNotificationPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    private fun showHeadsUpNotification(title: String, body: String, deviceId: String = "", plantId: String = "") {
        val channelId = "urban_green_alerts"
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "UrbanGreen Botanical Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Global heads-up alerts from ESP32 via ntfy.sh and local telemetry"
                enableVibration(true)
                enableLights(true)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            }
            notificationManager.createNotificationChannel(channel)
        }

        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("notification_action", "low_moisture_decision")
            putExtra("deviceId", deviceId)
            putExtra("plantId", plantId)
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            (System.currentTimeMillis() % 10000).toInt(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setContentIntent(pendingIntent)

        val notifId = (System.currentTimeMillis() % 100000).toInt() + 100
        notificationManager.notify(notifId, builder.build())
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == NOTIF_PERMISSION_CODE) {
            val granted = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                // --- Notifications ---
                "checkNotificationPermission" -> {
                    result.success(hasNotificationPermission())
                }
                "requestNotificationPermission" -> {
                    if (hasNotificationPermission()) {
                        result.success(true)
                    } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        pendingPermissionResult = result
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                            NOTIF_PERMISSION_CODE
                        )
                    } else {
                        result.success(true)
                    }
                }
                "getPendingNotificationPayload" -> {
                    val p = pendingPayload
                    pendingPayload = null
                    result.success(p)
                }
                "showDrySoilNotification", "showNotification" -> {
                    val title = call.argument<String>("title") ?: "🌱 UrbanGreen Alert"
                    val body = call.argument<String>("body") ?: "ESP32 Notification Alert received."
                    val deviceId = call.argument<String>("deviceId") ?: ""
                    val plantId = call.argument<String>("plantId") ?: ""
                    showHeadsUpNotification(title, body, deviceId, plantId)
                    result.success(true)
                }

                "getDeviceModel" -> {
                    val manufacturer = Build.MANUFACTURER.replaceFirstChar { it.uppercase() }
                    val model = Build.MODEL
                    result.success("$manufacturer $model")
                }

                // --- Captive Portal & System Navigation ---
                "openWifiSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_WIFI_SETTINGS).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val fallbackIntent = Intent(Settings.ACTION_SETTINGS).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(fallbackIntent)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.error("INTENT_ERROR", e2.localizedMessage, null)
                        }
                    }
                }
                "openBrowserUrl" -> {
                    val url = call.argument<String>("url") ?: "http://192.168.4.1"
                    try {
                        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INTENT_ERROR", e.localizedMessage, null)
                    }
                }
                "openAppSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.fromParts("package", packageName, null)
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INTENT_ERROR", e.localizedMessage, null)
                    }
                }

                // --- Network Information ---
                "getWifiSsid" -> {
                    try {
                        val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
                        val connectivityManager = applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager

                        var ssid: String? = null

                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                            val allNetworks = connectivityManager?.allNetworks ?: emptyArray()
                            for (net in allNetworks) {
                                val caps = connectivityManager?.getNetworkCapabilities(net)
                                if (caps != null && caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) {
                                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                                        val wifiInfo = caps.transportInfo as? WifiInfo
                                        val curSsid = wifiInfo?.ssid
                                        if (curSsid != null && curSsid != "<unknown ssid>" && curSsid != "0x") {
                                            ssid = curSsid
                                            break
                                        }
                                    }
                                }
                            }
                        }

                        if (ssid == null || ssid == "<unknown ssid>" || ssid == "0x") {
                            @Suppress("DEPRECATION")
                            val info = wifiManager?.connectionInfo
                            ssid = info?.ssid
                        }

                        if (ssid != null) {
                            if (ssid.startsWith("\"") && ssid.endsWith("\"")) {
                                ssid = ssid.substring(1, ssid.length - 1)
                            }
                            if (ssid == "<unknown ssid>" || ssid == "0x" || ssid.trim().isEmpty()) {
                                ssid = null
                            }
                        }

                        result.success(ssid)
                    } catch (e: Exception) {
                        result.success(null)
                    }
                }
                "getWifiGatewayIp" -> {
                    try {
                        val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
                        val dhcpInfo = wifiManager?.dhcpInfo
                        if (dhcpInfo != null && (dhcpInfo.gateway != 0 || dhcpInfo.serverAddress != 0 || dhcpInfo.ipAddress != 0)) {
                            val gatewayIp = android.text.format.Formatter.formatIpAddress(dhcpInfo.gateway)
                            val ipAddress = android.text.format.Formatter.formatIpAddress(dhcpInfo.ipAddress)
                            val serverIp = android.text.format.Formatter.formatIpAddress(dhcpInfo.serverAddress)
                            val isEsp = (gatewayIp == "192.168.4.1" || serverIp == "192.168.4.1" || ipAddress.startsWith("192.168.4."))
                            result.success(mapOf(
                                "gateway" to gatewayIp,
                                "ip" to ipAddress,
                                "server" to serverIp,
                                "isEspGateway" to isEsp
                            ))
                        } else {
                            result.success(null)
                        }
                    } catch (e: Exception) {
                        result.success(null)
                    }
                }
                "bindProcessToWifi" -> {
                    try {
                        val connectivityManager = applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
                        val bind = call.argument<Boolean>("bind") ?: true
                        if (bind) {
                            var bound = false
                            val allNetworks = connectivityManager?.allNetworks ?: emptyArray()
                            for (net in allNetworks) {
                                val caps = connectivityManager?.getNetworkCapabilities(net)
                                if (caps != null && caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) {
                                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                        connectivityManager?.bindProcessToNetwork(net)
                                        bound = true
                                        break
                                    }
                                }
                            }
                            result.success(bound)
                        } else {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                connectivityManager?.bindProcessToNetwork(null)
                            }
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "getNetworkType" -> {
                    try {
                        val connectivityManager = applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
                        val activeNetwork = connectivityManager?.activeNetwork
                        val capabilities = connectivityManager?.getNetworkCapabilities(activeNetwork)
                        if (capabilities != null) {
                            if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) {
                                result.success("wifi")
                            } else if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)) {
                                result.success("cellular")
                            } else if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)) {
                                result.success("ethernet")
                            } else {
                                result.success("other")
                            }
                        } else {
                            result.success("none")
                        }
                    } catch (e: Exception) {
                        result.success("unknown")
                    }
                }

                // --- Storage Persistence ---
                "saveStorage" -> {
                    val key = call.argument<String>("key")
                    val value = call.argument<String>("value")
                    if (key != null && value != null) {
                        val prefs = applicationContext.getSharedPreferences("urban_green_prefs", Context.MODE_PRIVATE)
                        val success = prefs.edit().putString(key, value).commit()
                        result.success(success)
                    } else {
                        result.success(false)
                    }
                }
                "loadStorage" -> {
                    val key = call.argument<String>("key")
                    if (key != null) {
                        val prefs = applicationContext.getSharedPreferences("urban_green_prefs", Context.MODE_PRIVATE)
                        val value = prefs.getString(key, null)
                        result.success(value)
                    } else {
                        result.success(null)
                    }
                }
                "loadAllStorage" -> {
                    try {
                        val prefs = applicationContext.getSharedPreferences("urban_green_prefs", Context.MODE_PRIVATE)
                        val all = prefs.all
                        val resultMap = HashMap<String, String>()
                        for ((k, v) in all) {
                            if (v != null) {
                                resultMap[k] = v.toString()
                            }
                        }
                        result.success(resultMap)
                    } catch (e: Exception) {
                        result.success(HashMap<String, String>())
                    }
                }
                "getAppFilesDir" -> {
                    try {
                        result.success(applicationContext.filesDir.absolutePath)
                    } catch (e: Exception) {
                        result.success(null)
                    }
                }

                // --- Deprecated BLE Stubs (Safe No-ops for Backward Compatibility) ---
                "checkBlePermissions" -> {
                    result.success(true)
                }
                "requestBlePermissions" -> {
                    result.success(true)
                }
                "isBluetoothEnabled" -> {
                    result.success(false)
                }
                "startBleScan" -> {
                    result.success(ArrayList<Map<String, Any>>())
                }
                "readBleGattTelemetry" -> {
                    result.success(mapOf("success" to false, "deprecated" to true))
                }
                "sendBleWifiCredentials" -> {
                    result.success(mapOf("success" to false, "deprecated" to true, "error" to "BLE provisioning deprecated in favor of SoftAP captive portal"))
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
