import subprocess
import json
import urllib.request
import urllib.error

def get_token():
    return subprocess.check_output('gcloud auth print-access-token', shell=True).decode().strip()

def inspect_user(uid):
    token = get_token()
    url = f"https://firestore.googleapis.com/v1/projects/urbangreenfyp/databases/(default)/documents/users/{uid}"
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode())
            fields = data.get("fields", {})
            print(f"User {uid} fields: {list(fields.keys())}")
            if "gardenPlants" in fields:
                print(f"  gardenPlants: {fields['gardenPlants']}")
            if "gardenPlantsCount" in fields:
                print(f"  gardenPlantsCount: {fields['gardenPlantsCount']}")
    except urllib.error.HTTPError as e:
        print(f"HTTPError user {uid}: {e.code}")

def main():
    users = ['iOEvvfkTn1TKLEeXKRZztxICszP2', 'pljmCRB1N4TWjjIZHPqRlGrw5572', 'vYcqkk3dAQZpRbp7zn5cHEP0cKm1']
    for u in users:
        inspect_user(u)

if __name__ == "__main__":
    main()
