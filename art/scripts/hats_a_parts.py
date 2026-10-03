"""Geometry helpers for hats_a.py (own file; hats_parts.py / chef_parts.py are untouched).

Frame: Blender Z-up, origin = HatAnchor, front = -Y. The head (hats_parts.HEAD_*) has its top at z = 0.132;
a hat rim sits near z = 0 (front a little higher over the brows, back lower over the hair).
`Rev` is a surface of revolution whose horizontal section is the chef's egg (flat front, roomy back that clears
the back hair) for narrow radii and fades to a plain circle for wide brims.
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bmesh  # noqa: E402
import bpy  # noqa: E402,F401
from chef_parts import V, _interp, _make, ellip, grid, tube, xf  # noqa: E402,F401
from hats_parts import PI, clearance, tilt  # noqa: E402,F401

RXREF, RYF, RYB = 0.262, 0.237, 0.29


def clamp(x, a=0.0, b=1.0):
    return max(a, min(b, x))


def smoothstep(a, b, x):
    t = clamp((x - a) / (b - a))
    return t * t * (3 - 2 * t)


class Rev:
    """Surface of revolution. path = [(r, z), ...] swept around Z. u = fraction of the turn (0 = front, 0.5 = back).
    warp(p, theta) -> p is applied to every point (used for brim curls, dents, bends)."""

    def __init__(self, path, per=2, dy=0.0, egg=True, smooth=True, warp=None):
        self.dy, self.egg, self.warp = dy, egg, warp
        if smooth and per > 0 and len(path) > 2:
            tab = [(i, r, z) for i, (r, z) in enumerate(path)]
            n = (len(path) - 1) * per
            self.pts = [tuple(_interp(tab, (len(path) - 1) * k / n)) for k in range(n + 1)]
        else:
            self.pts = [tuple(p) for p in path]
        self.nv = len(self.pts) - 1

    def k(self, th, r):
        if not self.egg:
            return 1.0
        b = (1 + math.cos(th)) / 2
        ry = RYB + (RYF - RYB) * b
        return 1 + (ry / RXREF - 1) * clamp((0.34 - r) / 0.08)

    def at(self, u, r, z):
        th = 2 * PI * u
        p = V((r * math.sin(th), self.dy - r * self.k(th, r) * math.cos(th), z))
        return self.warp(p, th) if self.warp else p

    def pt(self, u, j):
        r, z = self.pts[j]
        return self.at(u, r, z)

    def mesh(self, mat, nu, name):
        return grid(mat, lambda u, v: self.pt(u, int(round(v * self.nv))), nu, self.nv, closed=True, name=name)

    def ring(self, j, n):
        return [self.pt(i / n, j) for i in range(n)]

    def r_at_z(self, z):
        """Radius of the (z-monotone) profile at height z."""
        for (r0, z0), (r1, z1) in zip(self.pts, self.pts[1:]):
            if (z0 - z) * (z1 - z) <= 0 and z1 != z0:
                return r0 + (r1 - r0) * (z - z0) / (z1 - z0)
        return self.pts[-1][0]

    def j_near(self, r, z):
        return min(range(len(self.pts)), key=lambda j: (self.pts[j][0] - r) ** 2 + (self.pts[j][1] - z) ** 2)

    def normal(self, u, j):
        j0, j1 = max(j - 1, 0), min(j + 1, self.nv)
        du = 1e-3
        a = self.pt(u + du, j) - self.pt(u - du, j)
        b = self.pt(u, j1) - self.pt(u, j0)
        n = a.cross(b)
        if n.length < 1e-9:
            return V((0, 0, 1))
        n.normalize()
        p = self.pt(u, j)
        if n.dot(V((p.x, p.y - self.dy, 0))) < 0:
            n = -n
        return n


class Frame:
    """Local frame on a surface: right (+X-ish), up, out = normal. P(a, b, c) = p + right*a + up*b + out*c."""

    def __init__(self, p, n, up=(0, 0, 1)):
        self.p, self.n = V(p), V(n).normalized()
        self.r = V(up).cross(self.n)
        if self.r.length < 1e-6:
            self.r = V((1, 0, 0))
        self.r.normalize()
        self.u = self.n.cross(self.r)

    def P(self, a=0.0, b=0.0, c=0.0):
        return self.p + self.r * a + self.u * b + self.n * c


def star(mat, fr, size, name="Star", lift=0.14, points=5):
    """Flat 5-point star pyramid lying on a surface frame."""
    bm = bmesh.new()
    apex = bm.verts.new(fr.P(0, 0, size * lift))
    ring = []
    for i in range(points * 2):
        ang = PI / 2 + i * PI / points
        rad = size if i % 2 == 0 else size * 0.45
        ring.append(bm.verts.new(fr.P(math.cos(ang) * rad, math.sin(ang) * rad, 0.0)))
    for i in range(len(ring)):
        bm.faces.new((apex, ring[i], ring[(i + 1) % len(ring)]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _make(bm, mat, name, smooth=False)


def paint_panels(obj, mats, n, dy=0.0):
    """Assign material slots 0..len(mats)-1 to the n vertical panels (by angle) of a Rev mesh."""
    for m in mats:
        if m.name not in [x.name for x in obj.data.materials]:
            obj.data.materials.append(m)
    ids = {m.name: i for i, m in enumerate(obj.data.materials)}
    for p in obj.data.polygons:
        c = p.center
        u = (math.atan2(c.x, -(c.y - dy)) / (2 * PI)) % 1.0
        p.material_index = ids[mats[int(u * n) % len(mats)].name]


def tri_count(objs):
    return sum(len(p.vertices) - 2 for o in objs for p in o.data.polygons)
