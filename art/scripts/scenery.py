"""Scenery models (static). Run: tools/blender-run.ps1 art/scripts/scenery.py"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import artlib  # noqa: E402
from shapes import ball, box, build_asset, cyl, ellip_along, lathe, rod  # noqa: E402

M = artlib.material


def shaker(salt):
    if salt:
        glass = M("SaltGlass", "#bfe3f2", 0.1, alpha=0.45)
        fill = M("SaltFill", "#f7f7f4", 0.8)
        cap = M("SaltCap", "#c9cfd5", 0.3, 0.7)
    else:
        glass = M("PepperGlass", "#4a5163", 0.1, alpha=0.5)
        fill = M("PepperFill", "#1b140f", 0.9)
        cap = M("PepperCap", "#2e3239", 0.35, 0.7)
    hole = M("ShakerHole", "#0a0a0c", 0.9)
    parts = [lathe(fill, [(0, 0.15), (1.36, 0.15), (1.43, 0.4), (1.43, 3.7), (0, 3.7)], verts=14),
             lathe(cap, [(0, 5.1), (1.3, 5.1), (1.3, 6.1), (1.0, 6.7), (0.75, 7.0), (0, 7.0)], verts=14),
             lathe(glass, [(0, 0), (1.3, 0), (1.5, 0.3), (1.5, 4.6), (1.3, 5.2), (0, 5.2)], verts=14)]
    for x, y in ((0, 0), (0.42, 0.0), (-0.21, 0.36), (-0.21, -0.36)):
        parts.append(cyl(hole, 0.11, 0.05, (x, y, 7.0), verts=6))
    return parts, (3, 7, 3)


def ketchup_bottle():
    red = M("KetchupRed", "#d61f1f", 0.35)
    label = M("KetchupLabel", "#f6edd2", 0.6)
    white = M("KetchupCap", "#f6f6f2", 0.4)
    green = M("KetchupLeaf", "#3aa02c", 0.6)
    body = [(0, 0), (1.5, 0), (1.75, 0.4), (1.75, 5.2), (1.3, 6.6), (0.8, 7.4), (0.8, 8.5), (0, 8.5)]
    parts = [lathe(red, body, verts=14),
             lathe(label, [(0, 2.2), (1.78, 2.2), (1.78, 4.6), (0, 4.6)], verts=14),
             lathe(white, [(0, 8.3), (0.98, 8.3), (0.98, 9.1), (0.6, 9.8), (0.32, 10.0), (0, 10.0)], verts=10),
             ball(red, (0.62, 0.05, 0.62), (0, -1.79, 3.55), seg=10, rings=6),
             ball(green, (0.22, 0.06, 0.12), (0, -1.83, 4.18), seg=6, rings=4)]
    return parts, (3.5, 10, 3.5)


def utensil_pot():
    teal = M("PotCeramic", "#2f8f9d", 0.35)
    cream = M("PotStripe", "#f4ead0", 0.4)
    inside = M("PotInside", "#0d1416", 0.9)
    wood = M("UtensilWood", "#c98d4d", 0.8)
    red = M("UtensilRed", "#d92b2b", 0.5)
    steel = M("UtensilSteel", "#cdd4da", 0.3, 0.7)
    prof = [(0, 0), (2.3, 0), (3.0, 0.7), (3.0, 7.0), (2.75, 7.4), (2.5, 7.4), (2.5, 6.6), (0, 6.6)]
    parts = [lathe([teal, inside], prof, verts=16,
                   face_mat=lambda c: 1 if (c.z < 7.35 and math.hypot(c.x, c.y) < 2.55 and c.z > 6.5) else 0),
             lathe(cream, [(0, 4.5), (3.03, 4.5), (3.03, 5.3), (0, 5.3)], verts=16)]

    def item(base, theta, phi, top, mat, r):
        th, ph = math.radians(theta), math.radians(phi)
        d = (math.sin(th) * math.cos(ph), math.sin(th) * math.sin(ph), math.cos(th))
        L = (top - base[2]) / d[2]
        p1 = (base[0] + d[0] * L, base[1] + d[1] * L, top)
        parts.append(rod(mat, base, p1, r, verts=6))
        return p1, d, (0, th, ph)

    # wooden spoon
    p1, d, rot = item((-0.8, 0.3, 6.7), 10, 180, 12.0, wood, 0.26)
    parts.append(ellip_along(wood, (p1[0] + d[0] * 0.9, p1[1], p1[2] + d[2] * 0.9), d, (0.3, 0.85, 1.35), seg=8, rings=5))
    # red spatula
    p1, d, rot = item((0.9, -0.6, 6.7), 8, 20, 11.2, steel, 0.22)
    parts.append(box(red, (1.7, 0.15, 2.4), (p1[0] + d[0] * 1.15, p1[1] + d[1] * 1.15, p1[2] + d[2] * 1.15), rot=rot))
    # steel ladle
    p1, d, rot = item((0.3, 1.0, 6.7), 6, -100, 12.6, steel, 0.2)
    parts.append(ball(steel, (0.9, 0.9, 0.5), (p1[0] + 0.5, p1[1] - 0.1, p1[2] + 0.45), seg=8, rings=5))
    return parts, (6, 14, 6)


def sink_tap():
    chrome = M("TapChrome", "#dfe6ec", 0.3, 0.5)
    blue = M("TapBlue", "#2a6fd6", 0.4)
    red = M("TapRed", "#d62a2a", 0.4)
    R, zc, tr = 2.8, 8.3, 0.7
    parts = [cyl(chrome, 1.9, 0.5, (0, 0, 0.25), verts=16),
             cyl(chrome, 1.25, 0.9, (0, 0, 0.95), verts=12),
             rod(chrome, (0, 0, 0.8), (0, 0, zc), tr, verts=10)]
    pts = [(0, -R * (1 - math.cos(math.pi * i / 8)), zc + R * math.sin(math.pi * i / 8)) for i in range(9)]
    for a, b in zip(pts[:-1], pts[1:]):
        parts.append(rod(chrome, a, b, tr, verts=10))
    for p in pts:
        parts.append(ball(chrome, tr * 1.02, p, seg=10, rings=5))
    tip = pts[-1]
    parts.append(rod(chrome, tip, (tip[0], tip[1], zc - 1.7), tr, verts=10))
    parts.append(cyl(chrome, 0.9, 0.6, (tip[0], tip[1], zc - 1.85), verts=10))
    for sx, mat in ((-1, blue), (1, red)):
        parts.append(rod(chrome, (sx * 0.4, 0, 3.6), (sx * 2.55, 0, 4.5), 0.3, verts=8))
        parts.append(ball(mat, 0.55, (sx * 2.6, 0, 4.55), seg=8, rings=5))
    return parts, (6, 12, 8)


JOBS = (("salt_shaker", lambda: shaker(True)), ("pepper_shaker", lambda: shaker(False)),
        ("ketchup_bottle", ketchup_bottle), ("utensil_pot", utensil_pot), ("sink_tap", sink_tap))
for name, fn in JOBS:
    artlib.reset_scene()
    parts, size = fn()
    build_asset(name, parts, size)
