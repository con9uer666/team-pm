"""Generate app icon PNGs for team-pm-mobile.

Run from repo root:
    python mobile/tools/gen_icon.py

Outputs:
    mobile/assets/icon/icon.png            (1024x1024 full icon, with rounded bg)
    mobile/assets/icon/icon_foreground.png (1024x1024 foreground for adaptive icon, transparent bg, inset)
    mobile/assets/icon/icon_background.png (1024x1024 solid background)
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont


OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "icon")
os.makedirs(OUT_DIR, exist_ok=True)

SIZE = 1024

# Design tokens (match AppTheme.gradHero)
BLUE = (59, 130, 246)       # #3B82F6
PURPLE = (139, 92, 246)     # #8B5CF6
INDIGO = (99, 102, 241)     # #6366F1


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def radial_gradient(size, inner, outer):
    img = Image.new("RGB", (size, size), outer)
    px = img.load()
    cx = cy = size / 2
    max_r = math.hypot(cx, cy)
    for y in range(size):
        for x in range(size):
            t = math.hypot(x - cx, y - cy) / max_r
            px[x, y] = lerp(inner, outer, min(1.0, t))
    return img


def diagonal_gradient(size, top_left, bottom_right):
    img = Image.new("RGB", (size, size), top_left)
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * (size - 1))
            px[x, y] = lerp(top_left, bottom_right, t)
    return img


def rounded_mask(size, radius):
    m = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    return m


def draw_zhan_glyph(img, size, font_path, fill=(255, 255, 255, 255)):
    """Draw the '战' character centered, scaled to ~70% of canvas."""
    draw = ImageDraw.Draw(img)
    target_h = int(size * 0.58)
    # Pick a font size that makes 战 ~target_h tall.
    fs = int(target_h * 1.02)
    font = ImageFont.truetype(font_path, fs)
    text = "战"
    # Use getbbox for tight glyph metrics.
    bbox = font.getbbox(text)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    x = (size - tw) / 2 - bbox[0]
    y = (size - th) / 2 - bbox[1]
    # Soft shadow underneath.
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.text((x + 8, y + 10), text, font=font, fill=(0, 0, 0, 110))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=8))
    img.alpha_composite(shadow)
    draw.text((x, y), text, font=font, fill=fill)


def make_full_icon():
    # Background: diagonal blue->purple gradient with soft inner highlight.
    bg = diagonal_gradient(SIZE, BLUE, PURPLE).convert("RGBA")

    # Add a subtle highlight blob top-left.
    highlight = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    hd = ImageDraw.Draw(highlight)
    hd.ellipse(
        [SIZE * 0.05, SIZE * -0.10, SIZE * 0.70, SIZE * 0.55],
        fill=(255, 255, 255, 55),
    )
    highlight = highlight.filter(ImageFilter.GaussianBlur(radius=60))
    bg = Image.alpha_composite(bg, highlight)

    # Draw 战 glyph.
    draw_zhan_glyph(bg, SIZE, r"C:\Windows\Fonts\msyhbd.ttc")

    # Apply rounded corners (~22% radius for standard Android look).
    mask = rounded_mask(SIZE, int(SIZE * 0.22))
    out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    out.paste(bg, (0, 0), mask=mask)
    out.save(os.path.join(OUT_DIR, "icon.png"))


def make_adaptive():
    # Background layer: solid gradient, square (Android adaptive system masks itself).
    bg = diagonal_gradient(SIZE, BLUE, PURPLE).convert("RGBA")
    bg.save(os.path.join(OUT_DIR, "icon_background.png"))

    # Foreground: transparent canvas with inset 战 glyph so the system mask doesn't clip it.
    # Adaptive icons clip to a safe zone of ~66% in the center.
    fg = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    inner = int(SIZE * 0.66)
    inset = Image.new("RGBA", (inner, inner), (0, 0, 0, 0))
    draw_zhan_glyph(inset, inner, r"C:\Windows\Fonts\msyhbd.ttc")
    ox = (SIZE - inner) // 2
    fg.paste(inset, (ox, ox), inset)
    fg.save(os.path.join(OUT_DIR, "icon_foreground.png"))


if __name__ == "__main__":
    make_full_icon()
    make_adaptive()
    print("wrote icons to", os.path.abspath(OUT_DIR))
