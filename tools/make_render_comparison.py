"""Create local screenshot comparison sheets without changing captured images."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
REF = ROOT / "docs/reference"
font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 22)
small = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 17)

sheet = Image.new("RGB", (1180, 950), "#16191e")
draw = ImageDraw.Draw(sheet)
draw.text((20, 16), "WuKong - actual simulator rendering comparison", font=font, fill="white")
draw.text((20, 52), "A window: 1140 x 700. Captures include SDK overlays; pose and timing vary.", font=small, fill="#abb3bf")
for row, view in enumerate(("spawn", "pool")):
    for col, version in enumerate(("before", "final")):
        path = REF / ("render-runtime-" + version + "-" + view + ".jpg")
        img = Image.open(path).convert("RGB")
        img.thumbnail((570, 390), Image.Resampling.LANCZOS)
        x, y = 20 + col * 580, 90 + row * 425
        draw.text((x, y), view.title() + " / " + version.title(), font=font, fill="white")
        sheet.paste(img, (x, y + 32))
sheet.save(REF / "render-runtime-comparison.jpg", quality=95)

sheet = Image.new("RGB", (1300, 840), "#16191e")
draw = ImageDraw.Draw(sheet)
draw.text((10, 10), "Final Unity camera views - 1280 x 720, FOV 55, ACES", font=font, fill="white")
for index, view in enumerate(("spawn", "pool", "wukong", "tiger")):
    img = Image.open(ROOT / ("unity/Assets/WuKong/Evidence/render-final-" + view + ".png"))
    img = img.resize((640, 360), Image.Resampling.LANCZOS)
    x, y = 10 + (index % 2) * 650, 50 + (index // 2) * 390
    draw.text((x, y), view.title(), font=font, fill="white")
    sheet.paste(img, (x, y + 27))
sheet.save(REF / "render-final-camera-views.jpg", quality=95)
print(REF / "render-runtime-comparison.jpg")
print(REF / "render-final-camera-views.jpg")
