import subprocess
import json
import urllib.request

def get_token():
    return subprocess.check_output('gcloud auth print-access-token', shell=True).decode().strip()

def inspect_device():
    token = get_token()
    url = "https://firestore.googleapis.com/v1/projects/urbangreenfyp/databases/(default)/documents/iot_devices/SmartPlant-20FB3F"
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read().decode())
        print(json.dumps(data, indent=2))

if __name__ == "__main__":
    inspect_device()
