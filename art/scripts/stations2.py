"""Stations batch 2: fryer (flat, sunk into the counter like the griddle) and soda_fountain (solid).

Run: tools/blender-run.ps1 art/scripts/stations2.py [-- name ...]
Fryer: nothing rises above T = 0.5; the oil surface sits at T - 0.1 (visible depth inside the well).
Front is Blender -Y (Godot +Z).
"""
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import artlib  # noqa: E402
from shapes import build_asset  # noqa: E402
from station_parts import Acc, hexcol as M, rrect_fn, rrect_pts  # noqa: E402

PI = math.pi


# ===========================================================================
# FRYER 7 x 0.5 x 6
# ===========================================================================
def fryer():
    T = 0.5
    steel = M("FryerSteel", "#b9c1c8", 0.3, 0.6)
    steel_d = M("FryerSteelDark", "#8f989f", 0.38, 0.6)
    brushed = M("FryerBrushed", "#d3d9de", 0.45, 0.55)
    well = M("FryerWell", "#2a2523", 0.5, 0.5)
    floor = M("FryerFloor", "#4a2608", 0.8)
    oil = artlib.material("FryerOil", "#e8921a", 0.08, 0.0, emission="#c46a00", emission_strength=0.8, alpha=0.9)
    oil_hi = artlib.material("FryerOilShine", "#fff0a0", 0.05, 0.0, emission="#ffd060", emission_strength=1.0, alpha=0.85)
    bubble = artlib.material("FryerBubble", "#fff0a8", 0.2, 0.0, alpha=0.85)
    wire = M("FryerWire", "#7d8892", 0.3, 0.85)
    grip = M("FryerGrip", "#c4281c", 0.5)
    grip_d = M("FryerGripDark", "#2a1412", 0.6)
    panel = M("FryerPanel", "#1f2227", 0.5, 0.3)
    chrome = M("FryerChrome", "#f0f5f8", 0.12, 0.95)
    knob = M("FryerKnob", "#15161a", 0.35, 0.2)
    white = M("FryerMark", "#f4f4ef", 0.5)
    red = M("FryerTick", "#ff4a30", 0.5)
    green = M("FryerLampG", "#38f070", 0.3, emis="#20e060", strength=2.0)
    amber = M("FryerLampA", "#ffb020", 0.3, emis="#ff9a10", strength=2.2)
    red_l = M("FryerLampR", "#ff3a2a", 0.3, emis="#ff2010", strength=1.6)
    slot = M("FryerSlot", "#0c0b0b", 0.9)
    a = Acc()

    WX, WY, WCY = 6.2, 4.0, 0.2
    outer = rrect_pts(7, 6, 0.4, 5)
    inner = rrect_pts(WX, WY, 0.22, 5, 0, WCY)
    a.poly(steel_d, outer, 0, 0.16)
    a.band(brushed, outer, inner, 0.0, T - 0.03)
    a.sweep(steel, rrect_fn(7, 6, 0.4), [(-0.03, T - 0.26), (0, T - 0.23), (0, T - 0.06), (-0.03, T - 0.03)], closed=True)
    a.band(steel, outer, rrect_pts(6.9, 5.9, 0.35, 5), T - 0.03, T, None)
    a.band(steel, rrect_pts(WX + 0.3, WY + 0.3, 0.3, 5, 0, WCY), rrect_pts(WX, WY, 0.22, 5, 0, WCY), T - 0.03, T)
    a.poly(well, rrect_pts(WX + 0.02, WY + 0.02, 0.22, 5, 0, WCY), 0.14, 0.3)
    a.poly(floor, rrect_pts(WX - 0.25, WY - 0.25, 0.2, 5, 0, WCY), 0.3, 0.33)
    OZ = T - 0.1
    a.poly(oil, rrect_pts(WX - 0.12, WY - 0.12, 0.2, 5, 0, WCY), OZ - 0.025, OZ)
    rng = random.Random(4)
    for _ in range(26):
        x, y = rng.uniform(-2.9, 2.9), rng.uniform(-1.6, 2.0)
        a.disc(bubble, rng.uniform(0.05, 0.12), OZ - 0.004, OZ + 0.006, x, y, 10)
    for (x, y, rx, ry, rot) in ((-2.6, -0.9, 0.5, 0.15, 0.3), (0.1, 1.5, 0.7, 0.18, -0.2), (2.4, 0.5, 0.45, 0.14, 0.5)):
        a.disc(oil_hi, rx, OZ - 0.01, OZ + 0.003, x, y, 20, ry=ry, rot=rot)

    # three wire baskets with divider bars
    for bx in (-2.05, 0.0, 2.05):
        bw, y0, y1 = 1.85, -1.55, 1.5
        zr0, zr1 = T - 0.17, T - 0.08
        for sx in (-1, 1):
            a.box(wire, (0.08, y1 - y0, zr1 - zr0), (bx + sx * bw / 2, (y0 + y1) / 2, (zr0 + zr1) / 2))
        for yy in (y0, y1):
            a.box(wire, (bw + 0.08, 0.08, zr1 - zr0), (bx, yy, (zr0 + zr1) / 2))
        for k in range(1, 7):
            a.box(wire, (0.06, y1 - y0, 0.05), (bx - bw / 2 + k * bw / 7, (y0 + y1) / 2, 0.425))
        for k in range(1, 12):
            a.box(wire, (bw, 0.06, 0.05), (bx, y0 + k * (y1 - y0) / 12, 0.42))
        for sx in (-0.45, 0.45):
            a.box(wire, (0.1, 0.62, 0.1), (bx + sx, y1 + 0.28, T - 0.13))
        a.box(grip_d, (1.1, 0.14, 0.14), (bx, y1 + 0.6, T - 0.12), bevel=0.02)
        a.box(grip, (0.85, 0.46, 0.16), (bx, y1 + 0.66, T - 0.1), bevel=0.04, seg=2)
    for dx in (-1.025, 1.025):
        a.box(steel, (0.12, WY - 0.3, 0.12), (dx, WCY, T - 0.07), bevel=0.02)

    # front control strip (flush)
    py = -2.42
    a.box(panel, (6.5, 0.86, 0.06), (0, py, T - 0.04), bevel=0.02)
    pz = T - 0.014
    for x, ang in ((-2.6, -0.8), (-1.4, 0.4), (-0.2, 1.2)):
        a.disc(chrome, 0.32, pz - 0.02, pz + 0.004, x, py, 32, bevel=0.006)
        a.disc(knob, 0.25, pz - 0.02, T - 0.004, x, py, 32, bevel=0.03, seg=2)
        a.box(white, (0.055, 0.2, 0.012), (x + 0.13 * math.sin(ang), py + 0.13 * math.cos(ang), T - 0.008), rot=-ang)
        for k in range(9):
            t = math.radians(-135 + 270 * k / 8)
            a.box(red if k > 5 else white, (0.035, 0.07, 0.008),
                  (x + 0.37 * math.sin(t), py + 0.37 * math.cos(t), pz + 0.002), rot=-t)
    for x, lamp in ((1.0, green), (1.75, amber), (2.5, red_l)):
        a.disc(chrome, 0.2, pz - 0.02, pz + 0.006, x, py, 24, bevel=0.005)
        a.disc(lamp, 0.145, pz - 0.02, pz + 0.008, x, py, 24, bevel=0.01)
    a.box(chrome, (0.6, 0.3, 0.03), (3.05, py, pz - 0.004), bevel=0.012, seg=2)
    for k in range(3):
        a.box(panel, (0.45, 0.035, 0.02), (3.05, py - 0.08 + k * 0.08, pz + 0.004))

    # drip rail along the back
    a.box(slot, (6.5, 0.42, 0.05), (0, 2.6, T - 0.045), bevel=0.02)
    for k in range(-15, 16):
        a.box(steel, (0.09, 0.4, 0.03), (k * 0.2, 2.6, T - 0.03))
    a.box(steel, (6.5, 0.06, 0.04), (0, 2.85, T - 0.025), bevel=0.01)
    a.box(steel, (6.5, 0.06, 0.04), (0, 2.35, T - 0.025), bevel=0.01)
    for sx in (-1, 1):
        for yy in (2.6, -2.72):
            a.disc(chrome, 0.07, T - 0.04, T - 0.004, sx * 3.25, yy, 10, bevel=0.01)
        a.box(slot, (0.1, 3.6, 0.03), (sx * 3.35, 0.2, T - 0.02))
    return [a.finish("Fryer")], (7, 0.5, 6)


# ===========================================================================
# SODA FOUNTAIN 4 x 5 x 3   (tower x -2..1, cup stack at x ~1.5, front -Y)
# ===========================================================================
def soda_fountain():
    teal = M("SodaTeal", "#2fb6ae", 0.42, 0.05)
    teal_d = M("SodaTealDark", "#1f8a84", 0.5, 0.05)
    cream = M("SodaCream", "#f6eed8", 0.5)
    chrome = M("SodaChrome", "#f0f5f8", 0.12, 0.95)
    steel = M("SodaSteel", "#a9b2ba", 0.3, 0.7)
    dark = M("SodaDark", "#1b1d22", 0.6, 0.3)
    red = M("SodaRed", "#d8322a", 0.4)
    blue = M("SodaBlue", "#2a6fe0", 0.4)
    green = M("SodaGreen", "#35b94a", 0.4)
    orange = M("SodaOrange", "#ff8a1e", 0.4)
    glow = M("SodaSign", "#fff3c2", 0.5, emis="#ffd66a", strength=2.6)
    glow_r = M("SodaSignRed", "#ff5a3a", 0.5, emis="#ff3a1a", strength=2.4)
    glow_b = M("SodaSignBlue", "#5ab0ff", 0.5, emis="#2a8aff", strength=2.4)
    bulb = M("SodaBulb", "#fff9d8", 0.3, emis="#ffe9a0", strength=3.0)
    cup_r = M("SodaCupRed", "#e02a25", 0.5)
    cup_w = M("SodaCupWhite", "#f7f4ee", 0.5)
    a = Acc()

    X0, X1 = -1.95, 0.95
    XC, XW = (X0 + X1) / 2, X1 - X0
    # drip tray across the whole footprint
    a.box(chrome, (4.0, 2.8, 0.33), (0, 0, 0.165), bevel=0.06, seg=2)
    a.box(dark, (3.7, 2.5, 0.06), (0, 0, 0.33), bevel=0.02)
    for k in range(-6, 7):
        a.box(steel, (3.6, 0.08, 0.05), (0, k * 0.19, 0.36))
    # back column with grille slots and chrome trim
    a.box(teal, (XW, 1.3, 4.05), (XC, 0.75, 0.35 + 2.025), bevel=0.09, seg=3)
    a.box(chrome, (XW + 0.06, 0.08, 0.1), (XC, 0.04, 0.6), bevel=0.02)
    for sx in (X0 + 0.12, X1 - 0.12):
        a.box(chrome, (0.1, 0.06, 3.3), (sx, 0.03, 1.9), bevel=0.02)
    for k in range(6):
        a.box(teal_d, (1.6, 0.04, 0.08), (XC, 0.035, 1.0 + k * 0.17), bevel=0.01)
    # nozzle head overhanging the tray
    a.box(teal, (XW, 2.4, 1.6), (XC, 0.2, 3.5), bevel=0.1, seg=3)
    a.box(chrome, (XW + 0.06, 2.46, 0.12), (XC, 0.2, 2.78), bevel=0.03, seg=2)
    a.box(chrome, (XW + 0.06, 2.46, 0.1), (XC, 0.2, 4.22), bevel=0.03, seg=2)
    fy = 0.2 - 1.2
    a.box(dark, (XW - 0.3, 0.06, 1.0), (XC, fy - 0.02, 3.55), bevel=0.02)
    flav = ((red, XC - 0.93), (blue, XC - 0.31), (green, XC + 0.31), (orange, XC + 0.93))
    for mat, x in flav:
        a.box(cream, (0.46, 0.05, 0.46), (x, fy - 0.07, 3.85), bevel=0.14, seg=3)
        a.box(mat, (0.34, 0.05, 0.34), (x, fy - 0.1, 3.85), bevel=0.11, seg=3)
        a.box(chrome, (0.16, 0.26, 0.16), (x, fy - 0.16, 3.42), bevel=0.03)
        a.box(mat, (0.5, 0.2, 0.62), (x, fy - 0.3, 3.3), bevel=0.07, seg=3)
        a.disc(chrome, 0.15, 2.58, 2.76, x, fy + 0.55, 14)
        a.lathe(chrome, [(0.0, 2.3), (0.1, 2.3), (0.17, 2.4), (0.15, 2.6), (0.0, 2.6)], 14, x, fy + 0.55)
        a.disc(mat, 0.07, 2.25, 2.32, x, fy + 0.55, 10)
    # lit sign band on top
    sf = -0.5
    a.box(red, (XW + 0.1, 1.9, 0.78), (XC, 0.45, 4.69), bevel=0.09, seg=3)
    a.box(glow, (XW - 0.1, 0.06, 0.52), (XC, sf - 0.01, 4.69), bevel=0.02)
    for k, mat in enumerate((glow_r, glow_b, glow_r, glow_b, glow_r)):
        a.box(mat, (0.22, 0.05, 0.4), (X0 + 0.45 + k * 0.5, sf - 0.04, 4.69))
    for k in range(9):
        x = X0 + 0.1 + k * (XW - 0.2) / 8
        for zz in (4.36, 4.98):
            a.box(bulb, (0.1, 0.06, 0.1), (x, sf - 0.02, zz), bevel=0.03, seg=2)
    # cup stack on a little shelf at the side
    cx, cy = 1.45, 0.05
    a.disc(steel, 0.5, 0.36, 0.4, cx, cy, 24, bevel=0.01)
    h, step, n = 0.95, 0.27, 8
    for i in range(n):
        z0 = 0.4 + i * step
        prof = [(0.0, z0), (0.29, z0), (0.47, z0 + h), (0.47, z0 + h - 0.03), (0.3, z0 + h - 0.6), (0.0, z0 + h - 0.6)]
        rim_z = z0 + h - 0.13
        body, rim = (cup_r, cup_w) if i % 2 == 0 else (cup_w, cup_r)
        a.lathe(body, prof, 20, cx, cy, mat_fn=lambda c, rz=rim_z, b=body, r_=rim: r_ if c.z > rz else b)
    return [a.finish("SodaFountain")], (4, 5, 3)


BUILDERS = (("fryer", fryer), ("soda_fountain", soda_fountain))

if __name__ == "__main__" or True:
    only = artlib.script_args()
    for name, fn in BUILDERS:
        if only and name not in only:
            continue
        artlib.reset_scene()
        parts, size = fn()
        build_asset(name, parts, size)
