"""Geometry helpers for beards and face accessories (face_items.py). Own helper file.

Everything is authored in the chef's RAW authoring frame (characters.py before the settle shift), Blender Z-up,
front = -Y, then translated so the model origin is its anchor (BeardAnchor / FaceAnchor). Head = ellipsoid
HC / HR (same numbers as characters.py).
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Matrix  # noqa: E402
from chef_parts import V, grid, ellip, tube, xf, tri_count, _interp  # noqa: E402,F401

PI = math.pi
HC = V((0.0, 0.0, 0.895))
HR = (0.238, 0.218, 0.212)
FACE_RAW = V((0.0, -0.21795, 0.90))


def head_xz(x, z, off=0.0):
    """Point/normal on the head front at lateral x, raw height z, pushed out by off."""
    dx, dz = x / HR[0], (z - HC.z) / HR[2]
    t = max(0.0, 1.0 - dx * dx - dz * dz)
    y = -HR[1] * math.sqrt(t)
    p = V((x, y, z))
    n = V((x / HR[0] ** 2, y / HR[1] ** 2, (z - HC.z) / HR[2] ** 2)).normalized()
    return p + n * off, n


def head_az(theta, z, off=0.0, smin=0.0):
    """Point/normal on the head at angle theta (0 = front, +x side positive) and raw height z."""
    dz = (z - HC.z) / HR[2]
    s = math.sqrt(max(0.0, 1.0 - dz * dz))
    s = max(s, smin)
    p = V((HR[0] * s * math.sin(theta), -HR[1] * s * math.cos(theta), z))
    n = V((p.x / HR[0] ** 2, p.y / HR[1] ** 2, (z - HC.z) / HR[2] ** 2))
    if n.length < 1e-6:
        n = V((0, 0, -1))
    n.normalize()
    return p + n * off, n


BEARD_RAW = head_xz(0.0, 0.817)[0]


def sm(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def to_anchor(parts, anchor):
    m = Matrix.Translation(-anchor)
    for o in parts:
        xf(o, m)
    return parts


def sq_pt(a, hw, hh, e):
    """Point on a superellipse (rounded rectangle for e > 2) at angle a."""
    c, s = math.cos(a), math.sin(a)
    return hw * math.copysign(abs(c) ** (2.0 / e), c), hh * math.copysign(abs(s) ** (2.0 / e), s)


def rrect_loop(cx, cz, hw, hh, e=3.0, n=28, off=0.0, rot=0.0):
    """Closed loop of points on the head surface following a rounded rectangle in (x, z)."""
    pts = []
    for i in range(n):
        a = 2 * PI * i / n
        dx, dz = sq_pt(a, hw, hh, e)
        if rot:
            dx, dz = dx * math.cos(rot) - dz * math.sin(rot), dx * math.sin(rot) + dz * math.cos(rot)
        pts.append(head_xz(cx + dx, cz + dz, off)[0])
    return pts


def disc_on_head(mat, cx, cz, hw, hh, e=3.0, off=0.0, nu=20, nv=3, name="Disc", rot=0.0):
    """Filled rounded-rect sheet following the head surface (a lens)."""
    def f(u, v):
        a = 2 * PI * u
        dx, dz = sq_pt(a, hw, hh, e)
        if rot:
            dx, dz = dx * math.cos(rot) - dz * math.sin(rot), dx * math.sin(rot) + dz * math.cos(rot)
        return head_xz(cx + dx * v, cz + dz * v, off)[0]
    return grid(mat, f, nu, nv, closed=True, name=name)


def make_mesh(bm, mat, name, smooth=True):
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = smooth
    me.materials.append(mat)
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    return o


def solid_patch(mat, rows, nfn, thick, closed_u=False, name="Patch", smooth=False):
    """Thin closed solid from a grid of 3D points (rows x cols); nfn(p) -> outward normal for the thickness."""
    bm = bmesh.new()
    F, B = [], []
    for row in rows:
        F.append([bm.verts.new(p + nfn(p) * thick * 0.5) for p in row])
        B.append([bm.verts.new(p - nfn(p) * thick * 0.5) for p in row])
    J, I = len(rows), len(rows[0])
    ni = I if closed_u else I - 1

    def quad(a, b, c, d):
        try:
            bm.faces.new((a, b, c, d))
        except ValueError:
            pass
    for j in range(J - 1):
        for i in range(ni):
            i2 = (i + 1) % I
            quad(F[j][i], F[j][i2], F[j + 1][i2], F[j + 1][i])
            quad(B[j][i2], B[j][i], B[j + 1][i], B[j + 1][i2])
    for i in range(ni):
        i2 = (i + 1) % I
        quad(B[0][i], B[0][i2], F[0][i2], F[0][i])
        quad(F[J - 1][i], F[J - 1][i2], B[J - 1][i2], B[J - 1][i])
    if not closed_u:
        for j in range(J - 1):
            quad(F[j][0], F[j + 1][0], B[j + 1][0], B[j][0])
            quad(B[j][I - 1], B[j + 1][I - 1], F[j + 1][I - 1], F[j][I - 1])
    return make_mesh(bm, mat, name, smooth)


def frame_ring(mat, cx, cz, hw, hh, w, e=3.0, n=28, off=0.0, thick=0.008, name="Frame", rot=0.0, smooth=False):
    """Flat card frame around a window: rounded-rect annulus of width w following the head surface."""
    inner = rrect_loop(cx, cz, hw, hh, e, n, off, rot)
    outer = rrect_loop(cx, cz, hw + w, hh + w, e, n, off, rot)
    nfn = lambda p: head_norm(p)  # noqa: E731
    return solid_patch(mat, [inner, outer], nfn, thick, closed_u=True, name=name, smooth=smooth)


def head_norm(p):
    n = V((p.x / HR[0] ** 2, p.y / HR[1] ** 2, (p.z - HC.z) / HR[2] ** 2))
    return n.normalized() if n.length > 1e-9 else V((0, -1, 0))


def strip_on_head(mat, path_aw, width, thick, off, n=40, name="Strap", smooth=False, closed=False):
    """Band hugging the head. path_aw(t) -> (theta, z_centre) for t in [0,1]; band is `width` tall."""
    rows = []
    for k in (-0.5, 0.5):
        row = []
        for i in range(n if closed else n + 1):
            t = i / n
            th, z = path_aw(t)
            row.append(head_az(th, z + k * width, off(t) if callable(off) else off)[0])
        rows.append(row)
    return solid_patch(mat, rows, head_norm, thick, closed_u=closed, name=name, smooth=smooth)


def hang_sheet(mat, rows, ztop_fn, zbot_fn, thm, nu=22, nv=14, name="Beard", top_blend=0.14, side_blend=0.3,
               rx_mod=None, ph_smin=0.35, top_off=0.004):
    """Beard curtain hanging from the jaw. rows: ascending (z, rx, ry, yf) with yf = front y at x=0; the
    cross-section at height z is the front arc of an ellipse (rx, ry) centred y = yf + ry. theta spans
    [-thm, thm]. The top edge and the side edges melt into the head surface."""
    tbl = sorted(rows)

    def f(u, v):
        th = (2 * u - 1) * thm
        zt, zb = ztop_fn(th), zbot_fn(th)
        z = zt + (zb - zt) * v
        rx, ry, yf = _interp(tbl, z)
        if rx_mod:
            rx *= rx_mod(z, th)
        pb = V((rx * math.sin(th), yf + ry - ry * math.cos(th), z))
        ph = head_az(th, z, top_off, smin=ph_smin)[0]
        k = sm(v / top_blend) * sm((thm - abs(th)) / (side_blend * thm))
        return ph + (pb - ph) * k
    return grid(mat, f, nu, nv, closed=False, name=name, outward=(0, 0.5, 0.8))


def loft(mat, rows, nu=24, nv=14, mod=None, name="Loft", cap=True):
    """Closed volume: stack of closed elliptical rings. rows ascending-z table (z, rx, ry, cy): ring at height z is
    x = rx sin t, y = cy - ry cos t (front = -y). mod(t, z) -> radial multiplier. Top/bottom are capped."""
    tbl = sorted(rows)
    z0, z1 = tbl[0][0], tbl[-1][0]

    def f(u, v):
        z = z1 + (z0 - z1) * v   # v=0 top
        rx, ry, cy = _interp(tbl, z)
        t = 2 * PI * u
        k = mod(t, z) if mod else 1.0
        return V((rx * k * math.sin(t), cy - ry * k * math.cos(t), z))
    return grid(mat, f, nu, nv, closed=True, name=name, cap=cap)


def hug_sheet(mat, th0, th1, ztop_fn, zbot_fn, off_fn, nu=16, nv=8, name="Hug"):
    """Pad hugging the head between angles th0..th1 and the height curves; off_fn(u, v) is the thickness
    (0 at the edges melts into the head)."""
    def f(u, v):
        th = th0 + (th1 - th0) * u
        zt, zb = ztop_fn(th, u), zbot_fn(th, u)
        z = zt + (zb - zt) * v
        return head_az(th, z, 0.003 + off_fn(u, v))[0]
    return grid(mat, f, nu, nv, closed=False, name=name, outward=(0, 0.2, 0.9))


def tube_on_head(mat, spec, r, samples=30, seg=7, name="Bar"):
    """spec: list of (x, raw z, off); tube following the head surface."""
    pts = [head_xz(x, z, o)[0] for x, z, o in spec]
    return tube(mat, pts, r, samples=samples, seg=seg, name=name)


def report(label, parts, anchor, check_head=True):
    """Print triangles and the minimum head-ellipsoid value over vertices (1 = on the head, <1 inside)."""
    tris = tri_count(parts)
    worst = 9.0
    inside = 0
    n = 0
    if check_head:
        for o in parts:
            if o.name.split(".")[0] in ("NoCheck",):
                continue
            for v in o.data.vertices:
                p = o.matrix_world @ v.co + anchor
                g = ((p.x / HR[0]) ** 2 + (p.y / HR[1]) ** 2 + ((p.z - HC.z) / HR[2]) ** 2)
                if abs(p.x) < 0.3:
                    n += 1
                    worst = min(worst, g)
                    if g < 0.985:
                        inside += 1
    print("REPORT %s: tris=%d min head-g=%.3f verts-inside-head=%d/%d" % (label, tris, worst, inside, n))
