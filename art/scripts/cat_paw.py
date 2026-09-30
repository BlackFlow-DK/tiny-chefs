"""Giant cat paw for the cat_paw shift event (world/events/cat_paw_event.gd).

Run: tools/blender-run.ps1 art/scripts/cat_paw.py
Orange tabby paw, about 12 (X) x 4 (up) x 10 (depth) m, toes to the front (Blender -Y = Godot +Z),
pink pads underneath, darker stripes over the top, fluff tufts round the rim and a short wrist stub
at the back (the arm above it is built in code). Origin at the base centre: the pads touch y = 0.
"""
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bpy  # noqa: E402

import artlib  # noqa: E402

random.seed(11)


def ellipsoid(mat, size, loc, rot=(0, 0, 0), seg=28, rings=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, radius=0.5, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.scale = size
    bpy.ops.object.shade_smooth()
    return artlib.with_material(o, mat)


def cone(mat, r, h, loc, rot):
    bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=r, radius2=0.0, depth=h, location=loc, rotation=rot)
    o = bpy.context.active_object
    bpy.ops.object.shade_smooth()
    return artlib.with_material(o, mat)


def cylinder(mat, r, h, loc, rot=(0, 0, 0), verts=28):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=loc, rotation=rot)
    o = bpy.context.active_object
    bpy.ops.object.shade_smooth()
    return artlib.with_material(o, mat)


def main():
    artlib.reset_scene()
    fur = artlib.material("PawFur", "#f28c28", 0.9)
    stripe = artlib.material("PawStripe", "#c2561a", 0.9)
    cream = artlib.material("PawCream", "#ffe2b8", 0.95)
    pad = artlib.material("PawPad", "#f29aa8", 0.55)
    parts = []

    # Palm: a broad squashed dome sitting on the pads.
    parts.append(ellipsoid(fur, (10.4, 8.6, 3.6), (0, 0.6, 2.05)))
    # Wrist stub at the back, rising (the code-built arm continues it upwards).
    parts.append(cylinder(fur, 3.1, 1.6, (0, 2.6, 3.2)))
    parts.append(ellipsoid(fur, (6.4, 5.6, 2.2), (0, 2.4, 3.4)))

    # Four toes along the front (-Y), each a fat bean with a cream tip.
    toes_x = (-3.9, -1.3, 1.3, 3.9)
    for i, x in enumerate(toes_x):
        y = -3.4 + (0.45 if i in (0, 3) else 0.0)
        parts.append(ellipsoid(fur, (2.9, 3.2, 2.9), (x, y, 1.75)))
        parts.append(ellipsoid(cream, (2.3, 1.4, 1.5), (x, y - 1.15, 1.25)))
        # toe beans underneath
        parts.append(ellipsoid(pad, (1.7, 1.9, 0.7), (x, y - 0.2, 0.35), seg=18, rings=10))
    # Big palm pad (three lobes) underneath.
    for x, y, s in ((0, 0.9, 4.2), (-1.8, 1.5, 2.6), (1.8, 1.5, 2.6)):
        parts.append(ellipsoid(pad, (s, s * 0.8, 0.8), (x, y, 0.4), seg=20, rings=10))

    # Tabby stripes: dark bands over the top of the palm and toes, running front to back.
    for k, x in enumerate((-4.2, -2.3, -0.4, 1.5, 3.4)):
        w = 0.7 if k % 2 == 0 else 0.55
        parts.append(ellipsoid(stripe, (w, 6.2, 1.2), (x + 0.3, 0.7, 3.55 - 0.12 * abs(x)), rot=(0, math.radians(-x * 4.5), 0)))
    for x in toes_x:
        parts.append(ellipsoid(stripe, (0.5, 1.9, 0.6), (x, -3.2 + (0.45 if abs(x) > 3 else 0.0), 3.05)))
    for x in (-2.0, 0.0, 2.0):
        parts.append(ellipsoid(stripe, (0.55, 3.4, 0.9), (x, 2.5, 4.35), rot=(math.radians(-20), 0, 0)))

    # Fluff: little tufts poking out around the rim and between the toes.
    for i in range(22):
        a = 2 * math.pi * i / 22 + random.uniform(-0.08, 0.08)
        rx, ry = 5.3, 4.5
        x, y = rx * math.cos(a), 0.6 + ry * math.sin(a)
        if y < -2.0:   # the toes cover the front
            continue
        tilt = math.atan2(y - 0.6, x)
        parts.append(cone(cream if i % 3 == 0 else fur, 0.45, 1.3, (x, y, 1.1 + random.uniform(0, 0.5)),
                          (math.radians(70), 0, tilt - math.pi / 2)))
    for x in (-2.6, 0.0, 2.6):
        parts.append(cone(cream, 0.35, 1.1, (x, -4.4, 1.3), (math.radians(-80), 0, 0)))

    artlib.join(parts, "CatPaw")
    artlib.export_glb("cat_paw")


main()
