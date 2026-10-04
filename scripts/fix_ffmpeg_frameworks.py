#!/usr/bin/env python3
import os
import sys
import glob
import shutil
import subprocess

def fix_framework(fw_dir):
    if not os.path.isdir(fw_dir):
        return False
    if os.path.exists(os.path.join(fw_dir, "Versions")):
        return False
    plist_path = os.path.join(fw_dir, "Info.plist")
    if not os.path.exists(plist_path):
        return False

    name = os.path.splitext(os.path.basename(fw_dir))[0]
    print(f"[fix_framework] Restructuring shallow macOS framework: {name} in {fw_dir}")

    # Make writable
    subprocess.run(["chmod", "-R", "u+w", fw_dir], check=False)

    versions_a = os.path.join(fw_dir, "Versions", "A")
    resources = os.path.join(versions_a, "Resources")
    os.makedirs(resources, exist_ok=True)

    # Move Info.plist
    os.rename(plist_path, os.path.join(resources, "Info.plist"))

    # Move binary
    binary = os.path.join(fw_dir, name)
    if os.path.exists(binary) and not os.path.islink(binary):
        os.rename(binary, os.path.join(versions_a, name))

    # Move Headers, Modules
    for folder in ["Headers", "Modules"]:
        folder_path = os.path.join(fw_dir, folder)
        if os.path.exists(folder_path) and not os.path.islink(folder_path):
            os.rename(folder_path, os.path.join(versions_a, folder))

    # Remove old signature if present
    sig = os.path.join(fw_dir, "_CodeSignature")
    if os.path.exists(sig):
        shutil.rmtree(sig, ignore_errors=True)

    # Create standard macOS symlinks
    current_link = os.path.join(fw_dir, "Versions", "Current")
    if not os.path.exists(current_link):
        os.symlink("A", current_link)

    bin_link = os.path.join(fw_dir, name)
    if not os.path.exists(bin_link):
        os.symlink(os.path.join("Versions", "Current", name), bin_link)

    res_link = os.path.join(fw_dir, "Resources")
    if not os.path.exists(res_link):
        os.symlink(os.path.join("Versions", "Current", "Resources"), res_link)

    for folder in ["Headers", "Modules"]:
        if os.path.exists(os.path.join(versions_a, folder)):
            sym_path = os.path.join(fw_dir, folder)
            if not os.path.exists(sym_path):
                os.symlink(os.path.join("Versions", "Current", folder), sym_path)

    return True

def main():
    fixed_count = 0

    # 1. Target build dir / Frameworks folder (from Xcode environment)
    target_build_dir = os.environ.get("TARGET_BUILD_DIR") or os.environ.get("BUILT_PRODUCTS_DIR")
    frameworks_folder = os.environ.get("FRAMEWORKS_FOLDER_PATH", "Contents/Frameworks")
    if target_build_dir:
        fw_path = os.path.join(target_build_dir, frameworks_folder)
        for item in glob.glob(os.path.join(fw_path, "*.framework")):
            if fix_framework(item):
                fixed_count += 1
                # Ad-hoc sign
                subprocess.run(["codesign", "--force", "--sign", "-", "--timestamp=none", item], check=False)

    # 2. Check DerivedData SourcePackages checkouts
    home = os.path.expanduser("~")
    sp_fws = glob.glob(f"{home}/Library/Developer/Xcode/DerivedData/**/SourcePackages/checkouts/FFmpegKit/Sources/*/macos*/*.framework", recursive=True)
    for item in sp_fws:
        if fix_framework(item):
            fixed_count += 1

    print(f"[fix_framework] Restructured {fixed_count} frameworks.")

if __name__ == "__main__":
    main()
