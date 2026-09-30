"""Smooth-surface builders for the chef and glove (own helper file; does not touch shapes.py).

Everything is a parametric grid turned into a smooth-shaded bmesh object with one material.
Blender Z-up, front is -Y.
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Matrix, Quaternion, Vector  # noqa: E402

V = Vector


def _make(bm, mat, name, smooth=True):
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = smooth
    me.materials.append(mat)
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    return o


def grid(mat, f, nu, nv, closed=True, name="Part", outward=None, cap=False):
    """Parametric surface. f(u, v) -> Vector; u in [0,1) (periodic if closed), v in [0,1].

    outward: reference point; winding is flipped if normals point towards it on average
    (closed shapes are re-oriented by bmesh instead).
    """
    bm = bmesh.new()
    nuv = nu if closed else nu + 1
    rows = []
    for j in range(nv + 1):
        row = []
        for i in range(nuv):
            u = i / nu
            row.append(bm.verts.new(f(u, j / nv)))
        rows.append(row)
    for j in range(nv):
        for i in range(nuv if closed else nuv - 1):
            i2 = (i + 1) % nuv
            try:
                bm.faces.new((rows[j][i], rows[j][i2], rows[j + 1][i2], rows[j + 1][i]))
            except ValueError:
                pass
    if cap:
        for row in (rows[0], rows[-1]):
            try:
                bm.faces.new(row)
            except ValueError:
                pass
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    if closed:
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    elif outward is not None:
        bm.faces.ensure_lookup_table()
        s = 0.0
        for fc in bm.faces:
            s += fc.normal.dot(fc.calc_center_median() - V(outward))
        if s < 0:
            bmesh.ops.reverse_faces(bm, faces=bm.faces)
    return _make(bm, mat, name)


def ellip(mat, c, r, n=None, rot=None, nu=8, nv=5, name="Ellip", sq=None):
    """Ellipsoid centred at c with radii r. n: aim the local -Y (front) at this direction.
    rot: euler (x, y, z) applied before n. sq: superellipse exponent (>2 = boxier)."""
    rx, ry, rz = (r, r, r) if not isinstance(r, (tuple, list)) else r
    m = Matrix.Identity(3)
    if rot is not None:
        m = Matrix.Rotation(rot[2], 3, "Z") @ Matrix.Rotation(rot[1], 3, "Y") @ Matrix.Rotation(rot[0], 3, "X")
    if n is not None:
        q = V((0, -1, 0)).rotation_difference(V(n).normalized())
        m = q.to_matrix() @ m
    c = V(c)

    def sp(x, e):
        return math.copysign(abs(x) ** (2.0 / e), x)

    def f(u, v):
        th, ph = 2 * math.pi * u, math.pi * v
        s = math.sin(ph)
        if sq:
            p = V((rx * sp(s * math.cos(th), sq), ry * sp(s * math.sin(th), sq), rz * sp(math.cos(ph), sq)))
        else:
            p = V((rx * s * math.cos(th), ry * s * math.sin(th), rz * math.cos(ph)))
        return c + m @ p
    return grid(mat, f, nu, nv, name=name)


def _interp(table, t):
    """Catmull-Rom through table rows [(key, a, b, ...)] evaluated at key t (keys ascending)."""
    n = len(table)
    if t <= table[0][0]:
        return list(table[0][1:])
    if t >= table[-1][0]:
        return list(table[-1][1:])
    i = 0
    while table[i + 1][0] < t:
        i += 1
    p0, p1, p2, p3 = table[max(i - 1, 0)], table[i], table[i + 1], table[min(i + 2, n - 1)]
    s = (t - p1[0]) / (p2[0] - p1[0])
    out = []
    for k in range(1, len(p1)):
        a, b, c, d = p0[k], p1[k], p2[k], p3[k]
        out.append(0.5 * ((2 * b) + (-a + c) * s + (2 * a - 5 * b + 4 * c - d) * s * s + (-a + 3 * b - 3 * c + d) * s ** 3))
    return out


def superxy(rx, ry, th, e=2.4):
    c, s = math.cos(th), math.sin(th)
    return (rx * math.copysign(abs(c) ** (2 / e), c), ry * math.copysign(abs(s) ** (2 / e), s))


def lathe(mat, table, nu=32, nv=16, name="Lathe", mod=None, e=2.0, z0=None, z1=None, close_ends=True):
    """Surface of revolution. table rows: (z, rx, ry[, amp]); sampled with Catmull-Rom.
    mod(theta, amp) -> radial multiplier for pleats. e>2 = superelliptic section."""
    za = table[0][0] if z0 is None else z0
    zb = table[-1][0] if z1 is None else z1

    def f(u, v):
        z = za + (zb - za) * v
        row = _interp(table, z)
        rx, ry = row[0], row[1]
        amp = row[2] if len(row) > 2 else 0.0
        th = 2 * math.pi * u
        x, y = superxy(rx, ry, th + math.pi / 2, e)  # theta 0 = front (-Y)
        y = -y
        k = mod(th, amp) if mod else 1.0
        return V((x * k, y * k, z))
    return grid(mat, f, nu, nv, name=name)


def curve(points, samples=24):
    """Catmull-Rom sampled polyline through 3D points."""
    pts = [V(p) for p in points]
    tab = [(i, p.x, p.y, p.z) for i, p in enumerate(pts)]
    out = []
    for k in range(samples + 1):
        t = (len(pts) - 1) * k / samples
        a = _interp(tab, t)
        out.append(V(a))
    return out


def tube(mat, points, r, samples=None, seg=6, closed=False, name="Tube", taper=None):
    """Tube along a smooth path. r: radius or fn(t)->radius. Rounded ends unless closed."""
    rf0 = r if callable(r) else (lambda t: r)
    if rf0(0.5) < 0.02:
        seg = min(seg, 5)
    path = curve(points, max(4, (samples or len(points) * 4) // 2)) if not closed else points
    n = len(path)
    if closed:
        path = path + path[:1]
        n = len(path)
    rf = r if callable(r) else (lambda t: r)
    # frames by parallel transport
    tans = []
    for i in range(n):
        a = path[max(i - 1, 0)]
        b = path[min(i + 1, n - 1)]
        tans.append((b - a).normalized())
    up = V((0, 0, 1)) if abs(tans[0].z) < 0.9 else V((1, 0, 0))
    side = tans[0].cross(up).normalized()
    frames = []
    for i in range(n):
        t = tans[i]
        side = (side - t * side.dot(t))
        if side.length < 1e-6:
            side = t.cross(V((0, 0, 1)))
        side = side.normalized()
        frames.append((side, t.cross(side)))
    rings = []
    if not closed:
        r0 = rf(0)
        rings.append((path[0] - tans[0] * r0 * 0.5, 0.0, frames[0]))
        rings.append((path[0] - tans[0] * r0 * 0.3, r0 * 0.8, frames[0]))
    for i in range(n):
        t = i / (n - 1)
        rings.append((path[i], rf(t), frames[i]))
    if not closed:
        r1 = rf(1)
        rings.append((path[-1] + tans[-1] * r1 * 0.3, r1 * 0.8, frames[-1]))
        rings.append((path[-1] + tans[-1] * r1 * 0.5, 0.0, frames[-1]))
    bm = bmesh.new()
    vs = []
    for (p, rad, (s, b)) in rings:
        row = []
        for k in range(seg):
            a = 2 * math.pi * k / seg
            row.append(bm.verts.new(p + (s * math.cos(a) + b * math.sin(a)) * rad))
        vs.append(row)
    for j in range(len(vs) - 1):
        for k in range(seg):
            k2 = (k + 1) % seg
            try:
                bm.faces.new((vs[j][k], vs[j][k2], vs[j + 1][k2], vs[j + 1][k]))
            except ValueError:
                pass
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _make(bm, mat, name)


def ring(mat, c, rx, ry, r, z_wobble=0.0, seg=6, n=28, name="Ring", tilt=None):
    """Torus-like tube around an ellipse in the XY plane at centre c."""
    c = V(c)
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n
        p = V((rx * math.cos(a), ry * math.sin(a), z_wobble * math.sin(2 * a)))
        if tilt:
            p.z += tilt * p.y
        pts.append(c + p)
    return tube(mat, pts, r, seg=seg, closed=True, name=name)


def join_named(objs, name, mat_first=True):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    o.name = name
    o.data.name = name
    return o


def tri_count(objs):
    t = 0
    for o in objs:
        for p in o.data.polygons:
            t += len(p.vertices) - 2
    return t


def xf(o, m):
    """Bake a 4x4 matrix into the object's mesh data."""
    o.data.transform(m)
    return o
