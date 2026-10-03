"""Geometry helpers for chef outfits and back items (own helper file; characters.py/chef_parts.py untouched).

Everything is authored in the chef's RAW authoring frame (characters.py before the settle shift): Blender Z-up,
front is -Y, back is +Y, the character's own right is -X. `to_chef` shifts raw -> chef space (origin at the feet),
`to_anchor` shifts raw -> a model whose origin is the BackAnchor. The jacket helpers below are copies of the
ones in characters.py (that file builds the chef on import, so it cannot be imported).
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Matrix  # noqa: E402
from chef_parts import V, _interp, curve, ellip, grid, lathe, ring, superxy, tube, xf  # noqa: E402,F401

PI = math.pi
E = 2.4
CHEF_SHIFT = V((0.0, -0.03881, 0.006))
JT = [
    (0.18, 0.0, 0.0), (0.185, 0.215, 0.18), (0.20, 0.255, 0.215), (0.24, 0.268, 0.225), (0.34, 0.272, 0.228),
    (0.44, 0.266, 0.226), (0.54, 0.262, 0.222), (0.62, 0.256, 0.214), (0.68, 0.225, 0.19),
    (0.725, 0.165, 0.14), (0.755, 0.12, 0.10), (0.77, 0.10, 0.085), (0.775, 0.0, 0.0),
]
BACK_RAW = None  # set below


def jr(z):
    return _interp(JT, z)


def jpt(x, z, off=0.0, back=False):
    rx, ry = jr(z)
    rx += off
    ry += off
    q = max(0.0, 1.0 - min(abs(x) / rx, 1.0) ** E)
    y = ry * q ** (1.0 / E)
    return V((x, y if back else -y, z))


def jang(th, z, off=0.0):
    rx, ry = jr(z)
    x, y = superxy(rx + off, ry + off, th + PI / 2, E)
    return V((x, -y, z))


BACK_RAW = jpt(0.0, 0.60, 0.0, back=True)


def G(p):
    """Jacket implicit value: <1 inside, 1 on the surface."""
    if p.z >= 0.775 or p.z <= 0.18:
        return 9.0 if p.z >= 0.775 else 0.5
    rx, ry = jr(p.z)
    if rx < 1e-4:
        return 9.0
    return (abs(p.x) / rx) ** E + (abs(p.y) / ry) ** E


def jnormal(p):
    h = 1e-3
    g = V((G(p + V((h, 0, 0))) - G(p - V((h, 0, 0))), G(p + V((0, h, 0))) - G(p - V((0, h, 0))),
           G(p + V((0, 0, h))) - G(p - V((0, 0, h)))))
    return g.normalized() if g.length > 1e-9 else V((0, -1, 0))


def wrap_pt(x, ang_deg, off=0.0, cz=0.55):
    """Ray from (x, 0, cz) at angle ang (0 = front, 90 = up, 180 = back) to the jacket surface, pushed out by off
    along the surface normal. Returns (point, normal)."""
    a = math.radians(ang_deg)
    d = V((0, -math.cos(a), math.sin(a)))
    c = V((x, 0, cz))
    lo, hi = 0.0, 0.7
    for _ in range(40):
        mid = (lo + hi) / 2
        if G(c + d * mid) < 1.0:
            lo = mid
        else:
            hi = mid
    p = c + d * lo
    n = jnormal(p)
    return p + n * off, n


def push_out(objs, margin=0.006):
    """Move any vertex that is inside the jacket (+margin) radially out to the surface + margin (raw frame)."""
    moved = 0
    for o in objs:
        me = o.data
        for v in me.vertices:
            p = v.co
            if p.z > 0.775 or p.z < 0.2:
                continue
            if G(V((p.x, p.y, p.z))) < 1.0 + 0.0:
                # find the surface along the ray from the axis
                axis = V((0, 0, p.z))
                d = V((p.x, p.y, 0))
                if d.length < 1e-6:
                    d = V((0, 1, 0))
                d.normalize()
                lo, hi = 0.0, 0.6
                for _ in range(30):
                    mid = (lo + hi) / 2
                    if G(axis + d * mid) < 1.0:
                        lo = mid
                    else:
                        hi = mid
                v.co = axis + d * (lo + margin)
                moved += 1
    return moved


# ------------------------------------------------------------------ meshes
def _finish(bm, mats, name):
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    for m in mats:
        me.materials.append(m)
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    return o


def sheet(mat, f, nu, nv, thick=0.01, closed_u=False, name="Sheet", inner=None, flip=None):
    """Thin solid cloth: surface f(u, v) (u in [0,1], v in [0,1]) with thickness `thick` extruded toward the
    INSIDE of the normal given by f's du x dv (flip=True reverses). inner = optional material for the back layer."""
    bm = bmesh.new()
    nuv = nu if closed_u else nu + 1
    if flip is None:  # thickness goes toward the body axis (or toward the origin axis for non-body items)
        sc = 0.0
        for uu in (0.2, 0.5, 0.8):
            for vv in (0.2, 0.5, 0.8):
                p = f(uu, vv)
                a = f(min(uu + 1e-3, 1.0), vv) - f(max(uu - 1e-3, 0.0), vv)
                b = f(uu, min(vv + 1e-3, 1.0)) - f(uu, max(vv - 1e-3, 0.0))
                sc += a.cross(b).normalized().dot(V((p.x, p.y, 0)))
        flip = sc < 0

    def nrm(u, v):
        e = 1e-3
        a = f(min(u + e, 1.0), v) - f(max(u - e, 0.0), v)
        b = f(u, min(v + e, 1.0)) - f(u, max(v - e, 0.0))
        n = a.cross(b)
        if n.length < 1e-12:
            n = V((0, 0, 1))
        n.normalize()
        return -n if flip else n

    A, B = [], []
    for j in range(nv + 1):
        ra, rb = [], []
        for i in range(nuv):
            u, v = i / nu, j / nv
            p = f(u, v)
            ra.append(bm.verts.new(p))
            rb.append(bm.verts.new(p - nrm(u, v) * thick))
        A.append(ra)
        B.append(rb)
    mi = 1 if inner is not None else 0

    def quad(vs, idx):
        try:
            fc = bm.faces.new(vs)
            fc.material_index = idx
        except ValueError:
            pass
    rng_i = range(nuv) if closed_u else range(nuv - 1)
    for j in range(nv):
        for i in rng_i:
            i2 = (i + 1) % nuv
            quad((A[j][i], A[j][i2], A[j + 1][i2], A[j + 1][i]), 0)
            quad((B[j][i], B[j + 1][i], B[j + 1][i2], B[j][i2]), mi)
    for i in rng_i:
        i2 = (i + 1) % nuv
        quad((A[0][i], B[0][i], B[0][i2], A[0][i2]), 0)
        quad((A[nv][i], A[nv][i2], B[nv][i2], B[nv][i]), 0)
    if not closed_u:
        for j in range(nv):
            quad((A[j][0], A[j + 1][0], B[j + 1][0], B[j][0]), 0)
            quad((A[j][nuv - 1], B[j][nuv - 1], B[j + 1][nuv - 1], A[j + 1][nuv - 1]), 0)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _finish(bm, [mat] + ([inner] if inner is not None else []), name)


def strip(mat, xc, ang0, ang1, width, off=0.03, thick=0.012, n=14, name="Strip", cz=0.55):
    """Band running over the shoulder / chest: centre x = xc(a) at angle a (see wrap_pt), width across x."""
    def f(u, v):
        a = ang0 + (ang1 - ang0) * u
        return wrap_pt(xc(a) + (v - 0.5) * width, a, off, cz)[0]
    return sheet(mat, f, n, 3, thick, name=name)


def ribbon_path(mat, pts, width, thick=0.01, name="Ribbon", up=None, n=None):
    """Flat ribbon along a smooth path through pts. width direction = path tangent x up (up defaults to the
    direction from the body axis, i.e. the ribbon lies flat on the body)."""
    path = curve(pts, n or max(6, len(pts) * 3))
    m = len(path) - 1

    def f(u, v):
        t = min(max(u, 0.0), 1.0) * m
        i = min(int(t), m - 1)
        s = t - i
        p = path[i] * (1 - s) + path[i + 1] * s
        tan = (path[min(i + 1, m)] - path[max(i, 0)]).normalized()
        upv = up if up is not None else V((p.x, p.y, 0)).normalized()
        side = tan.cross(upv).normalized()
        return p + side * (v - 0.5) * width
    return sheet(mat, f, m, 2, thick, name=name)


def prism(mat, outline, origin, normal, depth=0.02, inset=0.2, name="Prism", sink=0.004, round_iters=1, up=None, scale=1.0, rot=0.0):
    """Pillowed flat shape: 2D outline [(a, b)] in the plane at `origin` facing `normal` (a = viewer's right, b = up),
    extruded outward by depth with an inset top. Concave outlines are fine (triangulated cap)."""
    pts = [V((a, b, 0)) for a, b in outline]
    for _ in range(round_iters):
        out = []
        for i in range(len(pts)):
            p, q = pts[i], pts[(i + 1) % len(pts)]
            out += [p * 0.75 + q * 0.25, p * 0.25 + q * 0.75]
        pts = out
    c = sum(pts, V((0, 0, 0))) / len(pts)
    n = V(normal).normalized()
    upv = V(up) if up is not None else V((0, 0, 1))
    upv = (upv - n * n.dot(upv))
    if upv.length < 1e-6:
        upv = V((0, 1, 0))
    upv.normalize()
    right = upv.cross(n)
    ca, sa = math.cos(rot), math.sin(rot)
    bm = bmesh.new()
    rings = []
    for k, (s, z) in enumerate(((1.0, -sink), (1.0, depth * 0.35), (1.0 - inset, depth))):
        row = []
        for p in pts:
            q = c + (p - c) * s * scale
            a, b = q.x * ca - q.y * sa, q.x * sa + q.y * ca
            row.append(bm.verts.new(V(origin) + right * a + upv * b + n * z))
        rings.append(row)
    L = len(pts)
    for k in range(2):
        for i in range(L):
            i2 = (i + 1) % L
            try:
                bm.faces.new((rings[k][i], rings[k][i2], rings[k + 1][i2], rings[k + 1][i]))
            except ValueError:
                pass
    for row in (rings[0], rings[2]):
        try:
            bm.faces.new(row)
        except ValueError:
            pass
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    return _finish(bm, [mat], name)


def star_outline(n=5, ro=1.0, ri=0.45, r0=-PI / 2):
    out = []
    for i in range(n * 2):
        r = ro if i % 2 == 0 else ri
        a = r0 + PI * i / n
        out.append((r * math.cos(a), -r * math.sin(a)))
    return out


def frame_up():
    return V((0, 0, 1))


# ------------------------------------------------------------------ placement
def to_chef(objs):
    m = Matrix.Translation(CHEF_SHIFT)
    for o in objs:
        xf(o, m)
    return objs


def to_anchor(objs):
    m = Matrix.Translation(-BACK_RAW)
    for o in objs:
        xf(o, m)
    return objs


def tris(objs):
    t = 0
    for o in objs:
        for p in o.data.polygons:
            t += len(p.vertices) - 2
    return t


def rbox(mat, c, size, sq=3.2, n=None, rot=None, nu=10, nv=6, name="Box"):
    """Rounded box (superellipsoid). size = full extents."""
    return ellip(mat, c, (size[0] / 2, size[1] / 2, size[2] / 2), n=n, rot=rot, nu=nu, nv=nv, sq=sq, name=name)


def cyl(mat, a, b, r, seg=10, name="Cyl", caps=True, taper=None):
    """Capped cylinder / cone from a to b (radius r or (ra, rb))."""
    a, b = V(a), V(b)
    ra, rb = (r, r) if not isinstance(r, tuple) else r
    ax = (b - a)
    L = ax.length
    ax.normalize()
    up = V((0, 0, 1)) if abs(ax.z) < 0.9 else V((1, 0, 0))
    s = ax.cross(up).normalized()
    t = ax.cross(s)
    bm = bmesh.new()
    rows = []
    prof = [(0.0, 0.0), (0.0, 1.0), (1.0, 1.0), (1.0, 0.0)] if caps else [(0.0, 1.0), (1.0, 1.0)]
    for pos, k in prof:
        rad = (ra + (rb - ra) * pos) * k
        c = a + ax * (L * pos)
        rows.append([bm.verts.new(c + (s * math.cos(2 * PI * i / seg) + t * math.sin(2 * PI * i / seg)) * rad) for i in range(seg)])
    for j in range(len(rows) - 1):
        for i in range(seg):
            i2 = (i + 1) % seg
            try:
                bm.faces.new((rows[j][i], rows[j][i2], rows[j + 1][i2], rows[j + 1][i]))
            except ValueError:
                pass
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _finish(bm, [mat], name)


def smooth(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def waist_band(mat, z0, z1, off_front, off_back=None, th0=-PI, th1=PI, bulge=0.012, nu=40, name="Band", thick=0.012,
               nv=4, inner=None, taper=0.07):
    """Belt-like band round the jacket between heights z0 < z1. th: 0 = front, +-pi = back. Offset blends from
    off_front (|th| < 100 deg) to off_back (|th| > 160 deg) so a back bow can be covered."""
    full = abs((th1 - th0) - 2 * PI) < 1e-6
    off_back = off_front if off_back is None else off_back

    def f(u, v):
        th = th0 + (th1 - th0) * u
        w = (th + PI) % (2 * PI) - PI
        b = smooth(math.radians(100), math.radians(165), abs(w))
        off = off_front + (off_back - off_front) * b + bulge * math.sin(PI * v)
        zc, hh = (z0 + z1) / 2, (z1 - z0) / 2
        if not full:
            k = min(1.0, min(u, 1 - u) / taper) ** 0.6
            hh *= k
            off = off * (0.55 + 0.45 * k)
        z = zc + hh * (1 - 2 * v)
        p = jang(th, min(max(z, 0.19), 0.72), off)
        p.z = z
        return p
    return sheet(mat, f, nu, nv, thick, closed_u=full, name=name, inner=inner, flip=False)


def loop_ribbon(mat, th0_deg, amp, zc, width, off=0.035, nu=44, name="Loop", thick=0.01, th_range=None, gap_z=None):
    """Diagonal band round the torso (sash, guitar strap): height z = zc + amp * cos(th - th0); th0 is where it
    is highest (over a shoulder). th_range=(a, b) in degrees limits it to part of the loop."""
    th0 = math.radians(th0_deg)
    a0, a1 = (-PI, PI) if th_range is None else (math.radians(th_range[0]), math.radians(th_range[1]))
    full = th_range is None

    def c(th):
        z = zc + amp * math.cos(th - th0)
        p = jang(th, z, off)
        p.z = z
        return p

    def f(u, v):
        th = a0 + (a1 - a0) * u
        p = c(th)
        t = (c(th + 0.01) - c(th - 0.01)).normalized()
        n = jnormal(p - jnormal(p) * off)
        w = t.cross(n).normalized()
        return p + w * (v - 0.5) * width + n * 0.006 * math.sin(PI * v)
    return sheet(mat, f, nu, 4, thick, closed_u=full, name=name)


def blob(mat, c, A, B, C, ra, rb, rc, nu=8, nv=4, name="Blob"):
    """Ellipsoid with arbitrary orthonormal axes A (long), B, C and radii ra, rb, rc, centred at c."""
    A, B, C, c = V(A), V(B), V(C), V(c)

    def f(u, v):
        th, ph = 2 * PI * u, PI * v
        s = math.sin(ph)
        return c + A * (ra * math.cos(ph)) + B * (rb * s * math.cos(th)) + C * (rc * s * math.sin(th))
    return grid(mat, f, nu, nv, name=name)


def revolve(mat, prof, origin, axis, nu=24, name="Rev"):
    """Closed surface of revolution about `axis` through `origin`; prof = [(r, h), ...] from one pole round to the
    other (h runs along the axis)."""
    ax = V(axis).normalized()
    up = V((0, 0, 1)) if abs(ax.z) < 0.9 else V((1, 0, 0))
    s = ax.cross(up).normalized()
    t = ax.cross(s)
    o = V(origin)
    n = len(prof) - 1

    def f(u, v):
        k = min(int(v * n), n - 1)
        w = v * n - k
        r = prof[k][0] * (1 - w) + prof[k + 1][0] * w
        h = prof[k][1] * (1 - w) + prof[k + 1][1] * w
        th = 2 * PI * u
        return o + ax * h + (s * math.cos(th) + t * math.sin(th)) * r
    return grid(mat, f, nu, n * 2, closed=True, name=name)
