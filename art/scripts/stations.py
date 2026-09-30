"""Station models (static). Run: tools/blender-run.ps1 art/scripts/stations.py [-- name ...]

IMPORTANT: the game sinks the flat stations (griddle, cutting_board, plate, trash_drain) into the
counter so that only their top 3 cm show. All their art therefore lives in a thin skin just under
the top height T: colour inlays, layered plates, grooves a few mm deep. Nothing rises above T
(decals stand at most a few mm proud). Knife and bell are free-form.
"""
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import artlib  # noqa: E402
from shapes import build_asset  # noqa: E402
from station_parts import Acc, circle_pts, ellipse_pts, hexcol as M, rot_pts, rrect_fn, rrect_pts  # noqa: E402

PI = math.pi


def solid_profile(c, z0, z1):
    """Chamfered slab profile for Acc.sweep (open, capped): bottom inset, side, top inset."""
    return [(-c, z0), (0, z0 + c), (0, z1 - c), (-c, z1)]


def ring_profile(r0, r1, z0, z1, c=0.0):
    """Closed (r, z) profile of a ring section with optional top chamfer c."""
    return [(r0, z0), (r1, z0), (r1, z1 - c), (r1 - c, z1), (r0 + c, z1), (r0, z1 - c)]


# ===========================================================================
# GRIDDLE 9 x 0.5 x 7   (front = -Y)
# ===========================================================================
def griddle():
    T = 0.5
    F = T - 0.02          # frame level
    body = M("GriddleBody", "#1b1d22", 0.6, 0.5)
    frame = M("GriddleFrame", "#b6bec6", 0.32, 0.5)
    fin = M("GriddleFin", "#cfd6dc", 0.28, 0.5)
    panel = M("GriddlePanel", "#23262d", 0.5, 0.3)
    chrome = M("GriddleChrome", "#e6ebef", 0.15, 0.5)
    knob = M("GriddleKnob", "#121316", 0.35, 0.2)
    white = M("GriddleMark", "#f2f2ee", 0.5)
    glow = M("GriddleGlow", "#ff6a10", 0.5, emis="#ff4a00", strength=2.6)
    green = M("GriddleLampG", "#38f070", 0.3, emis="#20e060", strength=2.0)
    amber = M("GriddleLampA", "#ffb020", 0.3, emis="#ff9a10", strength=2.0)
    red = M("GriddleLampR", "#ff3a2a", 0.3, emis="#ff2010", strength=1.6)
    bright = M("GriddleBright", "#a9b1b9", 0.3, 0.5)
    season = M("GriddleSeasoned", "#2b2521", 0.5, 0.5)
    sheen = M("GriddleSheen", "#4d3d2f", 0.12, 0.45)
    scrape = M("GriddleScrape", "#6c6157", 0.4, 0.5)
    burnt = M("GriddleBurn", "#161311", 0.7, 0.3)
    smear = M("GriddleSmear", "#818991", 0.22, 0.5)
    streak = M("GriddleStreak", "#dde3e8", 0.2, 0.5)
    grease = M("GriddleGrease", "#1a120d", 0.28, 0.2)
    pit = M("GriddlePit", "#040404", 0.9)
    a = Acc()

    a.poly(body, rrect_pts(9, 7, 0.45), 0, T - 0.05)
    a.sweep(frame, rrect_fn(9, 7, 0.45), solid_profile(0.03, F - 0.2, F))

    # ---- front control panel ----------------------------------------------
    a.box(panel, (8.76, 0.86, 0.06), (0, -2.99, F - 0.024), bevel=0.02)
    pz = F + 0.006
    for x, ang in ((-3.3, -0.9), (-2.0, 0.0), (-0.7, 0.9)):
        a.disc(chrome, 0.33, pz - 0.02, pz + 0.006, x, -2.99, 32, bevel=0.006)
        a.disc(knob, 0.265, pz - 0.02, T - 0.004, x, -2.99, 32, bevel=0.03, seg=2)
        ix, iy = x + 0.135 * math.sin(ang), -2.99 + 0.135 * math.cos(ang)
        a.box(white, (0.055, 0.2, 0.012), (ix, iy, T - 0.002), rot=-ang)
        for k in range(9):                       # scale ticks on a 270 degree arc
            t = math.radians(-135 + 270 * k / 8)
            a.box(white, (0.035, 0.07, 0.008), (x + 0.385 * math.sin(t), -2.99 + 0.385 * math.cos(t), pz + 0.002),
                  rot=-t)
    for x, lamp in ((1.05, green), (1.95, amber), (2.85, red)):
        a.disc(chrome, 0.21, pz - 0.02, pz + 0.008, x, -2.99, 24, bevel=0.005)
        a.disc(lamp, 0.15, pz - 0.02, pz + 0.016, x, -2.99, 24, bevel=0.01)
    a.box(chrome, (0.95, 0.42, 0.03), (3.85, -2.99, pz - 0.006), bevel=0.012, seg=2)
    for k in range(3):
        a.box(panel, (0.62, 0.035, 0.02), (3.85, -3.09 + k * 0.1, pz + 0.003))

    # ---- steel rails and glowing vent fins ----------------------------------
    a.box(fin, (8.76, 0.2, 0.06), (0, -2.5, T - 0.03), bevel=0.025, seg=2)      # front rail
    a.box(fin, (8.76, 0.34, 0.06), (0, 3.215, T - 0.03), bevel=0.025, seg=2)    # back rail
    y0, y1, n, gap = -2.4, 3.05, 7, 0.19
    fl = (y1 - y0 - gap * (n - 1)) / n
    for side in (-1, 1):
        for k in range(n):
            ya = y0 + k * (fl + gap)
            a.box(fin, (0.48, fl, 0.06), (side * 4.14, ya + fl / 2, T - 0.03), bevel=0.025, seg=2)
            if k < n - 1:
                a.box(glow, (0.3, gap - 0.05, 0.03), (side * 4.14, ya + fl + gap / 2, F - 0.007))
    for sx in (-1, 1):
        for yy in (3.215, -2.5):
            a.disc(chrome, 0.085, T - 0.03, T + 0.003, sx * 4.14, yy, 12, bevel=0.01)

    # ---- glowing heat ring, cooking plate, trough ---------------------------
    cy = 0.325
    ring = rrect_fn(7.8, 5.45, 0.3, cy=cy)
    a.sweep(glow, ring, [(0, F + 0.004), (0, F + 0.009), (-0.15, F + 0.009), (-0.15, F + 0.004)], closed=True)
    a.sweep(bright, rrect_fn(7.5, 4.6, 0.22, cy=0.03), solid_profile(0.03, T - 0.2, T))
    a.box(grease, (7.5, 0.6, 0.05), (0, 2.63, F - 0.019), bevel=0.02, seg=2)
    a.box(pit, (1.0, 0.44, 0.03), (2.9, 2.63, F - 0.007))
    for k in range(4):
        a.box(bright, (0.07, 0.42, 0.02), (2.55 + k * 0.24, 2.63, F))

    # seasoned zone and its wear marks
    a.sweep(season, rrect_fn(5.05, 4.25, 0.2, cx=-1.25, cy=0.03), solid_profile(0.012, T - 0.1, T + 0.004))
    Z = T + 0.004
    rng = random.Random(7)
    for (x, y, rx, ry, rot) in ((-2.6, 1.0, 0.85, 0.42, 0.4), (-0.4, -0.9, 0.7, 0.34, -0.3),
                                (-1.6, -1.4, 0.5, 0.26, 0.9), (0.2, 1.3, 0.55, 0.3, 0.1)):
        a.disc(sheen, rx, Z - 0.01, Z + 0.003, x, y, 28, ry=ry, rot=rot)
    for (x, y, ln, rot) in ((-2.9, -0.2, 1.5, 0.35), (-1.9, 0.5, 1.9, -0.25), (-0.7, 1.55, 1.2, 0.55),
                            (-2.4, -1.5, 1.4, 0.15), (-0.3, -0.1, 1.6, -0.45), (-1.1, -1.7, 0.9, 0.8),
                            (-3.0, 1.6, 0.9, -0.6)):
        a.box(scrape, (ln, 0.035, 0.01), (x, y, Z + 0.002), rot=rot)
    for (x, y, r) in ((-3.0, -1.7, 0.16), (-0.2, 1.75, 0.13), (-1.4, 0.0, 0.11), (0.5, -1.7, 0.14)):
        a.disc(burnt, r, Z - 0.01, Z + 0.004, x, y, 14, ry=r * 0.7, rot=rng.random() * 3)
    for (x, y) in ((-2.4, -0.6), (-0.6, 0.6)):
        a.lathe_closed(sheen, ring_profile(1.02, 1.12, Z - 0.012, Z + 0.003), 40, x, y)
    # bright zone: smears and polish streaks
    for (x, y, rx, ry, rot) in ((2.55, -0.6, 0.6, 0.3, 0.3), (2.6, 1.2, 0.5, 0.25, -0.5)):
        a.disc(smear, rx, T - 0.008, T + 0.003, x, y, 24, ry=ry, rot=rot)
    for (x, y, ln, rot) in ((2.4, 0.3, 1.5, 1.45), (2.9, -1.2, 1.2, 1.5), (2.0, 1.7, 0.9, 1.35), (3.3, 0.9, 1.3, 1.55)):
        a.box(streak, (ln, 0.03, 0.008), (x, y, T + 0.001), rot=rot)
    a.box(burnt, (0.06, 4.2, 0.02), (1.32, 0.03, T + 0.002))     # zone divider

    return [a.finish("Griddle")], (9, 0.5, 7)


# ===========================================================================
# CUTTING BOARD 9 x 0.4 x 6
# ===========================================================================
def cutting_board():
    T = 0.4
    F = T - 0.022
    a = Acc()
    deep = M("BoardDeep", "#2e1c0f", 0.9)
    rimw = M("BoardRim", "#5a3820", 0.55)
    plank = M("BoardPlank", "#d6a468", 0.6)
    grain = M("BoardGrainLine", "#b9834a", 0.7)
    scar = M("BoardScar", "#5b3a1c", 0.8)
    scratch = M("BoardScratch", "#f6e2b8", 0.6)
    tones = [M("BoardBlock%d" % i, c, 0.55) for i, c in enumerate(
        ("#efd29b", "#e6bf7d", "#d9a865", "#c98d50", "#b47640", "#9a5f30", "#7f4a26", "#e9c88d"))]
    tones_d = [M("BoardRing%d" % i, c, 0.6) for i, c in enumerate(
        ("#e2c088", "#d6ac6c", "#c6955a", "#b57b40", "#9f6633", "#844f26", "#6a3d1e", "#dcb87c"))]
    outline = rrect_fn(9, 6, 0.65)

    a.poly(deep, rrect_pts(9, 6, 0.65), 0, F)
    a.sweep(rimw, outline, [(0, F - 0.02), (0, T - 0.025), (-0.025, T), (-0.27, T), (-0.3, T - 0.025), (-0.3, F - 0.02)],
            closed=True)

    # end-grain block field
    x0, x1, y0, y1 = -3.95, 2.35, -2.45, 2.45
    nx, ny = 13, 10
    cw, ch = (x1 - x0) / nx, (y1 - y0) / ny
    rng = random.Random(11)
    rowbias = [rng.random() for _ in range(ny)]
    for j in range(ny):
        for i in range(nx):
            cx, cy = x0 + (i + 0.5) * cw, y0 + (j + 0.5) * ch
            m = 0.62 * rowbias[j] + 0.38 * rng.random()
            if (i + j) % 2:
                m = min(0.99, m + 0.28)
            idx = int(m * (len(tones) - 1) + rng.random() * 0.9)
            ti = min(idx, len(tones) - 1)
            a.box(tones[ti], (cw - 0.075, ch - 0.075, 0.07), (cx, cy, T - 0.035), bevel=0.015, seg=1)
            a.box(tones_d[ti], (cw * 0.42, ch * 0.42, 0.008), (cx + rng.uniform(-0.05, 0.05), cy + rng.uniform(-0.05, 0.05), T + 0.001),
                  rot=rng.uniform(0, 1.5), bevel=0.01)

    # long-grain handle plank with a stadium hole (dark, the body shows through)
    pcx = 3.42
    outer = rrect_pts(1.55, 4.9, 0.2, cx=pcx)
    hole = rrect_pts(0.62, 2.3, 0.31, cx=pcx)
    a.band(plank, outer, hole, F - 0.02, T)
    for k in range(7):
        xg = pcx - 0.6 + k * 0.2
        y_half = 2.3 if abs(xg - pcx) > 0.34 else 1.05
        if abs(xg - pcx) > 0.34:
            a.box(grain, (0.028, 4.5, 0.008), (xg, 0, T + 0.002))
        else:
            for sgn in (-1, 1):
                a.box(grain, (0.028, 1.15, 0.008), (xg, sgn * 1.85, T + 0.002))
    a.sweep(rimw, rrect_fn(0.62, 2.3, 0.31, cx=pcx), [(0.05, T - 0.025), (0.0, T), (0.0, F - 0.01), (0.05, F - 0.01)],
            closed=True) if False else None

    # knife scars, scratches
    srng = random.Random(3)
    for k in range(9):
        x = srng.uniform(x0 + 0.4, x1 - 0.4)
        y = srng.uniform(y0 + 0.4, y1 - 0.4)
        ang = srng.choice((0.0, 0.0, 0.2, -0.25, 1.5, 1.35, 1.7)) + srng.uniform(-0.1, 0.1)
        a.box(scar, (srng.uniform(0.4, 1.1), 0.028, 0.008), (x, y, T + 0.002), rot=ang)
    for k in range(5):
        x = srng.uniform(x0 + 0.5, x1 - 0.5)
        y = srng.uniform(y0 + 0.5, y1 - 0.5)
        a.box(scratch, (srng.uniform(0.25, 0.6), 0.02, 0.006), (x, y, T + 0.002), rot=srng.uniform(-0.6, 0.6))
    return [a.finish("CuttingBoard")], (9, 0.4, 6)


# ===========================================================================
# PLATE 7 x 0.4 x 7
# ===========================================================================
def plate():
    T = 0.4
    porc = M("PlatePorcelain", "#f3f1ea", 0.24)
    glaze = M("PlateGlaze", "#dfeaf4", 0.06)
    blue = M("PlateBlue", "#2d68b4", 0.22)
    gold = M("PlateGold", "#d9aa32", 0.28, 0.5)
    white = M("PlateDot", "#f6f4ee", 0.3)
    # top surface z(r): a whisper of a rim, well surface below it
    top = [(0.0, T - 0.022), (2.55, T - 0.022), (2.75, T - 0.013), (3.0, T - 0.008), (3.3, T - 0.003), (3.42, T)]

    def zb(r):
        if r >= top[-1][0]:
            return T
        for (r0, z0), (r1, z1) in zip(top[:-1], top[1:]):
            if r <= r1:
                return z0 + (z1 - z0) * (r - r0) / (r1 - r0) if r1 > r0 else z1
        return T

    prof = [(0, 0), (3.0, 0), (3.48, 0.14), (3.5, T - 0.06), (3.48, T - 0.02), (3.42, T)]
    prof += [p for p in reversed(top[:-1])]
    a = Acc()
    a.lathe(porc, prof, 64)

    def band(mat, r0, r1, lift=0.005, n=64):
        rr = [r0 + (r1 - r0) * i / 3 for i in range(4)]
        pr = [(r, zb(r) + lift) for r in rr] + [(r1, zb(r1) - 0.02), (r0, zb(r0) - 0.02)]
        a.lathe_closed(mat, pr, n)

    a.disc(glaze, 2.3, T - 0.06, T - 0.022 + 0.004, n=64, bevel=0.008)
    band(blue, 2.36, 2.46)
    band(gold, 2.5, 2.54)
    band(gold, 2.78, 2.83)
    band(blue, 2.88, 3.12)
    band(gold, 3.17, 3.22)
    for k in range(32):
        t = 2 * PI * k / 32
        a.disc(white, 0.048, zb(3.0), zb(3.0) + 0.011, 3.0 * math.cos(t), 3.0 * math.sin(t), 8)
    return [a.finish("Plate")], (7, 0.4, 7)


# ===========================================================================
# TRASH DRAIN 4 x 0.2 x 4
# ===========================================================================
def trash_drain():
    T = 0.2
    F = T - 0.022
    flange = M("DrainFlange", "#b1b8c0", 0.3, 0.5)
    void = M("DrainVoid", "#040405", 0.9)
    rib_o = M("DrainRibOuter", "#9aa2aa", 0.32, 0.5)
    rib_m = M("DrainRibMid", "#767d86", 0.36, 0.5)
    rib_i = M("DrainRibInner", "#4d535b", 0.4, 0.5)
    plug = M("DrainPlug", "#0b0d11", 0.5, 0.3)
    chrome = M("DrainChrome", "#e2e7eb", 0.18, 0.5)
    slot = M("DrainSlot", "#1a1c20", 0.5)
    a = Acc()
    prof = [(0, 0), (2.0, 0), (2.0, T - 0.03), (1.97, T - 0.01), (1.9, T), (1.66, T), (1.61, T - 0.012),
            (1.5, T - 0.02), (1.44, F), (0, F)]
    a.lathe(flange, prof, 64, mat_fn=lambda c: void if (math.hypot(c.x, c.y) < 1.43 and c.z < T - 0.02) else flange)
    zt = T - 0.008
    for r0, r1, m in ((1.16, 1.43, rib_o), (0.76, 1.04, rib_m), (0.4, 0.64, rib_i)):
        a.lathe_closed(m, ring_profile(r0, r1, F - 0.01, zt, 0.02), 48)
    for k in range(8):
        t = 2 * PI * k / 8 + PI / 8
        rm = 0.85
        a.box(rib_m, (1.1, 0.085, 0.02), (rm * math.cos(t), rm * math.sin(t), zt - 0.012), rot=t)
    a.lathe_closed(chrome, ring_profile(0.27, 0.38, F - 0.01, zt + 0.002, 0.01), 32)
    a.disc(plug, 0.27, F - 0.01, zt - 0.006, n=32, bevel=0.008)
    for k in range(4):
        t = PI / 4 + k * PI / 2
        x, y = 1.78 * math.cos(t), 1.78 * math.sin(t)
        a.disc(chrome, 0.1, T - 0.02, T + 0.004, x, y, 14, bevel=0.008)
        a.box(slot, (0.13, 0.024, 0.008), (x, y, T + 0.005), rot=t + 0.5)
    return [a.finish("TrashDrain")], (4, 0.2, 4)


# ===========================================================================
# KNIFE 7 x 0.3 x 1.4  (blade along +X, lying flat)
# ===========================================================================
def knife():
    zc = 0.15
    steel = M("KnifeSteel", "#c9d1d8", 0.24, 0.5)
    satin = M("KnifeSatin", "#8f9aa3", 0.5, 0.5)
    edge = M("KnifeEdge", "#f7fbff", 0.1, 0.5)
    bolster = M("KnifeBolster", "#dde3e8", 0.2, 0.5)
    black = M("KnifeHandle", "#1e1f26", 0.35, 0.05)
    brass = M("KnifeRivet", "#e0ae3a", 0.28, 0.5)
    a = Acc()
    xh, xt, y_tip = -1.0, 3.5, 0.06

    def y_spine(x):
        if x <= 1.6:
            return 0.55
        t = min(1.0, (x - 1.6) / (xt - 1.6))
        return y_tip + (0.55 - y_tip) * (1 - t ** 2.1)

    def y_edge(x):
        if x <= 0.2:
            return -0.85
        t = min(1.0, (x - 0.2) / (xt - 0.2))
        return -0.85 + (y_tip + 0.85) * t ** 1.9

    def thick(x):
        th = 0.11 - 0.055 * (x - xh) / (xt - xh)
        return th * min(1.0, (xt - x) / 0.45)

    def bw(x):
        return min(0.34, 0.45 * (y_spine(x) - y_edge(x)))

    rings = []
    N = 40
    for i in range(N + 1):
        x = xh + (xt - xh) * i / N
        ys, ye, th, b = y_spine(x), y_edge(x), thick(x), bw(x)
        ysh = ye + b
        ymid = ysh + 0.55 * (ys - ysh)
        h = th / 2
        rings.append([(x, ys, zc + h), (x, ymid, zc + h), (x, ysh, zc + h), (x, ye, zc),
                      (x, ysh, zc - h), (x, ymid, zc - h), (x, ys, zc - h)])

    def blade_mat(c):
        d = c.y - y_edge(c.x)
        b = bw(c.x)
        if d < b * 0.8:
            return edge
        ysh = y_edge(c.x) + b
        return satin if c.y > ysh + 0.55 * (y_spine(c.x) - ysh) else steel
    a.rings(steel, rings, False, blade_mat)

    # bolster and brass collar
    bol = [(-1.08, -0.66), (-0.68, -0.72), (-0.6, -0.62), (-0.6, 0.5), (-0.7, 0.58), (-1.08, 0.58)]
    a.poly(bolster, bol, zc - 0.115, zc + 0.115, bevel=0.03, seg=2)
    a.box(brass, (0.07, 0.62, 0.25), (-1.11, -0.06, zc), bevel=0.02, seg=2)

    # handle: tang between two black scales
    yc = -0.06
    top, bot = [], []
    M_ = 14
    for k in range(M_ + 1):
        x = -1.14 - 2.2 * k / M_
        hw = 0.30 - 0.03 * math.sin(PI * k / M_) + 0.04 * (k / M_) ** 2
        top.append((x, yc + hw))
        bot.append((x, yc - hw))
    hw_end = 0.34
    arc = [(-3.34 - 0.16 * math.sin(PI * (i / 8)), yc + hw_end * math.cos(PI * (i / 8))) for i in range(1, 8)]
    pts = top + arc + bot[::-1]
    a.poly(steel, pts, zc - 0.045, zc + 0.045)
    a.poly(black, pts, zc + 0.03, zc + 0.15, bevel=0.035, seg=2)
    a.poly(black, pts, zc - 0.15, zc - 0.03, bevel=0.035, seg=2)
    for x in (-1.65, -2.3, -2.95):
        a.disc(brass, 0.085, zc + 0.11, zc + 0.152, x, yc, 14, bevel=0.012)
        a.disc(brass, 0.085, zc - 0.152, zc - 0.11, x, yc, 14, bevel=0.012)
    a.disc(brass, 0.05, zc - 0.05, zc + 0.05, -1.65, yc, 10)
    return [a.finish("Knife")], (7, 0.3, 1.4)


# ===========================================================================
# SERVICE BELL 2 x 1.6 x 2
# ===========================================================================
def service_bell():
    wood = M("BellWood", "#3a2416", 0.5)
    wood_hi = M("BellWoodTrim", "#5a3a22", 0.45)
    brass = M("BellBrass", "#e3a917", 0.26, 0.5)
    brass_hi = M("BellBrassHi", "#fff0a6", 0.12, 0.5)
    brass_deep = M("BellBrassDeep", "#a86f0e", 0.35, 0.5)
    chrome = M("BellChrome", "#e6ebef", 0.14, 0.5)
    red = M("BellButton", "#e02a2a", 0.16)
    bead = M("BellBead", "#ffcf4a", 0.2, 0.5)
    dark = M("BellEngrave", "#1a1208", 0.6)
    a = Acc()

    # dark wooden base with a stepped, rounded edge
    a.lathe(wood, [(0, 0), (0.97, 0), (1.0, 0.03), (1.0, 0.19), (0.96, 0.25), (0.9, 0.27), (0.86, 0.27),
                   (0.86, 0.3), (0, 0.3)], 56)
    a.lathe_closed(wood_hi, ring_profile(0.7, 0.9, 0.24, 0.285, 0.015), 56)
    a.lathe_closed(brass, ring_profile(0.72, 0.86, 0.28, 0.325, 0.02), 56)

    # engraved brass name plate on the front of the base (front = -Y)
    a.box(brass, (0.66, 0.05, 0.13), (0, -0.985, 0.13), bevel=0.012, seg=2)
    a.box(dark, (0.46, 0.012, 0.022), (0, -1.012, 0.155))
    a.box(dark, (0.34, 0.012, 0.022), (0, -1.012, 0.115))
    for sx in (-1, 1):
        a.disc(dark, 0.017, 0.0, 0.02, 0.0, 0.0, 6) if False else None
        a.box(dark, (0.03, 0.012, 0.03), (sx * 0.29, -1.012, 0.13))

    # brass dome: bell profile, highlight streaks, darker lower band
    z0, z1, R = 0.33, 1.38, 0.93
    steps = 26
    prof = [(0, z0)]
    for i in range(steps + 1):
        t = i / steps
        prof.append((max(R * (1 - t ** 2.15) ** 0.6, 0.0), z0 + (z1 - z0) * t))
    prof[-1] = (0.0, z1)

    def dome_mat(c):
        return brass_deep if c.z < 0.5 else brass
    a.lathe(brass, prof, 48, mat_fn=dome_mat)
    for zb_ in (0.66, 1.02):
        rb = R * (1 - ((zb_ - z0) / (z1 - z0)) ** 2.15) ** 0.6
        a.lathe_closed(bead, [(rb + 0.035 * math.cos(2 * PI * k / 8), zb_ + 0.035 * math.sin(2 * PI * k / 8))
                                  for k in range(8)], 48)
    a.lathe_closed(brass_deep, [(0.93, 0.36), (0.99, 0.37), (1.02, 0.42), (0.99, 0.47), (0.93, 0.47)], 48)  # rolled lip

    # plunger: chrome collar, stem, red button
    a.lathe(chrome, [(0, 1.32), (0.25, 1.32), (0.25, 1.4), (0.2, 1.45), (0, 1.45)], 32)
    a.lathe(red, [(0, 1.43), (0.2, 1.43), (0.2, 1.49), (0.16, 1.56), (0.09, 1.595), (0, 1.6)], 32)
    return [a.finish("ServiceBell")], (2, 1.6, 2)


BUILDERS = (("cutting_board", cutting_board), ("knife", knife), ("griddle", griddle), ("plate", plate),
            ("service_bell", service_bell), ("trash_drain", trash_drain))

if __name__ == "__main__" or True:
    only = artlib.script_args()
    for name, fn in BUILDERS:
        if only and name not in only:
            continue
        artlib.reset_scene()
        parts, size = fn()
        build_asset(name, parts, size)
