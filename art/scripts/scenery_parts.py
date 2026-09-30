"""Extra builders for the high-detail scenery models (Blender 5.2, Z-up).

Own helper module for the scenery_* scripts; artlib/shapes/foodparts stay untouched.
Everything returns an object with materials assigned; finish with build().
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import artlib  # noqa: E402
from shapes import _assign, _pascal, _to_object, ball, box, cyl, lathe, rod, roughen, settle  # noqa: E402,F401

M = artlib.material


# ---------------------------------------------------------------------------
# Profiles
# ---------------------------------------------------------------------------
def fillet(pts, r=0.15, n=3, radii=None):
    """Round the interior corners of a 2D polyline (quadratic bezier arcs).

    radii: {index: radius} overrides; radius 0 keeps a corner sharp.
    """
    P = [Vector(p) for p in pts]
    out = [P[0]]
    for i in range(1, len(P) - 1):
        rr = radii.get(i, r) if radii else r
        A, B, C = P[i - 1], P[i], P[i + 1]
        if rr <= 0:
            out.append(B)
            continue
        d1, d2 = (A - B).length, (C - B).length
        t = min(rr, d1 * 0.45, d2 * 0.45)
        P0 = B + (A - B).normalized() * t
        P2 = B + (C - B).normalized() * t
        for k in range(n + 1):
            s = k / n
            out.append(P0 * (1 - s) ** 2 + B * (2 * s * (1 - s)) + P2 * s * s)
    out.append(P[-1])
    return [(p.x, p.y) for p in out]


def threads(r, z0, z1, count, depth):
    """Zig-zag profile points (r, z) imitating screw threads between z0 and z1."""
    pts = []
    for i in range(count):
        a = z0 + (z1 - z0) * i / count
        b = z0 + (z1 - z0) * (i + 0.5) / count
        c = z0 + (z1 - z0) * (i + 1) / count
        pts += [(r - depth, a), (r, a + (b - a) * 0.35), (r, b), (r - depth, c - (c - b) * 0.2)]
    return pts


# ---------------------------------------------------------------------------
# Solids
# ---------------------------------------------------------------------------
def rbox(mat, size, loc=(0, 0, 0), rot=(0, 0, 0), r=0.1, seg=2):
    """Box with bevelled (rounded) edges, centred on loc."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z *= size[2]
    r = min(r, min(size) * 0.49)
    bmesh.ops.bevel(bm, geom=list(bm.edges), offset=r, offset_type="OFFSET", segments=seg,
                    profile=0.5, affect="EDGES")
    obj = _to_object(bm, "RBox", loc)
    obj.rotation_euler = rot
    return _assign(obj, [mat])


def sweep(mat, path, radius, sides=8, closed=False, caps=True, up=None, rect=False):
    """Tube along a 3D polyline. radius: number, (a, b) ellipse, or a list of those per point.

    Frame: parallel transport, or the projection of `up` when given (ribbons).
    rect=True gives a rectangular section with half-extents (a, b).
    """
    P = [Vector(p) for p in path]
    n = len(P)
    if not isinstance(radius, list):
        radius = [radius] * n
    rads = [(r, r) if not isinstance(r, (tuple, list)) else tuple(r) for r in radius]
    tans = []
    for i in range(n):
        if closed:
            t = P[(i + 1) % n] - P[i - 1]
        else:
            t = P[min(i + 1, n - 1)] - P[max(i - 1, 0)]
        tans.append(t.normalized())
    frames = []
    prev = None
    for i in range(n):
        t = tans[i]
        if up is not None:
            nn = Vector(up) - t * Vector(up).dot(t)
            if nn.length < 1e-4:
                nn = prev if prev is not None else t.orthogonal()
        elif prev is None:
            nn = t.orthogonal()
        else:
            nn = prev - t * prev.dot(t)
        nn = nn.normalized()
        prev = nn
        frames.append((nn, t.cross(nn).normalized()))
    bm = bmesh.new()
    rings = []
    ang0 = math.pi / 4 if rect else 0.0
    for i in range(n):
        nn, bb = frames[i]
        a, b = rads[i]
        ring = []
        for k in range(sides):
            th = ang0 + 2 * math.pi * k / sides
            c, s = math.cos(th), math.sin(th)
            if rect:
                c, s = c * math.sqrt(2), s * math.sqrt(2)
            ring.append(bm.verts.new(P[i] + nn * (c * a) + bb * (s * b)))
        rings.append(ring)
    last = n if closed else n - 1
    for i in range(last):
        r0, r1 = rings[i], rings[(i + 1) % n]
        for k in range(sides):
            k2 = (k + 1) % sides
            bm.faces.new((r0[k], r0[k2], r1[k2], r1[k]))
    if caps and not closed:
        for ring, pt, flip in ((rings[0], P[0], True), (rings[-1], P[-1], False)):
            c = bm.verts.new(pt)
            for k in range(sides):
                k2 = (k + 1) % sides
                bm.faces.new((c, ring[k2], ring[k]) if flip else (c, ring[k], ring[k2]))
    return _assign(_to_object(bm, "Sweep", (0, 0, 0)), [mat])


def bezier(p0, p1, p2, p3, n=12):
    a, b, c, d = map(Vector, (p0, p1, p2, p3))
    out = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        out.append(a * (u ** 3) + b * (3 * u * u * t) + c * (3 * u * t * t) + d * (t ** 3))
    return out


def arc(center, radius, a0, a1, n=12, plane="xz"):
    """Polyline on a circle in the xz (default), xy or yz plane; angles in degrees."""
    cx, cy, cz = center
    pts = []
    for i in range(n + 1):
        a = math.radians(a0 + (a1 - a0) * i / n)
        c, s = math.cos(a) * radius, math.sin(a) * radius
        if plane == "xz":
            pts.append((cx + c, cy, cz + s))
        elif plane == "xy":
            pts.append((cx + c, cy + s, cz))
        else:
            pts.append((cx, cy + c, cz + s))
    return pts


def torus(mat, R, r, loc=(0, 0, 0), rot=(0, 0, 0), seg=24, sides=8):
    pts = [(R * math.cos(2 * math.pi * i / seg), R * math.sin(2 * math.pi * i / seg), 0) for i in range(seg)]
    o = sweep(mat, pts, r, sides=sides, closed=True)
    o.location = loc
    o.rotation_euler = rot
    return o


def lathe_arc(mat, profile, a0, a1, verts=12, rot_z=0.0):
    """Open patch of a surface of revolution between angles a0..a1 (degrees), e.g. a label."""
    bm = bmesh.new()
    cols = []
    steps = verts
    for k in range(steps + 1):
        a = math.radians(a0 + (a1 - a0) * k / steps)
        cols.append([bm.verts.new((r * math.cos(a), r * math.sin(a), z)) for r, z in profile])
    for k in range(steps):
        for j in range(len(profile) - 1):
            bm.faces.new((cols[k][j], cols[k + 1][j], cols[k + 1][j + 1], cols[k][j + 1]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    f = bm.faces[0]
    c = f.calc_center_median()
    if f.normal.dot(Vector((c.x, c.y, 0))) < 0:  # make sure it faces outward
        bmesh.ops.reverse_faces(bm, faces=list(bm.faces))
    obj = _to_object(bm, "Patch", (0, 0, 0))
    obj.rotation_euler = (0, 0, math.radians(rot_z))
    return _assign(obj, [mat])


def prism_xz(mat, pts, y0, y1, loc=(0, 0, 0), rot=(0, 0, 0)):
    """Polygon in the XZ plane extruded along Y from y0 to y1."""
    bm = bmesh.new()
    front = [bm.verts.new((x, y0, z)) for x, z in pts]
    back = [bm.verts.new((x, y1, z)) for x, z in pts]
    bm.faces.new(front)
    bm.faces.new(back[::-1])
    k = len(pts)
    for i in range(k):
        j = (i + 1) % k
        bm.faces.new((front[i], back[i], back[j], front[j]))
    obj = _to_object(bm, "PrismXZ", loc)
    obj.rotation_euler = rot
    return _assign(obj, [mat])


def ribbed(mat, r, h, ribs, depth, loc=(0, 0, 0), verts=None, r2=None):
    """Cylinder/cone with vertical ribs (screw-cap grip)."""
    verts = verts or ribs * 3
    o = cyl(mat, r, h, loc, verts=verts, r2=r2)
    bpy.context.view_layer.update()
    for v in o.data.vertices:
        a = math.atan2(v.co.y, v.co.x)
        f = 1.0 - depth * (0.5 + 0.5 * math.cos(ribs * a))
        v.co.x *= f
        v.co.y *= f
    return o


def spiral_ring(mat, R, r, z, turns_z, loc_xy=(0, 0)):
    """Single flat ring (torus) at height z used for hoops, bands and lips."""
    return torus(mat, R, r, (loc_xy[0], loc_xy[1], z), seg=28, sides=6)


def frame(zdir, hint=(0, 0, 1)):
    """Orthonormal (x, y, z) frame with z along zdir; x = hint x z."""
    z = Vector(zdir).normalized()
    x = Vector(hint).cross(z)
    if x.length < 1e-4:
        x = Vector((1, 0, 0)).cross(z)
    x.normalize()
    return x, z.cross(x), z


def euler_of(x, y, z):
    return Matrix((x, y, z)).transposed().to_euler()


def oriented(obj, loc, zdir, hint=(0, 0, 1)):
    """Place obj at loc with its local Z along zdir (roll from hint)."""
    obj.location = loc
    obj.rotation_euler = euler_of(*frame(zdir, hint))
    return obj


def wall_r(pts, z):
    """Radius of the outer wall polyline pts [(r, z)...] at height z (linear interpolation)."""
    best = pts[0][0]
    for (r0, z0), (r1, z1) in zip(pts[:-1], pts[1:]):
        if (z0 <= z <= z1 or z1 <= z <= z0) and abs(z1 - z0) > 1e-6:
            best = r0 + (r1 - r0) * (z - z0) / (z1 - z0)
    return best


def ring_band(mat, pts, z0, z1, off=0.03, thick=0.05, verts=32, steps=4):
    """Thin band hugging a wall profile between z0 and z1 (closed loop, does not touch the axis)."""
    zs = [z0 + (z1 - z0) * i / steps for i in range(steps + 1)]
    outer = [(wall_r(pts, z) + off, z) for z in zs]
    inner = [(wall_r(pts, z) + off - thick, z) for z in zs][::-1]
    return lathe(mat, outer + inner + [outer[0]], verts=verts)


def flip_z(pts):
    return [(r, -z) for r, z in pts][::-1]


# ---------------------------------------------------------------------------
# Finishing
# ---------------------------------------------------------------------------
def shade(obj, angle_deg=48.0):
    """Smooth shading with hard edges only where the surface bends more than angle_deg."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    lim = math.radians(angle_deg)
    for f in bm.faces:
        f.smooth = True
    for e in bm.edges:
        if len(e.link_faces) == 2:
            try:
                e.smooth = e.calc_face_angle() < lim
            except ValueError:
                e.smooth = True
    bm.to_mesh(obj.data)
    bm.free()


def build(name, parts, expect, tol=0.10, angle=48.0):
    """Join, smooth, ground, verify the contract size and export."""
    obj = artlib.join(parts, _pascal(name))
    shade(obj, angle)
    got = settle(name, expect, tol=tol)
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    print(f"TRIS {name}: {tris}")
    artlib.export_glb(name)
    return got


def run(jobs):
    """Run named jobs (name -> function returning (parts, size)); optional name filter after '--'."""
    only = set(artlib.script_args())
    for name, fn in jobs:
        if only and name not in only:
            continue
        artlib.reset_scene()
        parts, size = fn()
        build(name, parts, size)
