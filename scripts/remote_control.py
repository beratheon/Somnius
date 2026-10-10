#!/usr/bin/env python3
import sys
import os
import json
import subprocess
import urllib.request

REPO = "beratheon/Somnius"

def get_token():
    if "GITHUB_TOKEN" in os.environ and os.environ["GITHUB_TOKEN"]:
        return os.environ["GITHUB_TOKEN"].strip()
    home_token = os.path.expanduser("~/.somnius_token")
    if os.path.exists(home_token):
        with open(home_token, "r") as f:
            return f.read().strip()
    return None

def get_headers():
    token = get_token()
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "Somnius-RemoteControl",
        "X-GitHub-Api-Version": "2022-11-28"
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"
    return headers

def check_stats():
    print(f"📊 Checking download statistics and device traffic for {REPO}...\n")
    # 1. Release asset download counts
    try:
        req = urllib.request.Request(f"https://api.github.com/repos/{REPO}/releases", headers=get_headers())
        with urllib.request.urlopen(req) as resp:
            releases = json.loads(resp.read().decode())
            if releases:
                rel = releases[0]
                print(f"📦 Latest Release: {rel.get('name')} ({rel.get('tag_name')})")
                print(f"   Published At: {rel.get('published_at')}")
                total_dl = 0
                for a in rel.get("assets", []):
                    cnt = a.get("download_count", 0)
                    total_dl += cnt
                    print(f"   📥 {a.get('name')}: {cnt} downloads")
                print(f"\n   ⭐️ Total Package Downloads: {total_dl}")
            else:
                print("   No releases found.")
    except Exception as e:
        print(f"   Error fetching releases: {e}")

    # 2. Repository traffic
    try:
        req = urllib.request.Request(f"https://api.github.com/repos/{REPO}/traffic/views", headers=get_headers())
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode())
            print(f"\n👁️ Repo Traffic (last 14 days):")
            print(f"   Total Views: {data.get('count', 0)}")
            print(f"   Unique Visitors: {data.get('uniques', 0)}")
    except Exception as e:
        print(f"   Error fetching traffic views: {e}")

def set_kill_switch(lock: bool, title: str = None, message: str = None):
    action_text = "KILLING ALL USER ACCESS (LOCKING APP)" if lock else "RESTORING USER ACCESS (UNLOCKING APP)"
    print(f"🚨 {action_text}...")

    status_path = "app_status.json"
    if not os.path.exists(status_path):
        print(f"Error: {status_path} not found.")
        sys.exit(1)

    with open(status_path, "r") as f:
        config = json.load(f)

    config["kill_switch"] = lock
    config["beta_active"] = not lock
    if title:
        config["title"] = title
    if message:
        config["message"] = message

    with open(status_path, "w") as f:
        json.dump(config, f, indent=2)

    # Commit and push
    subprocess.run(["git", "add", "app_status.json"], check=True)
    msg = "remote-control: activate kill switch" if lock else "remote-control: deactivate kill switch"
    subprocess.run(["git", "commit", "-m", msg], check=True)

    token = get_token()
    if not token:
        print("Error: No GitHub token found. Set GITHUB_TOKEN or create ~/.somnius_token")
        sys.exit(1)
    remote_url = f"https://x-access-token:{token}@github.com/{REPO}.git"
    subprocess.run(["git", "push", remote_url, "main"], check=True)
    print(f"\n✅ SUCCESS! {status_path} updated on GitHub main branch.")
    if lock:
        print("🔒 All active instances of Somnius will now be locked out on next check.")
    else:
        print("🔓 App unlocked! Users can resume normal playback.")

def main():
    if len(sys.argv) < 2:
        print("Usage:")
        print("  python3 scripts/remote_control.py stats        - View download counts and visitors")
        print("  python3 scripts/remote_control.py lock         - Kill all users' access immediately")
        print("  python3 scripts/remote_control.py unlock       - Restore access for users")
        sys.exit(0)

    cmd = sys.argv[1].lower()
    if cmd == "stats":
        check_stats()
    elif cmd in ("lock", "kill"):
        title = sys.argv[2] if len(sys.argv) > 2 else "Beta Preview Expired"
        msg = sys.argv[3] if len(sys.argv) > 3 else "This preview build is no longer supported or active. Please download the latest official release."
        set_kill_switch(True, title, msg)
    elif cmd in ("unlock", "restore"):
        set_kill_switch(False)
    else:
        print(f"Unknown command '{cmd}'. Use 'stats', 'lock', or 'unlock'.")

if __name__ == "__main__":
    main()
