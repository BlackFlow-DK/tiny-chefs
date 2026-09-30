"""Theme props for the picnic map (theme "picnic").

Run: tools/blender-run.ps1 art/scripts/theme_picnic.py [-- model_name ...]
Blender Z-up, front = -Y, origin = base centre. Sizes are Godot X x Y(up) x Z.
"""
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from mathutils import Matrix, Vector  # noqa: E402

import theme_parts as tp  # noqa: E402
from theme_parts import (M, ball, bezier, cyl, fillet, lathe, place, prism_xz, rbox, rod, sweep, torus)  # noqa: E402


def lemon_slice(r, loc, rot=(0, 0, 0), thick=0.11):
    rind = M("LemonRind", "#f4cf2e", 0.45)
    pulp = M("LemonPulp", "#ffe566", 0.35, emission="#ffe566", emission_strength=0.5)
    pith = M("LemonPith", "#fff6c4", 0.5)
    parts = [cyl(rind, r, thick, (0, 0, 0), verts=18), cyl(pith, r * 0.88, thick + 0.02, (0, 0, 0), verts=18),
             cyl(pulp, r * 0.8, thick + 0.04, (0, 0, 0), verts=18)]
    for k in range(8):
        a = math.pi * k / 8
        parts.append(rbox(pith, (r * 1.62, 0.04, thick + 0.07), (0, 0, 0), rot=(0, 0, a), r=0.01, seg=1))
    parts.append(cyl(pith, r * 0.12, thick + 0.08, (0, 0, 0), verts=8))
    return place(parts, loc, rot)


# ---------------------------------------------------------------------------
def picnic_basket():
    w1 = M("WickerLight", "#d9a866", 0.85)
    w2 = M("WickerDark", "#b47c3e", 0.85)
    w3 = M("WickerRim", "#8d5a2a", 0.8)
    leather = M("BasketLeather", "#6b3b1e", 0.6)
    gold = M("BasketBuckle", "#e8b43a", 0.3, 0.8)
    inner = M("BasketInner", "#4a2d18", 0.9)
    red = M("GinghamRed", "#e0443c", 0.85)
    white = M("GinghamWhite", "#fbf3e4", 0.85)
    bread = M("Baguette", "#d9984a", 0.6)
    bread_c = M("BaguetteCut", "#f2d9a0", 0.6)
    YS = 0.68
    parts = []

    # body: tapered oval with a woven checker pattern
    zs = [0.0, 0.25, 0.65, 1.05, 1.45, 1.85, 2.25, 2.6, 2.9]
    prof = [(0, 0)] + [(3.9 + 0.5 * z / 2.9 - (0.25 * (1 - z / 0.5) if z < 0.5 else 0), z) for z in zs] + [(0, 2.9)]
    body = lathe([w1, w2], prof, verts=40,
                 face_mat=lambda c: (int(c.z / 0.36) + int((math.atan2(c.y / YS, c.x) + math.pi) / (2 * math.pi) * 40)) % 2)
    body.scale = (1, YS, 1)
    parts.append(body)
    # inside (dark) and rim
    parts.append(tp.cyl(inner, 4.05, 0.05, (0, 0, 2.6), verts=40))
    parts[-1].scale = (1, YS, 1)
    for z, rr, mat in ((2.9, 4.37, w3), (0.22, 4.0, w3)):
        rim = torus(mat, rr, 0.13, (0, 0, z), seg=40, sides=6)
        rim.scale = (1, YS, 1)
        parts.append(rim)

    def slat_flap(side, ang):
        """Half-elliptical lid of parallel slats hinged on the rim; side -1 = front half, +1 = back; ang = opening angle."""
        out = []
        n = 15
        for i in range(n):
            x = -4.2 + 8.4 * (i + 0.5) / n
            ch = 2.95 * math.sqrt(max(0.0, 1 - (x / 4.4) ** 2)) - 0.06
            if ch < 0.2:
                continue
            c = Vector((x, side * (ch / 2 + 0.02), 3.1))
            o = rbox(w1 if i % 2 == 0 else w2, (8.4 / n + 0.02, ch, 0.22), tuple(c), r=0.05, seg=1)
            if ang:
                from mathutils import Euler
                hinge = Vector((x, side * ch, 3.1))
                R = Euler((-side * ang, 0, 0)).to_matrix().to_4x4()
                T = Matrix.Translation(hinge) @ R @ Matrix.Translation(-hinge)
                tp.bpy_update()
                o.matrix_world = T @ o.matrix_world
            out.append(o)
        return out

    parts += slat_flap(-1, math.radians(20))
    back = slat_flap(1, math.radians(62))
    parts += back
    # frame edge around the closed front flap
    # leather strap + buckle at the front
    parts.append(rbox(leather, (0.5, 0.1, 2.1), (0, -2.93, 2.0), rot=(0.06, 0, 0), r=0.04, seg=1))
    parts.append(rbox(leather, (0.5, 0.1, 0.36), (0, -2.9, 3.2), r=0.04, seg=1))
    parts.append(torus(gold, 0.26, 0.04, (0, -3.0, 1.75), rot=(math.pi / 2, 0, 0), seg=12, sides=5))
    parts.append(rbox(gold, (0.12, 0.05, 0.5), (0, -3.0, 1.75), r=0.02, seg=1))

    # interior: gingham cloth bulging out, draped over the left rim
    cols, rows = 15, 10
    cw = 0.4
    grid = []
    for j in range(rows):
        row = []
        for i in range(cols):
            x = -4.7 + i * cw
            y = -0.4 + j * cw
            bump = 1.5 * math.exp(-(((x + 1.4) ** 2) / 3.6 + ((y - 1.5) ** 2) / 1.9))
            wave = 0.09 * math.sin(x * 2.3 + y * 1.7)
            z = 2.78 + bump + wave
            if x < -4.0:
                z -= (-4.0 - x) * 2.2
            row.append(Vector((x, y, z)))
        grid.append(row)
    cloth = tp.sheet_obj(red, grid, "Cloth", thick=0.05)
    cloth.data.materials.append(white)
    for p in cloth.data.polygons:
        c = p.center
        ix = int((c.x + 4.7) / cw / 1.0)
        iy = int((c.y + 0.4) / cw / 1.0)
        p.material_index = 1 if (ix + iy) % 2 == 0 else 0
    parts.append(cloth)
    # baguette poking out
    d = Vector((0.45, 0.06, 0.85))
    start = Vector((1.5, 1.0, 2.7))
    bag = tp.sp.oriented(tp.ball(bread, (0.42, 0.42, 1.6), (0, 0, 0), seg=12, rings=8), tuple(start + d.normalized() * 1.6), tuple(d))
    parts.append(bag)
    x, y, z = tp.sp.frame(d)
    for k in range(3):
        p = start + d.normalized() * (1.7 + k * 0.55)
        sl = tp.ball(bread_c, (0.3, 0.05, 0.11), tuple(p + (-y) * 0.36), seg=8, rings=4)
        sl.rotation_euler = tp.sp.euler_of(x, y, z)
        parts.append(sl)
    # swing handle
    hp = [(3.55 * math.cos(math.radians(a)), 0.05, 3.1 + 2.15 * math.sin(math.radians(a))) for a in range(0, 181, 12)]
    parts.append(sweep(w3, hp, (0.26, 0.26), sides=8))
    for a in range(18, 180, 36):
        pt = (3.55 * math.cos(math.radians(a)), 0.05, 3.1 + 2.15 * math.sin(math.radians(a)))
        parts.append(ball(w2, 0.3, pt, seg=8, rings=5))
    return parts, (9, 6, 6)


# ---------------------------------------------------------------------------
def lemonade_jug():
    glass = M("JugGlass", "#cfeef0", 0.05, alpha=0.3)
    juice = M("Lemonade", "#ffe36b", 0.15, alpha=0.75, emission="#ffe36b", emission_strength=0.45)
    steel = M("LadleSteel", "#c9d1d8", 0.25, 0.6)
    steel_d = M("LadleInner", "#8d979f", 0.4, 0.5)
    ice = M("JugIce", "#e8fbff", 0.1, alpha=0.6)
    parts = []
    outer = [(0, 0), (1.75, 0), (1.95, 0.12), (2.0, 0.6), (2.0, 3.2), (1.92, 5.0), (1.72, 6.1), (1.6, 6.8), (1.68, 7.15), (1.85, 7.35)]

    def wr(z):
        return tp.sp.wall_r(outer, z)

    # lemonade
    zs = [0.4, 0.8, 1.6, 3.2, 4.4, 5.3, 5.9]
    jp = [(0, 0.38)] + [(wr(z) - 0.12, z) for z in zs] + [(0, 5.95)]
    parts.append(lathe(juice, jp, verts=28))
    # lemon slices inside, pressed against the front wall, plus one floating on top
    parts.extend(lemon_slice(0.78, (-0.55, -(wr(4.9) - 0.24), 4.9), (math.pi / 2, 0, 0.2)))
    parts.extend(lemon_slice(0.74, (0.95, -(wr(3.3) - 0.24), 3.3), (math.pi / 2, 0, -0.35)))
    parts.extend(lemon_slice(0.7, (-0.8, -(wr(1.9) - 0.24), 1.9), (math.pi / 2, 0, 0.5)))
    parts.extend(lemon_slice(0.72, (0.3, 0.3, 5.92), (0.12, -0.1, 0.3)))
    for p in ((0.9, 0.6, 4.4), (-0.7, 0.9, 2.6), (0.2, -0.3, 1.0)):
        parts.append(tp.rbox(ice, (0.6, 0.6, 0.6), p, rot=(0.5, 0.3, 0.4), r=0.08, seg=1))
    # rim slice perched on the glass
    parts.extend(lemon_slice(0.78, (0.5, 1.55, 7.25), (math.pi / 2 - 0.25, 0, 0.0)))
    # ladle
    bowl_c = Vector((0.2, 0.25, 3.7))
    tip = Vector((-1.15, -2.95, 7.95))
    hp = bezier(tuple(bowl_c + Vector((0, 0, 0.5))), (0.0, -0.3, 5.5), (-0.6, -1.8, 7.7), tuple(tip), 12)
    parts.append(sweep(steel, [tuple(p) for p in hp], 0.12, sides=6))
    parts.append(ball(steel, (0.6, 0.6, 0.3), tuple(bowl_c), rot=(0.3, 0, 0), seg=12, rings=6))
    parts.append(ball(steel_d, (0.5, 0.5, 0.12), tuple(bowl_c + Vector((0, 0, 0.1))), rot=(0.3, 0, 0), seg=10, rings=4))
    parts.append(torus(steel, 0.17, 0.05, tuple(tip + Vector((0, 0, 0))), rot=(math.pi / 2, 0, 0.2), seg=10, sides=5))
    # pitcher handle (glass C shape on +X)
    hpath = bezier((1.9, 0, 6.0), (3.4, 0, 6.3), (3.4, 0, 2.3), (1.98, 0, 1.6), 14)
    parts.append(sweep(glass, [tuple(p) for p in hpath], [(0.3 - 0.06 * math.sin(math.pi * i / 14), 0.22) for i in range(15)], sides=8))
    # glass shell
    parts.append(lathe(glass, tp.glass_profile(outer, 0.1, 0.3), verts=32))
    # spout pinch at the front of the rim
    return parts, (5, 8, 5)


# ---------------------------------------------------------------------------
def watermelon_slice():
    rind_d = M("MelonRindDark", "#2b7a36", 0.5)
    rind = M("MelonRind", "#3e9b45", 0.5)
    pith = M("MelonPith", "#f3f7d6", 0.6)
    flesh_l = M("MelonFleshLight", "#ff7e86", 0.35)
    flesh = M("MelonFlesh", "#f2454f", 0.3)
    seed = M("MelonSeed", "#1d1512", 0.35)
    shine = M("MelonShine", "#ffb1b4", 0.2)
    zc, R = 0.47, 3.53

    def seg(r, y0, y1, mat, a0=None, a1=None, rin=None):
        if a0 is None:
            t0 = math.degrees(math.asin(max(-1.0, min(1.0, -zc / r))))
            pts = [(r * math.cos(math.radians(t0 + (180 - 2 * t0) * i / 28)), zc + r * math.sin(math.radians(t0 + (180 - 2 * t0) * i / 28))) for i in range(29)]
        else:
            n = 6
            outer = [(r * math.cos(math.radians(a0 + (a1 - a0) * i / n)), zc + r * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]
            inner = [(rin * math.cos(math.radians(a1 - (a1 - a0) * i / n)), zc + rin * math.sin(math.radians(a1 - (a1 - a0) * i / n))) for i in range(n + 1)]
            pts = outer + inner
        return prism_xz(mat, pts, y0, y1)

    parts = [seg(R, -0.85, 0.9, rind)]
    # darker stripes on the outside
    for k in range(7):
        a0 = 8 + k * 24
        parts.append(seg(R + 0.04, -0.8, 0.85, rind_d, a0 + 5, a0 + 15, R - 0.35))
    parts.append(seg(R - 0.08, -0.95, -0.83, pith))
    parts.append(seg(R - 0.4, -1.0, -0.93, flesh_l))
    parts.append(seg(R - 0.85, -1.05, -0.98, flesh))
    rnd = random.Random(5)
    spots = []
    tries = 0
    while len(spots) < 13 and tries < 400:
        tries += 1
        a = math.radians(rnd.uniform(25, 155))
        rr = rnd.uniform(1.0, 2.55)
        p = (rr * math.cos(a), zc + rr * math.sin(a))
        if p[1] < 0.55 or any(math.hypot(p[0] - q[0], p[1] - q[1]) < 0.75 for q in spots):
            continue
        spots.append(p)
    for (x, z) in spots:
        ang = math.atan2(z - zc, x)
        parts.append(ball(seed, (0.1, 0.04, 0.2), (x, -1.07, z), rot=(0, -(ang - math.pi / 2), 0) if False else (0, 0, 0), seg=8, rings=5))
        parts[-1].rotation_euler = (0, -(ang - math.pi / 2), 0)
    # juicy highlight
    parts.append(tp.sp.rod(shine, (-1.9, -1.08, 1.1), (-1.0, -1.08, 2.35), 0.07, verts=6))
    return parts, (7, 4, 2)


# ---------------------------------------------------------------------------
def daisy_flower():
    glass = M("DaisyGlass", "#d3f0f4", 0.05, alpha=0.3)
    water = M("DaisyWater", "#a8dcf0", 0.1, alpha=0.5, emission="#a8dcf0", emission_strength=0.3)
    green = M("DaisyStem", "#4ea83c", 0.6)
    green_l = M("DaisyLeaf", "#6cc24e", 0.55)
    petal = M("DaisyPetal", "#fffdf7", 0.5, emission="#fffdf7", emission_strength=0.25)
    petal2 = M("DaisyPetalShade", "#ecf0ef", 0.5)
    yellow = M("DaisyCentre", "#ffc629", 0.45)
    yellow_d = M("DaisyCentreDark", "#e59a12", 0.5)
    twine = M("DaisyTwine", "#c39a5e", 0.8)
    parts = []
    stem_pts = bezier((0, 0, 0.2), (0.15, 0.05, 1.8), (-0.2, -0.25, 3.4), (0.0, -0.55, 4.75), 14)
    parts.append(sweep(green, [tuple(p) for p in stem_pts], 0.085, sides=6))
    # leaves
    for sx, z, rot in ((1, 2.3, 0.9), (-1, 3.2, -0.8)):
        l = ball(green_l, (0.42, 0.11, 0.04), (0, 0, 0), seg=8, rings=4)
        p = stem_pts[int(len(stem_pts) * z / 4.9)]
        l.location = (p.x + sx * 0.42, p.y - 0.05, z)
        l.rotation_euler = (0.0, sx * -0.6, 0)
        parts.append(l)
    # flower head, tilted towards the camera
    n = Vector((0, -0.55, 0.83)).normalized()
    hc = Vector((0.0, -0.55, 4.95)) + n * 0.05
    head = []
    for layer, (mat, off, rad) in enumerate(((petal2, 0.0, 0.9), (petal, 0.06, 0.95))):
        for k in range(14):
            a = 2 * math.pi * (k + 0.5 * layer) / 14
            p = Vector((math.cos(a) * rad, math.sin(a) * rad, off))
            pet = ball(mat, (0.19, 0.56, 0.04), tuple(p), seg=8, rings=5)
            pet.rotation_euler = (0.15, 0, a - math.pi / 2)
            head.append(pet)
    head.append(ball(yellow, (0.42, 0.42, 0.2), (0, 0, 0.14), seg=12, rings=6))
    head.append(ball(yellow_d, (0.25, 0.25, 0.12), (0.0, 0.0, 0.26), seg=10, rings=5))
    for k in range(6):
        a = 2 * math.pi * k / 6
        head.append(ball(yellow_d, 0.06, (0.3 * math.cos(a), 0.3 * math.sin(a), 0.3), seg=6, rings=4))
    x, y, z = tp.sp.frame(n, (0, 1, 0))
    place(head, tuple(hc), frame=(x, y, z))
    parts += head
    # jar
    outer = [(0, 0), (0.78, 0), (0.88, 0.1), (0.92, 0.4), (0.92, 1.45), (0.8, 1.75), (0.72, 2.05)]
    zs = [0.3, 0.7, 1.2, 1.55]
    parts.append(lathe(water, [(0, 0.12)] + [(tp.sp.wall_r(outer, z) - 0.08, z) for z in zs] + [(0, 1.6)], verts=22))
    parts.append(lathe(glass, tp.glass_profile(outer, 0.07, 0.12), verts=24))
    parts.append(torus(twine, 0.75, 0.05, (0, 0, 1.9), seg=20, sides=5))
    parts.append(torus(twine, 0.77, 0.05, (0, 0, 1.78), seg=20, sides=5))
    # twine bow
    parts.append(ball(twine, (0.14, 0.06, 0.1), (0.35, -0.72, 1.85), seg=6, rings=4))
    parts.append(ball(twine, (0.14, 0.06, 0.1), (0.5, -0.66, 1.75), rot=(0, 0, 0.6), seg=6, rings=4))
    return parts, (3, 6, 3)


# ---------------------------------------------------------------------------
def paper_plates_stack():
    white = M("PlateWhite", "#fbf8f0", 0.85)
    cream = M("PlateCream", "#efe8d6", 0.85)
    red = M("PlateRed", "#e0443c", 0.7)
    blue = M("PlateBlue", "#4a86d6", 0.7)
    parts = []
    bottom = [(0, 0), (1.9, 0), (2.2, 0.05), (2.75, 0.3), (3.0, 0.34)]
    top = [(3.0, 0.39), (2.75, 0.35), (2.2, 0.1), (1.9, 0.05), (0, 0.05)]
    prof = bottom + top
    rnd = random.Random(2)
    for i in range(7):
        pl = lathe(white if i % 2 == 0 else cream, prof, verts=40, loc=(rnd.uniform(-0.05, 0.05), rnd.uniform(-0.05, 0.05), i * 0.27))
        for v in pl.data.vertices:
            if math.hypot(v.co.x, v.co.y) > 2.7:
                a = math.atan2(v.co.y, v.co.x)
                v.co.z += 0.04 * math.cos(20 * a + i) * (math.hypot(v.co.x, v.co.y) - 2.7) / 0.3
        pl.rotation_euler = (0, 0, rnd.uniform(0, 6.28))
        parts.append(pl)
    # printed rim stripes on the top plate
    ztop = 6 * 0.27
    parts.append(torus(red, 2.55, 0.035, (0, 0, ztop + 0.255), seg=40, sides=5))
    parts.append(torus(red, 2.72, 0.035, (0, 0, ztop + 0.325), seg=40, sides=5))
    parts.append(torus(blue, 2.0, 0.03, (0, 0, ztop + 0.085), seg=36, sides=5))
    for k in range(20):
        a = 2 * math.pi * k / 20
        parts.append(ball(red, (0.12, 0.05, 0.03), (2.4 * math.cos(a), 2.4 * math.sin(a), ztop + 0.2), rot=(0, 0, a), seg=6, rings=4))
    return parts, (6, 2, 6)


# ---------------------------------------------------------------------------
def ant():
    body = M("AntBody", "#3b2114", 0.35)
    body_l = M("AntBodyLight", "#6a3a1e", 0.35)
    white = M("AntEyeWhite", "#ffffff", 0.2)
    black = M("AntEyeBlack", "#0c0806", 0.2)
    shine = M("AntShine", "#d99a66", 0.2)
    parts = []
    parts.append(ball(body_l, (0.3, 0.42, 0.26), (0, 0.66, 0.3), seg=14, rings=8))
    parts.append(ball(body, (0.23, 0.33, 0.2), (0, -0.0, 0.36), seg=12, rings=7))
    parts.append(ball(body, 0.1, (0, 0.32, 0.32), seg=8, rings=5))
    parts.append(ball(body_l, (0.27, 0.27, 0.25), (0, -0.55, 0.38), seg=14, rings=8))
    parts.append(ball(shine, (0.07, 0.12, 0.05), (0.1, 0.5, 0.52), rot=(0, 0, 0.3), seg=6, rings=4))
    # eyes
    for s in (-1, 1):
        parts.append(ball(white, 0.09, (s * 0.15, -0.74, 0.44), seg=10, rings=6))
        parts.append(ball(black, 0.05, (s * 0.15, -0.81, 0.45), seg=8, rings=5))
        parts.append(ball(white, 0.018, (s * 0.135, -0.845, 0.475), seg=5, rings=3))
        # antennae
        pts = [(s * 0.09, -0.72, 0.56), (s * 0.15, -0.88, 0.6), (s * 0.26, -1.0, 0.54)]
        parts.append(sweep(body, pts, 0.022, sides=5))
        parts.append(ball(body, 0.045, (s * 0.26, -1.0, 0.54), seg=6, rings=4))
        # mandibles
        parts.append(rod(black, (s * 0.09, -0.78, 0.26), (s * 0.03, -0.9, 0.22), 0.03, verts=5))
    # legs: 3 pairs, knee up, foot down
    hips = (-0.2, -0.02, 0.15)
    kneey = (-0.42, -0.12, 0.42)
    footy = (-0.5, -0.02, 0.5)
    for s in (-1, 1):
        for hy, ky, fy in zip(hips, kneey, footy):
            hip = (s * 0.17, hy, 0.26)
            knee = (s * 0.5, ky, 0.5)
            foot = (s * 0.6, fy, 0.02)
            parts.append(sweep(body, [hip, knee, foot], 0.032, sides=5))
            parts.append(ball(body, 0.055, foot, seg=6, rings=4))
    for o in parts:
        o.location = Vector(o.location) * 0.93
        o.scale = Vector(o.scale) * 0.93
    return parts, (1.2, 0.6, 2.0)


# ---------------------------------------------------------------------------
def bee():
    yellow = M("BeeYellow", "#ffc820", 0.4)
    black = M("BeeBlack", "#231a12", 0.4)
    wing = M("BeeWing", "#dff4ff", 0.1, alpha=0.5)
    white = M("BeeEyeWhite", "#ffffff", 0.2)
    pupil = M("BeeEyePupil", "#0c0806", 0.2)
    cheek = M("BeeCheek", "#ff8a6b", 0.5)
    L = 0.52
    prof = [(0, -L)] + [(0.4 * math.sqrt(max(0.0, 1 - (z / L) ** 2)) , z) for z in [-0.49, -0.42, -0.3, -0.15, 0.0, 0.15, 0.3, 0.42, 0.49]] + [(0, L)]
    band = lambda c: int((c.z + L) / 0.175) % 2
    body = lathe([yellow, black], prof, verts=14, face_mat=band)
    body.rotation_euler = (-math.pi / 2, 0, 0)
    body.location = (0, 0.05, 0.47)
    parts = [body]
    # stinger
    parts.append(tp.sp.oriented(cyl(black, 0.07, 0.2, (0, 0, 0), verts=6, r2=0.0), (0, 0.66, 0.47), (0, 1, 0)))
    # head + face
    parts.append(ball(black, (0.27, 0.25, 0.26), (0, -0.6, 0.52), seg=14, rings=8))
    for s in (-1, 1):
        parts.append(ball(white, 0.11, (s * 0.14, -0.78, 0.56), seg=10, rings=6))
        parts.append(ball(pupil, 0.06, (s * 0.14, -0.87, 0.56), seg=8, rings=5))
        parts.append(ball(white, 0.02, (s * 0.12, -0.92, 0.59), seg=5, rings=3))
        parts.append(ball(cheek, (0.05, 0.02, 0.04), (s * 0.23, -0.81, 0.44), seg=6, rings=4))
        pts = [(s * 0.08, -0.72, 0.72), (s * 0.12, -0.83, 0.88), (s * 0.2, -0.88, 0.92)]
        parts.append(sweep(black, pts, 0.02, sides=5))
        parts.append(ball(yellow, 0.055, (s * 0.2, -0.89, 0.93), seg=6, rings=4))
        # wings
        w = ball(wing, (0.3, 0.22, 0.025), (s * 0.42, 0.0, 0.9), rot=(0, -s * 0.42, s * 0.12), seg=12, rings=5)
        parts.append(w)
        w2 = ball(wing, (0.2, 0.14, 0.02), (s * 0.36, 0.3, 0.86), rot=(0, -s * 0.38, -s * 0.2), seg=10, rings=4)
        parts.append(w2)
        # stubby legs
        for ly in (-0.25, 0.0, 0.25):
            parts.append(rod(black, (s * 0.17, ly, 0.2), (s * 0.27, ly, 0.0), 0.03, verts=5))
    parts.append(rbox(black, (0.12, 0.03, 0.02), (0, -0.88, 0.45), r=0.008, seg=1))
    for o in parts:
        o.location = Vector(o.location) * 0.95
        o.scale = Vector(o.scale) * 0.95
    return parts, (1.4, 1.0, 1.6)


# ---------------------------------------------------------------------------
def leaf():
    top = M("LeafTop", "#58b43e", 0.55)
    under = M("LeafUnder", "#3f8f30", 0.6)
    vein = M("LeafVein", "#a4dd72", 0.5)
    nt, ns = 14, 8
    y0, y1 = 0.93, -1.25  # base (back) to tip (front)

    def surf(t, s):
        w = 0.74 * math.sin(math.pi * t ** 0.78) ** 0.85
        x = s * w
        y = y0 + (y1 - y0) * t
        z = 0.07 * (1 - abs(s) ** 1.3) + 0.03 * math.sin(math.pi * t) - 0.04 * t * t + 0.012 * abs(s) * math.sin(11 * t)
        return Vector((x, y, z))

    grid = [[surf(i / (nt - 1), -1 + 2 * j / (ns - 1)) for j in range(ns)] for i in range(nt)]
    blade = tp.sheet_obj(top, grid, "Blade", thick=0.03)
    blade.data.materials.append(under)
    for p in blade.data.polygons:
        p.material_index = 1 if p.normal.z < -0.3 else 0
    parts = [blade]
    mid = [tuple(surf(i / 20 * 0.95, 0) + Vector((0, 0, 0.015))) for i in range(21)]
    parts.append(sweep(vein, mid, [(0.04 * (1 - 0.6 * i / 20), 0.025) for i in range(21)], sides=5))
    for side in (-1, 1):
        for k in range(1, 6):
            t0 = 0.12 + 0.14 * k
            a = surf(t0, 0)
            b = surf(min(0.97, t0 + 0.14), side * 0.78)
            m = (a + b) / 2 + Vector((0, 0, 0.02))
            parts.append(sweep(vein, [tuple(a + Vector((0, 0, 0.015))), tuple(m), tuple(b + Vector((0, 0, 0.012)))], 0.014, sides=4))
    stem = bezier((0, y0 + 0.02, 0.1), (0, y0 + 0.15, 0.1), (0.02, y0 + 0.26, 0.05), (0.06, y0 + 0.32, 0.0), 6)
    parts.append(sweep(under, [tuple(p) for p in stem], 0.04, sides=5))
    return parts, (1.5, 0.2, 2.5)


JOBS = (("picnic_basket", picnic_basket), ("lemonade_jug", lemonade_jug), ("watermelon_slice", watermelon_slice),
        ("daisy_flower", daisy_flower), ("paper_plates_stack", paper_plates_stack), ("ant", ant), ("bee", bee),
        ("leaf", leaf))

tp.sp.run(JOBS)
