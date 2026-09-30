"""Station models (static). Run: tools/blender-run.ps1 art/scripts/stations.py"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import artlib  # noqa: E402
from shapes import ball, box, build_asset, cyl, lathe, prism  # noqa: E402

M = artlib.material


def cutting_board():
    dark = M("BoardEdge", "#9c6a37", 0.85)
    light = M("BoardWood", "#e0b070", 0.8)
    line = M("BoardGrain", "#c08e4f", 0.9)
    parts = [box(dark, (9, 6, 0.38), (0, 0, 0.19)),
             box(light, (8.4, 5.4, 0.1), (0, 0, 0.35))]
    for y in (-1.8, -0.6, 0.6, 1.8):
        parts.append(box(line, (8.4, 0.08, 0.03), (0, y, 0.405)))
    for x in (-2.8, 0.4, 3.1):
        parts.append(box(line, (0.08, 1.15, 0.03), (x, 1.2, 0.405)))
    parts.append(cyl(dark, 0.3, 0.05, (3.9, 2.4, 0.4), verts=8))  # hang hole ring
    return parts, (9, 0.4, 6)


def knife():
    steel = M("KnifeSteel", "#d3dbe0", 0.25, 0.8)
    black = M("KnifeHandle", "#1b1b20", 0.6)
    brass = M("KnifeRivet", "#d6a83a", 0.4, 0.7)
    blade = [(-1.0, -0.85), (1.6, -0.8), (3.0, -0.5), (3.5, 0.0), (2.6, 0.55), (-1.0, 0.55)]
    parts = [prism(steel, blade, 0.11, 0.19),
             box(steel, (0.35, 0.65, 0.16), (-1.05, -0.05, 0.15)),
             box(black, (2.3, 0.55, 0.3), (-2.15, -0.05, 0.15))]
    parts.append(cyl(black, 0.275, 0.3, (-3.3, -0.05, 0.15), verts=8))
    for x in (-1.8, -2.5):
        parts.append(cyl(brass, 0.11, 0.33, (x, -0.05, 0.15), verts=8))
    return parts, (7, 0.3, 1.4)


def griddle():
    steel = M("GriddleSteel", "#2c2f36", 0.45, 0.6)
    plate = M("GriddlePlate", "#3d424b", 0.4, 0.6)
    heat = M("GriddleHeat", "#ff6a10", 0.5, emission="#ff4a00", emission_strength=1.3)
    knob = M("GriddleKnob", "#151518", 0.6)
    parts = [box(steel, (9, 7, 0.34), (0, 0, 0.17)),
             box(plate, (8.6, 6.6, 0.14), (0, 0, 0.41))]
    for y in (-2.4, -1.2, 0.0, 1.2, 2.4):
        parts.append(box(heat, (7.8, 0.36, 0.04), (0, y, 0.49)))
    for x in (-3.0, 0.0, 3.0):
        parts.append(cyl(knob, 0.16, 0.16, (x, -3.35, 0.2), rot=(math.pi / 2, 0, 0), verts=8))
    return parts, (9, 0.5, 7)


def plate():
    white = M("PlateWhite", "#ebebe6", 0.35)
    well = M("PlateWell", "#cdd7e0", 0.35)
    prof = [(0, 0), (2.5, 0), (3.5, 0.32), (3.5, 0.4), (3.3, 0.4), (2.7, 0.13), (0, 0.13)]
    return [lathe([white, well], prof, verts=20,
                  face_mat=lambda c: 1 if (c.z < 0.2 and math.hypot(c.x, c.y) < 2.6) else 0)], (7, 0.4, 7)


def service_bell():
    base = M("BellBase", "#26262c", 0.5, 0.3)
    brass = M("BellBrass", "#f0b820", 0.3, 0.8)
    red = M("BellButton", "#d92b2b", 0.4)
    parts = [cyl(base, 1.0, 0.3, (0, 0, 0.15), verts=16),
             cyl(brass, 0.95, 0.08, (0, 0, 0.34), verts=16)]
    prof = [(0, 0), (0.9, 0), (0.85, 0.35), (0.65, 0.7), (0.4, 0.95), (0, 1.05)]
    parts.append(lathe(brass, prof, verts=16, loc=(0, 0, 0.38)))
    parts.append(cyl(base, 0.1, 0.16, (0, 0, 1.5), verts=8))
    parts.append(ball(red, (0.17, 0.17, 0.12), (0, 0, 1.5), seg=8, rings=4))
    return parts, (2, 1.6, 2)


def trash_drain():
    ring = M("DrainRing", "#4b5058", 0.4, 0.7)
    bar = M("DrainBar", "#6c727a", 0.4, 0.7)
    void = M("DrainVoid", "#08080a", 0.9)
    prof = [(0, 0), (2.0, 0), (2.0, 0.2), (1.65, 0.2), (1.5, 0.05), (0, 0.05)]
    parts = [lathe([ring, void], prof, verts=20,
                   face_mat=lambda c: 1 if (c.z < 0.06 and math.hypot(c.x, c.y) < 1.5) else 0)]
    for x in (-1.0, -0.5, 0.0, 0.5, 1.0):
        ln = 2 * math.sqrt(1.6 ** 2 - x ** 2)
        parts.append(box(bar, (0.16, ln, 0.1), (x, 0, 0.11)))
    parts.append(cyl(ring, 0.42, 0.12, (0, 0, 0.14), verts=12))
    return parts, (4, 0.2, 4)


for name, fn in (("cutting_board", cutting_board), ("knife", knife), ("griddle", griddle), ("plate", plate),
                 ("service_bell", service_bell), ("trash_drain", trash_drain)):
    artlib.reset_scene()
    parts, size = fn()
    build_asset(name, parts, size)
