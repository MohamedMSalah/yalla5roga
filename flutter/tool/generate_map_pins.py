"""Generate Discover map PNGs and editable SVGs with Pillow (pip install Pillow).

Run from any directory. Set MAP_PIN_FONT to an outline color emoji font
(Segoe UI Emoji by default on Windows). Add future stable catalog IDs to PINS.
"""
import html
import os
import sys
from math import cos, pi, sin
from pathlib import Path
from xml.sax.saxutils import quoteattr

from PIL import Image, ImageColor, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/map/pins"
LANDMARK_OUT = OUT.parent / "landmarks"
SVG = ROOT / "tool/map_pin_sources"
REGISTRY = ROOT / "lib/core/maps/yalla_pin_categories.dart"

# The catalog keys were read from Neon place_categories, including inactive rows.
# Colors are RGB hex and the symbols are Unicode pictograms.
PINS = {
    "restaurants": ("db581f", 0x1F374),
    "fast_food": ("dc713d", 0x1F354),
    "cafes": ("95613d", 0x2615),
    "coffee_shops": ("855740", 0x1FAD6),
    "bakeries": ("a66824", 0x1F950),
    "dessert_shops": ("b84c6c", 0x1F370),
    "ice_cream": ("b05381", 0x1F366),
    "cinemas": ("7546b4", 0x1F3AC),
    "bowling": ("c14880", 0x1F3B3),
    "escape_rooms": ("784ea2", 0x1F510),
    "gaming_centers": ("5253a6", 0x1F3AE),
    "arcades": ("4e51a2", 0x1F579),
    "vr_centers": ("5548a6", 0x1F97D),
    "trampoline_parks": ("9960ab", 0x1F938),
    "amusement_parks": ("a44692", 0x1F3A1),
    "billiards": ("4c7873", 0x1F3B1),
    "parks": ("26815d", 0x1F333),
    "gardens": ("567b43", 0x1F337),
    "zoos": ("39794c", 0x1F981),
    "picnic_areas": ("44805c", 0x1F9FA),
    "outdoor_attractions": ("337c69", 0x1F3DE),
    "shopping_malls": ("345fb0", 0x1F6CD),
    "shopping_centers": ("326da4", 0x1F6D2),
    "markets": ("307895", 0x1F3EC),
    "karting": ("b74f46", 0x1F3CE),
    "sports_centers": ("277884", 0x1F3CB),
    "ice_skating": ("4177b7", 0x26F8),
    "indoor_activities": ("4868af", 0x1F3AF),
    "adventure_activities": ("367f6a", 0x1F9D7),
    "museums": ("8b6650", 0x1F3DB),
    "art_galleries": ("a55283", 0x1F3A8),
    "historical_attractions": ("946b3f", 0x1F3F0),
    "cultural_centers": ("685793", 0x1F3AD),
    "lounges": ("815990", 0x1F6CB),
    "social_clubs": ("3a7396", 0x1F465),
    "group_activities": ("407e93", 0x1F91D),
    "water_parks": ("2b78ab", 0x1F3C4),
    "tourist_attractions": ("8a693c", 0x1F4F7),
    "theaters": ("8f4c76", 0x1F3AD),
    "football_fields": ("307a54", 0x26BD),
    "padel_courts": ("437a67", 0x1F3BE),
    "swimming_pools": ("237caa", 0x1F3CA),
    "kids_entertainment": ("b05171", 0x1F9F8),
    "family_entertainment": ("a65b3d", 0x1F3AA),
}
SPECIAL = {
    "fallback": ("596781", 0x25C6),
    "private": ("7746c5", 0x2605),
    "temporary": ("345dc4", 0x2316),
}
LANDMARKS = {
    "landmark_school": [
        [(2, 11), (16, 4), (30, 11), (16, 18)],
        [(8, 16), (16, 20), (24, 16), (24, 24), (16, 28), (8, 24)],
        [(28, 12), (30, 12), (30, 23), (28, 23)],
    ],
    "landmark_culture": [
        [(2, 11), (16, 3), (30, 11), (30, 13), (2, 13)],
        *[[(x, 15), (x+3, 15), (x+3, 25), (x, 25)] for x in (6, 14, 22)],
        [(3, 27), (29, 27), (29, 30), (3, 30)],
    ],
}

SCALE = 3
FONT = Path(os.environ.get("MAP_PIN_FONT", "C:/Windows/Fonts/seguiemj.ttf"))
SHAPE = "M64 127 C52 112 19 79 17 57 C11 27 33 5 64 5 C95 5 117 27 111 57 C109 79 76 112 64 127 Z"
CURVES = [
    ((64, 127), (52, 112), (19, 79), (17, 57)),
    ((17, 57), (11, 27), (33, 5), (64, 5)),
    ((64, 5), (95, 5), (117, 27), (111, 57)),
    ((111, 57), (109, 79), (76, 112), (64, 127)),
]


def mix(a, b, amount):
    return tuple(round(x + (y - x) * amount) for x, y in zip(a, b))


def icon(draw, center, code, size, *, color=True, fill="white"):
    face = ImageFont.truetype(str(FONT), size * SCALE)
    glyph = chr(code)
    x0, y0, x1, y1 = draw.textbbox((0, 0), glyph, font=face, embedded_color=color)
    x, y = (v * SCALE for v in center)
    draw.text(
        (round(x - (x0 + x1) / 2), round(y - (y0 + y1) / 2)),
        glyph, font=face, embedded_color=color, fill=fill,
    )


def polygon(draw, points, fill):
    draw.polygon([(round(x * SCALE), round(y * SCALE)) for x, y in points], fill=fill)


def pin_boundary(center_x=64, tip_y=127, width_scale=1, height_scale=1):
    boundary = []
    for curve in CURVES:
        for step in range(33):
            t = step / 32
            weights = ((1-t)**3, 3*(1-t)**2*t, 3*(1-t)*t*t, t**3)
            x, y = (sum(point[axis] * w for point, w in zip(curve, weights))
                    for axis in (0, 1))
            boundary.append((
                round(SCALE * (center_x + (x - 64) * width_scale)),
                round(SCALE * (tip_y + (y - 127) * height_scale)),
            ))
    return boundary


def map_overlays():
    OUT.mkdir(parents=True, exist_ok=True)
    # The foreground tip is the anchor. The face is centered at (96, 96)
    # so MapLibre can align dynamic count text without baked-in numerals.
    for theme, left, right, top, bottom, outline in [
        ("light", "#9d70da", "#6945a9", "#7835d5", "#5022a3", "#c6a1f2"),
        ("dark", "#9866d8", "#583f9a", "#7b38c5", "#3f226f", "#cda2fb"),
    ]:
        size = 192 * SCALE
        sprite = Image.new("RGBA", (size, size))
        draw = ImageDraw.Draw(sprite)
        draw.polygon(pin_boundary(46, 144, .80, 1.04), fill=left)
        draw.polygon(pin_boundary(146, 135, .77, .88), fill=right)
        foreground = pin_boundary(96, 191, 1.13, 1.08)
        mask = Image.new("L", sprite.size)
        ImageDraw.Draw(mask).polygon(foreground, fill=255)
        gradient = Image.new("RGBA", sprite.size)
        gradient_draw = ImageDraw.Draw(gradient)
        top_color, bottom_color = ImageColor.getrgb(top), ImageColor.getrgb(bottom)
        for y in range(size):
            position = max(0, min(1, (y / SCALE - 59) / (191 - 59)))
            gradient_draw.line((0, y, size, y), fill=mix(top_color, bottom_color, position))
        gradient.putalpha(mask)
        sprite.alpha_composite(gradient)
        draw.line(foreground, fill=outline, width=4 * SCALE, joint="curve")
        sprite.resize((192, 192), Image.Resampling.LANCZOS).save(OUT / f"cluster_{theme}.png")

    glow_alpha = Image.new("L", (128 * SCALE, 128 * SCALE))
    ImageDraw.Draw(glow_alpha).polygon(pin_boundary(), fill=144)
    glow_alpha = glow_alpha.filter(ImageFilter.MaxFilter(25))
    glow_alpha = glow_alpha.filter(ImageFilter.GaussianBlur(6 * SCALE))
    glow = Image.new("RGBA", glow_alpha.size, "#a374f5")
    glow.putalpha(glow_alpha)
    glow.resize((128, 128), Image.Resampling.LANCZOS).save(OUT / "selection_glow.png")


def pin(file_id, hex_color, glyph):
    base = ImageColor.getrgb(f"#{hex_color}")
    top = mix(base, (255, 255, 255), .22)
    bottom = mix(base, (21, 13, 44), .16)
    inner = mix(base, (255, 255, 255), .28)
    mask = Image.new("L", (128 * SCALE, 128 * SCALE))
    ImageDraw.Draw(mask).polygon(pin_boundary(), fill=255)
    output = Image.new("RGBA", mask.size)
    draw = ImageDraw.Draw(output)
    for y in range(output.height):
        draw.line((0, y, output.width, y), fill=mix(top, bottom, y / output.height))
    output.putalpha(mask)
    draw.ellipse(tuple(v * SCALE for v in (28, 17, 100, 89)), fill=inner)
    if file_id == "private":
        points = [
            (64 + r * cos(angle), 53 + r * sin(angle))
            for i in range(10)
            for r, angle in [(24 if i % 2 == 0 else 10, i * pi / 5 - pi / 2)]
        ]
        polygon(draw, points, "white")
        coords = " ".join(f"{x:.2f},{y:.2f}" for x, y in points)
        artwork = f'<polygon points="{coords}" fill="white"/>'
    elif file_id == "temporary":
        draw.ellipse(tuple(v * SCALE for v in (46, 35, 82, 71)), outline="white", width=3 * SCALE)
        for x0, y0, x1, y1 in [(40, 53, 51, 53), (77, 53, 88, 53), (64, 29, 64, 40), (64, 66, 64, 77)]:
            draw.line(tuple(v * SCALE for v in (x0, y0, x1, y1)), fill="white", width=3 * SCALE)
        draw.ellipse(tuple(v * SCALE for v in (61, 50, 67, 56)), fill="white")
        artwork = ('<circle cx="64" cy="53" r="18" fill="none" stroke="white" stroke-width="3"/>'
                   '<path d="M40 53h11m26 0h11M64 29v11m0 26v11" stroke="white" stroke-width="3"/>'
                   '<circle cx="64" cy="53" r="3" fill="white"/>')
    else:
        icon(draw, (64, 53), glyph, 49, color=file_id not in SPECIAL)
        family = quoteattr(f"{ImageFont.truetype(str(FONT), 12).getname()[0]}, sans-serif")
        artwork = (f'<text x="64" y="53" text-anchor="middle" dominant-baseline="central" '
                   f'fill="white" font-family={family} font-size="49">{html.escape(chr(glyph))}</text>')
    output.resize((128, 128), Image.Resampling.LANCZOS).save(OUT / f"{file_id}.png")

    (SVG / f"{file_id}.svg").write_text(
        f'<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">\n'
        f'  <defs><linearGradient id="pin" x2="0" y2="1"><stop stop-color="rgb{top}"/>'
        f'<stop offset="1" stop-color="rgb{bottom}"/></linearGradient></defs>\n'
        f'  <path d="{SHAPE}" fill="url(#pin)"/>\n'
        f'  <circle cx="64" cy="53" r="36" fill="rgb{inner}"/>\n'
        f'  {artwork}\n'
        '</svg>\n', encoding="utf-8",
    )


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    SVG.mkdir(parents=True, exist_ok=True)
    for file_id, (color, glyph) in (PINS | SPECIAL).items():
        pin(file_id, color, glyph)
    LANDMARK_OUT.mkdir(parents=True, exist_ok=True)
    for file_id, shapes in LANDMARKS.items():
        image = Image.new("RGBA", (32 * SCALE, 32 * SCALE))
        draw = ImageDraw.Draw(image)
        for points in shapes:
            polygon(draw, points, "#c5bfef")
        image.resize((32, 32), Image.Resampling.LANCZOS).save(LANDMARK_OUT / f"{file_id}.png")
    map_overlays()
    ids = "".join(f"  '{key}',\n" for key in sorted(PINS))
    REGISTRY.write_text(
        "// Generated by tool/generate_map_pins.py.\n"
        f"const yallaPinCategories = <String>{{\n{ids}}};\n", encoding="utf-8",
    )


if __name__ == "__main__":
    if sys.argv[1:] == ["--map-overlays"]:
        map_overlays()
    else:
        main()
