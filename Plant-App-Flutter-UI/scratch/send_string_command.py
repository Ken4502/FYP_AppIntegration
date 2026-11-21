import subprocess
import json
import urllib.request
import urllib.error

def get_token():
    return subprocess.check_output('gcloud auth print-access-token', shell=True).decode().strip()

def send_reset():
    token = get_token()
    url = "https://firestore.googleapis.com/v1/projects/urbangreenfyp/databases/(default)/documents/iot_devices/SmartPlant-20FB3F?updateMask.fieldPaths=pendingCommand"
    body = {
        "fields": {
            "pendingCommand": {
                "stringValue": '{"command":"FACTORY_RESET","executed":false}'
            }
        }
    }
    data = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"}, method="PATCH")
    try:
        with urllib.request.urlopen(req) as resp:
            print("Successfully patched pendingCommand into SmartPlant-20FB3F!")
            return True
    except urllib.error.HTTPError as e:
        print(f"HTTPError: {e.code} - {e.read().decode()}")
        return False

if __name__ == "__main__":
    send_reset()
