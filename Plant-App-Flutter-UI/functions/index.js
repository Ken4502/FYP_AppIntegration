const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const https = require("https");

admin.initializeApp();
const db = admin.firestore();

/**
 * Cloud Scheduler Watchdog: Runs every 1 minute
 *
 * Scans `iot_devices` for probes whose heartbeat `lastSeen` is older than 90 seconds.
 * Automatically marks them `systemState: "OFFLINE"` in Firestore, appends an activity log,
 * and pushes an alert over ntfy.sh to all linked phones (even if the app is killed).
 */
exports.checkIotOfflineWatchdog = onSchedule("every 1 minutes", async (event) => {
  const now = Date.now();
  const ninetySecondsAgo = new Date(now - 90 * 1000);

  try {
    const snapshot = await db.collection("iot_devices")
      .where("systemState", "!=", "OFFLINE")
      .get();

    for (const doc of snapshot.docs) {
      const data = doc.data();
      const lastSeen = data.lastSeen ? (data.lastSeen.toDate ? data.lastSeen.toDate() : new Date(data.lastSeen)) : null;

      if (lastSeen && lastSeen < ninetySecondsAgo) {
        console.log(`[Watchdog] Device ${doc.id} ("${data.name || "ESP32"}") heartbeat expired. Marking OFFLINE.`);

        // 1. Mark device OFFLINE in Firestore
        await doc.ref.update({
          systemState: "OFFLINE",
          stateReason: "Heartbeat timeout (>90s) detected by Cloud Watchdog",
          isWifiConnected: false,
          wifiConnected: false,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // 2. Add an activity log entry
        await doc.ref.collection("logs").add({
          title: "Device Offline (Cloud Detected)",
          detail: `No telemetry received since ${lastSeen.toISOString()}. Probe marked offline.`,
          type: "network",
          deviceId: doc.id,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });

        // 3. Dispatch push alert via ntfy.sh to phone
        const topic = data.ntfyTopic || "urbangreen_esp32_alerts";
        postNtfyAlert(
          topic,
          "⚠️ Smart Plant Probe Offline",
          `Probe "${data.name || doc.id}" has stopped sending data for >90 seconds. Please check device power or Wi-Fi router.`
        );
      }
    }
  } catch (error) {
    console.error("[Watchdog Error]", error);
  }
});

function postNtfyAlert(topic, title, message) {
  const data = Buffer.from(message, "utf8");
  const options = {
    hostname: "ntfy.sh",
    port: 443,
    path: `/${topic}`,
    method: "POST",
    headers: {
      "Title": title,
      "Priority": "high",
      "Tags": "warning,satellite",
      "Content-Type": "text/plain",
      "Content-Length": data.length,
    },
  };

  const req = https.request(options, (res) => {
    console.log(`[ntfy] Response status: ${res.statusCode}`);
  });
  req.on("error", (e) => {
    console.error(`[ntfy] Error: ${e.message}`);
  });
  req.write(data);
  req.end();
}
