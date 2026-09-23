"""Google Play graphics: store icon (512x512) and feature graphic (1024x500) in store/.

Run from mobile/ after generate_brand_assets.py:   python tools/generate_store_assets.py
"""

import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "store")
os.makedirs(OUT, exist_ok=True)
icon = Image.open(os.path.join(ROOT, "assets", "brand", "app_icon_1024.png")).convert("RGB")
glyph = Image.open(os.path.join(ROOT, "assets", "brand", "app_glyph.png")).convert("RGBA")

icon.resize((512, 512), Image.LANCZOS).save(os.path.join(OUT, "icon-512.png"))


def font(size, bold=True):
    for name in ("segoeuib.ttf" if bold else "segoeui.ttf", "arialbd.ttf" if bold else "arial.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


W, H = 1024, 500
navy, blue = (3, 61, 149), (28, 116, 187)
img = Image.new("RGB", (W, H))
px = img.load()
for y in range(H):
    for x in range(W):
        t = (x / W * 0.6 + y / H * 0.4)
        px[x, y] = tuple(round(navy[i] + (blue[i] - navy[i]) * t) for i in range(3))

g = glyph.resize((260, 260), Image.LANCZOS)
img.paste(g, (90, (H - 260) // 2), g)
d = ImageDraw.Draw(img)
d.text((400, 150), "Habit Zone", font=font(84), fill="white")
d.text((404, 262), "Build discipline, one day at a time.", font=font(34, False), fill=(255, 255, 255, 220))
d.text((404, 318), "21-day challenges  •  Streaks  •  Groups", font=font(26, False), fill=(190, 212, 240))
img.save(os.path.join(OUT, "feature-graphic-1024x500.png"))
print("store assets written to", OUT)
