"""Scenery part 4: cookbook stack and rolling pin.

Run: tools/blender-run.ps1 art/scripts/scenery_baking.py [-- model_name ...]
"""
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from mathutils import Vector  # noqa: E402

import scenery_parts as sp  # noqa: E402
from scenery_parts import M, ball, bezier, cyl, fillet, lathe, rbox, sweep, torus  # noqa: E402

PAGES = PAGE_LINE = GOLD = CREAM = None


def init_mats():
    """Materials are recreated per job (reset_scene removes them)."""
    global PAGES, PAGE_LINE, GOLD, CREAM
    PAGES = M("BookPages", "#f3e9cf", 0.95)
    PAGE_LINE = M("BookPageLine", "#c9b98f", 0.95)
    GOLD = M("BookGold", "#d9a83a", 0.35, 0.4)
    CREAM = M("BookLabel", "#f6ecd0", 0.6)


def book(parts, cover, dark, size, z0, rot_deg, off, emblem=None, name=""):
    """One hardback lying flat, spine towards -Y. Built at the origin, then turned and moved."""
    w, d, t = size
    c = 0.13
    made = []
    made.append(rbox(cover, (w, d, c), (0, 0, z0 + c / 2), r=0.05, seg=2))
    made.append(rbox(cover, (w, d, c), (0, 0, z0 + t - c / 2), r=0.05, seg=2))
    made.append(rbox(PAGES, (w - 0.3, d - 0.28, t - 2 * c + 0.02), (0, 0.04, z0 + t / 2), r=0.05, seg=2))
    made.append(rbox(cover, (w, 0.5, t), (0, -d / 2 + 0.25, z0 + t / 2), r=min(0.24, t * 0.45), seg=4))
    # page lines on the fore edge and both ends
    for k in range(1, 5):
        z = z0 + c + (t - 2 * c) * k / 5
        made.append(rbox(PAGE_LINE, (w - 0.5, 0.03, 0.025), (0, d / 2 - 0.10, z), r=0.005, seg=1))
        for sx in (-1, 1):
            made.append(rbox(PAGE_LINE, (0.03, d - 0.7, 0.025), (sx * (w / 2 - 0.145), 0.04, z), r=0.005, seg=1))
    # spine decoration: gold bands and a label
    for sx in (-1, 1):
        for dx in (0.7, 1.0):
            made.append(rbox(GOLD, (0.07, 0.06, t * 0.8), (sx * (w / 2 - dx), -d / 2, z0 + t / 2), r=0.02, seg=1))
    made.append(rbox(CREAM, (w * 0.34, 0.06, t * 0.55), (0, -d / 2 - 0.0, z0 + t / 2), r=0.05, seg=2))
    made.append(rbox(dark, (w * 0.28, 0.08, t * 0.12), (0, -d / 2 - 0.02, z0 + t / 2), r=0.02, seg=1))
    if emblem:
        made += emblem(z0 + t, w, d)
    a = math.radians(rot_deg)
    ca, sa = math.cos(a), math.sin(a)
    for o in made:
        x, y, z = o.location
        o.location = (x * ca - y * sa + off[0], x * sa + y * ca + off[1], z)
        o.rotation_euler = (o.rotation_euler.x, o.rotation_euler.y, o.rotation_euler.z + a)
    parts += made
    return made


def cookbook_stack():
    init_mats()
    red = M("BookRed", "#c8372d", 0.55)
    red_d = M("BookRedDark", "#7c1c18", 0.55)
    green = M("BookGreen", "#3f8f4d", 0.55)
    green_d = M("BookGreenDark", "#1d5730", 0.55)
    mustard = M("BookMustard", "#e2a626", 0.55)
    must_d = M("BookMustardDark", "#8f5f0d", 0.55)
    white = M("BookWhite", "#fbf8f0", 0.5)
    steel = M("BookCutlery", "#8d959c", 0.35, 0.4)
    ribbon = M("BookRibbon", "#e23a5a", 0.6)
    ink = M("BookInk", "#5a3a26", 0.7)
    parts = []

    def plate(z, w, d):  # dinner plate with cutlery on the red book
        return [cyl(CREAM, 1.35, 0.05, (0.0, 0.0, z + 0.025), verts=32),
                cyl(white, 0.95, 0.07, (0.0, 0.0, z + 0.04), verts=32),
                torus(red_d, 1.2, 0.03, (0.0, 0.0, z + 0.06), seg=32, sides=5),
                rbox(steel, (0.14, 1.9, 0.05), (-1.9, 0.0, z + 0.03), r=0.02, seg=1),
                rbox(steel, (0.14, 1.9, 0.05), (1.9, 0.0, z + 0.03), r=0.02, seg=1)]

    def lines(z, w, d):  # unreadable text lines on a label
        out = [rbox(CREAM, (w * 0.62, d * 0.42, 0.04), (0, 0.2, z + 0.02), r=0.03, seg=1)]
        for k in range(4):
            out.append(rbox(green_d, (w * (0.42 if k != 1 else 0.3), 0.14, 0.03), (0, 0.7 - k * 0.42, z + 0.05), r=0.01, seg=1))
        out.append(rbox(green_d, (w * 0.62, 0.1, 0.03), (0, -0.62, z + 0.05), r=0.01, seg=1))
        return out

    def hat(z, w, d):  # flat chef's-hat badge on the top book
        return [cyl(white, 0.8, 0.06, (0, 0.1, z + 0.03), verts=24),
                cyl(must_d, 0.62, 0.08, (0, 0.1, z + 0.05), verts=24),
                cyl(white, 0.5, 0.1, (0, -0.05, z + 0.09), verts=20),
                ball(white, (0.5, 0.42, 0.14), (0, 0.32, z + 0.16), seg=14, rings=6),
                ball(white, (0.32, 0.3, 0.13), (-0.42, 0.22, z + 0.15), seg=10, rings=6),
                ball(white, (0.32, 0.3, 0.13), (0.42, 0.22, z + 0.15), seg=10, rings=6)]

    book(parts, red, red_d, (8, 6, 1.4), 0.0, 0, (0, 0), plate)
    book(parts, green, green_d, (6.8, 5.0, 1.15), 1.4, 8, (0.35, 0.05), lines)
    top = book(parts, mustard, must_d, (5.8, 4.3, 0.95), 2.55, -13, (-0.9, -0.05), hat)
    # bookmark ribbon: out of the top book's right end, over the green book's cover
    a = math.radians(-13)

    def tf(p):
        return (p[0] * math.cos(a) - p[1] * math.sin(a) - 0.9, p[0] * math.sin(a) + p[1] * math.cos(a) - 0.05, p[2])

    rp = [tf(p) for p in ((2.75, -1.0, 3.0), (3.2, -1.0, 2.98), (3.5, -1.0, 2.72), (3.55, -1.05, 2.62))]
    r2 = [(3.55, -1.05, 2.62), (3.75, -1.2, 2.62), (4.0, -1.35, 2.61)]
    path = rp + r2[1:]
    parts.append(sweep(ribbon, path, (0.3, 0.025), sides=4, rect=True, up=(0, 1, 0)))
    # V-notched ribbon tail
    tail = path[-1]
    parts.append(rbox(ribbon, (0.45, 0.6, 0.05), (tail[0] + 0.1, tail[1] - 0.05, 2.61), rot=(0, 0, -0.6), r=0.01, seg=1))
    return parts, (8, 3.5, 6)


def rolling_pin():
    maple = M("PinMaple", "#ecc98c", 0.7)
    grain = M("PinGrain", "#cf9f57", 0.75)
    walnut = M("PinWalnut", "#9a5d2c", 0.6)
    walnut_d = M("PinWalnutDark", "#6e3d1c", 0.6)
    flour = M("PinFlour", "#fbfaf4", 0.98)
    R = 0.7
    half = [(R, 0.0), (R, 3.05), (0.6, 3.22), (0.34, 3.3), (0.3, 3.5), (0.3, 3.85), (0.4, 4.05), (0.46, 4.4), (0.4, 4.78), (0.2, 4.97)]
    half = fillet([(0.0, 0.0)] + half + [(0.0, 5.0)], r=0.22, n=3, radii={1: 0, 2: 0, 3: 0.12, 4: 0.05, 9: 0.05})
    full = [(r, -z) for r, z in half][::-1] + half[1:]
    pin = lathe([maple, walnut], full, verts=40, face_mat=lambda c: 1 if abs(c.z) > 3.1 else 0)
    pin.location = (0, 0, R)
    pin.rotation_euler = (0, math.pi / 2, 0)
    parts = [pin]
    # wood-grain bands and dark rings at the handles
    for z0, z1 in ((-2.6, -2.5), (-1.55, -1.35), (-0.2, -0.1), (0.9, 1.25), (2.1, 2.2), (2.5, 2.6)):
        b = lathe(grain, [(R - 0.02, z0), (R + 0.014, z0), (R + 0.014, z1), (R - 0.02, z1), (R - 0.02, z0)], verts=40)
        b.location = (0, 0, R)
        b.rotation_euler = (0, math.pi / 2, 0)
        parts.append(b)
    for sgn in (-1, 1):
        t = torus(walnut_d, 0.66, 0.06, (0, 0, R), rot=(0, math.pi / 2, 0), seg=32, sides=6)
        t.location = (sgn * 3.02, 0, R)
        parts.append(t)
        t = torus(walnut_d, 0.4, 0.05, (0, 0, R), rot=(0, math.pi / 2, 0), seg=24, sides=6)
        t.location = (sgn * 3.95, 0, R)
        parts.append(t)
    # flour dusting on the barrel
    rnd = random.Random(3)
    for x, ang, sx, sy in ((-1.6, 80, 0.36, 0.14), (0.7, 100, 0.42, 0.16), (1.9, 88, 0.28, 0.12), (-0.5, 96, 0.2, 0.1)):
        a = math.radians(ang)
        radial = Vector((0, math.cos(a), math.sin(a)))
        pos = Vector((x, 0, R)) + radial * (R + 0.0)
        parts.append(sp.oriented(ball(flour, (sx, sy, 0.04), (0, 0, 0), seg=10, rings=5), pos, radial, (1, 0, 0)))
    return parts, (10, 1.4, 1.4)


sp.run((("cookbook_stack", cookbook_stack), ("rolling_pin", rolling_pin)))
