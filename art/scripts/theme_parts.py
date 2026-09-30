"""Helpers shared by the theme prop scripts (theme_truck.py, theme_picnic.py).

Everything sits on top of scenery_parts; Blender Z-up, front = -Y.
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bmesh  # noqa: E402
from mathutils import Vector  # noqa: E402

import scenery_parts as sp  # noqa: E402
from scenery_parts import M, ball, bezier, cyl, fillet, lathe, prism_xz, rbox, rod, sweep, torus  # noqa: E402,F401
from shapes import _assign, _to_object  # noqa: E402

GLASS = dict(roughness=0.05, alpha=0.3)


def glass_profile(outer, wall, floor):
    """Closed lathe profile of a hollow glass vessel.

    `outer` runs from (0, 0) up to the rim (r, z); returns outer + rim + inner wall down to the
    inner floor at height `floor` and back to the axis.
    """
    top_r, top_z = outer[-1]
    inner = []
    for r, z in outer[1:-1]:
        if z > floor:
            inner.append((max(r - wall, 0.05), z))
    inner.insert(0, (max(sp.wall_r(outer, floor) - wall, 0.05), floor))
    return list(outer) + [(top_r - wall, top_z)] + inner[::-1] + [(0, floor)]


def heart_pts(w, h, n=28, cx=0.0, cz=0.0):
    """Heart outline (x, z), centred on (cx, cz), w wide and h tall."""
    pts = []
    for i in range(n):
        t = 2 * math.pi * i / n
        x = 16 * math.sin(t) ** 3
        z = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((x / 32.0 * w + cx, (z + 2.5) / 29.0 * h + cz))
    return pts


def star_pts(cx, cz, R, r, n=5, rot=90.0):
    pts = []
    for i in range(2 * n):
        a = math.radians(rot + 180.0 * i / n)
        rr = R if i % 2 == 0 else r
        pts.append((cx + rr * math.cos(a), cz + rr * math.sin(a)))
    return pts


def circle_pts(cx, cz, r, n=16):
    return [(cx + r * math.cos(2 * math.pi * i / n), cz + r * math.sin(2 * math.pi * i / n)) for i in range(n)]


def arc_pts(cx, cz, r, a0, a1, n=10):
    return [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)),
             cz + r * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]


def sheet_obj(mat, quad_grid, name="Sheet", thick=0.0):
    """Surface from a 2D grid of Vectors (rows x cols); thick > 0 adds a displaced back side."""
    bm = bmesh.new()
    rows = len(quad_grid)
    cols = len(quad_grid[0])
    top = [[bm.verts.new(p) for p in row] for row in quad_grid]
    for i in range(rows - 1):
        for j in range(cols - 1):
            bm.faces.new((top[i][j], top[i][j + 1], top[i + 1][j + 1], top[i + 1][j]))
    if thick > 0:
        bot = [[bm.verts.new(Vector(p) - Vector((0, 0, thick))) for p in row] for row in quad_grid]
        for i in range(rows - 1):
            for j in range(cols - 1):
                bm.faces.new((bot[i][j], bot[i + 1][j], bot[i + 1][j + 1], bot[i][j + 1]))
        for i in range(rows - 1):
            bm.faces.new((top[i][0], top[i + 1][0], bot[i + 1][0], bot[i][0]))
            bm.faces.new((top[i][cols - 1], bot[i][cols - 1], bot[i + 1][cols - 1], top[i + 1][cols - 1]))
        for j in range(cols - 1):
            bm.faces.new((top[0][j], bot[0][j], bot[0][j + 1], top[0][j + 1]))
            bm.faces.new((top[rows - 1][j], top[rows - 1][j + 1], bot[rows - 1][j + 1], bot[rows - 1][j]))
    return _assign(_to_object(bm, name, (0, 0, 0)), [mat])


def squash_front(objs, y0, k):
    """Compress everything in front of y0 (y < y0) towards y0 by factor k (bakes the object transforms)."""
    import bpy
    from mathutils import Matrix
    bpy.context.view_layer.update()
    for o in objs:
        o.data.transform(o.matrix_world)
        o.matrix_world = Matrix.Identity(4)
        for v in o.data.vertices:
            if v.co.y < y0:
                v.co.y = y0 + (v.co.y - y0) * k


def place(objs, loc=(0, 0, 0), rot=(0, 0, 0), frame=None):
    """Move a group of objects as one: rotate about the origin (Euler, or the matrix of a frame) then translate."""
    import bpy
    from mathutils import Euler, Matrix
    bpy.context.view_layer.update()
    if frame is not None:
        x, y, z = frame
        R = Matrix(((x.x, y.x, z.x, 0), (x.y, y.y, z.y, 0), (x.z, y.z, z.z, 0), (0, 0, 0, 1)))
    else:
        R = Euler(rot).to_matrix().to_4x4()
    T = Matrix.Translation(loc) @ R
    for o in objs:
        o.matrix_world = T @ o.matrix_world
    return objs


def bpy_update():
    import bpy
    bpy.context.view_layer.update()
