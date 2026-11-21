import subprocess
import json
import urllib.request
import urllib.error
import time

def get_token():
    return subprocess.check_output('gcloud auth print-access-token', shell=True).decode().strip()

def send_reset_command():
    token = get_token()
    url = "https://firestore.googleapis.com/v1/projects/urbangreenfyp/databases/(default)/documents/iot_devices?documentId=SmartPlant-20FB3F"
    body = {
        "fields": {
            "pendingCommand": {
                "mapValue": {
                    "fields": {
                        "command": {"stringValue": "FACTORY_RESET"},
                        "executed": {"booleanValue": False}
                    }
                }
            }
        }
    }
    data = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"}, method="POST")
    try:
        with urllib.request.urlopen(req) as resp:
            print("Successfully created pendingCommand FACTORY_RESET in Firestore for SmartPlant-20FB3F.")
            return True
    except urllib.error.HTTPError as e:
        print(f"Error creating command: {e.code} - {e.read().decode()}")
        return False

if __name__ == "__main__":
    send_reset_command()
