"""Generates the store icon and feature graphic placeholders from game art.

Run: python tools/generate_store_assets.py
Writes docs/store/icon_512.png and docs/store/feature_graphic_1024x500.png.
These are placeholders: replace with painted store art before the Play listing.
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
STORE = ROOT / "docs" / "store"
MENU = ROOT / "docs" / "preview" / "m5b_menu_en.png"

GOLD = (242, 194, 48)
DARK = (15, 61, 30)
PANEL = (30, 107, 46)
LEAF = (123, 217, 58)
LIGHT = (245, 240, 225)
BLUE = (63, 169, 245)
BROWN = (92, 62, 30)


def _font(size: int, bold: bool = True):
    for name in (("arialbd.ttf" if bold else "arial.ttf"), "DejaVuSans-Bold.ttf"):
        for base in (Path("C:/Windows/Fonts"), Path("/usr/share/fonts/truetype/dejavu")):
            candidate = base / name
            if candidate.exists():
                return ImageFont.truetype(str(candidate), size)
    return ImageFont.load_default()


def icon() -> None:
    size = 512
    image = Image.new("RGBA", (size, size), DARK + (255,))
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((10, 10, size - 10, size - 10), radius=96, outline=GOLD, width=12)
    draw.rounded_rectangle((28, 28, size - 28, size - 28), radius=78, outline=(62, 154, 30), width=5)
    # Stylised tree: trunk, three canopy lobes and two blue rune lights.
    draw.rounded_rectangle((238, 286, 274, 432), radius=16, fill=BROWN, outline=GOLD, width=4)
    for cx, cy, r in ((256, 214, 120), (178, 262, 78), (334, 262, 78)):
        draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=LEAF, outline=DARK, width=8)
    draw.ellipse((330, 330, 362, 362), fill=BLUE)
    draw.ellipse((150, 342, 178, 370), fill=BLUE)
    image.convert("RGB").save(STORE / "icon_512.png", optimize=True)


def feature_graphic() -> None:
    width, height = 1024, 500
    menu = Image.open(MENU).convert("RGB")
    scale = max(width / menu.width, height / menu.height)
    menu = menu.resize((int(menu.width * scale) + 1, int(menu.height * scale) + 1), Image.LANCZOS)
    left = (menu.width - width) // 2
    top = (menu.height - height) // 2
    canvas = menu.crop((left, top, left + width, top + height))
    overlay = Image.new("RGB", (width, height), DARK)
    canvas = Image.blend(canvas, overlay, 0.86)
    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle((20, 20, width - 20, height - 20), radius=36, outline=GOLD, width=8)
    # Opaque copy plate so the captured menu labels never compete with the title.
    draw.rounded_rectangle((76, 72, width - 76, height - 72), radius=28, fill=PANEL, outline=GOLD, width=4)
    draw.text((width // 2, 168), "THE TREE", font=_font(104), fill=GOLD, anchor="mm")
    draw.text((width // 2, 292), "Idle Tower Defense", font=_font(54), fill=LIGHT, anchor="mm")
    draw.text((width // 2, 382), "Grow. Defend. Endure.", font=_font(32, bold=False), fill=LIGHT, anchor="mm")
    canvas.save(STORE / "feature_graphic_1024x500.png", optimize=True)


if __name__ == "__main__":
    STORE.mkdir(parents=True, exist_ok=True)
    icon()
    feature_graphic()
    print("wrote", STORE / "icon_512.png")
    print("wrote", STORE / "feature_graphic_1024x500.png")
