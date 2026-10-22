#!/usr/bin/env python3
"""
Generate Google Play Store graphic assets for Evernear:
1. Feature Graphic (Ảnh đầu trang): 1024 x 500 px, PNG, < 15 MB
2. Phone Screenshots (Ảnh chụp màn hình điện thoại): 8 images, 1080 x 1920 px (9:16), PNG, < 8 MB
3. 7-inch Tablet Screenshots (Máy tính bảng 7 inch): 8 images, 1350 x 2400 px (9:16), PNG, < 8 MB
4. 10-inch Tablet Screenshots (Máy tính bảng 10 inch): 8 images, 1440 x 2560 px (9:16) & 2560 x 1440 px (16:9), PNG, < 8 MB
"""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path("/home/tnuc/project/Carely")
IMG_DIR = ROOT / "landing" / "img"
FONT_DIR = ROOT / "landing" / "fonts"
OUT_DIR = ROOT / "google_play_assets"

# Brand Palette (Forest Green Material 3)
PRIMARY_DARK = (30, 77, 56)       # #1E4D38
PRIMARY = (45, 106, 79)           # #2D6A4F
SECONDARY = (104, 166, 125)       # #68A67D
ACCENT = (82, 183, 136)           # #52B788
PRIMARY_LIGHT = (230, 242, 236)   # #E6F2EC
BG_SAGE = (244, 246, 243)         # #F4F6F3
WHITE = (255, 255, 255)
TEXT_DARK = (24, 48, 37)          # #183025
TEXT_MUTED = (88, 110, 99)        # #586E63
CARD_BORDER = (224, 228, 222)

SCREENS = [
    {
        "id": "01_monitored_home",
        "file": "screen_monitored_home.png",
        "badge": "ĐIỂM DANH 1 CHẠM",
        "title": "Báo bình an mỗi ngày\nchỉ với một chạm",
        "subtitle": "Nút “Tôi vẫn ổn” rõ ràng, chữ lớn kèm tín hiệu sinh hoạt thụ động tự nhiên.",
    },
    {
        "id": "02_guardian_dashboard",
        "file": "screen_guardian_dashboard.png",
        "badge": "CHẾ ĐỘ NGƯỜI GIÁM HỘ",
        "title": "An tâm theo dõi\nngười thân từ xa",
        "subtitle": "Nắm bắt ngay trạng thái an toàn, thời hạn điểm danh và mức độ ưu tiên.",
    },
    {
        "id": "03_check_in_detail",
        "file": "screen_check_in_detail.png",
        "badge": "XÁC NHẬN AN TOÀN",
        "title": "Gửi lời nhắn bình an\nđến cả gia đình",
        "subtitle": "Tùy chọn chia sẻ vị trí một lần duy nhất khi điểm danh, không theo dõi ngầm.",
    },
    {
        "id": "04_qr_invite",
        "file": "screen_qr_invite.png",
        "badge": "GHÉP ĐÔI BẢO MẬT",
        "title": "Kết nối hai chiều\nqua mã QR 48 giờ",
        "subtitle": "Chỉ người thân được bạn chấp thuận mới có thể xem trạng thái an toàn.",
    },
    {
        "id": "05_monitoring_settings",
        "file": "screen_monitoring_settings.png",
        "badge": "GIỜ NGỦ YÊN TĨNH",
        "title": "Tự động đóng băng\nkhung giờ nghỉ ban đêm",
        "subtitle": "Không bao giờ đánh thức người thân lúc nửa đêm nhờ lịch trình theo múi giờ.",
    },
    {
        "id": "06_incidents",
        "file": "screen_incidents.png",
        "badge": "CẢNH BÁO & SỰ KIỆN",
        "title": "Phối hợp xử lý sự cố\nnhanh chóng, minh bạch",
        "subtitle": "Nhận thông báo đa kênh qua Push, SMS, Telegram và xác nhận hỗ trợ kịp thời.",
    },
    {
        "id": "07_privacy_security",
        "file": "screen_privacy_security.png",
        "badge": "QUYỀN RIÊNG TƯ MẶC ĐỊNH",
        "title": "Không Camera, Không Micro\nKhông GPS chạy nền",
        "subtitle": "Tôn trọng tuyệt đối không gian sống tự lập của bố mẹ và người thân.",
    },
    {
        "id": "08_devices_settings",
        "file": "screen_devices.png",
        "badge": "QUẢN LÝ ĐA THIẾT BỊ",
        "title": "Đồng bộ tin cậy ngay cả\nkhi mất kết nối mạng",
        "subtitle": "Theo dõi dung lượng pin, kiểm soát thiết bị và tự động đồng bộ ngoại tuyến.",
    },
]


def load_font(name: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONT_DIR / name), size)


def draw_check_icon(draw: ImageDraw.ImageDraw, cx: int, cy: int, r: int, bg_color: tuple, fg_color: tuple):
    """Draw a crisp circular badge with a checkmark inside."""
    draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=bg_color)
    lw = max(2, r // 4)
    p1 = (cx - int(r * 0.42), cy + int(r * 0.02))
    p2 = (cx - int(r * 0.10), cy + int(r * 0.34))
    p3 = (cx + int(r * 0.45), cy - int(r * 0.28))
    draw.line([p1, p2, p3], fill=fg_color, width=lw, joint="curve")


def create_vertical_gradient(width: int, height: int, top_color: tuple, bottom_color: tuple) -> Image.Image:
    base = Image.new("RGB", (width, height), top_color)
    top_r, top_g, top_b = top_color
    bot_r, bot_g, bot_b = bottom_color
    draw = ImageDraw.Draw(base)
    for y in range(height):
        t = y / max(1, height - 1)
        r = int(top_r + (bot_r - top_r) * t)
        g = int(top_g + (bot_g - top_g) * t)
        b = int(top_b + (bot_b - top_b) * t)
        draw.line([(0, y), (width, y)], fill=(r, g, b))
    return base


def round_corners(im: Image.Image, radius: int) -> Image.Image:
    mask = Image.new("L", im.size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, im.size[0], im.size[1]), radius=radius, fill=255)
    out = im.convert("RGBA")
    out.putalpha(mask)
    return out


def paste_with_shadow(
    canvas: Image.Image,
    fg_rgba: Image.Image,
    pos: tuple[int, int],
    radius: int = 36,
    blur: int = 28,
    offset: tuple[int, int] = (0, 14),
    shadow_alpha: int = 55,
):
    w, h = fg_rgba.size
    pad = blur * 2 + 20
    shadow = Image.new("RGBA", (w + pad * 2, h + pad * 2), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(shadow)
    sdraw.rounded_rectangle(
        (pad, pad, pad + w, pad + h),
        radius=radius,
        fill=(15, 38, 27, shadow_alpha),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur))
    canvas.paste(
        shadow,
        (pos[0] - pad + offset[0], pos[1] - pad + offset[1]),
        shadow,
    )
    canvas.paste(fg_rgba, pos, fg_rgba)


def draw_phone_mockup_by_height(screen_img: Image.Image, target_h: int, bezel: int = 16, radius: int = 48) -> Image.Image:
    """
    Create a sleek phone mockup whose inner viewport matches the exact aspect ratio
    of `screen_img` (780x1688) so zero pixels are cropped or overwritten.
    """
    src_w, src_h = screen_img.size
    inner_h = target_h - bezel * 2
    inner_w = int(round(inner_h * (src_w / src_h)))
    target_w = inner_w + bezel * 2

    resized = screen_img.resize((inner_w, inner_h), Image.Resampling.LANCZOS)

    frame = Image.new("RGBA", (target_w, target_h), (0, 0, 0, 0))
    fdraw = ImageDraw.Draw(frame)
    fdraw.rounded_rectangle(
        (0, 0, target_w - 1, target_h - 1),
        radius=radius,
        fill=(26, 46, 36, 255),
        outline=(92, 138, 114, 255),
        width=3,
    )

    inner_rounded = round_corners(resized, max(12, radius - bezel))
    frame.paste(inner_rounded, (bezel, bezel), inner_rounded)

    # Subtle speaker notch at top bezel
    notch_w = max(56, target_w // 6)
    notch_h = max(5, bezel // 3)
    nx0 = (target_w - notch_w) // 2
    ny0 = (bezel - notch_h) // 2
    fdraw.rounded_rectangle((nx0, ny0, nx0 + notch_w, ny0 + notch_h), radius=notch_h // 2, fill=(55, 82, 68, 255))

    return frame


def extend_screen_horizontally(screen_img: Image.Image, target_w: int, target_h: int) -> Image.Image:
    """
    Extend a mobile screenshot to a wider tablet viewport (`target_w x target_h`) seamlessly:
    every horizontal row's left/right edge pixels are extended outward, and the centered UI sits cleanly in the middle!
    """
    src_w, src_h = screen_img.size
    scale = target_h / src_h
    scaled_w = int(round(src_w * scale))
    if scaled_w > int(target_w * 0.88):
        scale = (target_w * 0.88) / src_w
        scaled_w = int(round(src_w * scale))
    scaled_h = int(round(src_h * scale))

    resized = screen_img.resize((scaled_w, scaled_h), Image.Resampling.LANCZOS)
    bg_color = screen_img.getpixel((4, src_h // 2))
    canvas = Image.new("RGB", (target_w, target_h), bg_color)

    cx = (target_w - scaled_w) // 2
    cy = (target_h - scaled_h) // 2

    # Sample right edge (which never intersects the left-most active tab pill) for both left & right horizontal extensions
    edge_col = resized.crop((scaled_w - 1, 0, scaled_w, scaled_h))
    left_strip = edge_col.resize((cx, scaled_h), Image.Resampling.NEAREST)
    right_strip = edge_col.resize((target_w - cx - scaled_w, scaled_h), Image.Resampling.NEAREST)

    canvas.paste(left_strip, (0, cy))
    canvas.paste(right_strip, (cx + scaled_w, cy))
    canvas.paste(resized, (cx, cy))

    if cy > 0:
        top_strip = canvas.crop((0, cy, target_w, cy + 1)).resize((target_w, cy), Image.Resampling.NEAREST)
        canvas.paste(top_strip, (0, 0))
    if cy + scaled_h < target_h:
        bot_strip = canvas.crop((0, cy + scaled_h - 1, target_w, cy + scaled_h)).resize(
            (target_w, target_h - (cy + scaled_h)), Image.Resampling.NEAREST
        )
        canvas.paste(bot_strip, (0, cy + scaled_h))

    return canvas


def build_tablet_screen_ui(screen_img: Image.Image, inner_w: int, inner_h: int) -> Image.Image:
    """
    Build a genuine wide-screen Tablet UI canvas from the mobile screen:
    - Top tablet status bar with properly right-aligned Wi-Fi & Battery
    - Seamlessly extended top app bar & bottom navigation bar across the full tablet width
    """
    status_h = max(38, int(inner_h * 0.030))
    canvas = Image.new("RGB", (inner_w, inner_h), BG_SAGE)
    draw = ImageDraw.Draw(canvas)

    # Top tablet status bar
    draw.rectangle((0, 0, inner_w, status_h), fill=PRIMARY_DARK)
    f_status = load_font("BeVietnamPro-SemiBold.ttf", max(16, int(status_h * 0.52)))
    left_txt = "09:41  ·  Evernear Tablet"
    right_txt = "Wi-Fi · 100% Pin"
    rb = draw.textbbox((0, 0), right_txt, font=f_status)
    rw = rb[2] - rb[0]
    ty = (status_h - (rb[3] - rb[1])) // 2 - 2
    draw.text((28, ty), left_txt, font=f_status, fill=WHITE)
    draw.text((inner_w - rw - 28, ty), right_txt, font=f_status, fill=PRIMARY_LIGHT)

    body_h = inner_h - status_h
    body_img = extend_screen_horizontally(screen_img, inner_w, body_h)
    canvas.paste(body_img, (0, status_h))
    return canvas


def draw_tablet_mockup(screen_img: Image.Image, target_w: int, target_h: int, bezel: int = 24, radius: int = 44) -> Image.Image:
    inner_w = target_w - bezel * 2
    inner_h = target_h - bezel * 2
    tablet_ui = build_tablet_screen_ui(screen_img, inner_w, inner_h)

    frame = Image.new("RGBA", (target_w, target_h), (0, 0, 0, 0))
    fdraw = ImageDraw.Draw(frame)
    fdraw.rounded_rectangle(
        (0, 0, target_w - 1, target_h - 1),
        radius=radius,
        fill=(24, 42, 33, 255),
        outline=(95, 142, 118, 255),
        width=4,
    )
    inner_rounded = round_corners(tablet_ui, max(14, radius - bezel))
    frame.paste(inner_rounded, (bezel, bezel), inner_rounded)

    # Front camera dot on top bezel
    cam_r = max(4, bezel // 5)
    cx = target_w // 2
    cy = bezel // 2
    fdraw.ellipse((cx - cam_r, cy - cam_r, cx + cam_r, cy + cam_r), fill=(72, 108, 88, 255))
    return frame


def generate_feature_graphic():
    """
    1. Feature Graphic (Ảnh đầu trang): 1024 x 500 px, PNG, < 15 MB
    """
    out_folder = OUT_DIR / "01_anh_dau_trang_1024x500"
    out_folder.mkdir(parents=True, exist_ok=True)

    W, H = 1024, 500
    canvas = create_vertical_gradient(W, H, (22, 62, 45), (42, 98, 73))
    draw = ImageDraw.Draw(canvas)

    # Decorative soft glowing circles
    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    odraw = ImageDraw.Draw(overlay)
    odraw.ellipse((540, -120, 1080, 420), fill=(82, 183, 136, 38))
    odraw.ellipse((620, 140, 1120, 640), fill=(230, 242, 236, 28))
    odraw.ellipse((-120, 280, 260, 620), fill=(82, 183, 136, 25))
    canvas.paste(overlay, (0, 0), overlay)

    # Logo + Brand Name
    logo = Image.open(IMG_DIR / "logo.png").convert("RGBA").resize((68, 68), Image.Resampling.LANCZOS)
    logo_bg = Image.new("RGBA", (76, 76), (0, 0, 0, 0))
    ldraw = ImageDraw.Draw(logo_bg)
    ldraw.rounded_rectangle((0, 0, 75, 75), radius=20, fill=WHITE)
    logo_bg.paste(logo, (4, 4), logo)
    canvas.paste(logo_bg, (52, 42), logo_bg)

    f_brand = load_font("BeVietnamPro-ExtraBold.ttf", 36)
    f_kicker = load_font("BeVietnamPro-SemiBold.ttf", 14)
    draw.text((144, 44), "Evernear", font=f_brand, fill=WHITE)
    draw.text((146, 88), "ĐỒNG HÀNH AN TOÀN · QUYỀN RIÊNG TƯ MẶC ĐỊNH", font=f_kicker, fill=(168, 224, 195))

    # Main Headline
    f_h1 = load_font("BeVietnamPro-Bold.ttf", 34)
    draw.text((52, 144), "Luôn ở gần người thương,", font=f_h1, fill=WHITE)
    draw.text((52, 188), "theo cách bình yên nhất.", font=f_h1, fill=(168, 230, 199))

    # Subtitle
    f_sub = load_font("BeVietnamPro-Regular.ttf", 16)
    draw.text(
        (52, 246),
        "Điểm danh “Tôi vẫn ổn” một chạm, tự động đóng băng\ngiờ ngủ ban đêm và cảnh báo đa kênh tới người thân.",
        font=f_sub,
        fill=(226, 240, 233),
        spacing=6,
    )

    # 3 Value Pills at bottom left with vector checkmark icons
    pills = [
        "Điểm danh 1 chạm",
        "Không Camera · Không GPS nền",
        "Cảnh báo đa kênh (Push, SMS, Telegram)",
    ]
    f_pill = load_font("BeVietnamPro-SemiBold.ttf", 14)
    px, py = 52, 332
    for idx, text in enumerate(pills):
        bbox = draw.textbbox((0, 0), text, font=f_pill)
        pw = (bbox[2] - bbox[0]) + 50
        ph = 38
        if idx == 2:
            px = 52
            py = 382
        draw.rounded_rectangle(
            (px, py, px + pw, py + ph),
            radius=19,
            fill=(35, 86, 63),
            outline=(104, 166, 125),
            width=1,
        )
        draw_check_icon(draw, px + 20, py + ph // 2, 10, ACCENT, PRIMARY_DARK)
        draw.text((px + 36, py + 9), text, font=f_pill, fill=WHITE)
        px += pw + 12

    # Two Phone Mockups on the right side (exact aspect ratio, zero cropping)
    s_home = Image.open(IMG_DIR / "screen_monitored_home.png").convert("RGB")
    s_guard = Image.open(IMG_DIR / "screen_guardian_dashboard.png").convert("RGB")

    phone_back = draw_phone_mockup_by_height(s_guard, 416, bezel=9, radius=26)
    phone_front = draw_phone_mockup_by_height(s_home, 444, bezel=10, radius=28)

    paste_with_shadow(canvas, phone_back, (780, 54), radius=26, blur=20, offset=(0, 10), shadow_alpha=75)
    paste_with_shadow(canvas, phone_front, (588, 28), radius=28, blur=24, offset=(0, 12), shadow_alpha=90)

    out_path = out_folder / "evernear_feature_graphic_1024x500.png"
    canvas.convert("RGB").save(out_path, format="PNG", optimize=True)
    return out_path


def render_vertical_showcase(
    screen_info: dict,
    width: int,
    height: int,
    is_tablet: bool = False,
) -> Image.Image:
    """
    Render a 9:16 portrait showcase image (for Phone 1080x1920, 7" Tablet 1350x2400, 10" Tablet 1440x2560).
    """
    scale = width / 1080.0
    canvas = create_vertical_gradient(width, height, (235, 244, 239), (244, 246, 243))
    draw = ImageDraw.Draw(canvas)

    # Top decorative soft arc
    arc_overlay = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    adraw = ImageDraw.Draw(arc_overlay)
    adraw.ellipse(
        (int(-width * 0.25), int(-height * 0.12), int(width * 1.25), int(height * 0.28)),
        fill=(45, 106, 79, 18),
    )
    canvas.paste(arc_overlay, (0, 0), arc_overlay)

    # Badge pill
    f_badge = load_font("BeVietnamPro-Bold.ttf", int(22 * scale))
    badge_text = screen_info["badge"]
    bb = draw.textbbox((0, 0), badge_text, font=f_badge)
    bw = (bb[2] - bb[0]) + int(48 * scale)
    bh = int(50 * scale)
    bx = (width - bw) // 2
    by = int(64 * scale)
    draw.rounded_rectangle((bx, by, bx + bw, by + bh), radius=bh // 2, fill=PRIMARY_LIGHT, outline=SECONDARY, width=max(1, int(2 * scale)))
    draw.text((bx + int(24 * scale), by + int(11 * scale)), badge_text, font=f_badge, fill=PRIMARY_DARK)

    # Title (2 lines centered)
    f_title = load_font("BeVietnamPro-ExtraBold.ttf", int(50 * scale))
    title_y = int(136 * scale)
    for line in screen_info["title"].split("\n"):
        tb = draw.textbbox((0, 0), line, font=f_title)
        tw = tb[2] - tb[0]
        draw.text(((width - tw) // 2, title_y), line, font=f_title, fill=TEXT_DARK)
        title_y += int(64 * scale)

    # Subtitle (wrapped nicely)
    f_sub = load_font("BeVietnamPro-Medium.ttf", int(25 * scale))
    sub_words = screen_info["subtitle"].split(" ")
    lines = []
    cur = ""
    max_sub_w = int(width * 0.84)
    for w in sub_words:
        test = (cur + " " + w).strip()
        if draw.textbbox((0, 0), test, font=f_sub)[2] <= max_sub_w:
            cur = test
        else:
            lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)

    sub_y = title_y + int(12 * scale)
    for line in lines:
        sb = draw.textbbox((0, 0), line, font=f_sub)
        sw = sb[2] - sb[0]
        draw.text(((width - sw) // 2, sub_y), line, font=f_sub, fill=TEXT_MUTED)
        sub_y += int(36 * scale)

    # Device Mockup placement
    src_img = Image.open(IMG_DIR / screen_info["file"]).convert("RGB")
    dev_top = sub_y + int(30 * scale)
    dev_h = height - dev_top - int(46 * scale)

    if not is_tablet:
        mockup = draw_phone_mockup_by_height(
            src_img,
            dev_h,
            bezel=max(14, int(18 * scale)),
            radius=int(48 * scale),
        )
        dev_w, dev_h = mockup.size
    else:
        dev_w = int(width * 0.86)
        mockup = draw_tablet_mockup(
            src_img,
            dev_w,
            dev_h,
            bezel=max(20, int(24 * scale)),
            radius=int(44 * scale),
        )

    dx = (width - dev_w) // 2
    dy = dev_top + (height - dev_top - int(40 * scale) - dev_h) // 2
    paste_with_shadow(
        canvas,
        mockup,
        (dx, dy),
        radius=int(48 * scale),
        blur=int(30 * scale),
        offset=(0, int(16 * scale)),
        shadow_alpha=60,
    )

    return canvas.convert("RGB")


def render_raw_9x16_phone(screen_info: dict, width: int = 1080, height: int = 1920) -> Image.Image:
    """
    Pure unframed 9:16 phone screenshot (1080x1920) fitted cleanly with top & bottom bars extended seamlessly.
    """
    src_img = Image.open(IMG_DIR / screen_info["file"]).convert("RGB")
    return extend_screen_horizontally(src_img, width, height)


def render_landscape_10inch_tablet(screen_info: dict, idx: int, width: int = 2560, height: int = 1440) -> Image.Image:
    """
    Render a 16:9 landscape 10-inch tablet showcase (2560 x 1440 px, each side >= 1080 px).
    """
    canvas = create_vertical_gradient(width, height, (233, 243, 238), (244, 246, 243))
    draw = ImageDraw.Draw(canvas)

    # Left column copy (x = 120 .. 1020)
    logo = Image.open(IMG_DIR / "logo.png").convert("RGBA").resize((84, 84), Image.Resampling.LANCZOS)
    canvas.paste(logo, (120, 140), logo)
    f_brand = load_font("BeVietnamPro-ExtraBold.ttf", 48)
    draw.text((224, 152), "Evernear", font=f_brand, fill=PRIMARY_DARK)

    # Badge
    f_badge = load_font("BeVietnamPro-Bold.ttf", 24)
    badge_text = screen_info["badge"]
    bb = draw.textbbox((0, 0), badge_text, font=f_badge)
    bw = (bb[2] - bb[0]) + 48
    bh = 56
    draw.rounded_rectangle((120, 290, 120 + bw, 290 + bh), radius=28, fill=PRIMARY_LIGHT, outline=SECONDARY, width=2)
    draw.text((144, 304), badge_text, font=f_badge, fill=PRIMARY_DARK)

    # Headline
    f_title = load_font("BeVietnamPro-ExtraBold.ttf", 62)
    ty = 390
    for line in screen_info["title"].split("\n"):
        draw.text((120, ty), line, font=f_title, fill=TEXT_DARK)
        ty += 82

    # Subtitle
    f_sub = load_font("BeVietnamPro-Medium.ttf", 30)
    words = screen_info["subtitle"].split(" ")
    lines, cur = [], ""
    for w in words:
        test = (cur + " " + w).strip()
        if draw.textbbox((0, 0), test, font=f_sub)[2] <= 860:
            cur = test
        else:
            lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)

    sy = ty + 30
    for line in lines:
        draw.text((120, sy), line, font=f_sub, fill=TEXT_MUTED)
        sy += 46

    # Bottom pill highlights with vector checkmarks
    f_check = load_font("BeVietnamPro-SemiBold.ttf", 26)
    highlights = [
        "Quyền riêng tư mặc định (Không Camera / GPS nền)",
        "Tự động đóng băng giờ ngủ ban đêm (Quiet Hours)",
        "Cảnh báo đa kênh qua Push, SMS & Telegram",
    ]
    hy = max(sy + 64, 960)
    for h_text in highlights:
        draw_check_icon(draw, 140, hy + 18, 16, PRIMARY, WHITE)
        draw.text((172, hy), h_text, font=f_check, fill=PRIMARY_DARK)
        hy += 62

    # Right column: 10-inch Landscape Tablet Device Mockup (1320 x 1120)
    tab_w, tab_h = 1320, 1120
    bezel = 32
    inner_w, inner_h = tab_w - bezel * 2, tab_h - bezel * 2

    primary_scr = Image.open(IMG_DIR / screen_info["file"]).convert("RGB")
    companion_info = SCREENS[(idx + 1) % len(SCREENS)]
    companion_scr = Image.open(IMG_DIR / companion_info["file"]).convert("RGB")

    tablet_ui = Image.new("RGB", (inner_w, inner_h), BG_SAGE)
    tdraw = ImageDraw.Draw(tablet_ui)

    # Top tablet app bar
    bar_h = 68
    tdraw.rectangle((0, 0, inner_w, bar_h), fill=PRIMARY_DARK)
    f_bar = load_font("BeVietnamPro-Bold.ttf", 24)
    f_bar_right = load_font("BeVietnamPro-Medium.ttf", 20)
    right_status = "Đang bảo vệ · Pin 100%"
    rs_box = tdraw.textbbox((0, 0), right_status, font=f_bar_right)
    tdraw.text((32, 18), "Evernear  ·  Giao diện Máy tính bảng 10 inch", font=f_bar, fill=WHITE)
    tdraw.text((inner_w - (rs_box[2] - rs_box[0]) - 32, 20), right_status, font=f_bar_right, fill=PRIMARY_LIGHT)

    body_h = inner_h - bar_h
    pane_w = (inner_w - 48) // 2

    for p_idx, scr in enumerate([primary_scr, companion_scr]):
        px = 16 + p_idx * (pane_w + 16)
        py = bar_h + 16
        ph = body_h - 32
        pane_card = extend_screen_horizontally(scr, pane_w, ph)
        pane_rounded = round_corners(pane_card, 24)
        tablet_ui.paste(pane_rounded, (px, py), pane_rounded)

    frame = Image.new("RGBA", (tab_w, tab_h), (0, 0, 0, 0))
    fdraw = ImageDraw.Draw(frame)
    fdraw.rounded_rectangle((0, 0, tab_w - 1, tab_h - 1), radius=52, fill=(24, 42, 33, 255), outline=(95, 142, 118, 255), width=4)
    ui_rounded = round_corners(tablet_ui, 28)
    frame.paste(ui_rounded, (bezel, bezel), ui_rounded)

    paste_with_shadow(canvas, frame, (1120, (height - tab_h) // 2), radius=52, blur=36, offset=(0, 18), shadow_alpha=65)
    return canvas.convert("RGB")


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    # 1. Feature Graphic (1024x500)
    fg_path = generate_feature_graphic()
    print(f"[1/4] Generated Feature Graphic: {fg_path}")

    # 2. Phone Screenshots (1080x1920 - 9:16)
    phone_dir = OUT_DIR / "02_anh_dien_thoai_1080x1920"
    phone_raw_dir = OUT_DIR / "02_anh_dien_thoai_thuan_1080x1920"
    phone_dir.mkdir(parents=True, exist_ok=True)
    phone_raw_dir.mkdir(parents=True, exist_ok=True)

    for item in SCREENS:
        img = render_vertical_showcase(item, 1080, 1920, is_tablet=False)
        img.save(phone_dir / f"phone_{item['id']}_1080x1920.png", format="PNG", optimize=True)

        raw_img = render_raw_9x16_phone(item, 1080, 1920)
        raw_img.save(phone_raw_dir / f"phone_raw_{item['id']}_1080x1920.png", format="PNG", optimize=True)
    print(f"[2/4] Generated 8 Phone Screenshots (Framed + Raw) in {phone_dir}")

    # 3. 7-inch Tablet Screenshots (1350x2400 - exact 9:16, between 320px and 3840px)
    tab7_dir = OUT_DIR / "03_anh_tablet_7inch_1350x2400"
    tab7_dir.mkdir(parents=True, exist_ok=True)
    for item in SCREENS:
        img = render_vertical_showcase(item, 1350, 2400, is_tablet=True)
        img.save(tab7_dir / f"tablet7_{item['id']}_1350x2400.png", format="PNG", optimize=True)
    print(f"[3/4] Generated 8 7-inch Tablet Screenshots in {tab7_dir}")

    # 4. 10-inch Tablet Screenshots (1440x2560 portrait 9:16 & 2560x1440 landscape 16:9, each side >= 1080px)
    tab10_portrait_dir = OUT_DIR / "04_anh_tablet_10inch_doc_1440x2560"
    tab10_landscape_dir = OUT_DIR / "04_anh_tablet_10inch_ngang_2560x1440"
    tab10_portrait_dir.mkdir(parents=True, exist_ok=True)
    tab10_landscape_dir.mkdir(parents=True, exist_ok=True)
    for idx, item in enumerate(SCREENS):
        img_p = render_vertical_showcase(item, 1440, 2560, is_tablet=True)
        img_p.save(tab10_portrait_dir / f"tablet10_portrait_{item['id']}_1440x2560.png", format="PNG", optimize=True)

        img_l = render_landscape_10inch_tablet(item, idx, 2560, 1440)
        img_l.save(tab10_landscape_dir / f"tablet10_landscape_{item['id']}_2560x1440.png", format="PNG", optimize=True)
    print(f"[4/4] Generated 8 Portrait + 8 Landscape 10-inch Tablet Screenshots in {tab10_portrait_dir}")


if __name__ == "__main__":
    main()
