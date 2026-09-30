"""Shape builders and finishing helpers on top of artlib (Tiny Chefs assets).

Blender Z-up; Godot size (X, Y, Z) == Blender (X, Z, Y). Every builder returns the
new object with its material(s) assigned, ready to hand to build_asset().
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import artlib  # noqa: E402


def _active():
    return bpy.context.active_object


def box(mat, size, loc=(0, 0, 0), rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = _active()
    o.scale = size
    return artlib.with_material(o, mat)


def cyl(mat, r, h, loc=(0, 0, 0), rot=(0, 0, 0), verts=12, r2=None):
    """Cylinder (cone frustum when r2 is given) centred on `loc`, axis local Z."""
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=loc, rotation=rot)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=h, location=loc, rotation=rot)
    return artlib.with_material(_active(), mat)


def ball(mat, r, loc=(0, 0, 0), rot=(0, 0, 0), seg=10, rings=6):
    """UV sphere; `r` is a radius or an (rx, ry, rz) tuple for an ellipsoid."""
    dims = (r, r, r) if not isinstance(r, (tuple, list)) else r
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, radius=1, location=loc, rotation=rot)
    o = _active()
    o.scale = dims
    return artlib.with_material(o, mat)


def _dir_euler(d):
    d = Vector(d).normalized()
    up = "X" if abs(d.y) > 0.9 else "Y"
    return d.to_track_quat("Z", up).to_euler()


def rod(mat, p0, p1, r, verts=8):
    """Cylinder from point p0 to point p1."""
    a, b = Vector(p0), Vector(p1)
    d = b - a
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=d.length, location=(a + b) / 2)
    o = _active()
    o.rotation_euler = _dir_euler(d)
    return artlib.with_material(o, mat)


def ellip_along(mat, center, direction, dims, seg=10, rings=6):
    """Ellipsoid whose local Z (dims[2]) is aligned to `direction`."""
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, radius=1, location=center)
    o = _active()
    o.scale = dims
    o.rotation_euler = _dir_euler(direction)
    return artlib.with_material(o, mat)


def box_along(mat, center, direction, dims):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    o = _active()
    o.scale = dims
    o.rotation_euler = _dir_euler(direction)
    return artlib.with_material(o, mat)


def _to_object(bm, name, loc):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = loc
    return obj


def _assign(obj, mats):
    for m in mats:
        obj.data.materials.append(m)
    return obj


def frustum(mat, bottom, top, h, loc=(0, 0, 0)):
    """Rectangular frustum; bottom/top are (width_x, depth_y); `loc` is the base centre."""
    bm = bmesh.new()
    (bw, bd), (tw, td) = bottom, top
    corners = ((-1, -1), (1, -1), (1, 1), (-1, 1))
    lo = [bm.verts.new((sx * bw / 2, sy * bd / 2, 0)) for sx, sy in corners]
    hi = [bm.verts.new((sx * tw / 2, sy * td / 2, h)) for sx, sy in corners]
    bm.faces.new(lo)
    bm.faces.new(hi)
    for i in range(4):
        j = (i + 1) % 4
        bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
    return _assign(_to_object(bm, "Frustum", loc), [mat])


def lathe(mats, profile, verts=12, loc=(0, 0, 0), face_mat=None):
    """Solid of revolution around Z from a profile of (r, z) points.

    The profile must start and end on the axis (r = 0) so the mesh is closed.
    `mats`: one material or a list; `face_mat(centre) -> slot index` per face.
    """
    mats = list(mats) if isinstance(mats, (list, tuple)) else [mats]
    bm = bmesh.new()
    rings = []
    for r, z in profile:
        if r < 1e-6:
            rings.append([bm.verts.new((0, 0, z))])
        else:
            rings.append([bm.verts.new((r * math.cos(2 * math.pi * k / verts),
                                        r * math.sin(2 * math.pi * k / verts), z)) for k in range(verts)])
    for a, b in zip(rings[:-1], rings[1:]):
        for k in range(verts):
            k2 = (k + 1) % verts
            cand = [a[k if len(a) > 1 else 0], a[k2 if len(a) > 1 else 0],
                    b[k2 if len(b) > 1 else 0], b[k if len(b) > 1 else 0]]
            uniq = []
            for v in cand:
                if v not in uniq:
                    uniq.append(v)
            if len(uniq) >= 3:
                bm.faces.new(uniq)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if face_mat:
        for f in bm.faces:
            f.material_index = face_mat(f.calc_center_median())
    return _assign(_to_object(bm, "Lathe", loc), mats)


def dome_profile(r, h, base=0.0, steps=4):
    """Domed disc: flat bottom, vertical rim `base` tall, elliptical dome up to height h."""
    pts = [(0, 0), (r, 0)]
    if base > 0:
        pts.append((r, base))
    for i in range(1, steps + 1):
        t = math.pi / 2 * i / steps
        pts.append((r * math.cos(t) if i < steps else 0, base + (h - base) * math.sin(t)))
    return pts


def roughen(obj, func):
    """Scale each vertex's radius (around Z) by func(angle): a rough edge."""
    for v in obj.data.vertices:
        r = math.hypot(v.co.x, v.co.y)
        if r > 1e-6:
            f = func(math.atan2(v.co.y, v.co.x))
            v.co.x *= f
            v.co.y *= f
    return obj


def sheet(mats, w, d, thick, n, dz, disc=False, loc=(0, 0, 0), face_mat=None):
    """Thick displaced sheet: n x n grid, optionally warped to a disc of diameter w.

    dz(x, y) is the vertical displacement; afterwards the lowest point sits at z=0.
    """
    mats = list(mats) if isinstance(mats, (list, tuple)) else [mats]
    bm = bmesh.new()
    top = [[None] * (n + 1) for _ in range(n + 1)]
    bot = [[None] * (n + 1) for _ in range(n + 1)]
    for i in range(n + 1):
        for j in range(n + 1):
            u, v = -1 + 2 * i / n, -1 + 2 * j / n
            if disc:
                m = math.hypot(u, v)
                if m > 1e-9:
                    k = max(abs(u), abs(v)) / m
                    u, v = u * k, v * k
            x, y = u * w / 2, v * d / 2
            z = dz(x, y)
            top[i][j] = bm.verts.new((x, y, z + thick))
            bot[i][j] = bm.verts.new((x, y, z))
    for i in range(n):
        for j in range(n):
            bm.faces.new((top[i][j], top[i + 1][j], top[i + 1][j + 1], top[i][j + 1]))
            bm.faces.new((bot[i][j], bot[i][j + 1], bot[i + 1][j + 1], bot[i + 1][j]))
    for i in range(n):
        bm.faces.new((top[i][0], bot[i][0], bot[i + 1][0], top[i + 1][0]))
        bm.faces.new((top[i][n], top[i + 1][n], bot[i + 1][n], bot[i][n]))
        bm.faces.new((top[0][i], top[0][i + 1], bot[0][i + 1], bot[0][i]))
        bm.faces.new((top[n][i], bot[n][i], bot[n][i + 1], top[n][i + 1]))
    lo = min(v.co.z for v in bm.verts)
    for v in bm.verts:
        v.co.z -= lo
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if face_mat:
        for f in bm.faces:
            f.material_index = face_mat(f.calc_center_median())
    return _assign(_to_object(bm, "Sheet", loc), mats)


def prism(mat, pts, z0, z1):
    """Polygon (list of (x, y), CCW) extruded from z0 to z1."""
    bm = bmesh.new()
    lo = [bm.verts.new((x, y, z0)) for x, y in pts]
    hi = [bm.verts.new((x, y, z1)) for x, y in pts]
    bm.faces.new(lo[::-1])
    bm.faces.new(hi)
    n = len(pts)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
    return _assign(_to_object(bm, "Prism", (0, 0, 0)), [mat])


# ---------------------------------------------------------------------------
# Finishing: join, ground, measure, export
# ---------------------------------------------------------------------------
def _pascal(name):
    return "".join(p.capitalize() for p in name.split("_"))


def world_bounds(objs):
    bpy.context.view_layer.update()
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for o in objs:
        for v in o.data.vertices:
            w = o.matrix_world @ v.co
            for a in range(3):
                lo[a] = min(lo[a], w[a])
                hi[a] = max(hi[a], w[a])
    return lo, hi


def settle(name, expect, keep=(), tol=0.10, limits=None):
    """Centre on XY, put the lowest point on z=0, bake the shift, verify the size.

    `expect` is the contract size in Godot axes (X, Y up, Z). Objects in `keep`
    retain their own origin (location not applied), e.g. the chef's hands.
    Raises if an axis is off by more than `tol`.
    """
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    lo, hi = world_bounds(meshes)
    shift = Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))
    for o in meshes:
        o.location += shift
    for o in meshes:
        if o not in keep:
            bpy.ops.object.select_all(action="DESELECT")
            o.select_set(True)
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    lo, hi = world_bounds(meshes)
    got = (hi.x - lo.x, hi.z - lo.z, hi.y - lo.y)
    if limits:  # (min, max) per axis instead of an exact contract size (dispensers)
        ok = all(lo_ <= g <= hi_ for g, (lo_, hi_) in zip(got, limits))
        expect = tuple(f"{a}..{b}" for a, b in limits)
    else:
        ok = all(abs(g - e) <= e * tol for g, e in zip(got, expect))
    faces = sum(len(o.data.polygons) for o in meshes)
    print(f"SIZE {name}: got {got[0]:.2f} x {got[1]:.2f} x {got[2]:.2f}  "
          f"want {expect[0]} x {expect[1]} x {expect[2]}  faces={faces}  {'OK' if ok else 'BAD'}")
    if not ok:
        raise RuntimeError(f"{name}: size {got} outside contract {expect}")
    return got


def build_asset(filename, parts, expect, separate=(), limits=None):
    """Join `parts` (except `separate` objects) into one mesh, ground, verify, export."""
    joinable = [p for p in parts if p not in separate]
    artlib.join(joinable, _pascal(filename))
    settle(filename, expect, keep=separate, limits=limits)
    artlib.export_glb(filename)
