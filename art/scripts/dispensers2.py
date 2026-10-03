"""Dispenser models, batch 2: bacon, eggs, onions, pickles, potatoes, chicken (supermarket packaging, giant).

Run: tools/blender-run.ps1 art/scripts/dispensers2.py [-- name ...]   (no names = all six)
Footprint about 5 x 5 (limit 6 x 6), height 3..6. Front (the side chefs approach) is Blender -Y.
"""
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import artlib  # noqa: E402
import shapes  # noqa: E402
from dispenser_parts import (M, barcode, disc, finish, loft, put, rbox, ring_tube, soft_ball,  # noqa: E402
                             sticker, superellipse, sweep, crinkle_fn)
from dispenser2_parts import bacon_strip, bars, egg, fillet, fork, onion, pickle, potato  # noqa: E402

LIMITS = ((0.5, 6.0), (3.0, 6.0), (0.5, 6.0))
PI = math.pi
D2R = math.radians


def film_mat(alpha=0.28, name="Film"):
    return M(name, "#e8f5ff", 0.12, alpha=alpha)


# ---------------------------------------------------------------------------
# BACON: vacuum pack, film peeled, strips fanned out, big header card
# ---------------------------------------------------------------------------
def dispenser_bacon():
    sleeve = M("BaconSleeve", "#3d1714", 0.6)
    card = M("BaconCard", "#b3261e", 0.6)
    card_l = M("BaconCardCream", "#fff1d6", 0.7)
    pad = M("BaconPad", "#f3e6d0", 0.9)
    lean = M("BaconLean", "#e5545c", 0.5)
    fat = M("BaconFat", "#fff5ec", 0.5)
    yellow = M("StickerYellow", "#ffd21f", 0.6)
    red = M("LabelRed", "#d9302a", 0.6)
    dark = M("InkDark", "#2b1d12", 0.9)
    film = film_mat(0.30)
    parts = []
    cy = -0.3
    # sleeve/tray with a pad and a base layer of bacon
    parts.append(rbox(sleeve, (4.7, 3.6, 0.7), (0, cy, 0.35), r=0.14, seg=3))
    parts.append(rbox(pad, (4.3, 3.2, 0.06), (0, cy, 0.72), r=0.03, seg=1))
    band = [0, 0, 1, 0, 0, 1, 0, 0]
    for k in range(3):  # base layer of wide rashers
        sb = bacon_strip([lean, fat], L=4.2, w=1.1, seed=k * 1.3, amp=0.06, nu=16, nv=8, th=0.1, band=band)
        put(sb, move=(-2.1, cy - 1.1 + k * 1.1, 0.74 + (k % 2) * 0.02))
        parts.append(sb)
    # front label on the sleeve
    parts.append(rbox(card_l, (2.7, 0.06, 0.46), (-0.7, cy - 1.83, 0.36), r=0.03, seg=1))
    parts.append(rbox(red, (2.7, 0.07, 0.12), (-0.7, cy - 1.84, 0.56), r=0.02, seg=1))
    parts += bars(dark, -1.95, cy - 1.86, 0.32, (0.7, 0.45, 0.6, 0.35), h=0.1, gap=0.1)
    parts += sticker(yellow, red, (1.45, cy - 1.84, 0.36), 0.25)
    parts += barcode(dark, card_l, (2.0, cy - 1.84, 0.36), w=0.6, h=0.3, seed=2)
    # film peeled open and rolled back behind the strips
    f3 = rbox(film, (4.5, 0.9, 0.04), (0, cy + 1.2, 1.5), rot=(D2R(-40), 0, 0), r=0.02, seg=1)
    parts.append(f3)
    # big rashers fanned out of the open pack, leaning towards the camera
    pivot = (0.0, cy + 0.9, 0.95)
    spread = [-44, -27, -9, 9, 27, 44]
    pitch = [14, 20, 26, 26, 20, 14]
    for k, (sp, pt) in enumerate(zip(spread, pitch)):
        sb = bacon_strip([lean, fat], L=3.6, w=1.1, seed=k * 2.1, amp=0.12, curl=-0.03, nu=20, nv=8, th=0.11, band=band)
        put(sb, rot=(0, -D2R(pt), D2R(-90 + sp)))
        put(sb, move=(pivot[0], pivot[1], pivot[2] + 0.1 + k * 0.05))
        parts.append(sb)
    # header card behind, with a bacon picture
    tilt = D2R(-7)
    cyc, ch = 1.95, 3.4
    deco = [rbox(card, (4.7, 0.18, ch), (0, cyc, 0.2 + ch / 2), r=0.1, seg=2),
            rbox(card_l, (4.1, 0.06, 2.1), (0, cyc - 0.11, 1.95), r=0.06, seg=2),
            rbox(red, (4.1, 0.07, 0.55), (0, cyc - 0.12, 0.72), r=0.04, seg=2)]
    deco += bars(card_l, -1.6, cyc - 0.16, 0.72, (0.5, 0.3, 0.55, 0.3, 0.6), h=0.26, gap=0.14)
    for k, zz in enumerate((2.45, 1.95, 1.45)):
        s = bacon_strip([lean, fat], L=3.3, w=0.42, seed=k * 1.7, amp=0.08, nu=16)
        put(s, rot=(PI / 2, 0, 0))
        put(s, move=(-1.65 + (k % 2) * 0.1, cyc - 0.18, zz))
        deco.append(s)
    deco += sticker(yellow, red, (1.85, cyc - 0.15, 3.15), 0.42)
    put(deco, rot=(tilt, 0, 0), pivot=(0, cyc, 0.2))
    parts += deco
    return parts


# ---------------------------------------------------------------------------
# EGGS: open pulp carton, eggs in cups, lid standing open with a fried-egg print
# ---------------------------------------------------------------------------
def dispenser_eggs():
    pulp = M("CartonPulp", "#b9b095", 0.95)
    pulp_d = M("CartonPulpDark", "#9a917a", 0.95)
    white = M("EggCream", "#f6ead2", 0.5)
    brown = M("EggBrown", "#c98c56", 0.55)
    yolk = M("EggYolk", "#ffb81f", 0.4)
    eggwhite = M("EggFriedWhite", "#fffdf4", 0.4)
    red = M("LabelRed", "#d9302a", 0.6)
    cream = M("BagCream", "#fff0c9", 0.8)
    yellow = M("StickerYellow", "#ffd21f", 0.6)
    dark = M("InkDark", "#2b1d12", 0.9)
    parts = []
    cy = -0.35
    parts.append(rbox(pulp, (4.9, 3.5, 0.3), (0, cy, 0.15), r=0.1, seg=3))
    cols = (-1.5, 0.0, 1.5)
    rows = (-0.85, 0.85)
    brown_at = {(0, 1), (2, 0)}
    empty = (2, 1)
    for ci, x in enumerate(cols):
        for ri, y in enumerate(rows):
            prof = [(0, 0.2), (0.62, 0.2), (0.8, 0.95), (0.66, 0.95), (0.5, 0.5), (0, 0.42)]
            parts.append(shapes.lathe(pulp_d, prof, verts=16, loc=(x, cy + y, 0.05)))
            if (ci, ri) == empty:
                continue
            m = brown if (ci, ri) in brown_at else white
            rot = (D2R(3 * (ci - 1)), D2R(-3 * ri), D2R(ci * 37 + ri * 20))
            parts.append(egg(m, (x, cy + y, 1.05), rot=rot))
    for x in (-2.25, -0.75, 0.75, 2.25):                      # cone posts between cups
        parts.append(shapes.cyl(pulp, 0.23, 1.25, (x, cy, 0.85), verts=8, r2=0.1))
    # lid hinged at the back, standing open
    hy = cy + 1.75
    lid = [rbox(pulp, (4.9, 3.5, 0.16), (0, hy - 1.75, 0.3 + 0.08), r=0.08, seg=2),
           rbox(pulp_d, (4.5, 3.1, 0.06), (0, hy - 1.75, 0.3 - 0.01), r=0.05, seg=2)]
    lid.append(rbox(cream, (4.2, 2.8, 0.05), (0, hy - 1.75, 0.3 - 0.03 + 0.0), r=0.06, seg=2))
    lid.append(rbox(red, (4.2, 0.6, 0.06), (0, hy - 1.75 - 1.05, 0.3 - 0.06), r=0.03, seg=1))
    lid += bars(cream, -1.8, hy - 1.75 - 1.05, 0.3 - 0.1, (0.45, 0.45, 0.6, 0.35), h=0.3, gap=0.18, depth=0.05)
    # fried-egg print (flat shapes in the lid plane)
    ew = soft_ball(eggwhite, (1.1, 0.85, 0.05), (-0.55, hy - 1.75 + 0.35, 0.3 - 0.08), seg=12, rings=6, lump=0.12, seed=3)
    ey = soft_ball(yolk, (0.42, 0.42, 0.1), (-0.5, hy - 1.75 + 0.35, 0.3 - 0.14), seg=10, rings=6)
    lid += [ew, ey]
    lid += bars(dark, 0.8, hy - 1.75 + 0.3, 0.3 - 0.085, (0.6, 0.4), h=0.2, gap=0.1, depth=0.04)
    lid += bars(dark, 0.8, hy - 1.75 + 0.75, 0.3 - 0.085, (0.35, 0.65), h=0.2, gap=0.1, depth=0.04)
    lid += sticker(yellow, red, (1.6, hy - 1.75 - 0.55, 0.3 - 0.085), 0.4)
    put(lid, rot=(D2R(-102), 0, 0), pivot=(0, hy, 0.3))
    parts += lid
    # spilled eggs on the counter
    return parts


# ---------------------------------------------------------------------------
# ONIONS: red net bag of onions, top gathered and tied, a few loose
# ---------------------------------------------------------------------------
def dispenser_onions():
    netm = M("OnionNet", "#d8322a", 0.5)
    skin = M("OnionSkin", "#8c2a68", 0.45)
    tip = M("OnionTip", "#d6b98b", 0.9)
    root = M("OnionRoot", "#e8dcc4", 0.9)
    chrome = M("ClipChrome", "#f0f5f8", 0.12, 0.95)
    cream = M("BagCream", "#fff0c9", 0.8)
    red = M("LabelRed", "#d9302a", 0.6)
    yellow = M("StickerYellow", "#ffd21f", 0.6)
    dark = M("InkDark", "#2b1d12", 0.9)
    parts = []
    by = 0.5                                                   # bag centre y
    oc = lambda x, y, z: (x, y + by, z)
    layer0 = [(0, 0)] + [(1.2 * math.cos(a), 1.2 * math.sin(a)) for a in [k * PI / 3 + 0.3 for k in range(6)]]
    n = 0
    for (x, y) in layer0:
        parts += onion(oc(x, y, 0.8), rot=(0, 0, n * 1.1), s=1.0, seed=n, mats=(skin, tip, root))
        n += 1
    for k in range(4):
        a = k * PI / 2 + 0.8
        parts += onion(oc(0.72 * math.cos(a), 0.72 * math.sin(a), 1.85), rot=(D2R(10), D2R(-8), n), s=0.95, seed=n,
                       mats=(skin, tip, root))
        n += 1
    for (x, y) in ((-0.35, 0.1), (0.4, -0.25)):
        parts += onion(oc(x, y, 2.75), rot=(D2R(8), D2R(6), n), s=0.88, seed=n, mats=(skin, tip, root))
        n += 1
    # the net: diamond strands over an envelope
    zs = [0.05, 0.5, 1.2, 2.0, 2.8, 3.4, 3.9, 4.3]
    rs = [1.4, 2.0, 2.3, 2.1, 1.6, 0.95, 0.42, 0.22]

    def env(z):
        for i in range(len(zs) - 1):
            if zs[i] <= z <= zs[i + 1]:
                t = (z - zs[i]) / (zs[i + 1] - zs[i])
                return rs[i] + (rs[i + 1] - rs[i]) * t
        return rs[-1]
    samples = [zs[0] + (zs[-1] - zs[0]) * i / 16 for i in range(17)]
    for direction in (1, -1):
        for k in range(14):
            a0 = 2 * PI * k / 14
            pts = []
            for z in samples:
                a = a0 + direction * 1.3 * (z / zs[-1])
                r = env(z)
                pts.append((r * math.cos(a), by + r * math.sin(a), z))
            parts.append(sweep(netm, pts, 0.03, verts=4, cap=True))
    for z in (0.35, 0.85, 1.6, 2.4, 3.1, 3.65):
        r = env(z)
        parts.append(ring_tube(netm, (r, r, 0, by), 0.028, z, n=28, e=2.0, verts=4))
    # gathered neck, tie and tag
    parts.append(sweep(netm, [(0, by, 3.9), (0, by, 4.4), (0.05, by, 4.75)], [0.42, 0.26, 0.2], verts=8))
    parts.append(ring_tube(chrome, (0.36, 0.36, 0, by), 0.1, 4.2, n=16, e=2.0, verts=6))
    tag = [rbox(cream, (1.5, 0.05, 1.05), (0.15, by - 0.55, 3.35), r=0.04, seg=1),
           rbox(red, (1.5, 0.06, 0.3), (0.15, by - 0.57, 3.72), r=0.03, seg=1)]
    tag += sticker(yellow, red, (-0.35, by - 0.6, 3.2), 0.24)
    tag += bars(dark, 0.0, by - 0.59, 3.12, (0.55, 0.3), h=0.1, gap=0.1)
    tag += bars(dark, -0.1, by - 0.59, 3.3, (0.4, 0.5), h=0.1, gap=0.1)
    put(tag, rot=(D2R(-12), 0, 0), pivot=(0.15, by - 0.55, 3.8))
    parts += tag
    parts.append(sweep(M("TagString", "#2b1d12", 0.9), [(0.2, by - 0.1, 4.1), (0.25, by - 0.5, 3.95)], 0.025, verts=4))
    # loose onions in front
    parts += onion((-1.2, -1.85, 0.8), rot=(0, 0, 0.5), s=0.92, seed=31, mats=(skin, tip, root))
    parts += onion((0.95, -2.0, 0.42), rot=(D2R(88), 0, 1.6), s=0.85, seed=41, mats=(skin, tip, root))
    return parts


# ---------------------------------------------------------------------------
# PICKLES: big glass jar of pickles in brine, lid off, fork in the jar
# ---------------------------------------------------------------------------
def dispenser_pickles():
    glass = M("JarGlass", "#cfeee6", 0.06, alpha=0.16)
    glass_e = M("JarGlassEdge", "#e9fbf6", 0.1, alpha=0.6)
    brine = M("Brine", "#a9c02a", 0.15, alpha=0.3)
    skin = M("PickleSkin", "#5e9a2a", 0.4)
    dark = M("PickleWart", "#3c6a1c", 0.5)
    pale = M("PicklePale", "#b7d36a", 0.4)
    gold = M("LidGold", "#d4a62a", 0.35, 0.6)
    gold_d = M("LidGoldDark", "#a67c14", 0.4, 0.6)
    steel = M("ForkSteel", "#d3d9de", 0.2, 0.8)
    lab = M("LabelCream", "#fff0c9", 0.8)
    green = M("LabelGreen", "#2f8a2f", 0.6)
    red = M("LabelRed", "#d9302a", 0.6)
    ink = M("InkDark", "#2b1d12", 0.9)
    parts = []
    R = 1.8
    jy = 0.3
    secs = [(0.0, R - 0.15, R - 0.15, 0, jy), (0.12, R, R, 0, jy), (3.2, R, R, 0, jy), (3.65, R - 0.12, R - 0.12, 0, jy),
            (3.95, R - 0.25, R - 0.25, 0, jy), (4.4, R - 0.25, R - 0.25, 0, jy)]
    parts.append(loft(glass, secs, n=40, e=2.0, cap_start=True))
    parts.append(ring_tube(glass_e, (R - 0.25, R - 0.25, 0, jy), 0.11, 4.4, n=40, e=2.0, verts=6))
    parts.append(ring_tube(glass_e, (R - 0.22, R - 0.22, 0, jy), 0.07, 4.05, n=40, e=2.0, verts=6))
    parts.append(ring_tube(glass_e, (R, R, 0, jy), 0.07, 0.08, n=40, e=2.0, verts=6))
    # brine
    bsecs = [(0.2, R - 0.2, R - 0.2, 0, jy), (3.25, R - 0.2, R - 0.2, 0, jy), (3.3, R - 0.2, R - 0.2, 0, jy)]
    parts.append(loft(brine, bsecs, n=36, e=2.0, cap_start=True, cap_end=True))
    # pickles: several standing and leaning, tips poke above the brine
    specs = [((-0.95, 0.3, 2.25), (D2R(-6), D2R(-9), 0), 2.9, 0.58), ((0.05, 0.95, 2.35), (D2R(9), D2R(4), 0), 3.0, 0.6),
             ((0.95, 0.1, 2.2), (D2R(4), D2R(11), 0), 2.8, 0.58), ((-0.15, -0.8, 2.15), (D2R(-12), D2R(3), 0), 2.7, 0.58),
             ((0.3, 0.2, 2.35), (D2R(3), D2R(-5), 0), 3.0, 0.56), ((-0.8, 1.05, 2.0), (D2R(-9), D2R(-14), 0), 2.6, 0.5),
             ((1.05, 0.95, 2.0), (D2R(10), D2R(9), 0), 2.6, 0.5),
             ((-0.2, 0.4, 0.85), (0, D2R(90), D2R(25)), 2.8, 0.55), ((0.3, -0.5, 0.75), (0, D2R(90), D2R(-30)), 2.7, 0.52)]
    for i, (p, rot, L, r) in enumerate(specs):
        parts += pickle((skin, dark), (p[0], p[1] + jy, p[2]), L, r, rot, seed=i + 2)
        tipcap = soft_ball(pale, (r * 0.75, r * 0.75, 0.14), (p[0], p[1] + jy, p[2] + L / 2 - 0.06), seg=8, rings=4)
        put(tipcap, rot=rot, pivot=(p[0], p[1] + jy, p[2]))
        parts.append(tipcap)
    # label on the glass
    parts.append(rbox(lab, (2.5, 0.06, 1.7), (0, jy - R - 0.02, 1.7), r=0.06, seg=2))
    parts.append(rbox(green, (2.5, 0.07, 0.42), (0, jy - R - 0.04, 2.35), r=0.04, seg=1))
    parts.append(rbox(green, (2.5, 0.07, 0.16), (0, jy - R - 0.04, 0.98), r=0.03, seg=1))
    parts += bars(lab, -1.0, jy - R - 0.08, 2.35, (0.4, 0.3, 0.45, 0.3, 0.4), h=0.22, gap=0.1)
    parts += [soft_ball(skin, (0.3, 0.06, 0.62), (-0.6, jy - R - 0.09, 1.55), seg=10, rings=6)]
    for k in range(4):
        parts.append(soft_ball(pale, (0.045, 0.03, 0.06), (-0.6 + (k - 1.5) * 0.09, jy - R - 0.14, 1.55), seg=5, rings=3))
    parts += bars(ink, 0.0, jy - R - 0.09, 1.6, (0.5, 0.3, 0.4), h=0.12, gap=0.1)
    parts += bars(ink, 0.0, jy - R - 0.09, 1.3, (0.75, 0.4), h=0.12, gap=0.1)
    # lid lying propped against the jar on the right
    lid = [shapes.cyl(gold, 1.4, 0.26, (0, 0, 0), verts=28), shapes.cyl(gold_d, 1.42, 0.12, (0, 0, -0.1), verts=28),
           shapes.cyl(lab, 1.15, 0.06, (0, 0, 0.14), verts=24)]
    for k in range(18):                                        # knurled rim
        a = 2 * PI * k / 18
        lid.append(shapes.box(gold_d, (0.1, 0.14, 0.26), (1.42 * math.cos(a), 1.42 * math.sin(a), 0), (0, 0, a)))
    lid.append(shapes.cyl(green, 0.55, 0.05, (0, 0, 0.17), verts=20))
    put(lid, rot=(0, D2R(78), 0))
    put(lid, move=(2.03, -0.1, 1.42))
    parts += lid
    # fork stuck in the jar
    parts += fork(steel, (-1.65, -1.6, 5.0), (-0.35, 0.3, 3.0), r=0.1)
    # pickle chips on the counter
    for (x, y, s) in ((-1.35, -2.3, 1.0), (-0.45, -2.45, 0.85)):
        parts.append(shapes.cyl(skin, 0.5 * s, 0.17, (x, y, 0.09), verts=16))
        parts.append(shapes.cyl(pale, 0.36 * s, 0.19, (x, y, 0.1), verts=14))
        for k in range(5):
            a = 2 * PI * k / 5
            parts.append(shapes.box(M("PickleSeed", "#f4f0c8", 0.6), (0.06, 0.06, 0.2),
                                    (x + 0.22 * s * math.cos(a), y + 0.22 * s * math.sin(a), 0.1)))
    return parts


# ---------------------------------------------------------------------------
# POTATOES: burlap sack rolled down, heap of potatoes, stencil print
# ---------------------------------------------------------------------------
def dispenser_potatoes():
    bur = M("Burlap", "#b9975a", 0.98)
    bur_d = M("BurlapDark", "#8e7040", 1.0)
    bur_l = M("BurlapLight", "#d3b676", 1.0)
    inside = M("SackInside", "#5e4526", 1.0)
    skin = M("PotatoSkin", "#b98a52", 0.75)
    eye = M("PotatoEye", "#6a4726", 0.9)
    red = M("StencilRed", "#b3261e", 0.8)
    stitch = M("Stitch", "#3a2a14", 0.9)
    tagm = M("SackTag", "#fff0c9", 0.8)
    parts = []
    sy = 0.25
    secs = [(0.0, 1.6, 1.35, 0, sy), (0.35, 2.05, 1.7, 0, sy), (1.4, 2.2, 1.85, 0, sy), (2.4, 2.1, 1.75, 0, sy),
            (3.0, 1.95, 1.6, 0, sy)]
    parts.append(loft(bur, secs, n=44, e=2.6, cap_start=True, wob=crinkle_fn(0.04, 1.3, 7)))
    parts.append(loft(inside, [(2.95, 1.85, 1.5, 0, sy), (3.02, 1.85, 1.5, 0, sy)], n=36, e=2.6, cap_start=True, cap_end=True))
    # woven horizontal threads
    for i, z in enumerate([0.7 + 0.42 * k for k in range(5)]):
        t = (z - 0.35) / 1.05 if z < 1.4 else 1.0
        hw = 2.05 + (2.2 - 2.05) * min(t, 1.0) if z < 1.4 else 2.2 - (z - 1.4) * 0.1
        parts.append(ring_tube(bur_d, (hw + 0.01, hw * 0.84 + 0.01, 0, sy), 0.022, z, n=44, e=2.6, verts=4))
    # rolled top rim: two fat tubes
    parts.append(ring_tube(bur_l, (2.0, 1.66, 0, sy), 0.42, 3.05, n=44, e=2.6, verts=8))
    parts.append(ring_tube(bur, (2.14, 1.78, 0, sy), 0.36, 2.72, n=44, e=2.6, verts=8))
    # stencil print on the front
    fy = sy - 1.85 - 0.06
    parts.append(rbox(red, (2.9, 0.06, 0.12), (0, fy - 0.0, 2.05), r=0.02, seg=1))
    parts.append(rbox(red, (2.9, 0.06, 0.12), (0, fy, 0.75), r=0.02, seg=1))
    parts += bars(red, -1.25, fy - 0.01, 1.55, (0.35, 0.25, 0.35, 0.25, 0.3, 0.25, 0.3), h=0.42, gap=0.1)
    parts += bars(red, -0.9, fy - 0.01, 1.05, (0.3, 0.4, 0.3, 0.3), h=0.22, gap=0.1)
    # stitched seam
    for k in range(9):
        parts.append(rbox(stitch, (0.05, 0.05, 0.22), (1.93, sy - 0.75, 0.3 + k * 0.3), r=0.01, seg=1))
    # potato heap
    heap = [((-1.0, 0.1, 3.3), 0.3), ((0.15, 0.55, 3.55), 1.1), ((1.0, 0.0, 3.35), 2.0), ((0.0, -0.75, 3.35), 2.8),
            ((-0.3, 0.2, 4.05), 0.6), ((0.7, -0.35, 4.15), 1.7), ((-1.1, -0.7, 3.65), 2.2), ((1.35, 0.8, 3.4), 0.9),
            ((-0.8, 0.85, 3.8), 2.5)]
    for i, (p, rz) in enumerate(heap):
        parts += potato((p[0], p[1] + sy, p[2]), rot=(D2R(10 * (i % 3 - 1)), D2R(8 * (i % 2)), rz), s=1.0 + 0.06 * (i % 3), seed=i + 3,
                        mats=(skin, eye))
    # spilled in front
    parts += potato((-1.85, -2.2, 0.42), rot=(0, 0, 0.6), s=0.7, seed=21, mats=(skin, eye))
    parts += potato((-0.3, -2.3, 0.4), rot=(0, 0, -0.3), s=0.68, seed=22, mats=(skin, eye))
    parts += potato((1.6, -2.15, 0.42), rot=(0, 0, 0.9), s=0.7, seed=23, mats=(skin, eye))
    return parts


# ---------------------------------------------------------------------------
# CHICKEN: butcher tray of raw fillets, film peeled back, label, header card
# ---------------------------------------------------------------------------
def dispenser_chicken():
    foam = M("TrayFoam", "#f4f1e8", 0.85)
    foam_in = M("TrayFoamIn", "#e6e0d0", 0.9)
    pad = M("AbsorbentPad", "#f1d9d6", 1.0)
    skin = M("ChickenSkin", "#f7b9a2", 0.35)
    pale = M("ChickenPale", "#fbd6c4", 0.4)
    fat = M("ChickenFat", "#fff0dd", 0.5)
    card = M("ChickenCard", "#e8a21a", 0.6)
    card_l = M("ChickenCardCream", "#fff6dc", 0.7)
    red = M("LabelRed", "#d9302a", 0.6)
    white = M("LabelWhite", "#ffffff", 0.7)
    yellow = M("StickerYellow", "#ffd21f", 0.6)
    dark = M("InkDark", "#2b1d12", 0.9)
    orange = M("HenBeak", "#ff8a1e", 0.5)
    hen = M("HenBody", "#fff7e0", 0.6)
    film = film_mat(0.22)
    W, D, TH = 5.2, 3.8, 0.9
    cy = -0.55
    parts = []
    outer = [(0.0, W / 2 * 0.90, D / 2 * 0.90, 0, cy), (0.18, W / 2 * 0.98, D / 2 * 0.98, 0, cy), (TH, W / 2, D / 2, 0, cy)]
    inner = [(0.22, W / 2 * 0.86, D / 2 * 0.86, 0, cy), (TH, W / 2 * 0.93, D / 2 * 0.93, 0, cy)]
    parts.append(loft(foam, outer, n=40, e=5, cap_start=True))
    parts.append(loft(foam_in, inner, n=40, e=5, cap_start=True))
    parts.append(ring_tube(foam, (W / 2 * 0.965, D / 2 * 0.965, 0, cy), 0.15, TH, n=48, e=5, verts=6))
    parts.append(rbox(pad, (W - 0.9, D - 0.9, 0.1), (0, cy, 0.27), r=0.04, seg=1))
    s = 0.88
    base = [(-1.0, -0.85, 0.05), (1.15, -0.8, -0.04), (-1.1, 0.8, -0.07), (1.05, 0.85, 0.06)]
    for i, (x, y, rz) in enumerate(base):
        parts += fillet((skin, pale, fat), (x, cy + y, 0.6), rot=(0, 0, rz + (PI if i % 2 else 0)), s=s, seed=i)
    parts += fillet((skin, pale, fat), (-0.9, cy + 0.85, 1.1), rot=(D2R(4), 0, D2R(25)), s=s, seed=8)
    parts += fillet((skin, pale, fat), (0.9, cy + 0.65, 1.1), rot=(D2R(-3), 0, D2R(160)), s=s, seed=9)
    parts += fillet((skin, pale, fat), (0.0, cy + 0.7, 1.55), rot=(0, D2R(-4), D2R(80)), s=s, seed=10)
    # film: a sealed strip on the left, peeled up and curling over towards the middle
    parts.append(rbox(film, (1.7, 3.4, 0.04), (-1.7, cy, TH + 0.04), r=0.02, seg=1))
    parts.append(rbox(film, (1.2, 3.4, 0.04), (-0.55, cy, TH + 0.3), rot=(0, D2R(-35), 0), r=0.02, seg=1))
    parts.append(rbox(film, (0.9, 3.3, 0.04), (0.12, cy + 0.05, TH + 0.85), rot=(0, D2R(25), D2R(2)), r=0.02, seg=1))
    # label on the tray front
    parts.append(rbox(white, (2.7, 0.06, 0.6), (-0.6, cy - D / 2 * 0.98 - 0.02, 0.5), r=0.03, seg=1))
    parts.append(rbox(red, (2.7, 0.07, 0.15), (-0.6, cy - D / 2 * 0.98 - 0.03, 0.73), r=0.02, seg=1))
    parts += bars(dark, -1.85, cy - D / 2 * 0.98 - 0.06, 0.45, (0.6, 0.4, 0.5, 0.35), h=0.11, gap=0.1)
    parts += sticker(yellow, red, (1.4, cy - D / 2 * 0.98 - 0.03, 0.55), 0.28)
    parts += barcode(dark, white, (2.0, cy - D / 2 * 0.98 - 0.03, 0.55), w=0.6, h=0.34, seed=6)
    # header card behind with a hen
    tilt = D2R(-6)
    cyc, ch = 1.9, 3.5
    deco = [rbox(card, (4.9, 0.18, ch), (0, cyc, 0.1 + ch / 2), r=0.1, seg=2),
            rbox(card_l, (4.3, 0.06, 2.2), (0, cyc - 0.11, 2.2), r=0.06, seg=2),
            rbox(red, (4.3, 0.07, 0.55), (0, cyc - 0.12, 0.8), r=0.04, seg=2)]
    deco += bars(card_l, -1.7, cyc - 0.16, 0.8, (0.5, 0.3, 0.55, 0.3, 0.7), h=0.26, gap=0.14)
    fy = cyc - 0.17
    hz = 2.2
    deco += [soft_ball(hen, (0.95, 0.18, 0.72), (0.15, fy, hz - 0.1), seg=12, rings=8),
             soft_ball(hen, (0.48, 0.17, 0.5), (-0.8, fy, hz + 0.62), seg=10, rings=6),
             soft_ball(red, (0.14, 0.12, 0.14), (-0.8, fy - 0.02, hz + 1.12), seg=6, rings=4),
             soft_ball(red, (0.12, 0.11, 0.12), (-0.62, fy - 0.02, hz + 1.1), seg=6, rings=4),
             soft_ball(red, (0.1, 0.1, 0.22), (-0.95, fy - 0.03, hz + 0.25), seg=6, rings=4),
             soft_ball(dark, (0.07, 0.05, 0.07), (-0.95, fy - 0.18, hz + 0.72), seg=6, rings=4),
             soft_ball(M("HenWing", "#f1dfae", 0.6), (0.6, 0.12, 0.38), (0.25, fy - 0.15, hz - 0.15), (0, 0, D2R(-15)), seg=10, rings=6),
             shapes.cyl(orange, 0.14, 0.4, (-1.4, fy - 0.03, hz + 0.6), (0, D2R(-90), 0), verts=8, r2=0.02)]
    for k in range(3):
        deco.append(soft_ball(hen, (0.12, 0.11, 0.5), (1.0 + k * 0.12, fy, hz + 0.3 + k * 0.05), (0, D2R(-20 - 22 * k), 0), seg=8, rings=5))
    deco += sticker(red, yellow, (1.75, cyc - 0.15, 3.15), 0.4)
    put(deco, rot=(tilt, 0, 0), pivot=(0, cyc, 0.1))
    parts += deco
    return parts


SMOOTH = {"dispenser_onions": 60}
BUILDERS = {"dispenser_bacon": dispenser_bacon, "dispenser_eggs": dispenser_eggs, "dispenser_onions": dispenser_onions,
            "dispenser_pickles": dispenser_pickles, "dispenser_potatoes": dispenser_potatoes,
            "dispenser_chicken": dispenser_chicken}

if __name__ == "__main__" or True:
    wanted = [a for a in artlib.script_args()] or list(BUILDERS)
    for name in wanted:
        artlib.reset_scene()
        finish(name, BUILDERS[name](), LIMITS, smooth_deg=SMOOTH.get(name, 48))
