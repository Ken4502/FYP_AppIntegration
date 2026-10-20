# UrbanGreen + PhytoCare Ultra App Integration

This directory contains the completed integration between the **UrbanGreen Flutter Mobile App** and the **PhytoCare Ultra Deep Learning Pathology Engine**.

---

## 📁 Directory Structure

```text
AppIntegration/
├── Plant-App-Flutter-UI/       # Flutter Mobile Application (Dart 3)
│   ├── android/                # Android native project with Camera & Network permissions
│   ├── ios/                    # iOS Runner configuration
│   ├── lib/
│   │   ├── models/
│   │   │   └── plant_diagnosis_model.dart # Parsed CoreTech AI schema
│   │   ├── services/
│   │   │   └── plant_api_service.dart     # HTTP Multipart client & host switch
│   │   ├── screens/
│   │   │   ├── camera/
│   │   │   │   ├── camera_screen.dart             # Full-screen preview & live AI trigger
│   │   │   │   ├── plant_capture_result_screen.dart # Real diagnosis & species card
│   │   │   │   └── plant_diagnostic_screen.dart   # Annotated lesions & treatments
│   │   │   └── main/
│   │   │       └── main_screen.dart               # Bottom navigation & camera FAB action
│   │   └── main.dart
│   └── pubspec.yaml
│
├── CoreTech/                   # Completed AI Diagnostic Backend (PyTorch + FastAPI)
│   ├── Plant_Disease_Experiment/ # PhytoCare Ultra (ConvNeXt-Small + Swin-T Ensemble)
│   ├── Plant_Identification_Experiment/ # FloraNet-250 Botanical Classifier
│   ├── preprocessing/          # YOLOv8-seg foliar extraction
│   ├── launch.py               # Master AI service launcher
│   ├── start.bat               # Windows virtual environment & service runner
│   └── Dockerfile              # Container definition for Firebase / Google Cloud Run
│
├── run_ai_backend.bat          # One-click Windows shortcut to launch the AI server
└── README.md                   # This instruction guide
```

---

## 🚀 Quick Start Guide

### Step 1: Start the AI CoreTech Server
1. Double-click `run_ai_backend.bat` in this folder (or run `python launch.py` inside `CoreTech/`).
2. The server will launch:
   - **PhytoCare Ultra Pathology Server:** `http://0.0.0.0:8001`
   - **FloraNet Botanical Server:** `http://0.0.0.0:8000`

---

### Step 2: Open and Run in Android Studio
1. Launch **Android Studio**.
2. Click **Open** (or `File` > `Open...`).
3. Select the folder:
   ```
   C:\Users\user\Desktop\FYP\AppIntegration\Plant-App-Flutter-UI
   ```
4. Wait for Android Studio to index the project and sync Dart packages.
5. In the device dropdown, select your desired target:
   - **Android Emulator** (Pixel, Galaxy, etc.)
   - **Physical Android Device** (connected via USB with USB Debugging enabled)
6. Click the green **Run (▶)** button or press `Shift + F10`.

---

## 📸 Real-Life Camera Snapping & Network Configuration

When you tap the central **Camera Icon (Floating Action Button)** on the main user page:
1. A menu will slide up offering:
   - **Snap Photo with Phone Camera:** Opens the physical phone camera in real time.
   - **Select from Photo Gallery:** Uploads an existing photo.
   - **AI Server Configuration:** Displays the active backend URL.
2. After taking a picture, `CameraScreen` lets you review the shot.
3. Tap **Diagnose** to transmit the image to the CoreTech AI.
4. The AI returns:
   - **Botanical Species:** Identified plant name and match confidence.
   - **Pathological Diagnosis:** Whether the plant is healthy or infected.
   - **Lesion Localization:** OpenCV computer vision spot detector overlays bounding boxes on infected areas.
   - **EPPO/USDA Severity Grade:** Quantitative Plant Disease Index (PDI).
   - **Care & Treatment Plan:** Immediate actions, organic remedies, chemical controls, and preventive measures.

### Configuring Network Endpoints:
* **Running in Android Emulator:** Uses `http://10.0.2.2:8001` (pre-configured default).
* **Running on Physical Phone (via Wi-Fi):**
  1. Ensure your PC and phone are on the same Wi-Fi.
  2. Find your PC's IP address: Run `ipconfig` in PowerShell (e.g. `192.168.1.85`).
  3. In the mobile app, tap the camera button, tap the **AI Server URL** tile, and set it to:
     ```
     http://192.168.1.85:8001
     ```
* **Running with Firebase / Cloud Run:** Set it to your public HTTPS endpoint:
  ```
  https://phytonet-ai-xxxxxx.a.run.app
  ```

---

## ☁️ Deploying to Firebase / Google Cloud Run (Project: `urbangreenfyp`)

Because your CoreTech AI utilizes PyTorch deep learning weights (~200MB) and OpenCV, deploying it as a container inside your Firebase Google Cloud project (`urbangreenfyp`) gives you a permanent, serverless HTTPS endpoint:

1. Open PowerShell in `AppIntegration/CoreTech`.
2. Authenticate with Google Cloud (linked to your Firebase account):
   ```powershell
   gcloud auth login
   gcloud config set project urbangreenfyp
   ```
3. Deploy directly to Cloud Run in your Firebase project:
   ```powershell
   gcloud run deploy phytonet-ai --source . --platform managed --region us-central1 --allow-unauthenticated --memory 2Gi --cpu 2
   ```
4. Cloud Run will provide you with a permanent HTTPS service URL:
   ```
   https://phytonet-ai-xxxxxx.a.run.app
   ```
5. Paste this URL into `PlantApiService.setServerUrl(...)` or through the in-app server settings dialog.

