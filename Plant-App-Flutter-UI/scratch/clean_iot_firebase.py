import subprocess
import json
import urllib.request
import urllib.error

def get_token():
    return subprocess.check_output('gcloud auth print-access-token', shell=True).decode().strip()

def list_collection(collection):
    token = get_token()
    url = f"https://firestore.googleapis.com/v1/projects/urbangreenfyp/databases/(default)/documents/{collection}"
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode())
            return [doc["name"].split("/")[-1] for doc in data.get("documents", [])]
    except urllib.error.HTTPError as e:
        print(f"HTTPError listing {collection}: {e.code} - {e.read().decode()}")
        return []

def main():
    print("Checking collections...")
    for col in ["iot_devices", "provisioning", "plants", "users"]:
        docs = list_collection(col)
        print(f"Collection '{col}': {docs}")

if __name__ == "__main__":
    main()
