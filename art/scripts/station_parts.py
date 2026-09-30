"""Mesh accumulator + layered-surface helpers for the station models.

Everything is appended into ONE bmesh with several material slots (`Acc`), so a
model with hundreds of inlays is still one cheap object. Shading: every face is
smooth, edges sharper than `angle` are split (like Blender's "smooth by angle"),
so bevels and lathes look round while flat faces stay crisp.

Blender Z-up; a model's Godot size is (X, Z-up height, Y).
"""
import math

import bmesh
import bpy
from mathutils import Vector

import artlib


# ---------------------------------------------------------------------------
# 2D outlines (lists of (x, y), CCW)
# ---------------------------------------------------------------------------
def circle_pts(r, n=32, cx=0.0, cy=0.0):
    return [(cx + r * math.cos(2 * math.pi * k / n), cy + r * math.sin(2 * math.pi * k / n)) for k in range(n)]


def ellipse_pts(rx, ry, n=28, cx=0.0, cy=0.0, rot=0.0):
    c, s = math.cos(rot), math.sin(rot)
    out = []
    for k in range(n):
        a = 2 * math.pi * k / n
        x, y = rx * math.cos(a), ry * math.sin(a)
        out.append((cx + x * c - y * s, cy + x * s + y * c))
    return out


def rrect_pts(w, h, r, seg=5, cx=0.0, cy=0.0):
    """Rounded rectangle, always 4*(seg+1) points (so offset outlines match)."""
    r = max(min(r, w / 2 - 1e-4, h / 2 - 1e-4), 1e-3)
    pts = []
    for (ox, oy, a0) in ((w / 2 - r, -(h / 2 - r), -90), (w / 2 - r, h / 2 - r, 0),
                         (-(w / 2 - r), h / 2 - r, 90), (-(w / 2 - r), -(h / 2 - r), 180)):
        for k in range(seg + 1):
            a = math.radians(a0 + 90.0 * k / seg)
            pts.append((cx + ox + r * math.cos(a), cy + oy + r * math.sin(a)))
    return pts


def rrect_fn(w, h, r, seg=5, cx=0.0, cy=0.0):
    """Outline function of an outward offset d (negative = inset)."""
    return lambda d: rrect_pts(w + 2 * d, h + 2 * d, r + d, seg, cx, cy)


def rot_pts(pts, ang, cx=0.0, cy=0.0):
    c, s = math.cos(ang), math.sin(ang)
    return [(cx + x * c - y * s, cy + x * s + y * c) for x, y in pts]


# ---------------------------------------------------------------------------
# Accumulator
# ---------------------------------------------------------------------------
class Acc:
    def __init__(self, angle=60.0):
        self.bm = bmesh.new()
        self.mats = []
        self.angle = math.radians(angle)

    # -- internals ---------------------------------------------------------
    def _slot(self, mat):
        if mat not in self.mats:
            self.mats.append(mat)
        return self.mats.index(mat)

    def _merge(self, tmp, mat, mat_fn=None, sharp=True):
        bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
        tmp.normal_update()
        for e in tmp.edges:
            ok = len(e.link_faces) == 2
            e.smooth = not (ok and sharp and e.calc_face_angle(0.0) > self.angle)
        vmap = {v: self.bm.verts.new(v.co) for v in tmp.verts}
        for f in tmp.faces:
            m = mat_fn(f.calc_center_median()) if mat_fn else mat
            nf = self.bm.faces.new([vmap[v] for v in f.verts])
            nf.material_index = self._slot(m)
            nf.smooth = True
        for e in tmp.edges:
            ne = self.bm.edges.get((vmap[e.verts[0]], vmap[e.verts[1]]))
            if ne is not None:
                ne.smooth = e.smooth
        tmp.free()

    # -- primitives ----------------------------------------------------------
    def poly(self, mat, pts, z0, z1, bevel=0.0, seg=1, mat_fn=None):
        """CCW polygon extruded from z0 to z1; `bevel` rounds every edge."""
        tmp = bmesh.new()
        lo = [tmp.verts.new((x, y, z0)) for x, y in pts]
        hi = [tmp.verts.new((x, y, z1)) for x, y in pts]
        tmp.faces.new(lo[::-1])
        tmp.faces.new(hi)
        n = len(pts)
        for i in range(n):
            j = (i + 1) % n
            tmp.faces.new((lo[i], lo[j], hi[j], hi[i]))
        if bevel > 0:
            bmesh.ops.bevel(tmp, geom=list(tmp.edges), offset=bevel, offset_type="OFFSET",
                            segments=seg, affect="EDGES")
        self._merge(tmp, mat, mat_fn)

    def box(self, mat, size, loc, rot=0.0, bevel=0.0, seg=1):
        """Box centred on loc=(x, y, z_centre); rot = spin around Z."""
        sx, sy, sz = size
        pts = rot_pts([(-sx / 2, -sy / 2), (sx / 2, -sy / 2), (sx / 2, sy / 2), (-sx / 2, sy / 2)],
                      rot, loc[0], loc[1])
        self.poly(mat, pts, loc[2] - sz / 2, loc[2] + sz / 2, bevel, seg)

    def slab(self, mat, x0, x1, y0, y1, z0, z1, bevel=0.0, seg=1, rot=0.0):
        self.box(mat, (x1 - x0, y1 - y0, z1 - z0), ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), rot, bevel, seg)

    def disc(self, mat, r, z0, z1, cx=0.0, cy=0.0, n=32, bevel=0.0, seg=1, ry=None, rot=0.0):
        """Vertical cylinder (ellipse if ry is given)."""
        self.poly(mat, ellipse_pts(r, ry if ry else r, n, cx, cy, rot), z0, z1, bevel, seg)

    def rings(self, mat, rings, closed=False, mat_fn=None):
        """Skin a list of point-rings (each a list of Vector3 of equal length, or a
        single point). Open sweeps get flat caps on both ends."""
        tmp = bmesh.new()
        vr = []
        for ring in rings:
            pts = ring
            if len(pts) > 1 and all((Vector(p) - Vector(pts[0])).length < 1e-6 for p in pts):
                pts = [pts[0]]
            vr.append([tmp.verts.new(p) for p in pts])
        pairs = list(zip(vr[:-1], vr[1:]))
        if closed:
            pairs.append((vr[-1], vr[0]))
        for a, b in pairs:
            n = max(len(a), len(b))
            for k in range(n):
                k2 = (k + 1) % n
                cand = [a[k if len(a) > 1 else 0], a[k2 if len(a) > 1 else 0],
                        b[k2 if len(b) > 1 else 0], b[k if len(b) > 1 else 0]]
                uniq = []
                for v in cand:
                    if v not in uniq:
                        uniq.append(v)
                if len(uniq) >= 3:
                    tmp.faces.new(uniq)
        if not closed:
            for r in (vr[0], vr[-1]):
                if len(r) > 2:
                    tmp.faces.new(r)
        self._merge(tmp, mat, mat_fn)

    def sweep(self, mat, outline_fn, profile, closed=False, mat_fn=None):
        """Sweep a (d, z) profile around an outline; d = outward offset from it."""
        rs = [[(x, y, z) for x, y in outline_fn(d)] for d, z in profile]
        self.rings(mat, rs, closed, mat_fn)

    def lathe(self, mat, profile, verts=40, cx=0.0, cy=0.0, mat_fn=None):
        """Solid of revolution from (r, z) points; ends should sit on the axis."""
        rs = []
        for r, z in profile:
            if r < 1e-6:
                rs.append([(cx, cy, z)])
            else:
                rs.append([(cx + x, cy + y, z) for x, y in circle_pts(r, verts)])
        self.rings(mat, rs, False, mat_fn)

    def annulus(self, mat, r0, r1, z_of, z_under, cx=0.0, cy=0.0, n=48, steps=3):
        """Thin ring lying on a curved surface z_of(r), top at z_of(r) + nothing.
        Closed profile from r0 to r1; underside at z_under (hidden)."""
        rr = [r0 + (r1 - r0) * i / steps for i in range(steps + 1)]
        prof = [(r, z_of(r)) for r in rr] + [(r1, z_under), (r0, z_under)]
        self.lathe_closed(mat, prof, n, cx, cy)

    def lathe_closed(self, mat, profile, verts=40, cx=0.0, cy=0.0):
        rs = [[(cx + x, cy + y, z) for x, y in circle_pts(r, verts)] for r, z in profile]
        self.rings(mat, rs, True)

    def band(self, mat, outer, inner, z0, z1, mat_fn=None):
        """Flat ring between two equal-length outlines (walls, top and bottom)."""
        o0 = [(x, y, z0) for x, y in outer]
        o1 = [(x, y, z1) for x, y in outer]
        i1 = [(x, y, z1) for x, y in inner]
        i0 = [(x, y, z0) for x, y in inner]
        self.rings(mat, [o0, o1, i1, i0], True, mat_fn)

    def finish(self, name):
        mesh = bpy.data.meshes.new(name)
        self.bm.to_mesh(mesh)
        self.bm.free()
        for m in self.mats:
            mesh.materials.append(m)
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.collection.objects.link(obj)
        return obj


def hexcol(name, hexcolor, rough=0.6, metal=0.0, emis=None, strength=3.0):
    return artlib.material(name, hexcolor, rough, metal, emission=emis, emission_strength=strength)
