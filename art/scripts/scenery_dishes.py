"""Scenery part 3: coffee mug, fruit bowl, spice jars, oil bottle, dish sponge.

Run: tools/blender-run.ps1 art/scripts/scenery_dishes.py [-- model_name ...]
"""
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from mathutils import Vector  # noqa: E402

import scenery_parts as sp  # noqa: E402
from scenery_parts import (M, ball, bezier, cyl, fillet, lathe, lathe_arc, rbox, ribbed, ring_band, rod, sweep, torus,  # noqa: E402
                           wall_r)


def coffee_mug():
    glaze = M("MugGlaze", "#e5522c", 0.22)
    cream = M("MugCream", "#f7ecd0", 0.3)
    coffee = M("MugCoffee", "#3a2010", 0.08)
    crema = M("MugCrema", "#a86c3a", 0.3)
    gloss = M("MugGloss", "#ff9c7c", 0.12)
    outer = [(0, 0), (1.3, 0), (1.52, 0.05), (1.6, 0.35), (1.78, 2.5), (1.92, 4.5)]
    prof = fillet(outer + [(1.72, 4.5), (1.66, 3.7), (0, 3.7)], r=0.3, n=3,
                  radii={1: 0.12, 2: 0.08, 3: 0.2, 5: 0.1, 6: 0.09, 7: 0.15})
    parts = [lathe([glaze, cream], prof, verts=36,
                   face_mat=lambda c: 1 if (math.hypot(c.x, c.y) < 1.76 and c.z > 3.62) else 0)]
    parts.append(cyl(coffee, 1.7, 0.08, (0, 0, 3.82), verts=36))
    parts.append(cyl(crema, 1.3, 0.05, (0, 0, 3.87), verts=32))
    rnd = random.Random(4)
    for _ in range(9):
        a, rr = rnd.uniform(0, 6.28), rnd.uniform(0.9, 1.5)
        parts.append(ball(crema, (0.09, 0.09, 0.03), (rr * math.cos(a), rr * math.sin(a), 3.9), seg=6, rings=4))
    cream_band = ring_band(cream, outer, 2.95, 3.35, off=0.035, thick=0.06, verts=36)
    parts.append(cream_band)
    parts.append(ring_band(cream, outer, 0.55, 0.85, off=0.035, thick=0.06, verts=36))
    for k in range(14):
        a = 2 * math.pi * (k + 0.5) / 14
        r = wall_r(outer, 1.9) + 0.01
        parts.append(ball(cream, (0.15, 0.05, 0.15), (r * math.cos(a), r * math.sin(a), 1.9), rot=(0, 0, a - math.pi / 2), seg=10, rings=6))
    parts.append(lathe_arc(gloss, [(wall_r(outer, 1.0) + 0.02, 1.0), (wall_r(outer, 2.5) + 0.02, 2.5)], 196, 204, 2))
    parts.append(lathe_arc(gloss, [(wall_r(outer, 3.55) + 0.02, 3.55), (wall_r(outer, 4.2) + 0.02, 4.2)], 196, 204, 2))
    # D handle
    hp = bezier((1.65, 0, 3.75), (2.85, 0, 4.1), (2.95, 0, 0.75), (1.58, 0, 0.95), 20)
    parts.append(sweep(glaze, hp, [(0.42, 0.3) for _ in hp], sides=14, up=(0, 1, 0)))
    for x, z in ((hp[10][0] + 0.15, hp[10][2] + 0.0),):
        parts.append(rbox(gloss, (0.06, 0.12, 1.0), (x + 0.13, 0, 2.3), r=0.02, seg=1))
    # coffee drip running down the front-left of the outside
    a = math.radians(-130)
    r0 = wall_r(outer, 4.3) + 0.04
    top = Vector((r0 * math.cos(a), r0 * math.sin(a), 4.42))
    r1 = wall_r(outer, 3.2) + 0.05
    bot = Vector((r1 * math.cos(a), r1 * math.sin(a), 3.15))
    drip = M("MugDrip", "#4a2812", 0.1)
    dpath = [tuple(top), tuple(top + (bot - top) * 0.35), tuple(top + (bot - top) * 0.7), tuple(bot)]
    parts.append(sweep(drip, dpath, [(0.2, 0.07), (0.14, 0.06), (0.11, 0.06), (0.16, 0.08)], sides=8, up=(math.cos(a), math.sin(a), 0)))
    parts.append(ball(drip, (0.2, 0.09, 0.26), bot + Vector((math.cos(a), math.sin(a), 0)) * 0.02 - Vector((0, 0, 0.12)), rot=(0, 0, a - math.pi / 2),
                      seg=10, rings=6))
    return parts, (4.5, 4.5, 4)


def apple(parts, body, blush, stem, leaf, pos, s, spin=0.0, tilt=(0.0, 0.0)):
    pr = fillet([(0, -0.8), (0.5, -0.78), (0.88, -0.45), (1.0, 0.1), (0.9, 0.55), (0.55, 0.82), (0.2, 0.78), (0, 0.56)],
                r=0.3, n=2, radii={1: 0.2})
    pr = [(r * s, z * s) for r, z in pr]
    o = lathe(body, pr, verts=18, loc=pos)
    o.rotation_euler = (tilt[0], tilt[1], spin)
    parts.append(o)
    if blush:
        bp = [(r * 1.012 + 0.005, z) for r, z in pr[1:-1]]
        p = lathe_arc(blush, bp, 205, 320, 10, rot_z=math.degrees(spin))
        p.location = pos
        p.rotation_euler = (tilt[0], tilt[1], spin)
        parts.append(p)
    st = Vector((0.04, 0, 0.52)) * s
    en = Vector((0.1, 0, 1.12)) * s
    from mathutils import Euler
    e = Euler((tilt[0], tilt[1], spin))
    st.rotate(e)
    en.rotate(e)
    parts.append(rod(stem, Vector(pos) + st, Vector(pos) + en, 0.055 * s, verts=6))
    lf = Vector((0.36, 0.0, 1.0)) * s
    lf.rotate(e)
    lo = ball(leaf, (0.36 * s, 0.13 * s, 0.05 * s), Vector(pos) + lf, seg=8, rings=5)
    lo.rotation_euler = (tilt[0], tilt[1] - 0.35, spin)
    parts.append(lo)


def fruit_bowl():
    cream = M("BowlCream", "#f4e6bd", 0.28)
    inside = M("BowlInside", "#fff5da", 0.3)
    band = M("BowlBlue", "#2c58a6", 0.3)
    red = M("AppleRed", "#c8221f", 0.28)
    red2 = M("AppleDeepRed", "#8f1215", 0.3)
    green = M("AppleGreen", "#79b833", 0.3)
    gold = M("AppleGold", "#e4c23a", 0.3)
    stem = M("FruitStem", "#5a3b1e", 0.8)
    leaf = M("FruitLeaf", "#3f9a2c", 0.5)
    orange = M("OrangePeel", "#f08a1c", 0.55)
    orange_d = M("OrangePore", "#d26c0d", 0.7)
    banana = M("BananaPeel", "#f5d431", 0.45)
    banana_t = M("BananaTip", "#4a3218", 0.8)
    outer = [(0, 0), (1.9, 0), (2.0, 0.1), (2.2, 0.45), (3.3, 0.9), (4.15, 1.55), (4.5, 2.5)]
    prof = fillet(outer + [(4.3, 2.5), (4.08, 2.3), (3.85, 1.72), (3.1, 1.15), (2.1, 0.8), (0, 0.75)], r=0.28, n=2,
                  radii={1: 0.05, 2: 0.06, 3: 0.35, 4: 0.5, 5: 0.5, 6: 0.09, 7: 0.09})
    parts = [lathe([cream, inside], prof, verts=36,
                   face_mat=lambda c: 1 if (math.hypot(c.x, c.y) < wall_r(outer, min(c.z, 2.49)) - 0.12) else 0)]
    parts.append(ring_band(band, outer, 1.95, 2.35, off=0.03, thick=0.06, verts=36))
    parts.append(ring_band(band, outer, 1.4, 1.5, off=0.03, thick=0.06, verts=36))
    for k in range(16):
        a = 2 * math.pi * (k + 0.5) / 16
        r = wall_r(outer, 1.72) + 0.02
        parts.append(ball(band, (0.13, 0.05, 0.13), (r * math.cos(a), r * math.sin(a), 1.72), rot=(0, 0, a - math.pi / 2), seg=6, rings=4))
    ang = math.radians
    ring = 2.4

    def at(deg, z):
        return (ring * math.cos(ang(deg)), ring * math.sin(ang(deg)), z)

    apple(parts, red, red2, stem, leaf, at(232, 2.0), 1.3, spin=0.6)
    apple(parts, green, None, stem, leaf, at(312, 2.0), 1.28, spin=2.2)
    apple(parts, gold, red, stem, leaf, at(40, 2.0), 1.25, spin=-0.9)
    apple(parts, red, red2, stem, leaf, (-0.1, -0.1, 3.2), 1.2, spin=1.7, tilt=(0.05, -0.08))
    # orange
    oc = Vector(at(140, 2.05))
    parts.append(ball(orange, (1.3, 1.3, 1.24), oc, seg=24, rings=12))
    rnd = random.Random(7)
    for i in range(28):
        y = 1 - 2 * (i + 0.5) / 28
        rr = math.sqrt(1 - y * y)
        th = i * 2.399963
        d = Vector((rr * math.cos(th), rr * math.sin(th), y))
        if d.z > 0.93:
            continue
        pos = oc + Vector((d.x * 1.32, d.y * 1.32, d.z * 1.25))
        pr = sp.oriented(ball(orange_d, (0.09, 0.09, 0.03), (0, 0, 0), seg=5, rings=3), pos, d, (0, 0, 1))
        parts.append(pr)
    parts.append(cyl(stem, 0.17, 0.08, oc + Vector((0.0, 0.0, 1.24)), verts=8))
    parts.append(cyl(leaf, 0.3, 0.03, oc + Vector((0.0, 0.0, 1.22)), verts=6))
    # banana draped over the back fruit
    bp = bezier((-3.4, 0.5, 2.5), (-1.8, 3.4, 4.6), (1.8, 3.4, 4.7), (3.4, 0.3, 2.7), 20)
    br = [0.16 + 0.42 * math.sin(math.pi * (i / 20) ** 0.9) ** 0.5 for i in range(21)]
    parts.append(sweep(banana, bp, br, sides=5, caps=True))
    parts.append(sweep(stem, [tuple(Vector(bp[0]) + (Vector(bp[0]) - Vector(bp[1])).normalized() * 0.4), bp[0]], 0.15, sides=6))
    parts.append(ball(banana_t, 0.16, tuple(Vector(bp[-1]) + (Vector(bp[-1]) - Vector(bp[-2])).normalized() * 0.05), seg=8, rings=5))
    return parts, (9, 4.5, 9)


def spice_jar(fill_hex, lid_kind, label_hex, name):
    glass = M("JarGlass", "#7fb7ae", 0.05, alpha=0.24)
    spice = M(f"Spice_{name}", fill_hex, 0.95)
    spice_l = M(f"SpiceLight_{name}", label_hex, 0.9)
    metal = M("JarLid", "#c9ced4", 0.28, 0.55)
    gold = M("JarLidGold", "#d9a531", 0.3, 0.6)
    cork = M("JarCork", "#c8955a", 0.9)
    cork_d = M("JarCorkSpeck", "#7c5330", 0.9)
    black = M("JarLidBlack", "#24272b", 0.4)
    cream = M("JarLabel", "#f7f0dc", 0.6)
    hole = M("JarHole", "#08080a", 0.9)
    gp = fillet([(0, 0), (0.8, 0), (0.98, 0.12), (1.0, 0.3), (1.0, 1.95), (0.9, 2.25), (0.72, 2.42), (0.72, 2.62), (0, 2.62)],
                r=0.3, n=3, radii={1: 0.05, 2: 0.06, 3: 0.1, 7: 0.03, 8: 0})
    parts = [lathe(glass, gp, verts=32)]
    fp = fillet([(0, 0.13), (0.86, 0.13), (0.94, 0.25), (0.94, 1.85), (0.82, 2.15), (0.5, 2.25), (0, 2.3)], r=0.25, n=3)
    parts.append(lathe(spice, fp, verts=28))
    rnd = random.Random(sum(map(ord, name)))
    for _ in range(14):  # grains on the heap
        a, rr = rnd.uniform(0, 6.28), rnd.uniform(0, 0.6)
        parts.append(ball(spice_l, 0.07, (rr * math.cos(a), rr * math.sin(a), 2.3 - rr * 0.35), seg=5, rings=3))
    parts.append(lathe_arc(cream, [(1.012, 0.65), (1.012, 1.75)], 215, 325, 14))
    parts.append(lathe_arc(spice, [(1.02, 0.65), (1.02, 0.85)], 217, 323, 14))
    parts.append(ball(spice_l, (0.24, 0.04, 0.24), (0, -1.03, 1.3), seg=10, rings=6))
    if lid_kind == "metal":
        parts.append(ribbed(gold, 0.78, 0.5, 18, 0.04, (0, 0, 2.7), verts=54))
        parts.append(lathe(gold, fillet([(0, 2.92), (0.76, 2.92), (0.7, 3.0), (0, 3.0)], r=0.06, n=2), verts=32))
        parts.append(lathe(gold, [(0, 2.44), (0.8, 2.44), (0.8, 2.52), (0, 2.52)], verts=32))
    elif lid_kind == "cork":
        parts.append(lathe(cork, fillet([(0, 2.4), (0.6, 2.4), (0.7, 2.75), (0.72, 2.95), (0.6, 3.0), (0, 3.0)], r=0.1, n=2, radii={1: 0.04}), verts=28))
        for _ in range(16):
            a, z = rnd.uniform(0, 6.28), rnd.uniform(2.55, 2.9)
            r = 0.68 + 0.03
            parts.append(ball(cork_d, (0.1, 0.04, 0.06), (r * math.cos(a), r * math.sin(a), z), rot=(0, 0, a - math.pi / 2), seg=6, rings=4))
    else:
        parts.append(ribbed(black, 0.8, 0.46, 18, 0.03, (0, 0, 2.72), verts=54))
        parts.append(lathe(black, fillet([(0, 2.92), (0.79, 2.92), (0.62, 3.0), (0, 3.0)], r=0.08, n=2), verts=32))
        parts.append(lathe(metal, [(0, 2.44), (0.82, 2.44), (0.82, 2.52), (0, 2.52)], verts=32))
        for x, y in ((0, 0.25), (0.22, -0.14), (-0.22, -0.14)):
            parts.append(cyl(hole, 0.09, 0.03, (x, y, 3.0), verts=8))
    return parts, (2, 3, 2)


def oil_bottle():
    glass = M("OilGlass", "#5fa843", 0.05, alpha=0.38)
    oil = M("OilFill", "#c4bd1c", 0.12)
    cream = M("OilLabel", "#f6efd4", 0.6)
    green = M("OilGreenBand", "#3d7d2b", 0.5)
    olive = M("OilOlive", "#485a1c", 0.4)
    gold = M("OilGold", "#d2a02f", 0.4, 0.4)
    black = M("OilPourer", "#25282c", 0.4)
    metal = M("OilPourerMetal", "#cbd2d8", 0.25, 0.55)
    hole = M("OilHole", "#08080a", 0.9)
    shine = M("OilShine", "#ffffff", 0.05, alpha=0.5)
    gp = fillet([(0, 0), (1.0, 0), (1.25, 0.15), (1.25, 4.8), (1.1, 5.5), (0.72, 6.45), (0.55, 6.95), (0.55, 7.55), (0.68, 7.6), (0.68, 7.85), (0, 7.85)],
                r=0.4, n=4, radii={1: 0.05, 2: 0.15, 3: 0.4, 4: 0.9, 5: 0.5, 6: 0.3, 7: 0.03, 8: 0.03, 9: 0.06})
    parts = [lathe(glass, gp, verts=32)]
    fp = fillet([(0, 0.35), (1.0, 0.35), (1.14, 0.5), (1.14, 4.75), (1.02, 5.4), (0.68, 6.3), (0.46, 6.9), (0.46, 7.7), (0, 7.7)], r=0.3, n=3)
    parts.append(lathe(oil, fp, verts=28))
    for x, z in ((0.3, 6.0), (-0.1, 7.1), (0.15, 5.1)):
        parts.append(ball(shine, 0.09, (x, 0.0, z), seg=6, rings=4))
    # pourer: collar, tapered body, angled spout, dark opening
    pp = fillet([(0, 7.45), (0.8, 7.45), (0.8, 7.75), (0.66, 7.95), (0.5, 8.3), (0.42, 8.6), (0, 8.6)], r=0.16, n=2, radii={1: 0.04})
    parts.append(lathe(black, pp, verts=28))
    parts.append(torus(metal, 0.78, 0.07, (0, 0, 7.72), seg=28, sides=6))
    d = Vector((0.6, 0.0, 0.8)).normalized()
    parts.append(sp.oriented(cyl(metal, 0.3, 0.9, (0, 0, 0), verts=14, r2=0.22), Vector((0.1, 0, 8.5)) + d * 0.4, d, (0, 1, 0)))
    parts.append(sp.oriented(cyl(hole, 0.17, 0.05, (0, 0, 0), verts=10), Vector((0.1, 0, 8.5)) + d * 0.86, d, (0, 1, 0)))
    parts.append(ball(black, 0.28, (-0.28, 0.0, 8.68), seg=12, rings=6))
    # label with olive emblem
    parts.append(lathe_arc(cream, [(1.262, 1.3), (1.262, 3.9)], 212, 328, 18))
    parts.append(lathe_arc(green, [(1.272, 1.3), (1.272, 1.55)], 214, 326, 18))
    parts.append(lathe_arc(green, [(1.272, 3.65), (1.272, 3.9)], 214, 326, 18))
    for dx, dz, rot in ((-0.32, 0.0, 0.5), (0.32, 0.0, -0.5), (0.0, 0.12, 0.0)):
        parts.append(ball(green, (0.3, 0.04, 0.09), (dx * 1.0, -1.28, 2.75 + dz), rot=(0, rot, 0), seg=8, rings=4))
    for dx, dz in ((-0.18, -0.25), (0.16, -0.32)):
        parts.append(ball(olive, (0.16, 0.06, 0.22), (dx, -1.29, 2.55 + dz), seg=10, rings=6))
    parts.append(lathe_arc(shine, [(1.262, 0.8), (1.262, 4.6)], 192, 199, 2))
    return parts, (2.5, 9, 2.5)


def dish_sponge():
    yellow = M("SpongeYellow", "#f4d322", 0.95)
    pore = M("SpongePore", "#c99a12", 0.95)
    green = M("SpongeScrub", "#2f9a48", 1.0)
    green_d = M("SpongeScrubDark", "#1b6a30", 1.0)
    bubble = M("SudsBubble", "#f2fbff", 0.05, alpha=0.7)
    parts = [rbox(yellow, (5, 3, 0.95), (0, 0, 0.475), r=0.32, seg=4),
             rbox(green, (5, 3, 0.4), (0, 0, 1.15), r=0.17, seg=3)]
    rnd = random.Random(11)
    for _ in range(26):  # pores on the front and side walls of the yellow layer
        side = rnd.choice(("f", "f", "l", "r", "b"))
        z = rnd.uniform(0.28, 0.72)
        s = rnd.uniform(0.09, 0.2)
        if side in ("f", "b"):
            x = rnd.uniform(-2.0, 2.0)
            y = (-1 if side == "f" else 1) * 1.46
            parts.append(ball(pore, (s * 1.3, s * 0.35, s), (x, y, z), seg=8, rings=5))
        else:
            y = rnd.uniform(-1.0, 1.0)
            x = (-1 if side == "l" else 1) * 2.46
            parts.append(ball(pore, (s * 0.35, s * 1.3, s), (x, y, z), seg=8, rings=5))
    for i in range(7):  # scrubby texture on top: rows of little darker bumps
        for j in range(4):
            x = -2.0 + i * 0.66 + (0.33 if j % 2 else 0)
            y = -1.05 + j * 0.7
            parts.append(ball(green_d, (0.17, 0.13, 0.05), (x + rnd.uniform(-0.08, 0.08), y, 1.34), seg=6, rings=4))
    for x, y, r in ((1.2, 0.3, 0.25), (1.65, -0.15, 0.2), (0.85, -0.4, 0.2), (1.5, 0.75, 0.16), (-1.5, 0.55, 0.22), (-1.1, 0.2, 0.15)):
        parts.append(ball(bubble, r, (x, y, 1.28 + r * 0.3), seg=10, rings=6))
    return parts, (5, 1.5, 3)


sp.run((
    ("coffee_mug", coffee_mug),
    ("fruit_bowl", fruit_bowl),
    ("spice_jar_a", lambda: spice_jar("#c02c10", "metal", "#e0552a", "a")),
    ("spice_jar_b", lambda: spice_jar("#eba007", "cork", "#f2c22e", "b")),
    ("spice_jar_c", lambda: spice_jar("#4f8a1e", "plastic", "#7fb640", "c")),
    ("oil_bottle", oil_bottle),
    ("dish_sponge", dish_sponge),
))
