"""Dispenser models: supermarket packaging scaled up to building size (footprint <= 6 x 6, height 3..6).

Run: tools/blender-run.ps1 art/scripts/dispensers.py [-- name ...]   (no names = all seven)
Front (the side chefs approach) is Blender -Y.
"""
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import artlib  # noqa: E402
import foodparts as fp  # noqa: E402
import shapes  # noqa: E402
from dispenser_parts import (M, barcode, disc, finish, flat, leaf, loft, put, rbox, ring_tube,  # noqa: E402
                             soft_ball, sticker, superellipse, sweep, sausage, wavy_sheet, crinkle_fn)

LIMITS = ((0.5, 6.0), (3.0, 6.0), (0.5, 6.0))
PI = math.pi
D2R = math.radians


def film_mat(alpha=0.30):
    return M("Film", "#e8f5ff", 0.12, alpha=alpha)


# ---------------------------------------------------------------------------
# BUNS: crinkled kraft bakery bag, rolled-down top, window, buns piled and spilling out
# ---------------------------------------------------------------------------
def dispenser_buns():
    kraft = M("BagKraft", "#cf9d5c", 0.92)
    kraft_d = M("BagKraftDark", "#a87b40", 0.95)
    inside = M("BagInside", "#7d5a2d", 1.0)
    cream = M("BagCream", "#fff0c9", 0.8)
    red = M("BagRed", "#d9302a", 0.6)
    yellow = M("StickerYellow", "#ffd21f", 0.6)
    dark = M("InkDark", "#2b1d12", 0.9)
    film = film_mat(0.28)
    gold = fp.m("Bun")
    W, D, H = 5.0, 3.3, 3.3
    yf = -D / 2 - 0.03
    parts = []
    secs = [(0.0, W / 2 * 0.90, D / 2 * 0.88, 0, 0), (0.12, W / 2 * 0.97, D / 2 * 0.96, 0, 0),
            (0.6, W / 2 * 1.0, D / 2 * 1.0, 0, 0), (1.7, W / 2 * 1.02, D / 2 * 1.03, 0, 0),
            (2.7, W / 2 * 1.0, D / 2 * 1.0, 0, 0), (H, W / 2 * 0.98, D / 2 * 0.98, 0, 0)]
    parts.append(loft(kraft, secs, n=40, e=4.5, cap_start=True, wob=crinkle_fn(0.045, 1.2, 3)))
    parts.append(rbox(inside, (W - 0.7, D - 0.7, 0.1), (0, 0, H - 0.2), r=0.03, seg=1))
    # rolled-down rim: back and side bars, lower tilted front bar
    parts.append(rbox(kraft_d, (W + 0.1, 0.62, 0.62), (0, D / 2 - 0.1, H + 0.02), r=0.26, seg=3))
    for sx in (-1, 1):
        parts.append(rbox(kraft_d, (0.62, D, 0.62), (sx * (W / 2 - 0.05), 0, H + 0.0), r=0.26, seg=3))
    parts.append(rbox(kraft_d, (W + 0.1, 0.62, 0.6), (0, -D / 2 + 0.05, H - 0.12), rot=(D2R(-14), 0, 0), r=0.25, seg=3))
    parts.append(rbox(red, (1.5, 0.7, 0.68), (0.35, D / 2 - 0.1, H + 0.02), r=0.05, seg=1))  # tape on the roll
    # front print
    parts.append(rbox(red, (W - 0.2, 0.07, 0.42), (0, yf + 0.01, 2.62), r=0.03, seg=1))
    parts.append(rbox(kraft_d, (2.55, 0.1, 1.7), (-1.05, yf, 1.38), r=0.06, seg=2))
    parts.append(rbox(cream, (2.25, 0.08, 1.4), (-1.05, yf - 0.03, 1.38), r=0.05, seg=1))
    for x, z, sc in ((-1.75, 1.3, 1.0), (-1.0, 1.45, 1.1), (-0.3, 1.3, 0.95)):
        parts.append(soft_ball(gold, (0.5 * sc, 0.2, 0.42 * sc), (x, yf - 0.1, z - 0.15), seg=12, rings=8))
    parts.append(rbox(film, (2.25, 0.05, 1.4), (-1.05, yf - 0.4, 1.38), r=0.03, seg=1))
    parts.append(disc(cream, 0.72, 0.06, (1.55, yf - 0.02, 1.55)))
    parts.append(disc(red, 0.55, 0.06, (1.55, yf - 0.05, 1.55)))
    parts.append(soft_ball(gold, (0.36, 0.14, 0.26), (1.55, yf - 0.1, 1.45), seg=12, rings=8))
    parts.append(soft_ball(M("Sesame", "#fff6d8", 0.6), (0.05, 0.03, 0.03), (1.55, yf - 0.22, 1.58), seg=5, rings=3))
    parts += sticker(yellow, red, (2.0, yf - 0.03, 0.62), 0.3)
    parts += barcode(dark, cream, (0.85, yf - 0.02, 0.62), w=1.0, h=0.5, seed=3)

    # bun pile in the open mouth
    def bun_at(kind, o, rot=(0, 0, 0), s=0.8):
        objs = fp.bun_top(o, s) if kind == "top" else fp.bun_bottom(o, s)
        put(objs, rot=rot, pivot=o)
        return objs
    parts += bun_at("top", (-1.15, 0.3, H - 0.15), (0, D2R(-6), D2R(15)))
    parts += bun_at("top", (1.2, 0.35, H - 0.15), (0, D2R(7), D2R(-20)))
    parts += bun_at("bottom", (0.05, 0.65, H + 0.45), (D2R(32), 0, D2R(10)))
    parts += bun_at("top", (0.0, -0.3, H + 0.62), (D2R(-10), 0, D2R(35)))
    parts += bun_at("top", (0.1, 0.45, H + 1.3), (D2R(6), D2R(4), D2R(-15)))
    # spilled onto the counter
    parts += bun_at("top", (1.3, -2.5, 0.02), (D2R(-8), D2R(6), D2R(-25)))
    parts += bun_at("bottom", (-1.5, -2.55, 0.02), (0, D2R(-5), D2R(20)))
    return parts


# ---------------------------------------------------------------------------
# PATTIES: foam butcher's tray, stacks of raw patties separated by paper, torn-back film, label
# ---------------------------------------------------------------------------
def dispenser_patties():
    foam = M("TrayFoam", "#f4f1e8", 0.85)
    foam_in = M("TrayFoamIn", "#e6e0d0", 0.9)
    pad = M("AbsorbentPad", "#f1d9d6", 1.0)
    paper = M("ButcherPaper", "#fbf8f0", 0.95)
    paper2 = M("ButcherPaperB", "#efe6d2", 0.95)
    red = M("LabelRed", "#d9302a", 0.6)
    white = M("LabelWhite", "#ffffff", 0.7)
    yellow = M("StickerYellow", "#ffd21f", 0.6)
    dark = M("InkDark", "#2b1d12", 0.9)
    film = film_mat(0.30)
    W, D, TH = 5.85, 5.5, 0.95
    parts = []
    outer = [(0.0, W / 2 * 0.90, D / 2 * 0.90, 0, 0), (0.18, W / 2 * 0.98, D / 2 * 0.98, 0, 0),
             (TH, W / 2, D / 2, 0, 0)]
    inner = [(0.22, W / 2 * 0.86, D / 2 * 0.86, 0, 0), (TH, W / 2 * 0.93, D / 2 * 0.93, 0, 0)]
    parts.append(loft(foam, outer, n=40, e=5, cap_start=True))
    parts.append(loft(foam_in, inner, n=40, e=5, cap_start=True))
    parts.append(ring_tube(foam, (W / 2 * 0.965, D / 2 * 0.965, 0, 0), 0.15, TH, n=48, e=5, verts=6))
    parts.append(rbox(pad, (W - 0.9, D - 0.9, 0.1), (0, 0, 0.27), r=0.04, seg=1))
    rng = random.Random(11)
    stacks = [((-1.4, -1.3), 5), ((1.4, -1.3), 7), ((0.0, 1.3), 9)]
    sc = 0.9
    tops = []
    for (cx, cy), n in stacks:
        z = 0.32
        for i in range(n):
            jx, jy = rng.uniform(-0.06, 0.06), rng.uniform(-0.06, 0.06)
            parts += fp.patty_raw((cx + jx, cy + jy, z), sc, seed=i + int(cx * 3), lumps=(i == n - 1))
            z += 0.56 * sc
            if i < n - 1:
                p = shapes.prism(paper if i % 2 else paper2, superellipse(20, 1.42, 1.42, 4.5), 0.0, 0.03)
                p.location = (cx + jx, cy + jy, z)
                p.rotation_euler = (0, 0, D2R(rng.uniform(-14, 14)))
                parts.append(p)
                z += 0.03
        tops.append((cx, cy, z))
    # torn-back film lying on the front-left stack, corner peeled up
    cx, cy, z = tops[0]
    fr = random.Random(2)
    pts = []
    for k in range(18):
        t = 2 * PI * k / 18
        c, sn = math.cos(t), math.sin(t)
        rr = 1.45 * (1.0 + fr.uniform(-0.09, 0.09)) / max(abs(c), abs(sn)) ** 0.25
        pts.append((rr * c * 0.98, rr * sn * 0.98))
    pts[3] = (pts[3][0] * 0.7, pts[3][1] * 0.7)  # torn notch
    pts[4] = (pts[4][0] * 0.72, pts[4][1] * 0.72)
    fl = shapes.prism(film, pts, 0.0, 0.03)
    fl.location = (cx, cy, z + 0.06)
    fl.rotation_euler = (0, 0, D2R(10))
    parts.append(fl)
    peel = shapes.prism(film, [(0, 0), (1.2, 0.05), (1.35, 0.9), (0.5, 1.25), (-0.1, 0.8)], 0.0, 0.03)
    put(peel, move=(cx + 0.7, cy - 1.25, z + 0.07), rot=(D2R(-32), 0, D2R(20)), pivot=(0, 0, 0))
    parts.append(peel)
    # label sticker on the tray front
    yf = -D / 2 * 0.985 - 0.02
    parts.append(rbox(white, (2.6, 0.06, 0.62), (-1.45, yf, 0.5), r=0.02, seg=1))
    parts.append(rbox(red, (2.6, 0.07, 0.16), (-1.45, yf - 0.005, 0.72), r=0.01, seg=1))
    parts += barcode(dark, white, (-0.75, yf - 0.02, 0.44), w=1.0, h=0.32, seed=5)
    parts += sticker(yellow, red, (1.6, yf - 0.03, 0.5), 0.3)
    parts += sticker(red, white, (2.25, yf - 0.03, 0.5), 0.2)
    return parts


# ---------------------------------------------------------------------------
# CHEESE: open resealable pack, fanned slice stack, one slice peeling, zip strip, wedge logo
# ---------------------------------------------------------------------------
def dispenser_cheese():
    white = M("PackWhite", "#f6f8fa", 0.6)
    red = M("PackRed", "#d9302a", 0.55)
    blue = M("ZipBlue", "#2f7fe0", 0.5)
    blue_l = M("ZipBlueLight", "#8cc2ff", 0.5)
    ch_a = M("Cheese", "#ffcf1c", 0.42)
    ch_b = M("CheeseB", "#ffe04a", 0.42)
    ch_c = M("CheeseC", "#f5b800", 0.45)
    hole = M("CheeseHole", "#d99a00", 0.6)
    film = film_mat(0.26)
    W, D = 4.5, 4.4
    parts = []
    wall_h = 2.5
    secs = [(0.0, W / 2 * 0.92, D / 2 * 0.92, 0, 0), (0.15, W / 2 * 0.99, D / 2 * 0.99, 0, 0),
            (1.2, W / 2 * 1.02, D / 2 * 1.02, 0, 0), (wall_h, W / 2, D / 2, 0, 0)]
    parts.append(loft(film, secs, n=40, e=4, cap_start=False))
    parts.append(rbox(white, (W * 0.9, D * 0.9, 0.16), (0, 0, 0.1), r=0.06, seg=2))
    parts.append(ring_tube(blue, (W / 2, D / 2, 0, 0), 0.13, wall_h, n=48, e=4, verts=6))
    parts.append(rbox(blue_l, (1.0, 0.35, 0.22), (1.3, -D / 2 - 0.1, wall_h + 0.05), r=0.06, seg=2))  # zip tab
    # printed panel on lower front
    yf = -D / 2 - 0.01
    parts.append(rbox(white, (W - 0.5, 0.09, 1.55), (0, yf, 0.98), r=0.05, seg=2))
    parts.append(rbox(red, (W - 0.5, 0.1, 0.42), (0, yf - 0.005, 1.32), r=0.03, seg=1))
    wedge = shapes.prism(ch_a, [(-1.0, -0.5), (1.0, -0.5), (1.0, 0.4), (-1.0, -0.05)], 0.0, 0.1)
    put(wedge, move=(-0.55, yf - 0.03, 0.85), rot=(PI / 2, 0, 0))
    parts.append(wedge)
    for hx, hz, hr in ((-0.4, 0.62, 0.13), (0.15, 0.75, 0.1), (0.55, 0.65, 0.17)):
        parts.append(disc(hole, hr, 0.05, (hx - 0.55, yf - 0.1, hz + 0.28), verts=12))
    # back flap standing up behind the stack (printed side)
    flap = rbox(white, (W - 0.3, 0.14, 3.0), (0, D / 2 - 0.05, wall_h + 1.35), r=0.05, seg=2)
    put(flap, rot=(D2R(-14), 0, 0), pivot=(0, D / 2, wall_h))
    parts.append(flap)
    band = rbox(red, (W - 0.3, 0.16, 0.5), (0, D / 2 - 0.05, wall_h + 2.6), r=0.03, seg=1)
    put(band, rot=(D2R(-14), 0, 0), pivot=(0, D / 2, wall_h))
    parts.append(band)
    w2 = shapes.prism(ch_a, [(-1.0, -0.55), (1.0, -0.55), (1.0, 0.45), (-1.0, -0.05)], 0.0, 0.12)
    put(w2, move=(0, 0, 0), rot=(PI / 2, 0, 0))
    put(w2, move=(0, D / 2 - 0.2, wall_h + 1.85), rot=(D2R(-14), 0, 0), pivot=(0, D / 2, wall_h))
    parts.append(w2)
    for hx, hz, hr in ((-0.5, 0.55, 0.15), (0.2, 0.7, 0.11), (0.6, 0.45, 0.2)):
        d = disc(hole, hr, 0.05, (hx, 0, hz), verts=12)
        put(d, move=(0, D / 2 - 0.3, wall_h + 1.85), rot=(D2R(-14), 0, 0), pivot=(0, D / 2, wall_h))
        parts.append(d)
    # slices
    rng = random.Random(5)
    n = 22
    z = 0.2
    T = 0.16
    for i in range(n):
        mat = (ch_a, ch_b, ch_c)[i % 3]
        ang = rng.uniform(-3, 3)
        fan = 0
        if i >= 13:
            fan = (i - 13) * 4.2
        o = rbox(mat, (3.05, 3.05, T), (rng.uniform(-0.06, 0.06), rng.uniform(-0.06, 0.06), z + T / 2),
                 (0, 0, D2R(ang)), r=0.03, seg=1)
        if fan:
            put(o, rot=(0, 0, D2R(fan)), pivot=(1.4, 1.4, 0))
        parts.append(o)
        z += T

    def lift(x, y):
        t = max(0.0, (-y + 0.2) / 1.7)
        return 1.6 * t ** 2.0 - 0.05 * (x / 1.5) ** 2

    peel = wavy_sheet(ch_b, 3.0, 3.0, 0.06, 8, lift, (0, 0, z + 0.04), (0, 0, D2R(-12)))
    parts.append(peel)
    return parts


# ---------------------------------------------------------------------------
# LETTUCE: big ruffled head in a blue produce crate, loose leaves draped in front
# ---------------------------------------------------------------------------
def dispenser_lettuce():
    crate = M("CrateBlue", "#3d84d6", 0.55)
    crate_d = M("CrateBlueDark", "#245aa0", 0.6)
    slot = M("CrateSlot", "#15335c", 0.9)
    parts = []
    W, D, H = 5.6, 4.2, 1.3
    parts.append(rbox(crate, (W - 0.3, D - 0.3, 0.2), (0, 0, 0.1), r=0.06, seg=2))
    for sy in (-1, 1):
        parts.append(rbox(crate, (W, 0.26, H), (0, sy * (D / 2 - 0.13), H / 2), r=0.1, seg=2))
    for sx in (-1, 1):
        parts.append(rbox(crate, (0.26, D, H), (sx * (W / 2 - 0.13), 0, H / 2), r=0.1, seg=2))
    parts.append(rbox(crate_d, (W + 0.16, 0.34, 0.24), (0, -D / 2 - 0.02, H - 0.04), r=0.1, seg=2))  # front lip
    parts.append(rbox(crate_d, (W + 0.16, 0.34, 0.24), (0, D / 2 + 0.02, H - 0.04), r=0.1, seg=2))
    for i in range(6):  # vent slots
        x = -2.25 + i * 0.9
        parts.append(rbox(slot, (0.5, 0.05, 0.5), (x, -D / 2 - 0.005, 0.55), r=0.02, seg=1))
        parts.append(rbox(slot, (0.5, 0.05, 0.5), (x, D / 2 + 0.005, 0.55), r=0.02, seg=1))
    for sx in (-1, 1):
        parts.append(rbox(slot, (0.05, 1.4, 0.4), (sx * (W / 2 + 0.005), 0, 0.72), r=0.02, seg=1))
    # head: loose, frilly leaf-lettuce rosette with pale wide ribs and open ruffled tips
    greens = [(M("LettuceDark", "#4fae35", 0.65), M("LettuceRibD", "#e6f7b4", 0.65)),
              (M("LettuceMid", "#6ccb45", 0.65), M("LettuceRibM", "#eefac4", 0.65)),
              (M("LettuceIn", "#93de60", 0.65), M("LettuceRibI", "#f3fcd2", 0.65)),
              (M("LettuceCore", "#bdee80", 0.65), M("LettuceRibC", "#f8fde0", 0.65))]
    pale = M("LettucePale", "#eef8c0", 0.65)
    rng = random.Random(9)
    rings_def = [  # count, length, width, alpha, base radius, base z, cup, ruffle, curl, freq
        (7, 2.6, 2.2, 32, 0.55, 1.1, 0.30, 0.26, 0.10, 4.2),
        (6, 2.6, 2.1, 46, 0.5, 1.5, 0.35, 0.28, 0.12, 4.6),
        (5, 2.4, 1.9, 60, 0.4, 1.95, 0.40, 0.26, 0.18, 5.0),
        (4, 2.0, 1.6, 72, 0.3, 2.4, 0.45, 0.22, 0.25, 5.4),
        (3, 1.4, 1.2, 82, 0.15, 2.8, 0.45, 0.15, 0.35, 5.4)]
    parts.append(soft_ball(M("LettuceHeart", "#d3f294", 0.65), (0.55, 0.55, 0.8), (0, -0.25, 3.1), seg=10, rings=6, lump=0.15))
    for ri, (cnt, ln, wd, alpha, r0, z0, cup, ruf, curl, fq) in enumerate(rings_def):
        gi = min(ri, 3)
        for i in range(cnt):
            a = 2 * PI * i / cnt + ri * 0.7 + rng.uniform(-0.12, 0.12)
            lf = leaf([greens[gi][0], pale, greens[gi][1]], ln * rng.uniform(0.92, 1.08), wd * rng.uniform(0.9, 1.05),
                      cup=cup, ruffle=ruf, seed=i + ri * 9, rib=True, nu=16, nv=12, curl=curl, freq=fq, rib_w=0.2,
                      base_pale=0.18)
            put(lf, rot=(0, -D2R(alpha + rng.uniform(-5, 5)), 0))
            put(lf, move=(r0 * math.cos(a), r0 * math.sin(a) - 0.25, z0), rot=(0, 0, a))
            parts.append(lf)
    # loose leaves draped over the front lip
    for x, ang, ln in ((1.5, -68, 1.9), (-1.5, -112, 1.8)):
        lf = leaf([greens[2][0], pale, greens[2][1]], ln, 2.3, cup=0.2, ruffle=0.3, seed=x, rib=True, nu=16, nv=12,
                  base_pale=0.12, freq=5.0, rib_w=0.2)
        put(lf, rot=(0, D2R(12), 0))
        put(lf, move=(x, -D / 2 + 0.7, H + 0.05), rot=(0, 0, D2R(ang)))
        parts.append(lf)
    return parts


# ---------------------------------------------------------------------------
# TOMATOES: slatted wooden crate, nails, wood-wool, heaped tomatoes on the vine
# ---------------------------------------------------------------------------
def tomato_obj(mat, o, r, seed):
    rng = random.Random(seed)
    sq = rng.uniform(0.86, 0.94)
    t = soft_ball(mat, (r, r, r * sq), (o[0], o[1], o[2] + r * sq), seg=14, rings=8, lump=0.05, seed=seed)
    return t


def dispenser_tomatoes():
    wood_a = M("CrateWoodA", "#c28c4a", 0.9)
    wood_b = M("CrateWoodB", "#a87838", 0.9)
    wood_c = M("CrateWoodC", "#8e6230", 0.9)
    metal = M("Nail", "#8c8f96", 0.4, 0.7)
    red_paint = M("CratePaint", "#d9302a", 0.6)
    white = M("PaintWhite", "#fff3d6", 0.7)
    tom = fp.m("Tomato")
    tom_d = fp.m("TomatoDark")
    stem = fp.m("Stem")
    stem_d = M("VineDark", "#2a7a26", 0.7)
    wool = M("WoodWool", "#f0d9a0", 0.95)
    wool2 = M("WoodWool2", "#e0c07c", 0.95)
    W, D, H = 5.4, 3.9, 1.75
    parts = []
    rng = random.Random(21)
    parts.append(rbox(wood_c, (W - 0.3, D - 0.3, 0.16), (0, 0, 0.08), r=0.04, seg=1))
    heights = [(0.16, 0.44), (0.72, 0.44), (1.28, 0.44)]
    for k, (z0, sl) in enumerate(heights):
        for sy in (-1, 1):
            parts.append(rbox((wood_a, wood_b, wood_a)[k], (W, 0.15, sl), (0, sy * (D / 2 - 0.075), z0 + sl / 2), r=0.05, seg=2))
        for sx in (-1, 1):
            parts.append(rbox((wood_b, wood_a, wood_b)[k], (0.15, D - 0.3, sl), (sx * (W / 2 - 0.075), 0, z0 + sl / 2), r=0.05, seg=2))
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(rbox(wood_c, (0.36, 0.36, H), (sx * (W / 2 - 0.2), sy * (D / 2 - 0.2), H / 2), r=0.07, seg=2))
            for z in (0.4, 0.95, 1.5):  # nails
                parts.append(disc(metal, 0.06, 0.05, (sx * (W / 2 - 0.2), -D / 2 - 0.09 if sy < 0 else D / 2 + 0.09, z), verts=8))
    # painted band and stickers on the front slat
    yf = -D / 2 - 0.075 - 0.02
    parts.append(rbox(red_paint, (2.4, 0.04, 0.4), (-1.0, yf, 0.94), r=0.01, seg=1))
    parts.append(disc(white, 0.18, 0.05, (-1.6, yf - 0.02, 0.94), verts=12))
    parts.append(soft_ball(stem, (0.2, 0.04, 0.12), (-1.0, yf - 0.05, 0.94), seg=8, rings=5))
    parts += sticker(M("StickerYellow", "#ffd21f", 0.6), red_paint, (1.3, yf - 0.02, 1.5), 0.26)
    # wood wool filler
    for i in range(40):
        x, y = rng.uniform(-W / 2 + 0.4, W / 2 - 0.4), rng.uniform(-D / 2 + 0.3, D / 2 - 0.3)
        z = rng.uniform(1.0, 1.85)
        parts.append(shapes.box(wool if i % 2 else wool2, (rng.uniform(0.7, 1.4), 0.05, 0.06), (x, y, z),
                                (rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6), rng.uniform(0, PI))))
    # tomatoes
    R = 0.95
    tomatoes = []
    for x in (-1.75, 0.0, 1.75):
        for y in (-0.92, 0.92):
            tomatoes.append((x, y, 0.16))
    for x, y in ((-0.95, -0.5), (0.95, -0.5), (-0.95, 0.65), (0.95, 0.65)):
        tomatoes.append((x, y, 1.15))
    for x, y in ((0.0, 0.1), (-1.0, 0.0)):
        tomatoes.append((x, y, 2.15))
    tomatoes.append((0.9, -0.2, 2.3))
    tomatoes += [(1.3, -2.75, 0.0), (-1.2, -2.85, 0.0)]
    for i, o in enumerate(tomatoes):
        r = R * rng.uniform(0.94, 1.04)
        parts.append(tomato_obj(tom if i % 4 else tom_d, o, r, i))
        # calyx: five little spiky sepals and a stalk
        top = o[2] + 2 * r * 0.9
        for k in range(5):
            a = 2 * PI * k / 5 + rng.uniform(0, 1)
            parts.append(shapes.box(stem, (0.5, 0.15, 0.05), (o[0] + 0.24 * math.cos(a), o[1] + 0.24 * math.sin(a), top - 0.04),
                                    (0, D2R(18), a)))
        parts.append(soft_ball(stem, (0.13, 0.13, 0.1), (o[0], o[1], top + 0.02), seg=8, rings=5))
        parts.append(sweep(stem, [(o[0], o[1], top), (o[0] + 0.05, o[1], top + 0.2), (o[0] + 0.16, o[1] + 0.03, top + 0.34)],
                           [0.07, 0.06, 0.05], verts=6))
    # vine truss draping over the front rim with leaves
    path = [(0.9, -0.2, 4.2), (1.3, -1.0, 4.5), (1.7, -1.8, 4.2), (2.0, -2.3, 3.4), (2.1, -2.6, 2.2), (2.0, -2.7, 1.0)]
    parts.append(sweep(stem_d, path, [0.09, 0.09, 0.08, 0.07, 0.06, 0.05], verts=6))
    for (px, py, pz), ang in (((1.7, -1.8, 4.2), 0.6), ((2.0, -2.3, 3.4), -0.5)):
        lf = soft_ball(stem_d, (0.75, 0.42, 0.06), (px + 0.5, py, pz), (0, D2R(-25), ang), seg=8, rings=5)
        parts.append(lf)
    return parts


# ---------------------------------------------------------------------------
# SAUSAGES: foam tray, layers of raw sausages, linked pair over the front lip, film peeled back, header card
# ---------------------------------------------------------------------------
def dispenser_sausages():
    foam = M("TrayBlue", "#fafcff", 0.8)
    foam_in = M("TrayBlueIn", "#d9e7f5", 0.9)
    pad = M("AbsorbentPad", "#f1d9d6", 1.0)
    pink_a = M("SausageRaw", "#f2a6a3", 0.5)
    pink_b = M("SausageRawB", "#eb8f8f", 0.5)
    pink_c = M("SausageRawC", "#f7bcb5", 0.5)
    card = M("HeaderCard", "#2a62c9", 0.7)
    card_l = M("HeaderCardLight", "#fff7e2", 0.7)
    red = M("LabelRed", "#d9302a", 0.6)
    yellow = M("StickerYellow", "#ffd21f", 0.6)
    dark = M("InkDark", "#2b1d12", 0.9)
    twist = M("LinkTwist", "#e8b6b0", 0.6)
    W, D, TH = 5.9, 5.0, 0.75
    parts = []
    outer = [(0.0, W / 2 * 0.90, D / 2 * 0.90, 0, 0), (0.18, W / 2 * 0.98, D / 2 * 0.98, 0, 0), (TH, W / 2, D / 2, 0, 0)]
    inner = [(0.22, W / 2 * 0.86, D / 2 * 0.86, 0, 0), (TH, W / 2 * 0.93, D / 2 * 0.93, 0, 0)]
    parts.append(loft(foam, outer, n=40, e=5, cap_start=True))
    parts.append(loft(foam_in, inner, n=40, e=5, cap_start=True))
    parts.append(ring_tube(foam, (W / 2 * 0.965, D / 2 * 0.965, 0, 0), 0.14, TH, n=48, e=5, verts=6))
    parts.append(rbox(pad, (W - 0.9, D - 0.9, 0.1), (0, 0, 0.27), r=0.04, seg=1))
    r = 0.44
    L = 4.7
    rng = random.Random(3)
    layers = [(5, 0.32 + r), (4, 0.32 + r + 0.76), (3, 0.32 + r + 1.52)]
    for li, (cnt, z) in enumerate(layers):
        for i in range(cnt):
            y = (i - (cnt - 1) / 2) * 2 * r * 1.0
            mat = (pink_a, pink_b, pink_c)[(i + li) % 3]
            parts.append(sausage(mat, (-L / 2 + rng.uniform(-0.1, 0.1), y, z), (L / 2 + rng.uniform(-0.1, 0.1), y + rng.uniform(-0.05, 0.05), z),
                                 r, bend=rng.uniform(-0.12, 0.12)))
    # linked pair draped from the top layer over the front lip
    a = (1.2, -0.3, 2.45)
    b = (1.05, -1.9, 1.55)
    c = (0.95, -3.3, 0.5)
    parts.append(sausage(pink_a, a, b, r, bend=0.0))
    parts.append(sausage(pink_c, b, c, r, bend=0.0))
    parts.append(sweep(twist, [(1.05, -1.85, 1.6), (1.05, -2.0, 1.5)], [0.14, 0.1], verts=8))
    # header card standing behind, tilted back, printed with a big sausage icon
    cw, ch = 5.7, 3.9
    board = rbox(card, (cw, 0.2, ch), (0, D / 2 - 0.5, TH + ch / 2 - 0.1), r=0.1, seg=2)
    put(board, rot=(D2R(-5), 0, 0), pivot=(0, D / 2 - 0.5, TH))
    parts.append(board)
    fy = D / 2 - 0.5 - 0.13
    deco = [rbox(card_l, (cw - 0.6, 0.06, 1.7), (0, fy, TH + 2.15), r=0.05, seg=2),
            sausage(pink_a, (-1.9, fy - 0.15, TH + 2.3), (1.3, fy - 0.15, TH + 2.3), 0.5, bend=0.1),
            sausage(pink_b, (-1.6, fy - 0.15, TH + 1.75), (1.6, fy - 0.15, TH + 1.75), 0.42, bend=-0.1),
            rbox(red, (cw - 0.6, 0.07, 0.4), (0, fy - 0.01, TH + 3.35), r=0.03, seg=1),
            rbox(red, (cw - 0.6, 0.07, 0.3), (0, fy - 0.01, TH + 0.5), r=0.03, seg=1)]
    deco += sticker(red, yellow, (2.05, fy - 0.03, TH + 2.9), 0.42)
    put(deco, rot=(D2R(-5), 0, 0), pivot=(0, D / 2 - 0.5, TH))
    parts += deco
    return parts


# ---------------------------------------------------------------------------
# HOT DOG BUNS: clear bag with bread clip, buns in rows, front open, one bun sliding out
# ---------------------------------------------------------------------------
def dispenser_hotdog_buns():
    film = M("BagFilm", "#dcefff", 0.1, alpha=0.3)
    rim = M("BagRimFilm", "#f4faff", 0.3, alpha=0.55)
    blue = M("ClipBlue", "#2f6fd6", 0.5)
    red = M("BagRed", "#d9302a", 0.6)
    cream = M("BagCream", "#fff0c9", 0.8)
    yellow = M("StickerYellow", "#ffd21f", 0.6)
    dark = M("InkDark", "#2b1d12", 0.9)
    parts = []
    # bag lofted along local Z (back -> front), then turned so local Z runs to world -Y
    L = 1.9
    hw, hh = 2.75, 1.75
    cuff = M("BagCuff", "#f6f1e2", 0.7)
    tsecs = [(0.0, 0.3, 0.3, 0.0, 2.3), (0.4, 0.55, 0.55, 0.0, 2.15), (0.9, 1.6, 1.3, 0.0, 1.9),
             (1.4, 2.6, 1.65, 0.0, hh), (L, hw, hh, 0.0, hh)]
    bag = loft(film, tsecs, n=40, e=2.8, cap_start=True, wob=crinkle_fn(0.02, 1.0, 5))
    # open mouth: the bag is rolled down into a thick opaque cuff
    rimo = ring_tube(cuff, (hw, hh, 0, hh), 0.2, L, n=48, e=2.8, verts=8)
    rim2 = ring_tube(cuff, (hw * 0.97, hh * 0.97, 0, hh), 0.17, L - 0.3, n=48, e=2.8, verts=8)
    # neck twist + bread clip at the back
    neck = sweep(film, [(0, 2.3, 0.0), (0, 2.3, -0.25)], [0.3, 0.2], verts=10)
    clip = rbox(blue, (1.15, 0.5, 0.16), (0, 2.3, -0.08), r=0.06, seg=2)
    clip_slot = rbox(M("ClipSlot", "#173a80", 0.6), (0.5, 0.2, 0.18), (0, 2.3, -0.1), r=0.03, seg=1)
    clip_t1 = rbox(blue, (0.2, 0.5, 0.4), (0.45, 2.3, -0.32), r=0.04, seg=1)
    seams = [ring_tube(rim, (2.62, 1.66, 0, 1.66), 0.06, 1.4, n=48, e=2.8, verts=6)]
    grp = [bag, rimo, rim2, neck, clip, clip_slot, clip_t1] + seams
    # world placement: local z -> -y ; local y -> +z
    put(grp, rot=(PI / 2, 0, 0))
    parts += grp
    # printed stripe and logo on top of the bag
    parts.append(rbox(blue, (4.6, 1.0, 0.06), (0, -1.0, 3.5), r=0.02, seg=1))
    parts.append(disc(red, 0.5, 0.07, (-1.6, -1.0, 3.5), facing="up"))
    parts.append(soft_ball(fp.m("Bun"), (0.3, 0.15, 0.2), (-1.6, -1.0, 3.53), seg=10, rings=6))
    parts += [rbox(cream, (1.6, 0.6, 0.07), (0.6, -1.0, 3.51), r=0.02, seg=1)]
    # buns: layer 1 (3 rows), layer 2 (2 rows), one sliding out of the front
    s = 0.86
    for t in (1.95, 3.3):
        parts += fp.hotdog_bun((0, -t, 0.1), s)
    for t in (2.6, 3.95):
        parts += fp.hotdog_bun((0.1, -t, 0.85), s)
    out = fp.hotdog_bun((0.4, -4.45, 0.02), s)
    put(out, rot=(0, 0, D2R(5)), pivot=(0.4, -4.45, 0.0))
    parts += out
    return parts


SMOOTH = {"dispenser_lettuce": 80, "dispenser_tomatoes": 60}
BUILDERS = {"dispenser_buns": dispenser_buns, "dispenser_patties": dispenser_patties,
            "dispenser_cheese": dispenser_cheese, "dispenser_lettuce": dispenser_lettuce,
            "dispenser_tomatoes": dispenser_tomatoes, "dispenser_sausages": dispenser_sausages,
            "dispenser_hotdog_buns": dispenser_hotdog_buns}

if __name__ == "__main__" or True:
    wanted = [a for a in artlib.script_args()] or list(BUILDERS)
    for name in wanted:
        artlib.reset_scene()
        finish(name, BUILDERS[name](), LIMITS, smooth_deg=SMOOTH.get(name, 48))
