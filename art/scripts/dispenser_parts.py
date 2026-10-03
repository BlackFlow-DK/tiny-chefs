"""Helpers for the detailed dispenser models (bmesh based; nothing shared is edited).

All builders return Blender objects (or lists of them) with materials assigned and
transforms NOT yet applied. `finish()` joins, smooths, grounds, checks and exports.
"""
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Euler, Matrix, Vector, noise  # noqa: E402

import artlib  # noqa: E402
import shapes  # noqa: E402

M = artlib.material


# ---------------------------------------------------------------------------
# object plumbing
# ---------------------------------------------------------------------------
def mk(bm, mats, loc=(0, 0, 0), rot=(0, 0, 0), name="Part"):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = loc
    obj.rotation_euler = rot
    for m in (mats if isinstance(mats, (list, tuple)) else [mats]):
        mesh.materials.append(m)
    return obj


def put(objs, move=(0, 0, 0), rot=(0, 0, 0), pivot=(0, 0, 0)):
    """Rotate `objs` (Euler XYZ, radians) about `pivot`, then translate by `move`."""
    if not isinstance(objs, (list, tuple)):
        objs = [objs]
    R = Euler(rot, "XYZ").to_matrix().to_4x4()
    mat = (Matrix.Translation(move) @ Matrix.Translation(pivot) @ R @ Matrix.Translation(-Vector(pivot)))
    for o in objs:
        o.matrix_basis = mat @ o.matrix_basis
    return objs


def flat(*groups):
    out = []
    for g in groups:
        if isinstance(g, (list, tuple)):
            out.extend(flat(*g))
        else:
            out.append(g)
    return out


# ---------------------------------------------------------------------------
# primitives
# ---------------------------------------------------------------------------
def rbox(mat, size, loc=(0, 0, 0), rot=(0, 0, 0), r=0.08, seg=2):
    """Box with bevelled edges. size = full extents."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z *= size[2]
    r = min(r, min(size) * 0.48)
    if r > 0.004:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=r, offset_type="OFFSET",
                        profile=0.5, segments=seg, affect="EDGES")
    return mk(bm, mat, loc, rot, "RBox")


def disc(mat, r, thick, loc, verts=20, facing="front", r2=None):
    """Round disc/puck. facing: 'front' (axis Y, disc visible from -Y) or 'up'."""
    rot = (math.pi / 2, 0, 0) if facing == "front" else (0, 0, 0)
    o = shapes.cyl(mat, r, thick, loc, rot, verts=verts, r2=r2)
    return o


def soft_ball(mat, radii, loc=(0, 0, 0), rot=(0, 0, 0), seg=14, rings=9, lump=0.0, seed=0):
    """Ellipsoid with optional lumpy noise; poles on local Z."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=1.0)
    rx, ry, rz = radii if isinstance(radii, (tuple, list)) else (radii,) * 3
    for v in bm.verts:
        p = v.co.copy()
        if lump:
            f = 1.0 + lump * noise.noise(p * 1.7 + Vector((seed * 3.1, seed * 1.7, seed * 0.7)))
            p *= f
        v.co = Vector((p.x * rx, p.y * ry, p.z * rz))
    return mk(bm, mat, loc, rot, "Ball")


def superellipse(n, hw, hd, e):
    pts = []
    for k in range(n):
        t = 2 * math.pi * k / n
        c, s = math.cos(t), math.sin(t)
        pts.append((hw * math.copysign(abs(c) ** (2 / e), c), hd * math.copysign(abs(s) ** (2 / e), s)))
    return pts


def loft(mats, secs, n=24, e=2.6, cap_start=False, cap_end=False, wob=None, mat_of=None,
         loc=(0, 0, 0), rot=(0, 0, 0)):
    """Loft superellipse rings along local Z.

    secs: list of (z, half_w, half_d, cx, cy). wob(theta, z) -> radial factor (crinkles).
    mat_of(face_centre) -> material slot index.
    """
    bm = bmesh.new()
    rings = []
    for (z, hw, hd, cx, cy) in secs:
        ring = []
        for k, (x, y) in enumerate(superellipse(n, max(hw, 0.001), max(hd, 0.001), e)):
            f = wob(2 * math.pi * k / n, z) if wob else 1.0
            ring.append(bm.verts.new((cx + x * f, cy + y * f, z)))
        rings.append(ring)
    for a, b in zip(rings[:-1], rings[1:]):
        for k in range(n):
            k2 = (k + 1) % n
            bm.faces.new((a[k], a[k2], b[k2], b[k]))
    if cap_start:
        bm.faces.new(rings[0][::-1])
    if cap_end:
        bm.faces.new(rings[-1])
    o = mk(bm, mats, loc, rot, "Loft")
    if mat_of:
        for p in o.data.polygons:
            p.material_index = mat_of(Vector(p.center))
    return o


def sweep(mat, pts, radii, verts=8, cap=True, loc=(0, 0, 0), rot=(0, 0, 0), name="Sweep", closed=False):
    """Tube along a polyline with per-point radius (list or scalar)."""
    pts = [Vector(p) for p in pts]
    n = len(pts)
    tang = [(pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized() for i in range(n)]
    ref = Vector((0, 0, 1)) if abs(tang[0].z) < 0.9 else Vector((1, 0, 0))
    nrm = (ref - tang[0] * ref.dot(tang[0])).normalized()
    bm = bmesh.new()
    rings = []
    for i in range(n):
        if i:
            nrm = nrm - tang[i] * nrm.dot(tang[i])
            nrm.normalize()
        bn = tang[i].cross(nrm)
        r = radii[i] if isinstance(radii, (list, tuple)) else radii
        r = max(r, 0.012)
        ring = [bm.verts.new(pts[i] + (nrm * math.cos(2 * math.pi * k / verts)
                                       + bn * math.sin(2 * math.pi * k / verts)) * r) for k in range(verts)]
        rings.append(ring)
    for a, b in zip(rings[:-1], rings[1:]):
        for k in range(verts):
            k2 = (k + 1) % verts
            bm.faces.new((a[k], a[k2], b[k2], b[k]))
    if closed:
        a, b = rings[-1], rings[0]
        for k in range(verts):
            k2 = (k + 1) % verts
            bm.faces.new((a[k], a[k2], b[k2], b[k]))
    elif cap:
        bm.faces.new(rings[0][::-1])
        bm.faces.new(rings[-1])
    return mk(bm, mat, loc, rot, name)


def ring_tube(mat, secs_pt, r, z, n=32, e=4.0, verts=6, loc=(0, 0, 0)):
    """Closed tube following a superellipse outline (hw, hd, cx, cy) at height z."""
    hw, hd, cx, cy = secs_pt
    pts = [(cx + x, cy + y, z) for x, y in superellipse(n, hw, hd, e)]
    return sweep(mat, pts, r, verts=verts, closed=True, loc=loc, name="RingTube")


def sausage(mat, p0, p1, r, bend=0.0, verts=10, bulge=0.06):
    """Rounded sausage from p0 to p1 (end points of the whole body incl. caps)."""
    a, b = Vector(p0), Vector(p1)
    d = b - a
    L = d.length
    dn = d / L
    side = dn.cross(Vector((0, 0, 1)))
    side = side.normalized() if side.length > 1e-4 else Vector((1, 0, 0))
    up = side.cross(dn)
    body = L - 2 * r
    t_list = []
    for j in (5, 4, 3, 2, 1):
        th = j * math.pi / 2 / 6
        t_list.append((r - r * math.sin(th), r * math.cos(th)))
    for i in range(7):
        t = r + body * i / 6
        t_list.append((t, r * (1 + bulge * math.sin(math.pi * i / 6))))
    for j in (1, 2, 3, 4, 5):
        th = j * math.pi / 2 / 6
        t_list.append((L - r + r * math.sin(th), r * math.cos(th)))
    pts, rad = [], []
    for t, rr in [(0.0, 0.05 * r)] + t_list + [(L, 0.05 * r)]:
        u = t / L
        off = bend * (1 - (2 * u - 1) ** 2)
        pts.append(a + dn * t + up * off * 0 + side * off)
        rad.append(rr)
    return sweep(mat, pts, rad, verts=verts, cap=True, name="Sausage")


def leaf(mats, length, width, cup=0.5, ruffle=0.15, seed=0, thick=0.0, nu=9, nv=7, rib=None, base_pale=0.28,
         curl=0.0, freq=3.4, rib_w=0.16):
    """Ruffled leaf growing along +X from its base, cupped up (+Z). mats = [green, pale, rib?]"""
    bm = bmesh.new()
    top = {}
    for i in range(nu + 1):
        u = i / nu
        hw = width / 2 * max(0.04, math.sin(math.pi * u ** 0.62)) ** 0.5
        for j in range(nv + 1):
            v = -1 + 2 * j / nv
            x = u * length
            y = v * hw
            z = cup * (v * hw) ** 2 / (width / 2) + curl * length * u * u
            z += ruffle * width * 0.5 * (abs(v) ** 2.2) * min(1.0, u * 3.0) * math.sin(freq * math.pi * u + seed * 2.1 + 1.6 * v)
            y += 0.03 * width * abs(v) * math.sin(4.5 * u + seed)
            top[(i, j)] = bm.verts.new((x, y, z))
    for i in range(nu):
        for j in range(nv):
            f1 = bm.faces.new((top[(i, j)], top[(i + 1, j)], top[(i + 1, j + 1)], top[(i, j + 1)]))
            u = (i + 0.5) / nu
            v = -1 + 2 * (j + 0.5) / nv
            slot = 0
            if rib is not None and abs(v) < rib_w and u < 0.9:
                slot = 2
            elif u < base_pale:
                slot = 1
            f1.material_index = slot
    return mk(bm, mats, name="Leaf")


def wavy_sheet(mat, w, d, thick, n, fz, loc=(0, 0, 0), rot=(0, 0, 0)):
    """shapes.sheet wrapper: displaced slab, then positioned/rotated."""
    o = shapes.sheet(mat, w, d, thick, n, fz)
    o.location = loc
    o.rotation_euler = rot
    return o


def crinkle_fn(amp=0.06, freq=1.6, seed=0):
    off = Vector((seed * 5.3, seed * 2.9, seed * 1.3))

    def f(theta, z):
        return 1.0 + amp * noise.noise(Vector((math.cos(theta) * freq * 2, math.sin(theta) * freq * 2, z * freq)) + off) \
            + amp * 0.5 * math.sin(theta * 9 + z * 2.0 + seed)
    return f


def barcode(mat_dark, mat_bg, loc, w=1.0, h=0.5, seed=1, facing_y=-1):
    """Barcode label on a Y-facing surface at loc (centre)."""
    rng = random.Random(seed)
    parts = [rbox(mat_bg, (w, 0.05, h), loc, r=0.015, seg=1)]
    x = -w / 2 + 0.07
    y = loc[1] + facing_y * 0.03
    while x < w / 2 - 0.09:
        bw = rng.choice((0.03, 0.05, 0.08))
        parts.append(shapes.box(mat_dark, (bw, 0.03, h * 0.7), (loc[0] + x + bw / 2, y, loc[2])))
        x += bw + rng.choice((0.03, 0.05))
    return parts


def sticker(mat_a, mat_b, loc, r=0.3, points=0):
    """Price-sticker: round disc with a smaller centre disc, facing front."""
    return [disc(mat_a, r, 0.05, loc, verts=20), disc(mat_b, r * 0.62, 0.06, (loc[0], loc[1] - 0.005, loc[2]), verts=16)]


# ---------------------------------------------------------------------------
# finishing
# ---------------------------------------------------------------------------
def tri_count(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def finish(name, parts, limits, smooth_deg=48):
    parts = flat(parts)
    obj = artlib.join(parts, "".join(p.capitalize() for p in name.split("_")))
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(smooth_deg))
    try:
        got = shapes.settle(name, None, limits=limits)
    except RuntimeError as ex:
        print("SIZE-WARNING", ex)
        got = None
    print(f"TRIS {name}: {tri_count(obj)}")
    artlib.export_glb(name)
    return got
