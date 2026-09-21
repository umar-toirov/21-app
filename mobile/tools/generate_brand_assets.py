"""Builds every app icon / splash / web icon from assets/brand/habitzone_icon.svg.

Run from mobile/:   python tools/generate_brand_assets.py
Needs Pillow and Google Chrome (used only to render the SVG; set CHROME to override).

Writes:
  android/app/src/main/res/  adaptive icon layers, legacy launcher icons, splash images
  web/icons + web/favicon.png
  assets/brand/app_icon.png, app_glyph.png (white check, for dark), app_glyph_light.png
  (navy check, for light backgrounds), app_icon_1024.png (store icon)
"""

import os
import re
import subprocess
import sys
import tempfile

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "brand", "habitzone_icon.svg")
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")
CHROME = os.environ.get("CHROME") or next(
    (
        p
        for p in (
            r"C:\Program Files\Google\Chrome\Application\chrome.exe",
            r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
            "/usr/bin/google-chrome",
            "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
        )
        if os.path.exists(p)
    ),
    None,
)
DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
SIZE = 1024


def split_svg(svg: str):
    defs = re.search(r"<defs>.*?</defs>", svg, re.S).group(0)
    rects = re.findall(r"<rect[^>]*/>", svg)
    body = svg[svg.index(rects[-1]) + len(rects[-1]) : svg.rindex("</svg>")]
    return defs, rects, body


def wrap(defs: str, inner: str) -> str:
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {SIZE} {SIZE}">{defs}{inner}</svg>'
    )


def layer_svgs():
    svg = open(SRC, encoding="utf-8").read()
    defs, rects, body = split_svg(svg)
    square = [re.sub(r' rx="\d+"', "", r) for r in rects]
    strokes = re.findall(r"<(?:path|polyline)[^>]*/>", body)  # the coloured arcs + check
    mono = "".join(re.sub(r'stroke="url\(#\w+\)"', 'stroke="#ffffff"', s) for s in strokes)
    return {
        "full": svg,  # rounded square, as designed
        "bg": wrap(defs, "".join(square)),  # full-bleed background for adaptive icons
        "fg": wrap(defs, body),  # glyph only, transparent
        "mono": wrap(defs, mono),  # single-colour glyph for themed icons
        # navy check + faint navy tracks: the glyph for light backgrounds
        "glyph_light": wrap(defs, body.replace('stroke="#ffffff"', 'stroke="#033d95"')),
    }


def render(svg: str, out_png: str):
    if not CHROME:
        sys.exit("Chrome not found. Set the CHROME environment variable.")
    with tempfile.TemporaryDirectory() as tmp:
        svg_path = os.path.join(tmp, "l.svg")
        html_path = os.path.join(tmp, "l.html")
        open(svg_path, "w", encoding="utf-8").write(svg)
        open(html_path, "w", encoding="utf-8").write(
            f'<html><body style="margin:0;background:transparent">'
            f'<img src="l.svg" width="{SIZE}" height="{SIZE}" style="display:block"></body></html>'
        )
        subprocess.run(
            [
                CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
                "--force-device-scale-factor=1", "--default-background-color=00000000",
                f"--window-size={SIZE},{SIZE}", f"--screenshot={out_png}",
                "file:///" + html_path.replace("\\", "/"),
            ],
            check=True, capture_output=True, timeout=120,
        )
    img = Image.open(out_png).convert("RGBA")
    if img.size != (SIZE, SIZE):
        img = img.crop((0, 0, SIZE, SIZE))
    return img


def save(img: Image.Image, path: str, px: int, opaque_bg=None):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    out = img.resize((px, px), Image.LANCZOS)
    if opaque_bg is not None:
        base = Image.new("RGBA", out.size, opaque_bg)
        base.alpha_composite(out)
        out = base.convert("RGB")
    out.save(path)


def padded(img, canvas, glyph_share):
    """The image scaled to `glyph_share` of a transparent square canvas, centred."""
    c = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    g = img.resize((round(canvas * glyph_share),) * 2, Image.LANCZOS)
    c.alpha_composite(g, ((canvas - g.width) // 2, (canvas - g.height) // 2))
    return c


def main():
    tmp = tempfile.mkdtemp()
    imgs = {name: render(svg, os.path.join(tmp, f"{name}.png")) for name, svg in layer_svgs().items()}
    full, bg, fg, mono = imgs["full"], imgs["bg"], imgs["fg"], imgs["mono"]
    glyph_light = imgs["glyph_light"]

    # Adaptive icon: 108dp layers. The 72dp centre is always visible, so the glyph is
    # shrunk a little to keep the outer ring clear of circular masks.
    fg_a, mono_a = padded(fg, SIZE, 0.88), padded(mono, SIZE, 0.88)
    for d, m in DENSITIES.items():
        px = round(108 * m)
        save(bg, f"{RES}/drawable-{d}/ic_launcher_background.png", px)
        save(fg_a, f"{RES}/drawable-{d}/ic_launcher_foreground.png", px)
        save(mono_a, f"{RES}/drawable-{d}/ic_launcher_monochrome.png", px)
        # Legacy (pre-Android 8) launcher icon: the designed rounded square.
        save(full, f"{RES}/mipmap-{d}/ic_launcher.png", round(48 * m))

    # Splash: the glyph on the brand navy (colour set in values/colors.xml).
    os.makedirs(f"{RES}/drawable-nodpi", exist_ok=True)
    # Android 12: 288dp canvas, only the inner 192dp circle is visible.
    padded(fg, 1152, 0.90).save(f"{RES}/drawable-nodpi/splash_icon.png")
    # Older Android: a plain bitmap centred on the launch background.
    padded(fg, 720, 0.70).save(f"{RES}/drawable-nodpi/splash_logo.png")

    # In-app icon (intro, landing) and store icon.
    save(full, os.path.join(ROOT, "assets", "brand", "app_icon.png"), 512)
    save(fg, os.path.join(ROOT, "assets", "brand", "app_glyph.png"), 512)
    save(glyph_light, os.path.join(ROOT, "assets", "brand", "app_glyph_light.png"), 512)
    flat = Image.new("RGBA", (SIZE, SIZE))
    flat.alpha_composite(bg)
    flat.alpha_composite(fg)
    flat.convert("RGB").save(os.path.join(ROOT, "assets", "brand", "app_icon_1024.png"))

    # Web: normal icons use the rounded design; maskable icons need a full-bleed
    # background and extra padding for the safe zone.
    for name, px in (("Icon-192", 192), ("Icon-512", 512)):
        save(full, os.path.join(ROOT, "web", "icons", f"{name}.png"), px)
    for name, px in (("Icon-maskable-192", 192), ("Icon-maskable-512", 512)):
        canvas = bg.copy()
        canvas.alpha_composite(padded(fg, SIZE, 0.80))
        save(canvas, os.path.join(ROOT, "web", "icons", f"{name}.png"), px)
    save(full, os.path.join(ROOT, "web", "favicon.png"), 48)
    print("brand assets written")


if __name__ == "__main__":
    main()
