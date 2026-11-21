import subprocess
import urllib.request
import urllib.error

def get_token():
    return subprocess.check_output('gcloud auth print-access-token', shell=True).decode().strip()

def delete_doc(doc_path):
    token = get_token()
    url = f"https://firestore.googleapis.com/v1/projects/urbangreenfyp/databases/(default)/documents/{doc_path}"
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"}, method="DELETE")
    try:
        with urllib.request.urlopen(req) as resp:
            print(f"Deleted {doc_path} successfully.")
    except urllib.error.HTTPError as e:
        print(f"Error deleting {doc_path}: {e.code} - {e.read().decode()}")

if __name__ == "__main__":
    delete_doc("iot_devices/SmartPlant-20FB3F")
