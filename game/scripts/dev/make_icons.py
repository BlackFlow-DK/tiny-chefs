"""Composites build/icon/subject_{a,b,c}.png (from scenes/dev/icon_shot.tscn) onto rounded tiles.
Usage: python game/scripts/dev/make_icons.py   (run from the repo root)
Writes docs/itch/icon/icon-{a,b,c}.png (1024), -64, -32 and sheet.png."""
import os
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
SRC = os.path.join(ROOT, "build", "icon")
OUT = os.path.join(ROOT, "docs", "itch", "icon")
INK = (0x2B, 0x22, 0x33)
SS = 2                     # supersample
N = 1024 * SS
TILE = int(N * 0.84)
INSET = (N - TILE) // 2
RADIUS = int(TILE * 0.22)

# key: (top colour, bottom colour, width fraction of tile, vertical centre fraction, align top)
CFG = {
    "a": ((0xF0, 0x55, 0x3A), (0xD8, 0x39, 0x20), 0.78, None),
    "b": ((0xFF, 0xD2, 0x52), (0xF5, 0xB8, 0x25), 0.88, 0.52),
    "c": ((0x66, 0xB4, 0xFF), (0x3F, 0x98, 0xF2), 0.86, 0.52),
}


def tile_mask():
    m = Image.new("L", (N, N), 0)
    ImageDraw.Draw(m).rounded_rectangle([INSET, INSET, INSET + TILE - 1, INSET + TILE - 1], RADIUS, fill=255)
    return m


def gradient(top, bot):
    g = Image.new("RGBA", (N, N), top + (255,))
    px = Image.new("RGBA", (1, TILE))
    for y in range(TILE):
        t = y / (TILE - 1)
        px.putpixel((0, y), tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)) + (255,))
    g.paste(px.resize((TILE, TILE)), (INSET, INSET))
    return g


def make(key):
    top, bot, wfrac, vc = CFG[key]
    subj = Image.open(os.path.join(SRC, f"subject_{key}.png")).convert("RGBA")
    subj = subj.crop(subj.getbbox())
    sc = TILE * wfrac / subj.width
    subj = subj.resize((int(subj.width * sc), int(subj.height * sc)), Image.LANCZOS)
    x = (N - subj.width) // 2
    y = INSET + int(TILE * 0.07) if vc is None else int(INSET + TILE * vc - subj.height / 2)
    layer = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    layer.paste(subj, (x, y))
    a = layer.getchannel("A")
    # ink outline: dilated alpha
    r = 7 * SS
    out = a.filter(ImageFilter.MaxFilter(2 * r + 1)).filter(ImageFilter.GaussianBlur(1.2 * SS))
    outline = Image.new("RGBA", (N, N), INK + (0,))
    outline.putalpha(out)
    # soft drop shadow
    sh = out.filter(ImageFilter.GaussianBlur(14 * SS)).point(lambda v: int(v * 0.38))
    shadow = Image.new("RGBA", (N, N), (30, 15, 30, 0))
    shadow.putalpha(ImageChops.offset(sh, 0, 16 * SS))
    img = gradient(top, bot)
    img.alpha_composite(shadow)
    img.alpha_composite(outline)
    img.alpha_composite(layer)
    mask = tile_mask()
    img.putalpha(ImageChops.multiply(img.getchannel("A"), mask))
    img = img.resize((1024, 1024), Image.LANCZOS)
    img.save(os.path.join(OUT, f"icon-{key}.png"))
    for s in (64, 32):
        img.resize((s, s), Image.LANCZOS).save(os.path.join(OUT, f"icon-{key}-{s}.png"))
    return img


def sheet(icons):
    W = 3 * 256 + 4 * 24
    rows = [(256, 256), (64, 64), (32, 32)]
    H_each = 24 * 2 + 256 + 24 + 64 + 24 + 32 + 16
    S = Image.new("RGBA", (W, H_each * 2), (0, 0, 0, 0))
    for bi, bg in enumerate([(244, 240, 232, 255), (30, 30, 34, 255)]):
        y0 = bi * H_each
        ImageDraw.Draw(S).rectangle([0, y0, W, y0 + H_each], fill=bg)
        y = y0 + 24
        for size in (256, 64, 32):
            for i, k in enumerate("abc"):
                x = 24 + i * (256 + 24) + (256 - size) // 2
                S.alpha_composite(icons[k].resize((size, size), Image.LANCZOS), (x, y))
            y += size + 24
    S.convert("RGB").save(os.path.join(OUT, "sheet.png"))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    icons = {k: make(k) for k in "abc"}
    sheet(icons)
