"""Food part builders for the second ingredient batch (ingredients2.py).

Same conventions as foodparts.py: each builder takes an offset `o` (base centre) and
returns a list of Blender objects with materials assigned. Blender Z-up.
"""
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import artlib  # noqa: E402
from shapes import (ball, box, cyl, frustum, lathe, rod, roughen, _to_object, _assign)  # noqa: E402

PAL = {
    # bacon
    "BaconFatRaw": ("#f8ebe4", 0.35), "BaconMeatRaw": ("#e4636b", 0.35),
    "BaconFatCooked": ("#cf8136", 0.5), "BaconMeatCooked": ("#84281b", 0.55),
    "BaconFatBurnt": ("#3d2d25", 0.9), "BaconMeatBurnt": ("#120d0b", 0.95),
    # eggs
    "EggShell": ("#f1e3c8", 0.45), "EggSpeck": ("#bf9a6a", 0.6),
    "EggWhite": ("#fdfdf6", 0.3), "EggYolk": ("#ffb000", 0.12), "EggShine": ("#fff3c4", 0.2),
    "EggBurntWhite": ("#4a2f1b", 0.85), "EggBurntEdge": ("#8c4c18", 0.8),
    "EggBurntYolk": ("#1c120c", 0.9),
    # onion
    "OnionSkin": ("#c88a3c", 0.55), "OnionSkinDark": ("#b27632", 0.6), "OnionNeck": ("#e0bf7c", 0.7),
    "OnionRoot": ("#efe3bf", 0.8),
    "OnionPale": ("#f4ead2", 0.4), "OnionPurple": ("#b75aa6", 0.4), "OnionLilac": ("#e2c4dc", 0.4),
    "Batter": ("#eaa62c", 0.6), "BatterDark": ("#c2741a", 0.7), "BatterBurnt": ("#241912", 0.95),
    "BatterBurntLight": ("#4a3424", 0.95),
    # pickle
    "PickleSkin": ("#46892a", 0.4), "PickleDark": ("#2d6a1c", 0.5), "PickleFlesh": ("#b6d466", 0.4),
    "PickleCore": ("#e9f2b8", 0.4), "PickleSeed": ("#fffbe0", 0.4),
    # potato / fries
    "Potato": ("#b5824d", 0.85), "PotatoDark": ("#6d4424", 0.9), "PotatoEye": ("#51301a", 0.9),
    "FryRaw": ("#efe79a", 0.5), "FryRawEdge": ("#c9b755", 0.6),
    "Fry": ("#f6c531", 0.5), "FryTip": ("#d9921c", 0.6), "FryBurnt": ("#2b190c", 0.9),
    "FryBurntTip": ("#0f0905", 0.95),
    "Carton": ("#dc2d2d", 0.6), "CartonDark": ("#a51d1d", 0.7), "Logo": ("#ffd91a", 0.5),
    "LogoRing": ("#ffffff", 0.5), "CartonBurnt": ("#7c1b1b", 0.8),
    # chicken
    "ChickenRaw": ("#f0a39d", 0.22), "ChickenRawLump": ("#f7bdb6", 0.22), "ChickenFat": ("#fff0e4", 0.3),
    "Crust": ("#d08a28", 0.75), "CrustDark": ("#9c5214", 0.8), "CrustLight": ("#ecb446", 0.7),
    "ChickenBurnt": ("#1a1411", 0.95), "ChickenBurntLump": ("#35291f", 0.95),
    "Ash2": ("#8a847c", 1.0), "Ember2": ("#d04a10", 0.6),
    # soda
    "CupWhite": ("#f7f7f2", 0.6), "CupBand": ("#e8232e", 0.5), "CupBand2": ("#2b6fe0", 0.5),
    "CupLid": ("#2a2d36", 0.4), "StrawRed": ("#e8232e", 0.4), "StrawWhite": ("#ffffff", 0.4),
    "Drop": ("#cfe8ff", 0.1),
}


def m(name):
    hexc, rough = PAL[name]
    return artlib.material(name, hexc, roughness=rough)


def _hash(*a):
    return (math.sin(sum(v * k for v, k in zip(a, (12.9898, 78.233, 37.719, 4.581)))) * 43758.5453) % 1.0


def _add(o, x, y, z):
    return (o[0] + x, o[1] + y, o[2] + z)


# ---------------------------------------------------------------------------
# generic builders
# ---------------------------------------------------------------------------
def grid_sheet(mats, w, d, thick, nx, ny, dz, wfun=None, face_mat=None, loc=(0, 0, 0)):
    """Thick heightfield sheet nx x ny; y half-width scaled by wfun(x) (tapered ends).

    dz(x, y) is the vertical displacement; the lowest point ends on z = 0.
    """
    mats = list(mats) if isinstance(mats, (list, tuple)) else [mats]
    bm = bmesh.new()
    top = [[None] * (ny + 1) for _ in range(nx + 1)]
    bot = [[None] * (ny + 1) for _ in range(nx + 1)]
    for i in range(nx + 1):
        for j in range(ny + 1):
            x = (-1 + 2 * i / nx) * w / 2
            f = wfun(x) if wfun else 1.0
            y = (-1 + 2 * j / ny) * d / 2 * f
            z = dz(x, y)
            top[i][j] = bm.verts.new((x, y, z + thick))
            bot[i][j] = bm.verts.new((x, y, z))
    for i in range(nx):
        for j in range(ny):
            bm.faces.new((top[i][j], top[i + 1][j], top[i + 1][j + 1], top[i][j + 1]))
            bm.faces.new((bot[i][j], bot[i][j + 1], bot[i + 1][j + 1], bot[i + 1][j]))
    for i in range(nx):
        bm.faces.new((top[i][0], bot[i][0], bot[i + 1][0], top[i + 1][0]))
        bm.faces.new((top[i][ny], top[i + 1][ny], bot[i + 1][ny], bot[i][ny]))
    for j in range(ny):
        bm.faces.new((top[0][j], top[0][j + 1], bot[0][j + 1], bot[0][j]))
        bm.faces.new((top[nx][j], bot[nx][j], bot[nx][j + 1], top[nx][j + 1]))
    lo = min(v.co.z for v in bm.verts)
    for v in bm.verts:
        v.co.z -= lo
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if face_mat:
        for f in bm.faces:
            f.material_index = face_mat(f.calc_center_median())
    return _assign(_to_object(bm, "Strip", loc), mats)


def torus(mat_fn, mats, R, r, loc=(0, 0, 0), rot=(0, 0, 0), nu=16, nv=6, bump=0.0, seed=0, squash=1.0):
    """Bumpy torus lying flat (axis Z). mat_fn(ui, vi) -> material slot index."""
    mats = list(mats) if isinstance(mats, (list, tuple)) else [mats]
    bm = bmesh.new()
    vs = []
    for i in range(nu):
        u = 2 * math.pi * i / nu
        row = []
        for j in range(nv):
            v = 2 * math.pi * j / nv
            rr = r * (1.0 + bump * (_hash(i, j, seed) - 0.5) * 2)
            row.append(bm.verts.new(((R + rr * math.cos(v)) * math.cos(u),
                                     (R + rr * math.cos(v)) * math.sin(u),
                                     rr * math.sin(v) * squash)))
        vs.append(row)
    for i in range(nu):
        for j in range(nv):
            f = bm.faces.new((vs[i][j], vs[(i + 1) % nu][j], vs[(i + 1) % nu][(j + 1) % nv], vs[i][(j + 1) % nv]))
            f.material_index = mat_fn(i, j)
    obj = _assign(_to_object(bm, "Torus", loc), mats)
    obj.rotation_euler = rot
    return obj


def annulus(mat, r_in, r_out, z0, z1, loc=(0, 0, 0), verts=20):
    """Flat ring (rectangular section) between radii and heights."""
    bm = bmesh.new()
    a, b, c, d = [], [], [], []
    for k in range(verts):
        t = 2 * math.pi * k / verts
        ct, st = math.cos(t), math.sin(t)
        a.append(bm.verts.new((r_in * ct, r_in * st, z0)))
        b.append(bm.verts.new((r_out * ct, r_out * st, z0)))
        c.append(bm.verts.new((r_out * ct, r_out * st, z1)))
        d.append(bm.verts.new((r_in * ct, r_in * st, z1)))
    for k in range(verts):
        k2 = (k + 1) % verts
        bm.faces.new((a[k], b[k], b[k2], a[k2]))
        bm.faces.new((d[k], d[k2], c[k2], c[k]))
        bm.faces.new((b[k], c[k], c[k2], b[k2]))
        bm.faces.new((a[k], a[k2], d[k2], d[k]))
    return _assign(_to_object(bm, "Annulus", loc), [mat])


# ---------------------------------------------------------------------------
# bacon
# ---------------------------------------------------------------------------
def bacon(kind, o=(0, 0, 0), seed=0):
    L, W = 4.0, 1.2
    fat, meat = {"raw": ("BaconFatRaw", "BaconMeatRaw"),
                 "cooked": ("BaconFatCooked", "BaconMeatCooked"),
                 "burnt": ("BaconFatBurnt", "BaconMeatBurnt")}[kind]
    if kind == "raw":
        amp, lam, thick, nx = 0.05, 1.9, 0.14, 24
        ph = seed

        def dz(x, y):
            return amp * math.sin(2 * math.pi * x / lam + ph) + 0.03 * math.sin(2.1 * y + x)

        def wfun(x):
            return 1.0 - 0.06 * math.sin(3 * x)
    else:
        amp, lam, thick, nx = 0.085, 0.95, 0.09, 40
        ph = seed + (0.6 if kind == "burnt" else 0)

        def dz(x, y):
            u = y / (W / 2)
            return (amp * math.sin(2 * math.pi * x / lam + ph) * (0.8 + 0.2 * u)
                    + 0.05 * u * u * math.sin(math.pi * x / 1.3 + 1.0))

        def wfun(x):
            return 0.86 - 0.16 * math.sin(2 * math.pi * x / lam + ph + 1.4) ** 2

    def band(c):
        u = c.y / (W / 2 * wfun(c.x))
        wob = 0.05 * math.sin(1.7 * c.x) if kind == "raw" else 0.08 * math.sin(2.3 * c.x + seed)
        v = (u + 1) / 2 + wob
        return int(v * (7 if kind == "raw" else 6)) % 2  # 0 fat, 1 meat

    parts = [grid_sheet([m(fat), m(meat)], L, W, thick, nx, 6, dz, wfun, band, loc=o)]
    top_z = amp * 2 + thick  # rough height of the strip above its lowest point
    rng = random.Random(seed + 5)
    if kind == "burnt":
        for _ in range(9):
            x, y = rng.uniform(-1.7, 1.7), rng.uniform(-0.3, 0.3)
            parts.append(ball(m("Ash2"), (rng.uniform(0.12, 0.3), rng.uniform(0.08, 0.16), 0.04),
                              _add(o, x, y, dz(x, y) + amp + thick + 0.03), seg=6, rings=3))
    if kind == "cooked":
        for _ in range(6):  # shiny crisp blisters
            x, y = rng.uniform(-1.6, 1.6), rng.uniform(-0.35, 0.35)
            parts.append(ball(m("BaconFatCooked"), (0.12, 0.09, 0.03),
                              _add(o, x, y, dz(x, y) + amp + thick + 0.03), seg=6, rings=3))
    return parts


# ---------------------------------------------------------------------------
# eggs
# ---------------------------------------------------------------------------
def egg(o=(0, 0, 0)):
    H, R = 2.2, 0.9
    prof = [(0, 0), (0.4, 0.0)]
    n = 10
    for i in range(1, n):
        t = math.pi * i / n
        prof.append((R * math.sin(t) * (1 + 0.16 * math.cos(t)), H * (1 - math.cos(t)) / 2))
    prof.append((0, H))
    parts = [lathe(m("EggShell"), prof, verts=14, loc=o)]
    rng = random.Random(12)
    for _ in range(9):  # speckles
        a = rng.uniform(0, 6.28)
        z = rng.uniform(0.4, 1.9)
        t = math.acos(1 - 2 * z / H)
        r = R * math.sin(t) * (1 + 0.16 * math.cos(t)) * 0.99
        parts.append(ball(m("EggSpeck"), (0.09, 0.09, 0.05),
                          _add(o, r * math.cos(a), r * math.sin(a), z), rot=(0, 0, a), seg=5, rings=3))
    parts.append(ball(m("EggWhite"), (0.14, 0.05, 0.34), _add(o, -0.55, -0.68, 1.4), rot=(0, 0.3, 0.6), seg=6, rings=4))
    return parts


def _egg_f(a):
    return 1 + 0.13 * math.sin(3 * a + 0.5) + 0.08 * math.sin(5 * a + 2.0) + 0.04 * math.sin(9 * a)


def fried_egg(kind, o=(0, 0, 0)):
    R = 1.5
    burnt = kind == "burnt"
    prof = [(0, 0), (R, 0), (R, 0.06), (R * 0.96, 0.12), (R * 0.65, 0.15), (0, 0.15)]
    body = lathe(m("EggBurntWhite" if burnt else "EggWhite"), prof, verts=20, loc=o)
    roughen(body, (lambda a: 1 + 0.55 * (_egg_f(a) - 1)) if burnt else _egg_f)
    parts = [body]
    if burnt:
        rng = random.Random(3)
        for i in range(22):  # crisp lacy brown edge blisters
            a = 2 * math.pi * i / 22 + rng.uniform(-0.1, 0.1)
            rr = R * (1 + 0.55 * (_egg_f(a) - 1)) * rng.uniform(0.84, 0.97)
            parts.append(ball(m("EggBurntEdge"), (0.23, 0.17, 0.08), _add(o, rr * math.cos(a), rr * math.sin(a), 0.13),
                              rot=(0, 0, a), seg=6, rings=3))
        parts.append(ball(m("EggBurntYolk"), (0.6, 0.55, 0.14), _add(o, 0.15, -0.05, 0.14), seg=10, rings=4))
        for i in range(4):
            parts.append(ball(m("EggBurntEdge"), (0.12, 0.08, 0.05),
                              _add(o, 0.15 + 0.3 * math.cos(i * 1.7), -0.05 + 0.27 * math.sin(i * 1.7), 0.27),
                              seg=5, rings=3))
    else:
        parts.append(ball(m("EggYolk"), (0.66, 0.63, 0.3), _add(o, 0.12, -0.06, 0.11), seg=14, rings=8))
        parts.append(ball(m("EggShine"), (0.17, 0.09, 0.05), _add(o, -0.05, -0.32, 0.39), rot=(0, 0, 0.6), seg=6, rings=4))
    return parts


# ---------------------------------------------------------------------------
# onion family
# ---------------------------------------------------------------------------
def onion(o=(0, 0, 0)):
    prof = [(0, 0.14), (0.4, 0.1), (0.85, 0.2), (1.15, 0.6), (1.2, 1.1), (1.06, 1.6), (0.62, 2.0),
            (0.22, 2.25), (0.07, 2.4), (0, 2.4)]
    verts = 16

    def fm(c):
        if c.z > 2.0:
            return 2
        return int(((math.atan2(c.y, c.x) / (2 * math.pi)) % 1.0) * verts) % 2

    parts = [lathe([m("OnionSkin"), m("OnionSkinDark"), m("OnionNeck")], prof, verts=verts, loc=o, face_mat=fm)]
    for i in range(9):  # tuft of root hairs
        a = 2 * math.pi * i / 9
        parts.append(rod(m("OnionRoot"), _add(o, 0.12 * math.cos(a), 0.12 * math.sin(a), 0.22),
                         _add(o, 0.42 * math.cos(a), 0.42 * math.sin(a), 0.0), 0.035, verts=4))
    parts.append(ball(m("OnionNeck"), (0.28, 0.06, 0.45), _add(o, 0.95, -0.4, 1.0), rot=(0, 0.3, -0.4), seg=6, rings=4))
    return parts


def onion_slice(o=(0, 0, 0)):
    R = 1.1
    parts = [cyl(m("OnionLilac"), R, 0.18, _add(o, 0, 0, 0.09), verts=24)]
    parts.append(cyl(m("OnionPale"), 0.3, 0.3, _add(o, 0, 0, 0.15), verts=16))
    for ri, ro, col, h in [(0.38, 0.52, "OnionPale", 0.27), (0.62, 0.76, "OnionLilac", 0.30),
                           (0.84, 0.97, "OnionPale", 0.27), (1.0, 1.1, "OnionPurple", 0.30)]:
        parts.append(annulus(m(col), ri, ro, 0.0, h, loc=o, verts=28))
    return parts


def onion_rings(kind, o=(0, 0, 0)):
    burnt = kind == "burnt"
    main, alt = ("BatterBurnt", "BatterBurntLight") if burnt else ("Batter", "BatterDark")
    mats = [m(main), m(alt)]

    def mf(i, j):
        return 1 if _hash(i, j, 7) > 0.68 else 0

    specs = [  # (x, y, z, R, tilt_x, tilt_y)
        (-0.52, 0.0, 0.2, 0.82, 0.0, 0.0),
        (0.52, 0.05, 0.2, 0.82, 0.0, 0.0),
        (0.05, 0.55, 0.52, 0.72, 0.0, 0.0),
        (-0.05, -0.55, 0.5, 0.72, 0.0, 0.0),
    ]
    parts = []
    for n, (x, y, z, R, tx, ty) in enumerate(specs):
        parts.append(torus(mf, mats, R, 0.2, _add(o, x, y, z), (tx, ty, n), nu=16, nv=6,
                           bump=0.2 if burnt else 0.13, seed=n, squash=0.92))
    rng = random.Random(9)
    if burnt:
        for _ in range(7):
            a, r = rng.uniform(0, 6.28), rng.uniform(0.75, 1.15)
            parts.append(ball(m("Ash2"), (0.16, 0.1, 0.05), _add(o, r * math.cos(a) * 0.9, r * math.sin(a) * 0.9, 0.78),
                              seg=5, rings=3))
        for _ in range(4):
            a = rng.uniform(0, 6.28)
            parts.append(ball(m("Ember2"), (0.1, 0.06, 0.04), _add(o, 0.95 * math.cos(a), 0.95 * math.sin(a), 0.5),
                              seg=5, rings=3))
    else:
        for _ in range(10):  # crumbs
            a, r = rng.uniform(0, 6.28), rng.uniform(0.8, 1.2)
            parts.append(ball(m("BatterDark"), (0.11, 0.09, 0.07), _add(o, r * math.cos(a) * 0.95, r * math.sin(a) * 0.95, 0.72),
                              seg=5, rings=3))
    return parts


# ---------------------------------------------------------------------------
# pickle
# ---------------------------------------------------------------------------
def pickle_slice(o=(0, 0, 0)):
    R, H = 0.8, 0.2
    prof = [(0, 0), (R, 0), (R, 0.1), (R * 0.97, H), (0, H)]

    def fm(c):
        r = math.hypot(c.x, c.y)
        if c.z > H * 0.9:
            return 3 if r < 0.3 else (2 if r < 0.55 else 1)
        return 0

    body = lathe([m("PickleDark"), m("PickleSkin"), m("PickleFlesh"), m("PickleCore")], prof, verts=20, loc=o, face_mat=fm)
    roughen(body, lambda a: 1 + 0.045 * math.sin(11 * a) + 0.02 * math.sin(5 * a))
    parts = [body]
    for i in range(12):  # bumpy rim
        a = 2 * math.pi * i / 12
        parts.append(ball(m("PickleDark"), (0.11, 0.09, 0.09), _add(o, (R - 0.02) * math.cos(a), (R - 0.02) * math.sin(a), 0.1),
                          seg=6, rings=3))
    for i in range(7):  # seeds
        a = 2 * math.pi * i / 7
        rr = 0.17 if i else 0.0
        parts.append(ball(m("PickleSeed"), (0.085, 0.05, 0.03), _add(o, rr * math.cos(a), rr * math.sin(a), H + 0.005),
                          rot=(0, 0, a), seg=6, rings=3))
    for i in range(6):
        a = 2 * math.pi * i / 6 + 0.3
        parts.append(ball(m("PickleCore"), (0.1, 0.05, 0.03), _add(o, 0.43 * math.cos(a), 0.43 * math.sin(a), H + 0.005),
                          rot=(0, 0, a), seg=6, rings=3))
    return parts


# ---------------------------------------------------------------------------
# potato and fries
# ---------------------------------------------------------------------------
def _pot_k(d):
    x, y, z = d
    return (1.0 + 0.10 * math.sin(3.1 * x + 1.0) * math.cos(2.3 * y)
            + 0.08 * math.sin(4.3 * z + 2.0 * x) + 0.05 * math.cos(6.1 * y + 1.3 * z))


def potato(o=(0, 0, 0)):
    dims = (1.3, 1.0, 1.0)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=14, ring_count=9, radius=1, location=(o[0], o[1], o[2] + 1.0))
    obj = bpy.context.active_object
    for v in obj.data.vertices:
        d = v.co.normalized()
        v.co = d * _pot_k(d)
    obj.scale = dims
    artlib.with_material(obj, m("Potato"))
    parts = [obj]
    rng = random.Random(6)
    for e in [(0.3, -0.92, 0.25), (-0.55, -0.75, -0.2), (0.8, 0.5, 0.4), (-0.3, 0.9, 0.3), (0.05, -0.5, 0.85), (-0.85, 0.2, 0.5)]:
        d = Vector(e).normalized()
        p = d * _pot_k(d)
        c = (o[0] + p.x * dims[0], o[1] + p.y * dims[1], o[2] + 1.0 + p.z * dims[2])
        rot = (rng.uniform(0, 3), rng.uniform(0, 3), rng.uniform(0, 3))
        parts.append(ball(m("PotatoDark"), (0.26, 0.2, 0.06), c, rot=rot, seg=6, rings=3))
        parts.append(ball(m("PotatoEye"), (0.15, 0.11, 0.07), c, rot=rot, seg=6, rings=3))
    return parts


def fries_raw(o=(0, 0, 0)):
    rng = random.Random(21)
    parts = []
    t, n = 0.3, 6
    for layer in range(4):
        z = t / 2 + layer * t
        for k in range(n):
            off = (-1 + 2 * (k + 0.5) / n) * 1.25 + rng.uniform(-0.05, 0.05)
            ln = rng.uniform(2.35, 2.75)
            sh = rng.uniform(-0.15, 0.15)
            col = "FryRaw" if rng.random() > 0.3 else "FryRawEdge"
            rz = rng.uniform(-0.12, 0.12)
            rx = rng.uniform(-0.06, 0.06)
            zz = z + rng.uniform(-0.03, 0.05)
            if layer % 2 == 0:
                parts.append(box(m(col), (ln, t * 0.92, t * 0.92), _add(o, sh, off, zz), rot=(rx, 0, rz)))
            else:
                parts.append(box(m(col), (t * 0.92, ln, t * 0.92), _add(o, off, sh, zz), rot=(0, rx, rz)))
    return parts


def fries(kind, o=(0, 0, 0)):
    burnt = kind == "burnt"
    rng = random.Random(35 if burnt else 33)
    bw, tw, h = 2.0, 2.8, 1.3  # carton depth at bottom/top (Y), height; width X 2.0 -> 2.8
    parts = [frustum(m("CartonBurnt" if burnt else "Carton"), (2.0, bw), (2.8, tw), h, loc=o)]
    parts.append(box(m("CartonDark"), (2.82, 0.08, 0.1), _add(o, 0, -tw / 2, h - 0.05)))
    tilt = math.atan2((tw - bw) / 2, h)
    fy = -(bw / 2 + (tw - bw) / 2 * 0.45) - 0.02
    rot = (math.pi / 2 + tilt, 0, 0)
    parts.append(cyl(m("LogoRing"), 0.43, 0.04, _add(o, 0, fy, h * 0.45), rot=rot, verts=14))
    parts.append(cyl(m("Logo"), 0.33, 0.06, _add(o, 0, fy - 0.01, h * 0.45), rot=rot, verts=14))
    parts.append(box(m("CartonDark"), (0.1, 0.05, 0.36), _add(o, -0.07, fy - 0.045, h * 0.45), rot=(tilt, 0, 0)))
    parts.append(box(m("CartonDark"), (0.24, 0.05, 0.09), _add(o, 0.05, fy - 0.045, h * 0.45 + 0.13), rot=(tilt, 0, 0)))
    for k in range(24 if burnt else 30):
        a, r = rng.uniform(0, 6.28), rng.uniform(0.0, 1.0) ** 0.7 * 1.0
        x, y = r * math.cos(a) * 1.1, r * math.sin(a) * 1.0
        top = rng.uniform(1.75, 2.45) if burnt else rng.uniform(1.9, 2.5)
        ln = top - 0.7
        tx, ty = rng.uniform(-0.3, 0.3) + x * 0.15, rng.uniform(-0.3, 0.3) + y * 0.15
        c = (o[0] + x, o[1] + y, o[2] + 0.7 + ln / 2)
        col = "FryBurnt" if burnt else ("Fry" if rng.random() > 0.25 else "FryTip")
        parts.append(box(m(col), (0.24, 0.24, ln), c, rot=(ty, -tx, rng.uniform(0, 1.5))))
        if rng.random() > 0.5:
            parts.append(box(m("FryBurntTip" if burnt else "FryTip"), (0.25, 0.25, 0.1),
                             (c[0] + math.sin(-tx) * ln / 2, c[1] - math.sin(ty) * ln / 2, o[2] + top - 0.04),
                             rot=(ty, -tx, 0)))
    return parts


# ---------------------------------------------------------------------------
# chicken
# ---------------------------------------------------------------------------
def chicken(kind, o=(0, 0, 0)):
    R = 1.5
    body_col = {"raw": "ChickenRaw", "cooked": "Crust", "burnt": "ChickenBurnt"}[kind]

    def f(a):
        return 1 + 0.10 * math.sin(2 * a + 1.0) + 0.06 * math.sin(3 * a + 0.3) + 0.03 * math.sin(7 * a)

    H = 0.46
    prof = [(0, 0), (R * 0.88, 0), (R, 0.15), (R * 0.98, 0.32), (R * 0.72, H), (R * 0.35, H + 0.04), (0, H + 0.04)]
    body = lathe(m(body_col), prof, verts=20, loc=o)
    roughen(body, f)
    parts = [body]
    rng = random.Random({"raw": 2, "cooked": 4, "burnt": 6}[kind])
    if kind == "raw":
        for _ in range(7):  # soft muscle lobes
            a, r = rng.uniform(0, 6.28), rng.uniform(0.0, 0.9)
            parts.append(ball(m("ChickenRawLump"), (rng.uniform(0.35, 0.6), rng.uniform(0.3, 0.5), 0.16),
                              _add(o, r * math.cos(a), r * math.sin(a), H - 0.02), rot=(0, 0, a), seg=8, rings=4))
        parts.append(ball(m("ChickenFat"), (0.85, 0.09, 0.05), _add(o, 0.0, -0.25, H + 0.14), rot=(0, 0, 0.5), seg=8, rings=3))
        parts.append(ball(m("ChickenFat"), (0.4, 0.06, 0.04), _add(o, 0.2, 0.55, H + 0.1), rot=(0, 0, -0.9), seg=6, rings=3))
    else:
        cols = ("Crust", "CrustDark", "CrustLight") if kind == "cooked" else ("ChickenBurnt", "ChickenBurntLump", "ChickenBurntLump")
        for i in range(95):
            a, r = rng.uniform(0, 6.28), min(rng.uniform(0.0, 1.45) ** 1.0, 1.4)
            rr = r * f(a)
            z = H * (1 - (r / R) ** 2 * 0.9)
            s = rng.uniform(0.11, 0.22)
            parts.append(ball(m(cols[rng.randrange(3)]), (s * 1.2, s, s * 0.85),
                              _add(o, rr * math.cos(a), rr * math.sin(a), min(z + 0.08, 0.6)), rot=(0, 0, a), seg=6, rings=4))
        if kind == "burnt":
            for _ in range(5):
                a, r = rng.uniform(0, 6.28), rng.uniform(0.2, 1.2)
                parts.append(ball(m("Ember2"), (rng.uniform(0.2, 0.45), 0.05, 0.04),
                                  _add(o, r * math.cos(a), r * math.sin(a), H + 0.06), rot=(0, 0, rng.uniform(0, 3)), seg=5, rings=3))
            for _ in range(7):
                a, r = rng.uniform(0, 6.28), rng.uniform(0.2, 1.3)
                parts.append(ball(m("Ash2"), (rng.uniform(0.12, 0.25), 0.1, 0.05),
                                  _add(o, r * math.cos(a), r * math.sin(a), H + 0.1), seg=5, rings=3))
    return parts


# ---------------------------------------------------------------------------
# soda cup
# ---------------------------------------------------------------------------
def soda_cup(o=(0, 0, 0)):
    def r_at(z):
        return 0.72 + (0.98 - 0.72) * z / 2.3

    zs = [0, 0.25, 0.55, 0.9, 1.4, 1.75, 2.0, 2.3]
    prof = [(0, 0)] + [(r_at(z), z) for z in zs] + [(0, 2.3)]

    def fm(c):
        if 0.6 < c.z < 1.35:
            return 1
        if 1.35 <= c.z < 1.5 or 0.45 < c.z <= 0.6:
            return 2
        return 0

    parts = [lathe([m("CupWhite"), m("CupBand"), m("CupBand2")], prof, verts=20, loc=o, face_mat=fm)]
    parts.append(lathe(m("CupLid"), [(0, 2.25), (1.1, 2.25), (1.1, 2.4), (0.98, 2.42), (0.75, 2.55), (0.2, 2.6), (0, 2.6)],
                       verts=20, loc=o))
    sr = 0.085
    p0, p1, p2 = _add(o, 0.25, 0.0, 2.1), _add(o, 0.5, 0.0, 2.85), _add(o, 0.88, 0.0, 2.92)
    parts.append(rod(m("StrawRed"), p0, p1, sr, verts=6))
    parts.append(rod(m("StrawRed"), p1, p2, sr, verts=6))
    parts.append(ball(m("StrawRed"), sr, p1, seg=6, rings=3))
    for t in (0.35, 0.7):
        q = (p0[0] + (p1[0] - p0[0]) * t, 0.0, p0[2] + (p1[2] - p0[2]) * t)
        parts.append(ball(m("StrawWhite"), (sr * 1.15, sr * 1.15, 0.05), q, rot=(0, -0.25, 0), seg=6, rings=3))
    rng = random.Random(14)
    for _ in range(9):  # condensation drops
        a = rng.uniform(0, 6.28)
        z = rng.choice([rng.uniform(0.1, 0.5), rng.uniform(1.55, 2.15)])
        rr = r_at(z) + 0.01
        parts.append(ball(m("Drop"), (0.055, 0.04, 0.08), _add(o, rr * math.cos(a), rr * math.sin(a), z), rot=(0, 0, a),
                          seg=5, rings=3))
    return parts
