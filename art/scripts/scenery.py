"""Scenery models, part 1: shakers, ketchup, utensil pot, sink tap.

Run: tools/blender-run.ps1 art/scripts/scenery.py [-- model_name ...]
More scenery: scenery_appliances.py, scenery_dishes.py, scenery_baking.py (share scenery_parts.py).
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from mathutils import Vector  # noqa: E402

import scenery_parts as sp  # noqa: E402
from scenery_parts import M, arc, ball, bezier, cyl, fillet, lathe, lathe_arc, oriented, rbox, ribbed, rod, sweep, threads, torus  # noqa: E402


def shaker(salt):
    if salt:
        glass = M("SaltGlass", "#cfeaf4", 0.06, alpha=0.36)
        fill = M("SaltFill", "#f4f4ef", 0.85)
        cap = M("SaltCap", "#c3cad1", 0.28, 0.6)
        band = M("SaltCapBand", "#ffffff", 0.12, 0.2)
        label = M("SaltLabel", "#f7f1dc", 0.6)
        accent = M("SaltAccent", "#2f79d8", 0.45)
    else:
        glass = M("PepperGlass", "#7f8aa3", 0.06, alpha=0.42)
        fill = M("PepperFill", "#1d1611", 0.9)
        cap = M("PepperCap", "#373c45", 0.3, 0.55)
        band = M("PepperCapBand", "#9aa3ae", 0.15, 0.3)
        label = M("PepperLabel", "#f1e6cc", 0.6)
        accent = M("PepperAccent", "#c8281f", 0.45)
    hole = M("ShakerHole", "#08080a", 0.9)
    body = fillet([(0, 0), (1.25, 0), (1.5, 0.35), (1.5, 3.2), (1.36, 4.4)], r=0.5, n=4)
    gp = body + threads(1.37, 4.5, 5.15, 3, 0.09) + [(1.3, 5.25), (0, 5.25)]
    parts = [lathe(glass, gp, verts=28)]
    fp = fillet([(0, 0.32), (1.3, 0.32), (1.44, 0.7), (1.44, 3.0), (1.22, 4.1), (0.6, 4.4), (0, 4.42)], r=0.35, n=3)
    parts.append(lathe(fill, fp, verts=24))
    cp = fillet([(0, 4.85), (1.47, 4.85), (1.47, 5.55), (1.41, 6.1), (1.06, 6.72), (0.62, 7.0), (0, 7.0)], r=0.36, n=4,
                radii={1: 0.06, 2: 0.05})
    parts.append(lathe(cap, cp, verts=28))
    # bright highlight band + grip grooves on the cap
    parts.append(lathe(band, [(0, 5.12), (1.5, 5.12), (1.5, 5.34), (0, 5.34)], verts=28))
    parts.append(lathe(band, [(0, 5.62), (1.455, 5.62), (1.435, 5.72), (0, 5.72)], verts=28))
    parts.append(torus(M("ShakerGroove", "#1a1d22", 0.5, 0.2), 1.47, 0.03, (0, 0, 5.45), seg=28, sides=5))
    # shaker holes
    spots = [(0, 0)] + [(0.4 * math.cos(a), 0.4 * math.sin(a)) for a in [i * math.pi / 3 for i in range(6)]] if salt else \
        [(0.34 * math.cos(a), 0.34 * math.sin(a)) for a in [math.pi / 2 + i * 2 * math.pi / 3 for i in range(3)]]
    for x, y in spots:
        parts.append(cyl(hole, 0.1, 0.05, (x, y, 7.0), verts=8))
    # label patch (front = -Y) with a tiny emblem
    parts.append(lathe_arc(label, [(1.515, 1.0), (1.515, 3.0)], 215, 325, 16))
    parts.append(lathe_arc(accent, [(1.525, 1.15), (1.525, 1.45)], 218, 322, 16))
    parts.append(lathe_arc(accent, [(1.525, 2.55), (1.525, 2.85)], 218, 322, 16))
    if salt:
        parts.append(sp.box(accent, (0.42, 0.06, 0.42), (0, -1.52, 2.0), rot=(0, math.pi / 4, 0)))
        for dx in (-0.55, 0.55):
            parts.append(sp.box(accent, (0.16, 0.05, 0.16), (dx, -1.5, 2.0), rot=(0, math.pi / 4, 0)))
    else:
        parts.append(ball(accent, (0.32, 0.06, 0.32), (0, -1.53, 2.0)))
        parts.append(ball(M("PepperLeaf", "#3a9b34", 0.5), (0.1, 0.05, 0.22), (0.05, -1.55, 2.32), rot=(0, 0.5, 0)))
    return parts, (3, 7, 3)


def ketchup_bottle():
    red = M("KetchupRed", "#d21f1c", 0.3)
    dark_red = M("KetchupDark", "#8f1110", 0.45)
    gloss = M("KetchupGloss", "#ff7a66", 0.15)
    cream = M("KetchupLabel", "#f6edd2", 0.6)
    white = M("KetchupCap", "#f7f7f2", 0.35)
    green = M("KetchupLeaf", "#3aa02c", 0.55)
    body = fillet([(0, 0), (1.45, 0), (1.75, 0.35), (1.75, 4.8), (1.55, 6.2), (1.0, 7.2), (0.86, 7.5), (0.86, 8.0), (0, 8.0)],
                  r=0.55, n=4, radii={1: 0.3, 2: 0.4, 3: 0.6, 4: 0.9, 5: 0.5, 6: 0.15})
    parts = [lathe(red, body, verts=32)]
    # neck ring + cap
    parts.append(lathe(white, fillet([(0, 7.62), (1.16, 7.62), (1.16, 7.92), (1.02, 8.05), (0, 8.05)], r=0.08, n=2), verts=28))
    parts.append(ribbed(white, 1.02, 1.0, 14, 0.05, (0, 0, 8.55), verts=56))
    parts.append(lathe(white, fillet([(0, 9.05), (1.02, 9.05), (0.78, 9.5), (0.45, 9.85), (0.32, 10.0), (0, 10.0)], r=0.2, n=3,
                                     radii={1: 0.05}), verts=28))
    parts.append(cyl(dark_red, 0.16, 0.05, (0, 0, 10.0), verts=8))
    # ketchup dribble down the cap
    parts.append(rod(red, (0.0, -0.72, 9.6), (0.0, -1.05, 8.85), 0.11, verts=8))
    parts.append(ball(red, (0.17, 0.17, 0.2), (0.0, -1.06, 8.72), seg=10, rings=6))
    # label + border stripes
    parts.append(lathe_arc(cream, [(1.765, 1.9), (1.765, 4.8)], 212, 328, 20))
    parts.append(lathe_arc(dark_red, [(1.775, 1.9), (1.775, 2.15)], 214, 326, 20))
    parts.append(lathe_arc(dark_red, [(1.775, 4.55), (1.775, 4.8)], 214, 326, 20))
    # tomato emblem
    parts.append(ball(red, (0.62, 0.09, 0.58), (0, -1.79, 3.35), seg=14, rings=8))
    parts.append(ball(gloss, (0.12, 0.05, 0.16), (-0.24, -1.86, 3.5), seg=8, rings=5))
    parts.append(ball(green, (0.28, 0.05, 0.1), (0, -1.86, 3.93), seg=8, rings=4))
    parts.append(ball(green, (0.1, 0.05, 0.28), (0, -1.86, 3.93), seg=8, rings=4))
    parts.append(ball(green, (0.24, 0.05, 0.08), (0, -1.86, 3.93), rot=(0, 0.8, 0), seg=8, rings=4))
    # glossy streak
    parts.append(lathe_arc(gloss, [(1.755, 0.85), (1.755, 4.4)], 188, 198, 3))
    return parts, (3.5, 10, 3.5)


def _dir(theta, phi):
    th, ph = math.radians(theta), math.radians(phi)
    return Vector((math.sin(th) * math.cos(ph), math.sin(th) * math.sin(ph), math.cos(th)))


def utensil_pot():
    teal = M("PotCeramic", "#2c94a3", 0.3)
    inside = M("PotInside", "#12363c", 0.6)
    cream = M("PotCream", "#f6ecd2", 0.4)
    yellow = M("PotDots", "#f2b632", 0.4)
    wood = M("UtensilWood", "#cf9455", 0.75)
    wood_dark = M("UtensilWoodDark", "#8b5a2b", 0.8)
    red = M("UtensilRed", "#dc2f2f", 0.4)
    black = M("UtensilBlack", "#25272b", 0.5)
    steel = M("UtensilSteel", "#d3d9df", 0.25, 0.55)
    slot = M("UtensilSlot", "#7a1414", 0.5)

    prof = fillet([(0, 0), (2.35, 0), (2.5, 0.15), (2.98, 0.95), (3.0, 1.1), (3.0, 6.8), (2.9, 7.15), (2.6, 7.15), (2.5, 6.9),
                   (2.5, 5.7), (0, 5.7)], r=0.28, n=3, radii={1: 0.05, 2: 0.15, 3: 0.4, 4: 0.5, 5: 0.12, 6: 0.12, 7: 0.1, 8: 0.1, 9: 0.15})
    parts = [lathe([teal, inside], prof, verts=40,
                   face_mat=lambda c: 1 if (math.hypot(c.x, c.y) < 2.55 and c.z > 5.6) else 0)]
    # decoration: cream bands and a row of yellow dots
    for z0, z1 in ((4.35, 4.7), (2.35, 2.7)):
        parts.append(lathe(cream, [(0, z0), (3.035, z0), (3.035, z1), (0, z1)], verts=40))
    for i in range(16):
        a = 2 * math.pi * i / 16
        parts.append(ball(yellow, (0.2, 0.2, 0.2), (3.0 * math.cos(a), 3.0 * math.sin(a), 3.52), seg=8, rings=5))
    # foot ring shadow line
    parts.append(torus(inside, 2.42, 0.05, (0, 0, 0.14), seg=32, sides=5))

    def handle(base, theta, phi, top, mat, r):
        d = _dir(theta, phi)
        L = (top - base[2]) / d[2]
        p1 = Vector(base) + d * L
        parts.append(rod(mat, base, p1, r, verts=10))
        return p1, d

    def hollow_head(mat, dark, p, d, hint, dims, off=0.0, dark_dims=None):
        x, y, z = sp.frame(d, hint)
        o = ball(mat, dims, p + d * off)
        o.rotation_euler = sp.euler_of(x, y, z)
        parts.append(o)
        rc = ball(dark, dark_dims or (dims[0] * 0.72, dims[1] * 0.9, dims[2] * 0.78), p + d * off + y * dims[1] * 0.55)
        rc.rotation_euler = sp.euler_of(x, y, z)
        parts.append(rc)

    # wooden spoon (leans -X)
    p1, d = handle((-1.1, 0.2, 5.9), 11, 180, 12.3, wood, 0.24)
    hollow_head(wood, wood_dark, p1 + d * 0.0, d, (0, -1, 0), (0.78, 0.26, 1.15), off=0.95)
    # spatula / turner, red silicone blade on a black handle (leans +X, slightly -Y)
    p1, d = handle((1.0, -0.7, 5.9), 9, 10, 11.4, black, 0.26)
    x, y, z = sp.frame(d, (0, 1, 0))
    blade = rbox(red, (1.7, 0.16, 2.3), p1 + d * 1.1, r=0.07, seg=2)
    blade.rotation_euler = sp.euler_of(x, y, z)
    parts.append(blade)
    for k in (-0.5, 0, 0.5):
        s = rbox(slot, (0.2, 0.2, 1.0), p1 + d * 1.5 + x * k, r=0.03, seg=1)
        s.rotation_euler = sp.euler_of(x, y, z)
        parts.append(s)
    # ladle (leans -Y)
    p1, d = handle((0.2, 0.9, 5.9), 9, 80, 12.8, steel, 0.2)
    x, y, z = sp.frame(d, (0, 0, 1))
    hollow_head(steel, M("LadleInner", "#6f777f", 0.35, 0.5), p1, d, (0, -1, 0), (0.9, 0.42, 0.9), off=0.5,
                dark_dims=(0.72, 0.4, 0.72))
    # whisk (leans +Y)
    p1, d = handle((-0.2, -1.4, 5.9), 9, -105, 10.6, black, 0.28)
    x, y, z = sp.frame(d, (0, 0, 1))
    for i in range(6):
        ang = math.pi * i / 6
        v = x * math.cos(ang) + y * math.sin(ang)
        pts = []
        for k in range(17):
            t = k / 16
            w = 0.78 * math.sin(math.pi * t) ** 0.8
            pts.append(p1 + d * (0.25 + 3.0 * t) + v * (w if t < 0.5 or True else w))
        loop = pts + [q + (v * -2 * ((q - p1 - d * ((q - p1).dot(d))).dot(v))) for q in pts[::-1]][1:-1]
        parts.append(sweep(steel, [tuple(q) for q in loop], 0.045, sides=5, closed=True))
    parts.append(cyl(steel, 0.32, 0.5, tuple(p1 + d * 0.1), verts=10))
    parts[-1].rotation_euler = sp.euler_of(x, y, z)
    return parts, (6, 14, 6)


def sink_tap():
    chrome = M("TapChrome", "#d7dfe6", 0.22, 0.5)
    shine = M("TapShine", "#ffffff", 0.1, 0.1)
    dark = M("TapDark", "#22262b", 0.6)
    blue = M("TapBlue", "#2a6fd6", 0.35)
    red = M("TapRed", "#d62a2a", 0.35)
    water = M("TapWater", "#7cc4f2", 0.05, alpha=0.6)
    R, zc = 2.6, 8.7
    parts = []
    base = fillet([(0, 0), (1.85, 0), (1.85, 0.35), (1.55, 0.8), (1.25, 1.0), (1.25, 1.5), (0, 1.5)], r=0.3, n=3, radii={1: 0.05})
    parts.append(lathe(chrome, base, verts=32))
    parts.append(torus(dark, 1.8, 0.07, (0, 0, 0.09), seg=32, sides=5))
    col = fillet([(0, 1.4), (1.2, 1.4), (1.05, 2.4), (1.0, 3.3), (1.1, 3.55), (1.1, 3.9), (0.95, 4.15), (0.85, 5.0), (0.8, zc), (0, zc)],
                 r=0.18, n=2, radii={1: 0.02, 8: 0.0, 9: 0})
    parts.append(lathe(chrome, col, verts=28))
    for z in (3.42, 3.98):
        parts.append(torus(chrome, 1.12, 0.09, (0, 0, z), seg=28, sides=6))
    # gooseneck arch
    pts = [(0, -R * (1 - math.cos(math.pi * i / 16)), zc + R * math.sin(math.pi * i / 16)) for i in range(17)]
    rads = [0.8 - 0.16 * (i / 16) for i in range(17)]
    parts.append(sweep(chrome, pts, rads, sides=16, caps=False))
    parts.append(ball(chrome, 0.8, pts[0], seg=16, rings=8))
    tip = Vector(pts[-1])
    # spout head: collar, aerator, dark screen
    parts.append(lathe(chrome, fillet([(0, tip.z - 2.05), (0.86, tip.z - 2.05), (0.86, tip.z - 0.4), (0.66, tip.z - 0.1), (0, tip.z - 0.1)],
                                      r=0.12, n=2, radii={1: 0.1}), verts=24, loc=(tip.x, tip.y, 0)))
    parts.append(lathe(dark, [(0, tip.z - 2.06), (0.55, tip.z - 2.06), (0.55, tip.z - 1.9), (0, tip.z - 1.9)], verts=16, loc=(tip.x, tip.y, 0)))
    parts.append(torus(shine, 0.9, 0.05, (tip.x, tip.y, tip.z - 1.35), seg=24, sides=5))
    # water drop
    dp = [(0, -0.5), (0.18, -0.4), (0.32, -0.12), (0.34, 0.08), (0.22, 0.3), (0.1, 0.55), (0, 0.78)]
    parts.append(lathe(water, dp, verts=12, loc=(tip.x, tip.y, tip.z - 2.75)))
    # highlight bands
    parts.append(rod(shine, (-0.42, -0.6, 1.9), (-0.42, -0.6, 3.1), 0.06, verts=6))
    parts.append(rod(shine, (-0.42, -0.6, 4.6), (-0.42, -0.5, 7.9), 0.07, verts=6))
    # (top-of-arch highlight follows the arch, offset towards the light)
    top_hl = []
    for i in range(3, 14):
        a = math.pi * i / 16
        c = Vector((0, -R, zc))
        outward = (Vector(pts[i]) - c).normalized()
        top_hl.append(tuple(Vector(pts[i]) + outward * (rads[i] * 0.86) + Vector((-0.28, 0, 0))))
    parts.append(sweep(shine, top_hl, 0.07, sides=5, caps=True))
    # two chunky knob handles with coloured domes
    kp = fillet([(0, 0), (1.0, 0), (1.0, 0.25), (0.86, 0.6), (0.52, 0.86), (0, 0.94)], r=0.22, n=3, radii={1: 0.05})
    for sx, mat in ((-1, blue), (1, red)):
        parts.append(rod(chrome, (sx * 0.7, 0, 3.75), (sx * 1.9, 0, 3.75), 0.42, verts=14))
        parts.append(lathe(mat, kp, verts=24, loc=(sx * 1.85, 0, 3.75)))
        parts[-1].rotation_euler = (0, sx * math.pi / 2, 0)
        parts.append(torus(chrome, 1.0, 0.09, (sx * 1.85, 0, 3.75), rot=(0, math.pi / 2, 0), seg=24, sides=6))
        parts.append(ball(shine, (0.16, 0.1, 0.1), (sx * 2.25, -0.35, 4.3), seg=8, rings=5))
    return parts, (6, 12, 8)


JOBS = (("salt_shaker", lambda: shaker(True)), ("pepper_shaker", lambda: shaker(False)),
        ("ketchup_bottle", ketchup_bottle), ("utensil_pot", utensil_pot), ("sink_tap", sink_tap))

sp.run(JOBS)
