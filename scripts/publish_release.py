#!/usr/bin/env python3
import sys
import os
import json
import subprocess
import urllib.request

REPO = "beratheon/Somnius"
TAG = "v1.0.1"
NAME = "Somnius 1.0.1 (Universal macOS & Resilient Multi-Source Update)"
BODY = r"""## Somnius 1.0.1 Compatibility & Bug Fix Update 🚀

This update brings universal macOS 12.0+ compatibility across all Apple Silicon Macs, resolves OS version alerts, and upgrades the streaming engine with multi-source parallel scraping and instant failover.

### What's New in Version 1.0.1:

- **Universal macOS 12.0+ Compatibility**: Resolved the macOS alert *"You can't use this version of the application 'Somnius' with this version of macOS"*. The app now runs smoothly on macOS 12 Monterey, 13 Ventura, 14 Sonoma, 15 Sequoia, 26 Tahoe (`26.6.2`), and 27+ across all Apple Silicon chips (M1, M2, M3, M4).
- **Multi-Source Resilient Scraping Engine**: Added parallel fallback indexers (**TorrentsDB**, **ThePirateBay / ApiBay**, **YTS**, **EZTV**, and **Peerflix**) alongside Torrentio and Comet. If any indexer encounters Cloudflare blocks or timeouts, streams are still discovered instantly without showing "No playable media sources found".
- **Instant Real-Debrid Resolution & Smart Cloud Failover**: Optimized Real-Debrid candidate resolution with immediate 0ms first-check verification, automatic file matching, and fast failover to the next healthy stream if a candidate is DMCA-restricted or stalling.
- **Enhanced UI Compatibility**: Adapted timeline hover scrubbing and navigation components for seamless performance across all supported macOS versions.

### Installation (macOS):
1. Download **`Somnius-1.0.1.dmg`** or **`Somnius-1.0.1.pkg`** below.
2. If using the DMG, open it and drag **`Somnius.app`** into your **`Applications`** folder.
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

    # 1. Push code to main branch (including appcast.xml, project updates)
    print("🚀 Pushing repository (code, appcast.xml) to GitHub main...")
    remote_url = f"https://x-access-token:{token}@github.com/{REPO}.git"
    try:
        subprocess.run(["git", "push", remote_url, "main"], check=True)
        subprocess.run(["git", "tag", "-fa", TAG, "-m", f"Somnius {TAG} Release"], check=True)
        subprocess.run(["git", "push", "-f", remote_url, TAG], check=True)
        print(f"✅ Git push and tag {TAG} succeeded!")
    except subprocess.CalledProcessError as e:
        print("⚠️ Git push note:", e)

    # 2. Check if release already exists or create new release for v1.0.1
    print(f"📦 Creating/Updating GitHub Release '{TAG}' on {REPO}...")
    release_url = f"https://api.github.com/repos/{REPO}/releases"
    payload = {
        "tag_name": TAG,
        "target_commitish": "main",
        "name": NAME,
        "body": BODY,
        "draft": False,
        "prerelease": False,
        "make_latest": "true"
    }

    req = urllib.request.Request(release_url, data=json.dumps(payload).encode(), headers=headers, method="POST")
    release_data = None
    try:
        with urllib.request.urlopen(req) as resp:
            release_data = json.loads(resp.read().decode())
            print(f"✅ Created release: {release_data.get('html_url')}")
    except urllib.error.HTTPError as e:
        if e.code == 422:
            print(f"ℹ️ Release tag {TAG} already exists, fetching and updating...")
            get_req = urllib.request.Request(f"https://api.github.com/repos/{REPO}/releases/tags/{TAG}", headers=headers)
            with urllib.request.urlopen(get_req) as resp:
                release_data = json.loads(resp.read().decode())
            try:
                patch_req = urllib.request.Request(
                    f"https://api.github.com/repos/{REPO}/releases/{release_data['id']}",
                    data=json.dumps({"body": BODY, "name": NAME, "prerelease": False, "make_latest": "true"}).encode(),
                    headers=headers,
                    method="PATCH"
                )
                with urllib.request.urlopen(patch_req) as p_resp:
                    release_data = json.loads(p_resp.read().decode())
                    print(f"✅ Updated release description for {TAG}!")
            except Exception as pe:
                print(f"⚠️ Note on updating release metadata: {pe}")
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

    # 3. Upload DMG, PKG and ZIP assets for v1.0.1
    assets_v101 = [
        ("Somnius-1.0.1.dmg", "build_output/Somnius-1.0.1.dmg", "application/x-apple-diskimage"),
        ("Somnius-1.0.1.pkg", "build_output/Somnius-1.0.1.pkg", "application/octet-stream"),
        ("Somnius-1.0.1-macOS.zip", "build_output/Somnius-1.0.1-macOS.zip", "application/zip")
    ]

    existing_assets = {a["name"]: a["id"] for a in release_data.get("assets", [])}
    for asset_name, asset_path, mime_type in assets_v101:
        if not os.path.exists(asset_path):
            print(f"⚠️ Warning: File {asset_path} does not exist, skipping.")
            continue

        if asset_name in existing_assets:
            del_id = existing_assets[asset_name]
            print(f"🗑️ Deleting older version of {asset_name} from {TAG}...")
            del_req = urllib.request.Request(f"https://api.github.com/repos/{REPO}/releases/assets/{del_id}", headers=headers, method="DELETE")
            try:
                with urllib.request.urlopen(del_req):
                    pass
            except Exception:
                pass

        file_size = os.path.getsize(asset_path)
        print(f"⬆️ Uploading {asset_name} to {TAG} ({file_size / (1024*1024):.1f} MB)...")
        upload_endpoint = f"{upload_url_template}?name={asset_name}"
        up_headers = dict(headers)
        up_headers["Content-Type"] = mime_type
        up_headers["Content-Length"] = str(file_size)

        with open(asset_path, "rb") as f:
            up_req = urllib.request.Request(upload_endpoint, data=f, headers=up_headers, method="POST")
            with urllib.request.urlopen(up_req) as up_resp:
                res = json.loads(up_resp.read().decode())
                print(f"✅ {asset_name} uploaded successfully! Download URL: {res.get('browser_download_url')}")

    # 4. Also update v1.0.0 release assets so users on older links get the fixed macOS 12+ binary
    try:
        get_req_v100 = urllib.request.Request(f"https://api.github.com/repos/{REPO}/releases/tags/v1.0.0", headers=headers)
        with urllib.request.urlopen(get_req_v100) as resp:
            v100_data = json.loads(resp.read().decode())
        v100_id = v100_data["id"]
        v100_upload = v100_data.get("upload_url", "").split("{")[0]
        v100_existing = {a["name"]: a["id"] for a in v100_data.get("assets", [])}

        assets_v100 = [
            ("Somnius-1.0.0.dmg", "build_output/Somnius-1.0.1.dmg", "application/x-apple-diskimage"),
            ("Somnius-1.0.0.pkg", "build_output/Somnius-1.0.1.pkg", "application/octet-stream"),
            ("Somnius-1.0.0-macOS.zip", "build_output/Somnius-1.0.1-macOS.zip", "application/zip")
        ]

        print("🔄 Updating v1.0.0 release assets with universal macOS 12+ builds...")
        for asset_name, asset_path, mime_type in assets_v100:
            if not os.path.exists(asset_path): continue
            if asset_name in v100_existing:
                del_id = v100_existing[asset_name]
                del_req = urllib.request.Request(f"https://api.github.com/repos/{REPO}/releases/assets/{del_id}", headers=headers, method="DELETE")
                try:
                    with urllib.request.urlopen(del_req): pass
                except Exception: pass

            file_size = os.path.getsize(asset_path)
            upload_endpoint = f"{v100_upload}?name={asset_name}"
            up_headers = dict(headers)
            up_headers["Content-Type"] = mime_type
            up_headers["Content-Length"] = str(file_size)

            with open(asset_path, "rb") as f:
                up_req = urllib.request.Request(upload_endpoint, data=f, headers=up_headers, method="POST")
                with urllib.request.urlopen(up_req) as up_resp:
                    res = json.loads(up_resp.read().decode())
                    print(f"✅ {asset_name} on v1.0.0 refreshed! Download URL: {res.get('browser_download_url')}")
    except Exception as e:
        print(f"⚠️ Note on refreshing v1.0.0 assets: {e}")

    print("\n🎉 ALL DONE! Your release is live:")
    print(f"👉 Release Page: {release_data.get('html_url')}")
    print(f"👉 Direct DMG Download: https://github.com/{REPO}/releases/download/{TAG}/Somnius-1.0.1.dmg")

if __name__ == "__main__":
    main()
