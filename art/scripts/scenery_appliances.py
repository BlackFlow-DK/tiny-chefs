"""Scenery part 2: toaster, kettle, paper towel roll.

Run: tools/blender-run.ps1 art/scripts/scenery_appliances.py [-- model_name ...]
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from mathutils import Vector  # noqa: E402

import scenery_parts as sp  # noqa: E402
from scenery_parts import (M, ball, bezier, box, cyl, fillet, lathe, prism_xz, rbox, rod, sweep, torus)  # noqa: E402


def toaster():
    chrome = M("ToasterChrome", "#eef3f6", 0.12, 0.95)
    shine = M("ToasterShine", "#ffffff", 0.1, 0.1)
    rim = M("ToasterRim", "#8d979f", 0.3, 0.5)
    black = M("ToasterBlack", "#1f2125", 0.45)
    slot = M("ToasterSlot", "#0b0b0d", 0.9)
    red = M("ToasterRed", "#d8302b", 0.4)
    glow = M("ToasterGlow", "#ff7a22", 0.5, emission="#ff5a10", emission_strength=4.0)
    white = M("ToasterWhite", "#f4f4ee", 0.5)
    crust = M("ToastCrust", "#7d4d24", 0.85)
    crumb = M("ToastCrumb", "#efc274", 0.9)
    golden = M("ToastToasted", "#d69a45", 0.9)
    parts = []
    zt = 4.6  # top plate height
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(rbox(black, (0.95, 0.95, 0.4), (sx * 3.0, sy * 1.35, 0.2), r=0.16))
    parts.append(rbox(chrome, (6.9, 4.2, 4.35), (0, 0, 0.3 + 4.35 / 2), r=0.95, seg=4))
    parts.append(rbox(rim, (6.0, 3.6, 0.22), (0, 0, zt - 0.02), r=0.08))
    # bakelite end caps with chrome trim
    for sx in (-1, 1):
        parts.append(rbox(black, (0.85, 4.15, 3.95), (sx * 3.6, 0, 2.5), r=0.32, seg=3))
        parts.append(rbox(chrome, (0.16, 3.5, 0.5), (sx * 4.02, 0, 3.0), r=0.06))
        parts.append(rbox(chrome, (0.16, 3.5, 0.5), (sx * 4.02, 0, 1.9), r=0.06))
    # top slots: chrome rim, black slot, one glowing empty slot and a slice of toast
    for sy in (-1, 1):
        parts.append(rbox(shine, (4.7, 1.32, 0.16), (0, sy * 1.0, zt + 0.06), r=0.06))
        parts.append(rbox(slot, (4.1, 0.86, 0.06), (0, sy * 1.0, zt + 0.15), r=0.02, seg=1))
    parts.append(rbox(glow, (3.6, 0.22, 0.03), (0, 1.0, zt + 0.19), r=0.01, seg=1))
    bread = [(-1.55, 0), (1.55, 0), (1.62, 1.6), (1.92, 2.3), (1.78, 2.95), (1.3, 3.25), (0.55, 3.3), (0, 3.05), (-0.55, 3.3),
             (-1.3, 3.25), (-1.78, 2.95), (-1.92, 2.3), (-1.62, 1.6)]
    zb = 6.0 - 3.3

    def scaled(k, cx=0.0, cz=1.65):
        return [(cx + (x - cx) * k, cz + (z - cz) * k) for x, z in bread]

    for pts, mat, half in ((bread, crust, 0.3), (scaled(0.87), crumb, 0.33), (scaled(0.62, cz=1.6), golden, 0.335)):
        parts.append(prism_xz(mat, pts, -1.0 - half, -1.0 + half, loc=(0, 0, zb)))
    # front: red stripe, badge, lever and dial
    parts.append(rbox(red, (5.6, 0.1, 0.36), (0, -2.08, 1.35), r=0.05, seg=1))
    parts.append(ball(white, (0.42, 0.06, 0.28), (0, -2.12, 2.9), seg=14, rings=8))
    parts.append(ball(red, (0.24, 0.07, 0.15), (0, -2.14, 2.9), seg=12, rings=6))
    parts.append(rbox(slot, (0.42, 0.14, 2.4), (-2.45, -2.1, 2.75), r=0.1, seg=2))
    parts.append(rbox(rim, (0.14, 0.18, 2.5), (-2.45, -2.12, 2.75), r=0.05, seg=1))
    parts.append(rod(chrome, (-2.45, -2.1, 3.45), (-2.45, -2.2, 3.45), 0.16, verts=10))
    parts.append(rbox(black, (0.95, 0.5, 0.55), (-2.45, -2.55, 3.45), r=0.2, seg=3))
    parts.append(ball(shine, (0.22, 0.08, 0.08), (-2.62, -2.8, 3.62), seg=8, rings=5))
    parts.append(cyl(chrome, 0.9, 0.16, (2.35, -2.14, 2.75), rot=(math.pi / 2, 0, 0), verts=32))
    parts.append(cyl(black, 0.66, 0.5, (2.35, -2.34, 2.75), rot=(math.pi / 2, 0, 0), verts=32))
    parts.append(cyl(rim, 0.5, 0.12, (2.35, -2.6, 2.75), rot=(math.pi / 2, 0, 0), verts=24))
    parts.append(rbox(white, (0.1, 0.1, 0.42), (2.35, -2.62, 3.02), r=0.03, seg=1))
    for k in range(7):  # dial ticks
        a = math.radians(-60 + 20 * k + 90)
        parts.append(rbox(white, (0.06, 0.04, 0.16), (2.35 + 1.06 * math.cos(a), -2.2, 2.75 + 1.06 * math.sin(a)),
                          rot=(0, -(a - math.pi / 2), 0), r=0.01, seg=1))
    # chrome highlight streaks
    parts.append(rbox(shine, (0.16, 0.06, 1.9), (-1.35, -2.06, 3.1), r=0.03, seg=1))
    parts.append(rbox(shine, (0.16, 0.06, 1.9), (0.95, -2.06, 3.1), r=0.03, seg=1))
    # power cord
    cord = bezier((2.6, 2.0, 1.1), (2.8, 2.6, 0.5), (3.6, 2.6, 0.2), (4.0, 2.1, 0.13), 10)
    parts.append(sweep(black, cord, 0.13, sides=8))
    return parts, (8, 6, 5)


def kettle():
    blue = M("KettleEnamel", "#2c68b5", 0.28)
    cream = M("KettleCream", "#f4e9cc", 0.4)
    steel = M("KettleSteel", "#cfd6dc", 0.22, 0.5)
    shine = M("KettleShine", "#ffffff", 0.12, 0.1)
    black = M("KettleBlack", "#23252a", 0.45)
    red = M("KettleRed", "#d8302b", 0.35)
    dark = M("KettleHole", "#0c0c0e", 0.9)
    parts = []
    body = fillet([(0, 0), (2.12, 0), (2.36, 0.2), (2.42, 0.9), (2.28, 2.6), (1.98, 3.45), (1.66, 3.78), (1.55, 3.95), (0, 3.95)],
                  r=0.5, n=4, radii={1: 0.05, 2: 0.25, 8: 0.05, 7: 0.1})
    parts.append(lathe(blue, body, verts=40))
    parts.append(lathe(steel, fillet([(0, 0), (2.36, 0), (2.42, 0.1), (2.44, 0.5), (2.4, 0.58), (0, 0.58)], r=0.04, n=1, radii={1: 0.02}), verts=40))
    parts.append(lathe(cream, [(0, 1.5), (2.41, 1.5), (2.4, 1.6), (2.34, 1.95), (2.32, 2.0), (0, 2.0)], verts=40))
    # steel lid with knob
    lid = fillet([(0, 3.8), (1.68, 3.8), (1.68, 4.0), (1.35, 4.28), (0.75, 4.55), (0.3, 4.62), (0, 4.62)], r=0.3, n=3, radii={1: 0.04, 2: 0.06})
    parts.append(lathe(steel, lid, verts=36))
    parts.append(torus(shine, 1.6, 0.05, (0, 0, 3.95), seg=36, sides=5))
    parts.append(cyl(steel, 0.2, 0.5, (0, 0, 4.85), verts=12))
    parts.append(ball(red, 0.5, (0, 0, 5.28), seg=20, rings=10))
    parts.append(ball(shine, (0.14, 0.1, 0.1), (-0.22, -0.3, 5.5), seg=8, rings=5))
    # spout (leans out to +X) with flip cap
    sp_path = bezier((1.85, 0, 1.0), (3.05, 0, 1.4), (3.15, 0, 2.8), (3.5, 0, 4.15), 12)
    sp_r = [0.95 - 0.62 * (i / 12) ** 0.7 for i in range(13)]
    parts.append(sweep(blue, sp_path, sp_r, sides=16))
    tip = Vector(sp_path[-1])
    tdir = (Vector(sp_path[-1]) - Vector(sp_path[-2])).normalized()
    parts.append(sp.oriented(cyl(steel, 0.42, 0.28, (0, 0, 0), verts=16), tip + tdir * 0.03, tdir))
    parts.append(sp.oriented(cyl(dark, 0.27, 0.06, (0, 0, 0), verts=12), tip + tdir * 0.18, tdir))
    parts.append(sweep(steel, [tuple(tip - tdir * 0.35 + Vector((0, 0, 0))), tuple(tip - tdir * 0.6 + Vector((-0.2, 0, 0.3)))], 0.1, sides=8))
    # bail handle over the top, turned 40 degrees so it reads from the front
    rz = math.radians(40)

    def turn(p):
        return (p[0] * math.cos(rz) - p[1] * math.sin(rz), p[0] * math.sin(rz) + p[1] * math.cos(rz), p[2])

    arch = [turn(p) for p in bezier((0, -2.22, 2.2), (0, -3.0, 7.5), (0, 3.0, 7.5), (0, 2.22, 2.2), 24)]
    parts.append(sweep(steel, arch, 0.2, sides=10))
    parts.append(sweep(black, arch[8:17], 0.42, sides=12))
    parts.append(sweep(shine, [(x - 0.14, y - 0.12, z + 0.32) for x, y, z in arch[9:16]], 0.06, sides=5))
    for sy in (-1, 1):
        lug = turn((0, sy * 2.3, 2.2))
        parts.append(ball(steel, 0.5, lug, seg=14, rings=8))
        parts.append(ball(shine, 0.14, (lug[0] - 0.2, lug[1] - 0.2, lug[2] + 0.2), seg=6, rings=4))
    # body highlight streak
    parts.append(sp.lathe_arc(M("KettleGloss", "#7fb0ee", 0.15), [(2.435, 0.9), (2.42, 1.4)], 200, 208, 2))
    parts.append(sp.lathe_arc(M("KettleGloss", "#7fb0ee", 0.15), [(2.4, 2.0), (2.26, 2.75)], 203, 211, 2))
    return parts, (6, 6.5, 5)


def paper_towel_roll():
    paper = M("TowelPaper", "#f6f3ec", 0.92)
    paper2 = M("TowelPaperShade", "#dcd8cf", 0.92)
    print_blue = M("TowelPrint", "#86bde6", 0.85)
    board = M("TowelCore", "#b98a55", 0.9)
    wood = M("TowelWood", "#7a4b2a", 0.6)
    chrome = M("TowelChrome", "#eef3f6", 0.12, 0.95)
    dark = M("TowelDark", "#3b3f45", 0.5)
    parts = []
    parts.append(lathe(wood, fillet([(0, 0), (1.9, 0), (2.0, 0.08), (2.0, 0.35), (1.75, 0.55), (0, 0.55)], r=0.14, n=3, radii={1: 0.03}), verts=40))
    parts.append(torus(dark, 1.72, 0.05, (0, 0, 0.56), seg=36, sides=5))
    parts.append(lathe(chrome, [(0, 0.5), (0.24, 0.5), (0.2, 8.4), (0, 8.4)], verts=16))
    parts.append(ball(chrome, 0.42, (0, 0, 8.6), seg=20, rings=10))
    parts.append(ball(M("TowelShine", "#ffffff", 0.1, 0.1), (0.1, 0.1, 0.1), (-0.14, -0.26, 8.78), seg=6, rings=4))
    roll = fillet([(0.5, 0.65), (1.83, 0.65), (1.83, 7.65), (0.5, 7.65), (0.5, 0.65)], r=0.16, n=3, radii={0: 0, 1: 0.12, 2: 0.12, 3: 0.03})
    parts.append(lathe(paper, roll, verts=40))
    parts.append(lathe(board, [(0.3, 0.55), (0.56, 0.55), (0.56, 7.75), (0.3, 7.75), (0.3, 0.55)], verts=24))
    # quilted rings and printed borders
    for z in [2.2, 3.0, 3.8, 4.6, 5.4, 6.2]:
        parts.append(torus(paper2, 1.83, 0.035, (0, 0, z), seg=40, sides=4))
    for z0, z1 in ((0.95, 1.4), (6.9, 7.35)):
        parts.append(lathe(print_blue, [(1.8, z0), (1.87, z0), (1.87, z1), (1.8, z1), (1.8, z0)], verts=40))
    for k in range(12):  # little printed dots between the border stripes
        a = 2 * math.pi * k / 12
        parts.append(ball(print_blue, (0.16, 0.05, 0.16), (1.85 * math.cos(a), 1.85 * math.sin(a), 1.17), seg=8, rings=4,
                          rot=(0, 0, a + math.pi / 2)))
    # the loose sheet: leaves the roll at the front and curls away
    path = [(0.0, -1.83, 4.3), (0.7, -1.98, 4.3), (1.35, -1.85, 4.3), (1.9, -1.4, 4.3), (2.15, -0.7, 4.3)]
    pts = list(path)
    # resample the polyline
    dense = []
    for i in range(len(pts) - 1):
        a, b = Vector(pts[i]), Vector(pts[i + 1])
        for k in range(4):
            dense.append(tuple(a + (b - a) * (k / 4)))
    dense.append(pts[-1])
    parts.append(sweep(paper, dense, (2.55, 0.03), sides=4, rect=True, up=(0, 0, 1)))
    # perforation dashes and emboss dots on the sheet
    for j in range(9):
        z = 2.0 + j * 0.55
        parts.append(rbox(paper2, (0.06, 0.06, 0.28), (2.13, -0.95, z), r=0.01, seg=1, rot=(0, 0, 0.5)))
    for j in range(4):
        for k in range(4):
            x, y = 0.4 + k * 0.42, -1.96 + (0.14 * k if k < 3 else 0.55)
            parts.append(ball(paper2, (0.09, 0.05, 0.09), (x, y - 0.03, 2.5 + j * 0.9), seg=6, rings=4))
    return parts, (4, 9, 4)


sp.run((("toaster", toaster), ("kettle", kettle), ("paper_towel_roll", paper_towel_roll)))
