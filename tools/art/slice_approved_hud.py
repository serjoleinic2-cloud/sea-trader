"""Extract reusable UI artwork from the approved concept; no baked-in labels."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageStat

ROOT = Path(__file__).resolve().parents[2]
source = Image.open(ROOT / 'assets/ui/concepts/main_hud_concept_v1.png').convert('RGBA')
out = ROOT / 'assets/ui/styles/approved_hud'
out.mkdir(parents=True, exist_ok=True)

# Preserve the painted metal edges. Extend the clean navy strip across the
# interior, removing both the illustration and the original Russian lettering.
button = source.crop((34, 26, 214, 83))
for y in range(9, 51):
    sample = source.crop((105, 26 + y, 113, 27 + y)).convert('RGB')
    color = tuple(round(v) for v in ImageStat.Stat(sample).mean) + (255,)
    for x in range(17, 167):
        button.putpixel((x, y), color)
mask = Image.new('L', button.size)
ImageDraw.Draw(mask).polygon([(12, 0), (167, 0), (179, 10), (179, 46),
                             (168, 56), (8, 56), (0, 45), (0, 13)], fill=255)
button.putalpha(mask)
button.save(out / 'button_frame.png')

# The upper strip contains chart markings only, no UI labels or scene content.
strip = source.crop((20, 0, 1650, 23))
chart = Image.new('RGBA', (1630, 88))
for i in range(4):
    patch = strip if i % 2 == 0 else strip.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
    chart.paste(patch, (0, i * 23))
chart = Image.alpha_composite(chart, Image.new('RGBA', chart.size, (6, 19, 27, 95)))
draw = ImageDraw.Draw(chart)
draw.line((0, 84, 1630, 84), fill=(203, 158, 79, 255), width=2)
draw.line((0, 87, 1630, 87), fill=(38, 31, 20, 255), width=2)
chart.save(out / 'chart_backdrop.png')

icons = {
    'map': (54, 34, 104, 76), 'port': (234, 33, 287, 76),
    'fleet': (402, 29, 458, 76), 'captain': (589, 32, 645, 77),
    'tasks': (806, 34, 851, 77), 'money': (1086, 45, 1117, 80),
    'resource_timber': (1199, 45, 1233, 80),
    'resource_parts': (1305, 45, 1342, 80),
    'resource_fish': (1413, 46, 1453, 79),
    'magic_shards': (1518, 45, 1554, 80),
}
for name, bounds in icons.items():
    icon = source.crop(bounds)
    for y in range(icon.height):
        for x in range(icon.width):
            r, g, b, _ = icon.getpixel((x, y))
            # Softly remove the dark plaque behind each painted icon.
            alpha = max(0, min(255, int((max(r, g, b) - 48) * 4.0)))
            icon.putpixel((x, y), (r, g, b, alpha))
    icon.thumbnail((30, 30), Image.Resampling.LANCZOS)
    canvas = Image.new('RGBA', (30, 30))
    canvas.alpha_composite(icon, ((30 - icon.width) // 2, (30 - icon.height) // 2))
    canvas.save(out / (name + '.png'))
print('Extracted frame, chart backdrop and 10 icons:', out)
