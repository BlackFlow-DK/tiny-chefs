"""Dispenser models (static, footprint <= 6 x 6, height 3..6). Run: tools/blender-run.ps1 art/scripts/dispensers.py"""
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import artlib  # noqa: E402
import foodparts as fp  # noqa: E402
from shapes import ball, box, box_along, build_asset, cyl, frustum  # noqa: E402

M = artlib.material
LIMITS = ((0.5, 6.05), (3.0, 6.0), (0.5, 6.05))


def tray(w, d, wall_h=0.5):
    steel = M("TraySteel", "#cfd6dc", 0.3, 0.5)
    parts = [box(steel, (w, d, 0.15), (0, 0, 0.075))]
    for sy in (-1, 1):
        parts.append(box(steel, (w, 0.15, wall_h), (0, sy * (d / 2 - 0.075), wall_h / 2)))
    for sx in (-1, 1):
        parts.append(box(steel, (0.15, d, wall_h), (sx * (w / 2 - 0.075), 0, wall_h / 2)))
    return parts


def dispenser_buns():
    kraft = M("BagKraft", "#c79a5e", 0.9)
    roll = M("BagRoll", "#a67b45", 0.9)
    label = M("BagLabel", "#fff1cc", 0.8)
    red = M("BagRed", "#d92b2b", 0.6)
    parts = [frustum(kraft, (4.2, 4.2), (3.8, 3.8), 2.6),
             box(roll, (3.95, 3.95, 0.3), (0, 0, 2.75)),
             box(label, (2.2, 0.08, 1.2), (0, -2.0, 1.3)),
             box(red, (2.2, 0.09, 0.3), (0, -2.0, 1.3))]
    for x, y in ((-0.78, -0.62), (0.78, -0.5), (0, 0.85)):
        parts += fp.bun_top((x, y, 2.85), 0.7)
    return parts


def dispenser_patties():
    parts = tray(5.8, 3.8, 0.5)
    for n, cx, cy, sc in ((6, -1.45, 0.0, 0.85), (4, 1.45, 0.15, 0.85)):
        for i in range(n):
            parts += fp.patty_raw((cx + 0.04 * ((i * 7) % 3 - 1), cy, 0.15 + i * 0.475), sc, seed=i + n,
                                  lumps=(i == n - 1))
    return parts


def dispenser_cheese():
    wrap = M("CheeseWrap", "#dfe9f0", 0.5)
    band = M("CheeseBand", "#d92b2b", 0.5)
    cheese_a = M("Cheese", "#ffcf1c", 0.5)
    cheese_b = M("CheeseB", "#ffe04a", 0.5)
    H, W = 1.7, 3.6
    parts = [box(wrap, (W, W, 0.12), (0, 0, 0.06))]
    for sy in (-1, 1):
        parts.append(box(wrap, (W, 0.1, H), (0, sy * (W / 2 - 0.05), H / 2)))
    for sx in (-1, 1):
        parts.append(box(wrap, (0.1, W, H), (sx * (W / 2 - 0.05), 0, H / 2)))
    parts.append(box(band, (2.0, 0.06, 0.7), (0, -W / 2 - 0.005, 0.85)))
    fl, c45 = 1.0, math.radians(45)
    k = 0.5 * fl * math.sqrt(0.5)
    for sy in (-1, 1):
        parts.append(box(wrap, (W, fl, 0.08), (0, sy * (W / 2 + k), H + k), rot=(sy * c45, 0, 0)))
    for sx in (-1, 1):
        parts.append(box(wrap, (fl, W, 0.08), (sx * (W / 2 + k), 0, H + k), rot=(0, -sx * c45, 0)))
    rng = random.Random(7)
    for i in range(20):
        parts.append(box(cheese_a if i % 2 else cheese_b, (3.0, 3.0, 0.15),
                         (rng.uniform(-0.14, 0.14), rng.uniform(-0.14, 0.14), 0.2 + i * 0.15 + 0.075),
                         rot=(0, 0, math.radians(rng.uniform(-8, 8)))))
    return parts


def dispenser_lettuce():
    dark = M("LettuceDark", "#3f9c2d", 0.7)
    mid = M("Lettuce", "#4fbf35", 0.7)
    light = M("LettuceLight", "#a6e36a", 0.7)
    parts = [ball(light, (1.5, 1.5, 1.35), (0, 0, 3.4), seg=10, rings=6)]
    for i in range(6):
        a = 2 * math.pi * i / 6 + 0.25
        parts.append(ball(light if i % 2 else mid, (0.55, 1.15, 2.3),
                          (1.1 * math.cos(a), 1.1 * math.sin(a), 2.5), rot=(0, 0.12, a), seg=8, rings=5))
    for i in range(8):
        a = 2 * math.pi * i / 8
        parts.append(ball(dark if i % 2 else mid, (0.6, 1.4, 2.0),
                          (1.9 * math.cos(a), 1.9 * math.sin(a), 2.05), rot=(0, 0.24, a), seg=8, rings=5))
    return parts


def dispenser_tomatoes():
    wood_a = M("CrateWoodA", "#b98444", 0.9)
    wood_b = M("CrateWoodB", "#9a6a34", 0.9)
    post = M("CratePost", "#7d5228", 0.9)
    W, D, H = 5.4, 4.2, 1.8
    parts = [box(wood_b, (W - 0.2, D - 0.2, 0.15), (0, 0, 0.075))]
    for k in range(3):
        z = 0.15 + 0.275 + k * 0.625
        mat = wood_a if k % 2 == 0 else wood_b
        for sy in (-1, 1):
            parts.append(box(mat, (W, 0.14, 0.5), (0, sy * (D / 2 - 0.07), z)))
        for sx in (-1, 1):
            parts.append(box(mat, (0.14, D, 0.5), (sx * (W / 2 - 0.07), 0, z)))
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(box(post, (0.32, 0.32, H), (sx * (W / 2 - 0.16), sy * (D / 2 - 0.16), H / 2)))
    s = 0.85
    for x in (-1.75, 0, 1.75):
        for y in (-0.85, 0.85):
            parts += fp.tomato((x, y, 0.2), s)
    for x in (-0.875, 0.875):
        parts += fp.tomato((x, 0, 1.0), s)
    parts += fp.tomato((0, 0, 1.75), s)
    return parts


def dispenser_sausages():
    parts = tray(5.0, 4.7, 0.5)
    r = 0.48
    z = 0.15
    for n in (4, 3, 2, 1):
        for i in range(n):
            y = (i - (n - 1) / 2) * 2 * r
            parts += fp.sausage("raw", (0, y, z), length=4.5, r=r)
        z += 0.83
    return parts


def dispenser_hotdog_buns():
    bag = M("BagCream", "#f3ead2", 0.8)
    roll = M("BagRollCream", "#d8cba6", 0.8)
    blue = M("BagBlue", "#2f6fd6", 0.6)
    red = M("BagRed", "#d92b2b", 0.6)
    parts = [frustum(bag, (5.2, 3.0), (4.8, 2.7), 2.4),
             box(roll, (4.9, 2.8, 0.3), (0, 0, 2.55)),
             box(blue, (3.6, 0.08, 0.5), (0, -1.46, 1.2)),
             box(red, (2.0, 0.09, 0.2), (0, -1.46, 1.2))]
    for y in (-0.65, 0.65):
        parts += fp.hotdog_bun((0, y, 2.6), 0.8)
    parts += fp.hotdog_bun((0, 0, 3.05), 0.8)
    return parts


for name, fn in (("dispenser_buns", dispenser_buns), ("dispenser_patties", dispenser_patties),
                 ("dispenser_cheese", dispenser_cheese), ("dispenser_lettuce", dispenser_lettuce),
                 ("dispenser_tomatoes", dispenser_tomatoes), ("dispenser_sausages", dispenser_sausages),
                 ("dispenser_hotdog_buns", dispenser_hotdog_buns)):
    artlib.reset_scene()
    build_asset(name, fn(), None, limits=LIMITS)
