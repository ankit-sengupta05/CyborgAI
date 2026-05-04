import json
import os
import subprocess
import sys


def main():
    json_path = os.path.join("android", "app", "google-services.json")
    print(f"Looking for {json_path}...")

    if not os.path.exists(json_path):
        print(f"Error: {json_path} not found.")
        sys.exit(1)

    try:
        with open(json_path, "r", encoding="utf-8") as f:
            data = json.load(f)
            # Safely extract the package name from the first client
            client_info = data["client"][0]["client_info"]
            package_name = client_info["android_client_info"]["package_name"]
    except Exception as e:
        print(f"Error reading package name from google-services.json: {e}")
        sys.exit(1)

    print(f"Found Firebase Package Name: '{package_name}'")
    print("Installing change_app_package_name utility...")

    # Use shell=True for Windows compatibility with flutter/dart commands
    subprocess.run("flutter pub add -d change_app_package_name", shell=True, check=True)

    print(f"\nApplying package name '{package_name}' across the entire Android project...")
    subprocess.run(f"dart run change_app_package_name:main {package_name}", shell=True, check=True)

    print("\n✅ Successfully synced project package name with Firebase!")
    print(
        "You can now safely replace google-services.json anytime "
        "and run this script to instantly plug-and-play."
    )


if __name__ == "__main__":
    main()
