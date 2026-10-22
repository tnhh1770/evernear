#!/usr/bin/env python3
import sys
import os
import shutil
from PIL import Image

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOGO_OPTIONS_DIR = os.path.join(PROJECT_ROOT, "logo_options")
MOBILE_DIR = os.path.join(PROJECT_ROOT, "mobile")
LANDING_DIR = os.path.join(PROJECT_ROOT, "landing")

OPTIONS = {
    1: "option_1_friendly_shield_pulse",
    2: "option_2_ribbon_care_hand",
    3: "option_3_shield_warm_heart",
    4: "option_4_shelter_dome_pearl",
    5: "option_5_infinity_heart_loop",
    6: "option_6_care_hands_sprout",
    7: "option_7_monogram_e_shield",
    8: "option_8_family_embrace_heart",
    9: "option_9_shield_check_pulse_green",
    10: "option_10_shield_check_pulse_navy",
}

ANDROID_MIPMAPS = {
    "mipmap-mdpi": (48, 48),
    "mipmap-hdpi": (72, 72),
    "mipmap-xhdpi": (96, 96),
    "mipmap-xxhdpi": (144, 144),
    "mipmap-xxxhdpi": (192, 192),
}

IOS_ICONS = {
    "Icon-App-20x20@1x.png": (20, 20),
    "Icon-App-20x20@2x.png": (40, 40),
    "Icon-App-20x20@3x.png": (60, 60),
    "Icon-App-29x29@1x.png": (29, 29),
    "Icon-App-29x29@2x.png": (58, 58),
    "Icon-App-29x29@3x.png": (87, 87),
    "Icon-App-40x40@1x.png": (40, 40),
    "Icon-App-40x40@2x.png": (80, 80),
    "Icon-App-40x40@3x.png": (120, 120),
    "Icon-App-60x60@2x.png": (120, 120),
    "Icon-App-60x60@3x.png": (180, 180),
    "Icon-App-76x76@1x.png": (76, 76),
    "Icon-App-76x76@2x.png": (152, 152),
    "Icon-App-83.5x83.5@2x.png": (167, 167),
    "Icon-App-1024x1024@1x.png": (1024, 1024),
}


def switch_logo(option_num):
    if option_num not in OPTIONS:
        print(f"Error: Invalid option {option_num}. Choose from 1 to {max(OPTIONS.keys())}.")
        sys.exit(1)

    prefix = OPTIONS[option_num]
    print(f"Applying Logo Option {option_num}: {prefix}...")

    src_512 = os.path.join(LOGO_OPTIONS_DIR, f"{prefix}_512x512.png")
    src_192 = os.path.join(LOGO_OPTIONS_DIR, f"{prefix}_192x192.png")

    if not os.path.exists(src_512):
        print(f"Error: File not found: {src_512}")
        sys.exit(1)

    # Select matching favicon folder (Navy variant for option 10, Green/Default for others)
    fav_folder_name = "favicon_navy" if option_num == 10 else "favicon"
    favicon_dir = os.path.join(LOGO_OPTIONS_DIR, fav_folder_name)
    if not os.path.exists(favicon_dir):
        favicon_dir = os.path.join(LOGO_OPTIONS_DIR, "favicon")

    fav_192 = os.path.join(favicon_dir, "favicon_192.png")
    fav_512 = os.path.join(favicon_dir, "favicon_512.png")
    fav_1024_opaque = os.path.join(favicon_dir, "favicon_1024_opaque.png")
    fav_ico = os.path.join(favicon_dir, "favicon.ico")

    # 1. Update App Asset Logo & Favicon (Mobile In-App Assets)
    dst_app_logo = os.path.join(MOBILE_DIR, "assets", "images", "evernear_logo.png")
    shutil.copyfile(src_512, dst_app_logo)
    print(f"  [OK] Updated Mobile App Logo: {dst_app_logo}")

    if os.path.exists(fav_192):
        dst_app_fav = os.path.join(MOBILE_DIR, "assets", "images", "favicon.png")
        shutil.copyfile(fav_192, dst_app_fav)
        print(f"  [OK] Updated Mobile App Favicon Badge: {dst_app_fav}")

    # 2. Update Landing Page Logo & Favicon
    landing_img_dir = os.path.join(LANDING_DIR, "assets", "images")
    if os.path.exists(landing_img_dir):
        shutil.copyfile(src_512, os.path.join(landing_img_dir, "evernear_logo.png"))
        if os.path.exists(fav_192):
            shutil.copyfile(fav_192, os.path.join(landing_img_dir, "favicon.png"))
        if os.path.exists(fav_ico):
            shutil.copyfile(fav_ico, os.path.join(landing_img_dir, "favicon.ico"))
        print(f"  [OK] Updated Landing Page Logo & Favicon in {landing_img_dir}")

    # 3. Update Android launcher mipmaps (using clean symbol badge for crisp small sizes)
    launcher_src = fav_512 if os.path.exists(fav_512) else src_512
    img = Image.open(launcher_src).convert("RGBA")
    res_dir = os.path.join(MOBILE_DIR, "android", "app", "src", "main", "res")
    for folder, size in ANDROID_MIPMAPS.items():
        out_dir = os.path.join(res_dir, folder)
        os.makedirs(out_dir, exist_ok=True)
        out_file = os.path.join(out_dir, "ic_launcher.png")
        resized = img.resize(size, Image.Resampling.LANCZOS)
        resized.save(out_file, "PNG")
        print(f"  [OK] Updated Android launcher: {folder}/ic_launcher.png ({size[0]}x{size[1]})")

    # 4. Update iOS AppIcon set (opaque RGB required by iOS App Store)
    ios_iconset_dir = os.path.join(
        MOBILE_DIR, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset"
    )
    if os.path.exists(ios_iconset_dir):
        ios_src = fav_1024_opaque if os.path.exists(fav_1024_opaque) else launcher_src
        ios_base = Image.open(ios_src).convert("RGBA")
        white_bg = Image.new("RGB", ios_base.size, (255, 255, 255))
        white_bg.paste(ios_base, mask=ios_base.split()[3])
        for filename, size in IOS_ICONS.items():
            out_path = os.path.join(ios_iconset_dir, filename)
            resized = white_bg.resize(size, Image.Resampling.LANCZOS)
            resized.save(out_path, "PNG")
        print(f"  [OK] Updated {len(IOS_ICONS)} iOS AppIcons in {ios_iconset_dir}")

    # 5. Update Web Favicon & PWA Icons
    if os.path.exists(fav_192):
        dst_favicon = os.path.join(MOBILE_DIR, "web", "favicon.png")
        shutil.copyfile(fav_192, dst_favicon)
        print(f"  [OK] Updated Web Favicon (distinct badge): {dst_favicon}")

        if os.path.exists(fav_ico):
            shutil.copyfile(fav_ico, os.path.join(MOBILE_DIR, "web", "favicon.ico"))
            print(f"  [OK] Updated Web Favicon ICO: mobile/web/favicon.ico")

        web_icons_dir = os.path.join(MOBILE_DIR, "web", "icons")
        if os.path.exists(web_icons_dir):
            shutil.copyfile(fav_192, os.path.join(web_icons_dir, "Icon-192.png"))
            shutil.copyfile(fav_512, os.path.join(web_icons_dir, "Icon-512.png"))
            shutil.copyfile(fav_192, os.path.join(web_icons_dir, "Icon-maskable-192.png"))
            shutil.copyfile(fav_512, os.path.join(web_icons_dir, "Icon-maskable-512.png"))
            print(f"  [OK] Updated Web PWA Icons in {web_icons_dir}")
    else:
        dst_favicon = os.path.join(MOBILE_DIR, "web", "favicon.png")
        shutil.copyfile(src_192, dst_favicon)
        print(f"  [OK] Updated fallback favicon: {dst_favicon}")

    print(
        f"\nSuccessfully activated Option {option_num} ({prefix}) across Mobile, Android, iOS, Web PWA & Landing Page!"
    )


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"Usage: python3 switch_logo.py <1-{max(OPTIONS.keys())}>")
        sys.exit(1)
    try:
        opt = int(sys.argv[1])
        switch_logo(opt)
    except ValueError:
        print(f"Error: Option must be an integer between 1 and {max(OPTIONS.keys())}.")
        sys.exit(1)
