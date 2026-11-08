"""
One-Click Online AI Diagnostic Server & Cloudflare HTTPS Tunnel
==============================================================
Starts the CoreTech AI backend (port 8001) and exposes it online
via a secure Cloudflare Tunnel (https://*.trycloudflare.com) for
100% free online plant diagnosis on any mobile device worldwide.
"""
import sys
import os
import re
import time
import subprocess
import signal
import urllib.request
from pathlib import Path

APP_DIR = Path(__file__).resolve().parent
CORETECH_DIR = APP_DIR / "CoreTech"
TOOLS_DIR = APP_DIR / "tools"
CLOUDFLARED_EXE = TOOLS_DIR / "cloudflared.exe"
URL_FILE = APP_DIR / "cloud_ai_url.txt"

VENV_PYTHON = CORETECH_DIR / ".venv" / "Scripts" / "python.exe"
if not VENV_PYTHON.exists():
    VENV_PYTHON = Path(sys.executable)

def main():
    print("=" * 72)
    print("       UrbanGreen FYP - PhytoCare AI Online Diagnostic Server")
    print("                (Cloudflare Secure Public Tunnel)")
    print("=" * 72)
    print()

    # 1. Start AI Diagnostic Backend on Port 8001
    print("[*] Starting PhytoCare AI Diagnostic Backend on port 8001...")
    disease_dir = CORETECH_DIR / "Plant_Disease_Experiment"

    backend_cmd = [
        str(VENV_PYTHON),
        "-m", "uvicorn",
        "web.app:app",
        "--host", "0.0.0.0",
        "--port", "8001",
        "--reload"
    ]
    
    backend_proc = subprocess.Popen(
        backend_cmd,
        cwd=str(disease_dir),
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )

    # 2. Wait for backend port 8001 to become active
    print("[*] Initializing neural network models (ConvNeXt-Swin Ensemble)...")
    online = False
    for i in range(45):
        try:
            with urllib.request.urlopen("http://127.0.0.1:8001/api/info", timeout=2) as res:
                if res.status == 200:
                    online = True
                    break
        except Exception:
            time.sleep(1)

    if online:
        print("[✓] CoreTech AI diagnostic backend is active and ready on port 8001!")
    else:
        print("[!] Backend startup took longer than expected, initializing tunnel...")

    # 3. Start Cloudflare Quick Tunnel
    print("[*] Opening Cloudflare HTTPS Public Tunnel...")
    cf_cmd = [
        str(CLOUDFLARED_EXE),
        "tunnel",
        "--url", "http://127.0.0.1:8001"
    ]

    cf_proc = subprocess.Popen(
        cf_cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1
    )

    tunnel_url = None
    url_pattern = re.compile(r"https://[a-zA-Z0-9-]+\.trycloudflare\.com")

    for line in iter(cf_proc.stdout.readline, ""):
        match = url_pattern.search(line)
        if match:
            tunnel_url = match.group(0)
            break

    if tunnel_url:
        with open(URL_FILE, "w", encoding="utf-8") as f:
            f.write(tunnel_url.strip() + "\n")

        print()
        print("=======================================================================")
        print(" [SUCCESS] YOUR ONLINE AI BACKEND IS LIVE!")
        print("=======================================================================")
        print(f" Live HTTPS URL : {tunnel_url}")
        print(f" Diagnostic API : {tunnel_url}/api/predict")
        print(f" Saved to file  : {URL_FILE.name}")
        print("=======================================================================")
        print()
        print(" INSTRUCTIONS FOR MOBILE APP:")
        print(" 1. In your Flutter app, tap the Settings gear icon on Camera screen.")
        print(f" 2. Enter or paste this URL: {tunnel_url}")
        print(" 3. Tap 'Test Ping' to confirm green checkmark, then tap 'Save & Retry'.")
        print()
        print(" * Keep this terminal window open while using the mobile app.")
        print(" * Press Ctrl+C at any time to stop the server.")
        print("=======================================================================")
    else:
        print("[!] Tunnel process running. Check cloud_ai_url.txt.")

    # Graceful shutdown handler
    def cleanup(signum=None, frame=None):
        print("\n[*] Stopping Cloudflare Tunnel and AI Backend...")
        try:
            cf_proc.terminate()
        except Exception:
            pass
        try:
            backend_proc.terminate()
        except Exception:
            pass
        print("[✓] All services stopped cleanly. Goodbye!")
        sys.exit(0)

    signal.signal(signal.SIGINT, cleanup)
    signal.signal(signal.SIGTERM, cleanup)

    try:
        cf_proc.wait()
    except KeyboardInterrupt:
        cleanup()

if __name__ == "__main__":
    main()
