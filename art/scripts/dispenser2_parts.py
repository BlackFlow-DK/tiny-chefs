"""Food + prop builders for dispensers2.py (bacon, eggs, onions, pickles, potatoes, chicken).

Builders return Blender objects with materials, transforms not applied (see dispenser_parts.py).
"""
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bmesh  # noqa: E402
from mathutils import Euler, Vector  # noqa: E402

import shapes  # noqa: E402
from dispenser_parts import M, mk, put, rbox, soft_ball  # noqa: E402

PI = math.pi
D2R = math.radians


# ---------------------------------------------------------------------------
# text-like label bars
# ---------------------------------------------------------------------------
def bars(mat, x0, y, z, widths, h=0.12, gap=0.09, depth=0.05):
    """Row of small bars (fake print) starting at x0, on a front-facing surface at y."""
    out = []
    x = x0
    for w in widths:
        out.append(rbox(mat, (w, depth, h), (x + w / 2, y, z), r=0.02, seg=1))
        x += w + gap
    return out


# ---------------------------------------------------------------------------
# bacon
# ---------------------------------------------------------------------------
def bacon_strip(mats, L=3.6, w=0.55, seed=0, curl=0.0, amp=0.1, th=0.07, nu=16, nv=6):
    """Wavy bacon strip, base at the origin running along +X, bands of lean/fat (mats[0], mats[1])."""
    bm = bmesh.new()
    top, bot = {}, {}
    for i in range(nu + 1):
        u = i / nu
        for j in range(nv + 1):
            v = j / nv - 0.5
            wob = 1.0 + 0.10 * math.sin(u * 9.0 + seed * 1.7)
            x = u * L
            y = v * w * wob + 0.05 * w * math.sin(u * 6.0 + seed)
            z = amp * math.sin(u * 2 * PI * 1.35 + seed) * (0.5 + abs(v)) + curl * L * u * u
            top[(i, j)] = bm.verts.new((x, y, z + th))
            bot[(i, j)] = bm.verts.new((x, y, z))
    band = [0, 1, 0, 0, 1, 0]
    for i in range(nu):
        for j in range(nv):
            f = bm.faces.new((top[(i, j)], top[(i + 1, j)], top[(i + 1, j + 1)], top[(i, j + 1)]))
            f.material_index = band[j]
            bm.faces.new((bot[(i, j)], bot[(i, j + 1)], bot[(i + 1, j + 1)], bot[(i + 1, j)])).material_index = 0
    for i in range(nu):
        bm.faces.new((top[(i, 0)], bot[(i, 0)], bot[(i + 1, 0)], top[(i + 1, 0)])).material_index = 0
        bm.faces.new((top[(i, nv)], top[(i + 1, nv)], bot[(i + 1, nv)], bot[(i, nv)])).material_index = 0
    for j in range(nv):
        bm.faces.new((top[(0, j)], top[(0, j + 1)], bot[(0, j + 1)], bot[(0, j)])).material_index = 0
        bm.faces.new((top[(nu, j)], bot[(nu, j)], bot[(nu, j + 1)], top[(nu, j + 1)])).material_index = 0
    return mk(bm, mats, name="Bacon")


# ---------------------------------------------------------------------------
# eggs, onions, potatoes, pickles, chicken
# ---------------------------------------------------------------------------
def egg(mat, loc, rot=(0, 0, 0), a=0.84, b=0.62):
    """Egg standing on its wide end; centre at loc."""
    prof = [(0.0, -a)]
    for i in range(1, 10):
        t = PI * i / 10
        prof.append((b * math.sin(t) * (1 + 0.14 * math.cos(t)), -a * math.cos(t)))
    prof.append((0.0, a))
    o = shapes.lathe(mat, prof, verts=16, loc=loc)
    o.rotation_euler = rot
    return o


def onion(loc, rot=(0, 0, 0), s=1.0, seed=0, mats=None):
    skin, tip, root = mats
    parts = [soft_ball(skin, (0.92 * s, 0.92 * s, 0.78 * s), loc, rot, seg=14, rings=9, lump=0.05, seed=seed)]
    top = shapes.cyl(tip, 0.30 * s, 0.6 * s, (loc[0], loc[1], loc[2] + 0.88 * s), verts=8, r2=0.03 * s)
    bot = shapes.cyl(root, 0.17 * s, 0.14 * s, (loc[0], loc[1], loc[2] - 0.78 * s), verts=8, r2=0.3 * s)
    grp = parts + [top, bot]
    put(grp, rot=rot, pivot=loc)
    return grp


def potato(loc, rot=(0, 0, 0), s=1.0, seed=0, mats=None):
    skin, eye = mats
    rx, ry, rz = 1.0 * s, 0.68 * s, 0.6 * s
    parts = [soft_ball(skin, (rx, ry, rz), loc, (0, 0, 0), seg=12, rings=8, lump=0.18, seed=seed)]
    rng = random.Random(seed)
    for _ in range(5):
        d = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.2, 1))).normalized()
        p = Vector(loc) + Vector((d.x * rx, d.y * ry, d.z * rz)) * 0.97
        parts.append(soft_ball(eye, (0.09 * s, 0.09 * s, 0.05 * s), tuple(p), seg=6, rings=4))
    put(parts, rot=rot, pivot=loc)
    return parts


def pickle(mats, loc, length=2.6, r=0.46, rot=(0, 0, 0), seed=0):
    """Warty gherkin standing along local Z, centred on loc."""
    skin, dark = mats
    parts = [soft_ball(skin, (r, r, length / 2), loc, (0, 0, 0), seg=12, rings=9, lump=0.07, seed=seed)]
    rng = random.Random(seed)
    for _ in range(9):
        a = rng.uniform(0, 2 * PI)
        z = rng.uniform(-0.8, 0.8) * length / 2
        k = math.sqrt(max(0.0, 1 - (z / (length / 2)) ** 2))
        parts.append(soft_ball(dark, (0.07, 0.07, 0.06),
                               (loc[0] + r * k * math.cos(a), loc[1] + r * k * math.sin(a), loc[2] + z), seg=5, rings=3))
    put(parts, rot=rot, pivot=loc)
    return parts


def fillet(mats, loc, rot=(0, 0, 0), s=1.0, seed=0):
    """Raw chicken breast fillet: fat rounded end towards +X, tapering tail."""
    skin, pale, fat = mats
    parts = [soft_ball(skin, (1.15 * s, 0.78 * s, 0.3 * s), (loc[0] + 0.25 * s, loc[1], loc[2]), seg=14, rings=8, lump=0.06, seed=seed),
             soft_ball(skin, (0.85 * s, 0.5 * s, 0.24 * s), (loc[0] - 0.85 * s, loc[1] + 0.05 * s, loc[2] - 0.02 * s), seg=10, rings=6, lump=0.06, seed=seed + 1),
             soft_ball(pale, (0.6 * s, 0.3 * s, 0.06 * s), (loc[0] + 0.35 * s, loc[1] - 0.15 * s, loc[2] + 0.255 * s), seg=8, rings=4),
             soft_ball(fat, (0.3 * s, 0.14 * s, 0.05 * s), (loc[0] - 0.7 * s, loc[1] + 0.12 * s, loc[2] + 0.21 * s), seg=6, rings=4)]
    put(parts, rot=rot, pivot=loc)
    return parts


def fork(mat, top, tip, r=0.09, head=0.75, tines=3):
    """Table fork from handle end `top` to tine tips `tip` (steel)."""
    a, b = Vector(top), Vector(tip)
    d = (b - a).normalized()
    side = d.cross(Vector((0, 0, 1)))
    side = side.normalized() if side.length > 1e-4 else Vector((1, 0, 0))
    up = d.cross(side)
    L = (b - a).length
    t0 = L - 1.15                                     # tines start here
    parts = [shapes.rod(mat, a, a + d * t0, r, verts=8),
             shapes.rod(mat, a + d * (t0 - 0.05), a + d * (t0 + 0.12), r * 1.0, verts=8)]
    parts.append(shapes.ball(mat, r * 1.9, tuple(a), seg=8, rings=5))                     # handle knob
    palm = shapes.box_along(mat, a + d * (t0 + 0.12), d, (head, 0.05, 0.3))
    palm.rotation_euler = Euler(_basis_euler(side, up, d), "XYZ")
    parts.append(palm)
    for k in range(tines):
        o = (k - (tines - 1) / 2) * head / (tines - 1) * 0.92
        parts.append(shapes.rod(mat, a + d * (t0 + 0.1) + side * o, a + d * L + side * o, 0.045, verts=6))
    return parts


def _basis_euler(x, y, z):
    from mathutils import Matrix
    m = Matrix((x, y, z)).transposed()
    return m.to_euler()
