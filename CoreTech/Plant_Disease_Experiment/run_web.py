"""
Launcher for PhytoCare Plant Disease Diagnostic Web Application (Port 8001)
Runs concurrently with FloraNet Plant Identification (Port 8000).
Supports local development, physical device testing (0.0.0.0), and Cloud Run containerization ($PORT).
"""

import sys
import os
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8")

EXPERIMENT_ROOT = Path(__file__).resolve().parent
CORETECH_ROOT = EXPERIMENT_ROOT.parent

if str(EXPERIMENT_ROOT) not in sys.path:
    sys.path.insert(0, str(EXPERIMENT_ROOT))
if str(CORETECH_ROOT) not in sys.path:
    sys.path.insert(0, str(CORETECH_ROOT))

import uvicorn

if __name__ == "__main__":
    host = os.environ.get("HOST", "0.0.0.0")
    port = int(os.environ.get("PORT", "8001"))

    print("=" * 65)
    print("[PhytoCare Ultra] Plant Disease Clinical Diagnosis & Advisory")
    print("[PhytoCare Ultra] Model: ConvNeXt-Small 384px + Swin-T Ensemble")
    print(f"[PhytoCare Ultra] Web Service Listening: http://{host}:{port}")
    print("=" * 65)
    uvicorn.run("web.app:app", host=host, port=port, log_level="info")
