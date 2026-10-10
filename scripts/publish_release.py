#!/usr/bin/env python3
import sys
import os
import json
import subprocess
import urllib.request

REPO = "beratheon/Somnius"
TAG = "v1.0.0"
NAME = "Somnius 1.0.0 Beta"
BODY = """## Somnius 1.0.0 Beta Release 🚀

### What's New:
- **Dual Video Engines**: Native KSPlayer + AVPlayer with fast audio & subtitle track switching.
- **Unified Metadata Engine**: TMDB & TVDB API integration for accurate TV shows, series, docuseries, and movies.
- **Universal Auto-Play**: Smart source selection, file size bandwidth limiter, and automatic hoster notice-clip skipping.
- **Decentralized Streaming Add-ons**: Built-in support for Torrentio, Comet v2, Meteor, and Knaben.
- **Native Downloads**: Built-in torrent and debrid download manager with background transmission.
- **Remote Gatekeeper**: Automatic update checking and preview lifecycle management.

### Installation (macOS):
1. Download **`Somnius-1.0.0.dmg`** below.
2. Open the disk image and drag **`Somnius.app`** into your **`Applications`** folder.
3. On first launch, **Right-click** (Control-click) `Somnius.app` in `/Applications` and select **Open** to approve macOS Gatekeeper.
"""

def main():
    token = os.environ.get("GITHUB_TOKEN") or (sys.argv[1] if len(sys.argv) > 1 else None)
    if not token:
        home_token = os.path.expanduser("~/.somnius_token")
        if os.path.exists(home_token):
            with open(home_token, "r") as f:
                token = f.read().strip()
    if not token:
        print("Error: No GitHub token provided.")
        print("Usage: python3 scripts/publish_release.py <YOUR_GITHUB_TOKEN>")
        print("Or export GITHUB_TOKEN=your_token or create ~/.somnius_token")
        sys.exit(1)

    token = token.strip()
    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "User-Agent": "Somnius-Release-Publisher",
        "X-GitHub-Api-Version": "2022-11-28"
    }

    # 1. Push code to main branch (including app_status.json and appcast.xml)
    print("🚀 Pushing repository (app_status.json, code, and updater config) to GitHub...")
    remote_url = f"https://x-access-token:{token}@github.com/{REPO}.git"
    try:
        subprocess.run(["git", "push", remote_url, "main", "--force"], check=True)
        print("✅ Git push succeeded!")
    except subprocess.CalledProcessError as e:
        print("⚠️ Git push failed or branch up to date:", e)

    # 2. Check if release already exists or create new release
    print(f"📦 Creating GitHub Release '{TAG}' on {REPO}...")
    release_url = f"https://api.github.com/repos/{REPO}/releases"
    payload = {
        "tag_name": TAG,
        "target_commitish": "main",
        "name": NAME,
        "body": BODY,
        "draft": False,
        "prerelease": True
    }

    req = urllib.request.Request(release_url, data=json.dumps(payload).encode(), headers=headers, method="POST")
    release_data = None
    try:
        with urllib.request.urlopen(req) as resp:
            release_data = json.loads(resp.read().decode())
            print(f"✅ Created release: {release_data.get('html_url')}")
    except urllib.error.HTTPError as e:
        if e.code == 422:
            print("ℹ️ Release tag already exists, fetching existing release...")
            get_req = urllib.request.Request(f"https://api.github.com/repos/{REPO}/releases/tags/{TAG}", headers=headers)
            with urllib.request.urlopen(get_req) as resp:
                release_data = json.loads(resp.read().decode())
        else:
            print(f"❌ Failed to create release: {e}")
            sys.exit(1)

    if not release_data:
        print("❌ Could not get release details.")
        sys.exit(1)

    release_id = release_data["id"]
    upload_url_template = release_data.get("upload_url", "").split("{")[0]
    if not upload_url_template:
        upload_url_template = f"https://uploads.github.com/repos/{REPO}/releases/{release_id}/assets"

    # 3. Upload DMG, PKG and ZIP assets
    assets = [
        ("Somnius-1.0.0.dmg", "build_output/Somnius-1.0.0.dmg", "application/x-apple-diskimage"),
        ("Somnius-1.0.0.pkg", "build_output/Somnius-1.0.0.pkg", "application/octet-stream"),
        ("Somnius-1.0.0-macOS.zip", "build_output/Somnius-1.0.0-macOS.zip", "application/zip")
    ]

    # Delete existing asset with same name if already present
    existing_assets = {a["name"]: a["id"] for a in release_data.get("assets", [])}

    for asset_name, asset_path, mime_type in assets:
        if not os.path.exists(asset_path):
            print(f"⚠️ Warning: File {asset_path} does not exist, skipping.")
            continue

        if asset_name in existing_assets:
            del_id = existing_assets[asset_name]
            print(f"🗑️ Deleting older version of {asset_name} from release...")
            del_req = urllib.request.Request(f"https://api.github.com/repos/{REPO}/releases/assets/{del_id}", headers=headers, method="DELETE")
            try:
                with urllib.request.urlopen(del_req) as _:
                    pass
            except Exception:
                pass

        file_size = os.path.getsize(asset_path)
        print(f"⬆️ Uploading {asset_name} ({file_size / (1024*1024):.1f} MB)...")
        upload_endpoint = f"{upload_url_template}?name={asset_name}"
        up_headers = dict(headers)
        up_headers["Content-Type"] = mime_type
        up_headers["Content-Length"] = str(file_size)

        with open(asset_path, "rb") as f:
            up_req = urllib.request.Request(upload_endpoint, data=f, headers=up_headers, method="POST")
            with urllib.request.urlopen(up_req) as up_resp:
                res = json.loads(up_resp.read().decode())
                print(f"✅ {asset_name} uploaded successfully! Download URL: {res.get('browser_download_url')}")

    print("\n🎉 ALL DONE! Your release is live:")
    print(f"👉 Release Page: {release_data.get('html_url')}")
    print(f"👉 Direct DMG Download: https://github.com/{REPO}/releases/download/{TAG}/Somnius-1.0.0.dmg")

if __name__ == "__main__":
    main()
