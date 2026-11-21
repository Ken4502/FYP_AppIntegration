import subprocess
import re
import time
import json
import urllib.request
from pathlib import Path

TOOLS_DIR = Path("c:/Users/user/Desktop/FYP/AppIntegration/tools")
CLOUDFLARED = TOOLS_DIR / "cloudflared.exe"
URL_FILE_1 = Path("c:/Users/user/Desktop/FYP/AppIntegration/cloud_ai_url.txt")
URL_FILE_2 = Path("c:/Users/user/Desktop/FYP/AppIntegration/active_server_url.txt")
DISCOVERY_TOPIC = "urbangreen_coretech_ai_discovery"

def publish(tunnel_url):
    data = {
        "tunnel_url": tunnel_url,
        "local_url": "http://192.168.1.9:8001",
        "local_ip": "192.168.1.9",
        "port": 8001,
        "timestamp": int(time.time()),
        "status": "online"
    }
    payload = json.dumps(data).encode("utf-8")
    req = urllib.request.Request(
        f"https://ntfy.sh/{DISCOVERY_TOPIC}",
        data=payload,
        headers={"Title": "CoreTech AI Online", "Tags": "seedling,robot"}
    )
    try:
        with urllib.request.urlopen(req, timeout=5) as res:
            print(f"[✓] Published to ntfy: {res.status}")
    except Exception as e:
        print(f"[!] ntfy error: {e}")

def main():
    print("[*] Starting cloudflared tunnel to http://127.0.0.1:8001...")
    proc = subprocess.Popen(
        [str(CLOUDFLARED), "tunnel", "--url", "http://127.0.0.1:8001"],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1
    )
    url_pattern = re.compile(r"https://[a-zA-Z0-9-]+\.trycloudflare\.com")
    tunnel_url = None

    for line in iter(proc.stdout.readline, ""):
        print(line, end="", flush=True)
        m = url_pattern.search(line)
        if m and not tunnel_url:
            tunnel_url = m.group(0)
            print(f"\n[✓] Cloudflare Tunnel Established: {tunnel_url}", flush=True)
            URL_FILE_1.write_text(tunnel_url + "\n")
            URL_FILE_2.write_text(tunnel_url + "\n")
            publish(tunnel_url)

    proc.wait()

if __name__ == "__main__":
    main()
