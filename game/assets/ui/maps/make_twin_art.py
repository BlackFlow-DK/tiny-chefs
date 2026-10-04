"""Generates twin_islands_art.png / twin_islands_art2.png (the flat UI-style Twin Islands map card
pictures) with Pillow. Logical canvas 640x256 (2x the card at 1080p), drawn at 4x and downsampled.
Run: python make_twin_art.py   (writes next to this file)"""
import os
from PIL import Image, ImageDraw

W, H, S = 640, 256, 4
INK = "#2B2233"; CREAM = "#FFF6E0"; TOMATO = "#E8452C"; MUSTARD = "#FFC93C"
LETTUCE = "#5DBB46"; SKY = "#4DA6FF"
SKYBG = "#BFE2FF"; WOOD = "#E0A458"; WOOD_D = "#C4843A"; COUNTER = "#E8D3A8"
CAB = "#3E6FA8"; WATER = "#4DA6FF"; WATER_D = "#2F86E0"; PINK = "#F07B86"; STEEL = "#9AA3AE"
OW = 6  # outline width, logical px (about 2 px at card size)


class Canvas:
    def __init__(self, bg):
        self.im = Image.new("RGB", (W * S, H * S), bg)
        self.d = ImageDraw.Draw(self.im)

    def _s(self, v):
        return [round(x * S) for x in v]

    def rect(self, x0, y0, x1, y1, fill, r=8, ow=OW, outline=INK, shadow=0):
        if shadow:
            self.d.rounded_rectangle(self._s([x0 + shadow, y0 + shadow, x1 + shadow, y1 + shadow]), radius=r * S, fill=INK)
        self.d.rounded_rectangle(self._s([x0, y0, x1, y1]), radius=r * S, fill=fill, outline=outline, width=round(ow * S))

    def ell(self, x0, y0, x1, y1, fill, ow=OW, outline=INK, shadow=0):
        if shadow:
            self.d.ellipse(self._s([x0 + shadow, y0 + shadow, x1 + shadow, y1 + shadow]), fill=INK)
        self.d.ellipse(self._s([x0, y0, x1, y1]), fill=fill, outline=outline, width=round(ow * S))

    def poly(self, pts, fill, ow=OW, shadow=0):
        if shadow:
            self.d.polygon(self._s([c + shadow for p in pts for c in p]), fill=INK)
        flat = [c for p in pts for c in p]
        self.d.polygon(self._s(flat), fill=fill)
        self.d.line(self._s(flat + flat[:2]), fill=INK, width=round(ow * S), joint="curve")

    def line(self, pts, fill=INK, w=OW):
        self.d.line(self._s([c for p in pts for c in p]), fill=fill, width=round(w * S), joint="curve")

    def save(self, path):
        self.im.resize((W, H), Image.LANCZOS).save(path, optimize=True)


def flame(c, cx, base, h, w):
    pts = [(cx - w, base), (cx - w * 0.8, base - h * 0.45), (cx - w * 0.2, base - h * 0.55), (cx, base - h),
           (cx + w * 0.3, base - h * 0.55), (cx + w * 0.85, base - h * 0.4), (cx + w, base)]
    c.poly(pts, TOMATO, ow=4)
    c.poly([(cx - w * 0.45, base), (cx - w * 0.3, base - h * 0.3), (cx, base - h * 0.5), (cx + w * 0.4, base - h * 0.25), (cx + w * 0.5, base)], MUSTARD, ow=3)


def chef(c, cx, feet, s=1.0, patty=True):
    """Little chef, arms up holding a patty overhead."""
    b0, b1 = feet - 34 * s, feet - 6 * s
    c.rect(cx - 12 * s, b0, cx + 12 * s, b1 + 2 * s, CREAM, r=8, ow=5)
    c.rect(cx - 10 * s, b1 - 4 * s, cx - 1 * s, feet + 1, TOMATO, r=3, ow=4)
    c.rect(cx + 1 * s, b1 - 4 * s, cx + 10 * s, feet + 1, TOMATO, r=3, ow=4)
    c.line([(cx - 11 * s, b0 + 8 * s), (cx - 20 * s, b0 - 14 * s)], INK, 9)
    c.line([(cx + 11 * s, b0 + 8 * s), (cx + 20 * s, b0 - 14 * s)], INK, 9)
    c.line([(cx - 11 * s, b0 + 8 * s), (cx - 20 * s, b0 - 14 * s)], CREAM, 4)
    c.line([(cx + 11 * s, b0 + 8 * s), (cx + 20 * s, b0 - 14 * s)], CREAM, 4)
    c.ell(cx - 14 * s, b0 - 22 * s, cx + 14 * s, b0 + 4 * s, "#FFD9B0", ow=5)
    c.ell(cx - 6 * s, b0 - 12 * s, cx - 2 * s, b0 - 7 * s, INK, ow=0)
    c.ell(cx + 2 * s, b0 - 12 * s, cx + 6 * s, b0 - 7 * s, INK, ow=0)
    c.rect(cx - 12 * s, b0 - 36 * s, cx + 12 * s, b0 - 18 * s, CREAM, r=8, ow=5)
    c.ell(cx - 17 * s, b0 - 40 * s, cx + 1 * s, b0 - 24 * s, CREAM, ow=5)
    c.ell(cx - 5 * s, b0 - 44 * s, cx + 17 * s, b0 - 24 * s, CREAM, ow=5)
    c.rect(cx - 12 * s, b0 - 26 * s, cx + 12 * s, b0 - 17 * s, CREAM, r=3, ow=0)
    if patty:
        py = b0 - 26 * s
        c.ell(cx - 26 * s, py - 12 * s, cx + 26 * s, py + 10 * s, PINK, ow=5, shadow=3)
        for dx in (-14, -2, 11):
            c.ell(cx + dx * s - 2, py - 3 * s, cx + dx * s + 3 * s, py + 2 * s, "#C94A58", ow=0)


def duck(c, cx, cy, s=1.0):
    c.ell(cx - 17 * s, cy - 5 * s, cx + 15 * s, cy + 14 * s, MUSTARD, ow=5)
    c.ell(cx + 2 * s, cy - 20 * s, cx + 20 * s, cy - 2 * s, MUSTARD, ow=5)
    c.poly([(cx + 19 * s, cy - 12 * s), (cx + 29 * s, cy - 9 * s), (cx + 19 * s, cy - 6 * s)], TOMATO, ow=3)
    c.ell(cx + 10 * s, cy - 14 * s, cx + 14 * s, cy - 10 * s, INK, ow=0)


def bubbles(c, spots):
    for x, y, r in spots:
        c.ell(x - r, y - r, x + r, y + r, "#EAF6FF", ow=3)


def make_a():
    c = Canvas(SKYBG)
    c.d.rectangle(c._s([0, 0, W, 70]), fill="#CDE8FF")
    for cx, cy in ((92, 36), (548, 30)):
        c.ell(cx - 32, cy - 10, cx + 32, cy + 12, CREAM, ow=0)
        c.ell(cx - 15, cy - 23, cx + 23, cy + 6, CREAM, ow=0)
    top, slab = 150, 22
    # sink: steel rim, water, bubbles, duck
    c.rect(226, top + 2, 414, 254, STEEL, r=8)
    c.rect(238, top + 14, 402, 246, WATER, r=5, ow=5)
    c.line([(244, top + 62), (268, top + 56), (292, top + 62), (316, top + 56), (340, top + 62), (364, top + 56), (396, top + 62)], WATER_D, 5)
    bubbles(c, [(262, 200, 8), (278, 218, 5), (372, 190, 9), (352, 222, 6), (296, 236, 6), (388, 232, 5)])
    duck(c, 322, 190, 1.2)
    for x0, x1 in ((8, 236), (404, 632)):
        c.rect(x0 + 8, top + slab - 4, x1 - 8, 262, CAB, r=8, shadow=6)
        for dx in (0.34, 0.68):
            x = x0 + (x1 - x0) * dx
            c.line([(x, top + slab + 12), (x, 258)], INK, 5)
        c.rect(x0, top, x1, top + slab, COUNTER, r=9, shadow=6)
        c.line([(x0 + 14, top + 7), (x1 - 14, top + 7)], CREAM, 5)
    # left island: tomato, egg, patty box
    c.ell(26, top - 50, 76, top + 1, TOMATO, ow=6)
    c.poly([(42, top - 49), (51, top - 60), (60, top - 49), (51, top - 42)], LETTUCE, ow=4)
    c.ell(88, top - 44, 134, top + 1, "#F4EAD2", ow=6)
    c.ell(100, top - 34, 122, top - 10, MUSTARD, ow=0)
    c.rect(146, top - 54, 222, top + 1, PINK, r=7, ow=6, shadow=4)
    c.rect(156, top - 44, 212, top - 26, CREAM, r=4, ow=0)
    # right island: griddle with flame, plate with a burger, bell
    c.rect(424, top - 22, 540, top + 1, STEEL, r=6, ow=6, shadow=4)
    c.rect(436, top - 16, 528, top - 8, "#6B7480", r=3, ow=0)
    flame(c, 482, top - 22, 46, 21)
    c.ell(556, top - 22, 626, top + 1, CREAM, ow=6, shadow=4)
    c.ell(574, top - 38, 608, top - 14, "#D9964A", ow=5)
    c.ell(580, top - 28, 602, top - 18, LETTUCE, ow=0)
    c.rect(542, top - 26, 560, top - 6, MUSTARD, r=5, ow=5)
    # plank
    c.rect(190, top - 18, 450, top + 6, WOOD, r=6, shadow=5)
    for x in (258, 320, 382):
        c.line([(x, top - 12), (x, top + 1)], WOOD_D, 3)
    chef(c, 320, top - 18, 1.35)
    return c


def make_b():
    """Bolder icon: mustard sun backdrop, two chunky blocks, plank, tomato flame, duck."""
    c = Canvas("#FFE29A")
    c.ell(256, 20, 384, 148, MUSTARD, ow=0)
    top = 130
    c.rect(196, top + 20, 444, 252, STEEL, r=6, ow=OW)
    c.rect(212, top + 36, 428, 244, WATER, r=4, ow=5)
    c.line([(214, top + 62), (240, top + 54), (266, top + 62), (292, top + 54), (318, top + 62), (344, top + 54), (370, top + 62), (396, top + 54), (426, top + 62)], WATER_D, 5)
    duck(c, 330, top + 62, 1.25)
    for x0, x1 in ((6, 214), (426, 634)):
        c.rect(x0, top, x1, 262, CAB, r=14, shadow=7)
        c.rect(x0 - 2, top - 6, x1 + 2, top + 26, COUNTER, r=12, shadow=0)
    c.ell(32, top - 52, 90, top - 4, TOMATO, ow=OW)
    c.poly([(52, top - 50), (61, top - 62), (72, top - 50), (61, top - 42)], LETTUCE, ow=4)
    c.ell(108, top - 44, 160, top - 4, CREAM, ow=OW)
    c.ell(122, top - 34, 146, top - 12, MUSTARD, ow=0)
    c.rect(168, top - 50, 206, top - 4, PINK, r=7, ow=OW, shadow=4)
    c.rect(174, top - 40, 200, top - 28, CREAM, r=3, ow=0)
    c.rect(466, top - 22, 590, top - 4, STEEL, r=6, ow=OW)
    flame(c, 528, top - 22, 52, 24)
    c.ell(582, top - 24, 618, top - 4, CREAM, ow=OW, shadow=3)
    c.ell(590, top - 38, 614, top - 20, "#D9964A", ow=5)
    bubbles(c, [(236, top + 56, 8), (250, top + 76, 5), (404, top + 58, 9), (392, top + 82, 5)])
    c.rect(198, top - 20, 442, top + 4, WOOD, r=6, shadow=5)
    chef(c, 320, top - 20, 1.3)
    return c


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    make_a().save(os.path.join(here, "twin_islands_art.png"))
    make_b().save(os.path.join(here, "twin_islands_art2.png"))
