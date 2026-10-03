"""Chef back items: back_<id>.glb, origin at the BackAnchor (jacket back between the shoulder blades), sticking out
toward Godot -Z (Blender +Y), facing +Z. Run: tools/blender-run.ps1 art/scripts/back_items.py  (optional arg: id)

Authored in the raw chef frame (see wear_parts.py) and shifted by the anchor. Every piece keeps clear of the jacket
back (about 1.5 cm) and well below the head so the game camera still sees the face and hat.
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import artlib  # noqa: E402
import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402
from wear_parts import (PI, blob, cyl, ellip, grid, jang, jpt, loop_ribbon, prism, rbox, revolve, sheet,  # noqa: E402
                        strip, to_anchor, tris, tube, wrap_pt)

M = artlib.material


def V(*a):
    return Vector(a[0] if len(a) == 1 else a)


def by(x, z, off=0.0):
    """Jacket back surface y at lateral x, height z (+off)."""
    return jpt(x, z, off, back=True).y


# ------------------------------------------------------------------ shared
def shoulder_straps(mat, buckle_mat, width=0.05, ang_back=158, ang_front=-18):
    P = []
    for s in (-1, 1):
        def xc(a, s=s):
            return s * (0.125 + 0.07 * math.sin(PI * (a - ang_front) / (ang_back - ang_front)))
        P.append(strip(mat, xc, ang_back, ang_front, width, off=0.026, thick=0.01, n=18, name="Strap"))
        p, n = wrap_pt(xc(ang_front), ang_front, 0.034)
        P.append(rbox(buckle_mat, p, (0.034, 0.012, 0.03), n=n, sq=3.5, nu=8, nv=4, name="Buckle"))
    return P


# ------------------------------------------------------------------ cape
def back_cape():
    tint = M("OutfitTint", "#d9483f", 0.75)
    lining = M("CapeLining", "#f3e2b0", 0.8)
    gold = M("CapeGold", "#f1b92e", 0.3, metallic=0.6)
    z_top, z_bot = 0.735, 0.2
    P = []

    def f(u, v):
        span = math.radians(66 + 24 * v ** 0.8)
        th = PI + (u - 0.5) * 2 * span
        z = z_top - (z_top - z_bot) * v
        wave = 0.03 * math.sin(th * 3.4 + 0.6) * v
        off = 0.03 + 0.12 * v ** 1.45 + wave
        p = jang(th, z, off)
        p.z = z - 0.03 * abs(2 * u - 1) ** 2 * v
        return p
    P.append(sheet(tint, f, 28, 14, 0.012, name="Cape", inner=lining, flip=False))
    hem = [f(i / 28.0, 1.0) for i in range(29)]
    P.append(tube(lining, hem, 0.0085, samples=40, seg=6, name="HemTrim"))
    for ue in (0.0, 1.0):
        P.append(tube(lining, [f(ue, k / 7.0) for k in range(8)], 0.0075, samples=14, seg=5, name="EdgeTrim"))
    # stand-up collar round the neck, open at the front, with a gold clasp
    pts = []
    for a in range(-150, 151, 15):
        th = PI + math.radians(a)
        p = jang(th, 0.742, 0.036)
        p.z = 0.742
        pts.append(p)
    P.append(tube(tint, pts, 0.031, samples=24, seg=8, name="Collar"))
    for end in (pts[0], pts[-1]):
        P.append(ellip(gold, end + V(0, -0.004, 0.0), (0.02, 0.02, 0.02), nu=8, nv=5, name="Clasp"))
    chain = [pts[0], V(pts[0].x * 0.5, pts[0].y - 0.014, pts[0].z - 0.022), V(0, pts[0].y - 0.02, 0.712),
             V(pts[-1].x * 0.5, pts[-1].y - 0.014, pts[-1].z - 0.022), pts[-1]]
    P.append(tube(gold, chain, 0.0055, samples=12, seg=5, name="Chain"))
    return P


# ------------------------------------------------------------------ backpack
def back_backpack():
    body = M("PackOlive", "#6f7f3a", 0.85)
    flap = M("PackFlap", "#8a5a2b", 0.8)
    strap = M("PackStrap", "#5a3d22", 0.8)
    roll = M("PackRoll", "#e0842c", 0.85)
    metal = M("PackBuckle", "#d9c27a", 0.35, metallic=0.5)
    P = []
    y0 = by(0, 0.55, 0.014)
    P.append(rbox(body, V(0, y0 + 0.095, 0.545), (0.34, 0.19, 0.40), sq=3.0, nu=14, nv=8, name="Pack"))
    P.append(rbox(flap, V(0, y0 + 0.108, 0.665), (0.35, 0.2, 0.15), sq=3.0, nu=14, nv=7, name="Flap"))
    P.append(rbox(body, V(0, y0 + 0.2, 0.42), (0.22, 0.07, 0.17), sq=3.2, nu=12, nv=6, name="Pocket"))
    P.append(rbox(flap, V(0, y0 + 0.232, 0.455), (0.2, 0.025, 0.07), sq=3.2, nu=10, nv=4, name="PocketFlap"))
    P.append(ellip(metal, V(0, y0 + 0.245, 0.43), (0.016, 0.01, 0.016), nu=8, nv=4, name="PocketClasp"))
    P.append(ellip(metal, V(0, y0 + 0.21, 0.665), (0.02, 0.012, 0.024), nu=8, nv=4, name="FlapClasp"))
    P.append(cyl(roll, V(-0.16, y0 + 0.095, 0.325), V(0.16, y0 + 0.095, 0.325), 0.052, seg=12, name="Bedroll"))
    for x in (-0.095, 0.095):
        P.append(cyl(strap, V(x, y0 + 0.095, 0.325), V(x + 0.014, y0 + 0.095, 0.325), 0.056, seg=12, name="RollStrap"))
    P.append(tube(strap, [V(-0.04, y0 + 0.1, 0.745), V(0, y0 + 0.1, 0.775), V(0.04, y0 + 0.1, 0.745)], 0.008, samples=8, seg=5, name="Handle"))
    P += shoulder_straps(strap, metal)
    return P


# ------------------------------------------------------------------ wings
def back_wings():
    white = M("WingWhite", "#fffaf0", 0.7)
    cream = M("WingCream", "#f0e6cf", 0.75)
    P = []
    yb = by(0, 0.62, 0.05)
    for s in (-1, 1):
        root = V(s * 0.115, yb, 0.6)
        P.append(ellip(white, root + V(s * 0.02, 0.012, 0.0), (0.075, 0.04, 0.062), nu=10, nv=6, name="WingRoot"))
        P.append(ellip(cream, V(s * 0.05, yb - 0.004, 0.6), (0.06, 0.03, 0.045), nu=8, nv=5, name="WingMount"))
        rows = [(cream, 0.24, [-22, -6, 10, 26, 42, 58]), (white, 0.28, [-14, 2, 18, 34, 50, 64]), (white, 0.19, [-5, 15, 35, 55])]
        for row, (mat, L, angles) in enumerate(rows):
            for a in angles:
                ar = math.radians(a)
                d = V(s * math.cos(ar) * 0.95, 0.26 * (0.4 + 0.6 * math.cos(ar)), math.sin(ar)).normalized()
                B = V(0, 1, 0).cross(d).normalized()
                C = d.cross(B).normalized()
                w = 0.036 - 0.003 * row
                c = root + V(0, row * 0.012 + 0.012, 0) + d * (L * 0.5 + 0.03)
                P.append(blob(mat, c, d, B, C, L * 0.5 + 0.015, w, 0.014, nu=7, nv=4, name="Feather"))
    return P


# ------------------------------------------------------------------ jetpack
def back_jetpack():
    steel = M("JetSteel", "#aeb6c4", 0.35, metallic=0.7)
    red = M("JetRed", "#d9392c", 0.45)
    dark = M("JetNozzle", "#3b3f4a", 0.4, metallic=0.5)
    flame = M("JetFlame", "#ffb03a", 0.5, emission="#ff8a1a", emission_strength=1.5)
    strap = M("JetStrap", "#2f3440", 0.8)
    metal = M("JetBuckle", "#d9c27a", 0.35, metallic=0.5)
    P = []
    y0 = by(0, 0.5, 0.016)
    for s in (-1, 1):
        x = s * 0.1
        yc = y0 + 0.078
        P.append(cyl(red, V(x, yc, 0.34), V(x, yc, 0.64), 0.076, seg=14, name="Tank"))
        P.append(ellip(red, V(x, yc, 0.64), (0.076, 0.076, 0.045), nu=14, nv=5, name="TankTop"))
        P.append(ellip(red, V(x, yc, 0.34), (0.076, 0.076, 0.04), nu=14, nv=5, name="TankBottom"))
        for z in (0.44, 0.56):
            P.append(cyl(steel, V(x, yc, z - 0.012), V(x, yc, z + 0.012), 0.081, seg=14, name="TankBand"))
        P.append(cyl(steel, V(x, yc, 0.665), V(x, yc, 0.715), 0.018, seg=8, name="Valve"))
        P.append(cyl(dark, V(x, yc, 0.33), V(x, yc, 0.215), (0.05, 0.07), seg=12, name="Nozzle"))
        P.append(cyl(flame, V(x, yc, 0.216), V(x, yc, 0.15), (0.045, 0.0), seg=10, name="Flame"))
    P.append(rbox(steel, V(0, y0 + 0.078, 0.5), (0.1, 0.05, 0.05), sq=3.2, nu=8, nv=5, name="Crossbar"))
    P.append(rbox(dark, V(0, y0 + 0.108, 0.5), (0.05, 0.03, 0.05), sq=3.2, nu=8, nv=5, name="Gauge"))
    P += shoulder_straps(strap, metal, ang_back=165)
    return P


# ------------------------------------------------------------------ guitar
def back_guitar():
    wood = M("GuitarWood", "#d98a2b", 0.35)
    dark = M("GuitarDark", "#3a2418", 0.5)
    neck_m = M("GuitarNeck", "#6b4223", 0.5)
    strap = M("GuitarStrap", "#2f6fd0", 0.75)
    metal = M("GuitarMetal", "#d4d8de", 0.3, metallic=0.8)
    P = []
    t = math.radians(52)
    g = V(math.sin(t), 0, math.cos(t))
    n = V(0, 1, 0)
    side = V(math.cos(t), 0, -math.sin(t))
    y0 = by(0, 0.5, 0.012)
    c0 = V(-0.12, y0 + 0.048, 0.42)
    P.append(blob(wood, c0, g, side, n, 0.15, 0.16, 0.048, nu=14, nv=8, name="LowerBout"))
    P.append(blob(wood, c0 + g * 0.19, g, side, n, 0.115, 0.115, 0.046, nu=12, nv=7, name="UpperBout"))
    P.append(blob(dark, c0 + n * 0.04, g, side, n, 0.05, 0.05, 0.014, nu=10, nv=4, name="SoundHole"))
    P.append(rbox(dark, c0 + n * 0.035 - g * 0.085, (0.08, 0.02, 0.018), rot=(0, -t, 0), sq=3.5, nu=8, nv=4, name="Bridge"))
    a, b = c0 + g * 0.28 + n * 0.012, c0 + g * 0.68 + n * 0.012
    P.append(tube(neck_m, [a, (a + b) / 2, b], 0.03, samples=8, seg=6, name="Neck"))
    P.append(rbox(dark, b + g * 0.045, (0.055, 0.03, 0.09), rot=(0, -t, 0), sq=3.2, nu=8, nv=5, name="Headstock"))
    for k in range(3):
        for sd in (-1, 1):
            P.append(ellip(metal, b + g * (0.02 + 0.03 * k) + side * sd * 0.035, (0.01, 0.01, 0.01), nu=6, nv=3, name="Peg"))
    P.append(loop_ribbon(strap, -62, 0.19, 0.52, 0.055, off=0.03, nu=44, name="Strap"))
    return P


# ------------------------------------------------------------------ shell
def back_shell():
    dome = M("ShellGreen", "#3f8f3f", 0.55)
    plate = M("ShellPlate", "#79c24c", 0.5)
    rim = M("ShellRim", "#e8d79b", 0.6)
    strap = M("ShellStrap", "#6b4a2b", 0.8)
    metal = M("ShellBuckle", "#d9c27a", 0.35, metallic=0.5)
    P = []
    y0 = by(0, 0.5, 0.016)
    cz = 0.5
    rx, rz, ry = 0.285, 0.26, 0.19

    def pt(ph, th):
        return V(rx * math.sin(ph) * math.cos(th), y0 + ry * math.cos(ph), cz + rz * math.sin(ph) * math.sin(th))

    def f(u, v):
        return pt(v * PI / 2, 2 * PI * u)
    P.append(grid(dome, f, 24, 8, closed=True, name="Dome", outward=None))
    ringp = [pt(PI / 2, 2 * PI * i / 24) for i in range(24)]
    P.append(tube(rim, ringp, 0.022, seg=7, closed=True, name="Rim"))

    def hexa(ph, th, size):
        p = pt(ph, th)
        e = 1e-3
        a = pt(ph + e, th) - pt(ph - e, th)
        b = pt(ph, th + e) - pt(ph, th - e)
        nn = a.cross(b).normalized()
        if nn.dot(p - V(0, y0, cz)) < 0:
            nn = -nn
        return prism(plate, [(size * math.cos(PI / 3 * i + PI / 6), size * math.sin(PI / 3 * i + PI / 6)) for i in range(6)],
                     p - nn * 0.002, nn, depth=0.014, inset=0.18, round_iters=0, name="Scute", up=V(0, 0, 1))
    P.append(hexa(0.0, 0.0, 0.075))
    for k in range(6):
        P.append(hexa(0.62, PI / 3 * k, 0.062))
    for k in range(6):
        P.append(hexa(1.1, PI / 3 * k + PI / 6, 0.05))
    P += shoulder_straps(strap, metal, width=0.044, ang_back=163)
    return P


# ------------------------------------------------------------------ pan
def back_pan():
    iron = M("PanIron", "#3d414b", 0.4, metallic=0.6)
    wood = M("PanHandle", "#8a5a2b", 0.7)
    strap = M("PanStrap", "#5a3d22", 0.8)
    metal = M("PanBuckle", "#d9c27a", 0.35, metallic=0.5)
    P = []
    t = math.radians(50)
    g = V(math.sin(t), 0, math.cos(t))
    y0 = by(0, 0.5, 0.012)
    c0 = V(-0.11, y0, 0.46)
    prof = [(0.0, 0.0), (0.14, 0.0), (0.172, 0.012), (0.183, 0.046), (0.172, 0.052), (0.15, 0.022), (0.0, 0.016)]
    P.append(revolve(iron, prof, c0, V(0, 1, 0), nu=28, name="Pan"))
    a = c0 + g * 0.17 + V(0, 0.024, 0)
    b = c0 + g * 0.42 + V(0, 0.024, 0)
    P.append(tube(wood, [a, (a + b) / 2, b], 0.021, samples=8, seg=7, name="Handle"))
    P.append(cyl(iron, a - g * 0.03, a + g * 0.06, 0.026, seg=8, name="Collar"))
    P.append(loop_ribbon(strap, -62, 0.19, 0.5, 0.05, off=0.03, nu=44, name="Sling"))
    sx = V(g.z, 0, -g.x)
    P.append(sheet(strap, lambda u, v: (c0 + sx * (0.19 * (2 * u - 1)) + g * (0.02 * (2 * v - 1)) + V(0, 0.056, 0)), 4, 1, 0.012,
                   name="PanBand", flip=False))
    P.append(rbox(metal, c0 + V(0, 0.066, 0), (0.04, 0.012, 0.034), sq=3.5, nu=8, nv=4, name="BandBuckle"))
    return P


# ------------------------------------------------------------------ balloon
def back_balloon():
    red = M("BalloonRed", "#e8334a", 0.3)
    shine = M("BalloonShine", "#ff8fa0", 0.25)
    cord = M("BalloonCord", "#f1ede0", 0.8)
    knot_m = M("BalloonKnot", "#c2243a", 0.4)
    y0 = by(0, 0.6, 0.014)
    pts = [V(0, y0 + 0.005, 0.6), V(0.03, y0 + 0.07, 0.8), V(-0.035, y0 + 0.14, 1.05), V(0.035, y0 + 0.2, 1.3),
           V(-0.01, y0 + 0.24, 1.52), V(0.0, y0 + 0.25, 1.64)]
    strings = [tube(cord, pts, 0.0065, samples=40, seg=5, name="Cord")]
    strings.append(ellip(cord, V(0, y0 + 0.01, 0.6), (0.026, 0.014, 0.026), nu=8, nv=4, name="Anchor"))
    top = pts[-1]
    bc = top + V(0, 0.0, 0.215)
    bal = [ellip(red, bc, (0.185, 0.185, 0.225), nu=18, nv=11, name="Balloon"),
           ellip(shine, bc + V(-0.07, -0.09, 0.09), (0.04, 0.02, 0.06), rot=(0, 0.4, 0), nu=8, nv=5, name="Shine"),
           cyl(knot_m, top + V(0, 0, 0.03), top + V(0, 0, -0.005), (0.0, 0.03), seg=10, name="Knot")]
    return strings, bal


# ------------------------------------------------------------------ sword (giant spatula)
def back_sword():
    """Giant spatula worn like a sword: handle above the +x shoulder, flipper hanging behind the -x hip, leather
    sling over the chest. Everything lies on the jacket back (x/z map, y from the jacket surface) so hands never reach it."""
    blade = M("SpatulaBlade", "#dfe4ec", 0.3, metallic=0.75)
    slot = M("SpatulaSlot", "#343843", 0.5, metallic=0.5)
    wood = M("SpatulaHandle", "#b5651d", 0.6)
    ring = M("SpatulaRing", "#d9c27a", 0.35, metallic=0.5)
    strap = M("SpatulaSling", "#5a3d22", 0.8)
    P = []
    H = (0.17, 0.87)
    T = (-0.16, 0.25)
    L = math.hypot(T[0] - H[0], T[1] - H[1])
    dx, dz = (T[0] - H[0]) / L, (T[1] - H[1]) / L
    px, pz = -dz, dx  # across the blade

    def surf(a, w, off):
        x = H[0] + (T[0] - H[0]) * a + w * px
        z = H[1] + (T[1] - H[1]) * a + w * pz
        p = jpt(x, min(z, 0.7), off, back=True)
        return V(x, p.y + (0.0 if z <= 0.7 else 0.02 * (z - 0.7) / 0.17), z)

    A0, A1 = 0.52, 1.0  # flipper span along the axis
    bw = 0.092

    def f(u, v):
        a = A0 + (A1 - A0) * v
        k = 2 * u - 1
        w = bw * (0.82 + 0.18 * v ** 0.7) * k
        # rounded tip corners
        corner = 1.0 - 0.3 * max(0.0, (v - 0.85) / 0.15) ** 2
        return surf(a, w * corner, 0.034 + 0.008 * (1 - k * k))
    P.append(sheet(blade, f, 8, 8, 0.012, name="Blade", flip=False))
    # slots
    for i in range(-2, 3):
        wc = i * 0.034
        P.append(sheet(slot, lambda u, v, wc=wc: surf(0.7 + 0.24 * v, wc + (u - 0.5) * 0.016, 0.0445), 1, 6, 0.004,
                       name="Slot", flip=False))
    # neck + handle
    neck = [surf(0.54, 0, 0.034), surf(0.49, 0, 0.04), surf(0.44, 0, 0.044)]
    P.append(tube(blade, neck, 0.011, samples=6, seg=6, name="Shank"))
    pts = [surf(0.44, 0, 0.046), surf(0.3, 0, 0.05), surf(0.15, 0, 0.066), surf(0.0, 0, 0.078)]
    P.append(tube(wood, pts, 0.021, samples=12, seg=8, name="Handle"))
    P.append(cyl(ring, surf(0.45, 0, 0.045), surf(0.41, 0, 0.047), 0.027, seg=10, name="Ferrule"))
    P.append(ellip(wood, surf(-0.005, 0, 0.078), (0.03, 0.03, 0.03), nu=8, nv=5, name="Knob"))
    # leather sling across the chest (thin, over the jacket)
    P.append(loop_ribbon(strap, -62, 0.19, 0.5, 0.032, off=0.022, nu=44, name="Sling", thick=0.008))
    return P


MAKERS = {"cape": back_cape, "backpack": back_backpack, "wings": back_wings, "jetpack": back_jetpack, "guitar": back_guitar,
          "shell": back_shell, "pan": back_pan, "balloon": back_balloon, "sword": back_sword}


def build(bid):
    artlib.reset_scene()
    res = MAKERS[bid]()
    if bid == "balloon":
        strings, bal = res
        to_anchor(strings + bal)
        print("TRIS back_balloon %d" % tris(strings + bal))
        artlib.join(strings, "BalloonCord")
        artlib.join(bal, "Float")
    else:
        to_anchor(res)
        print("TRIS back_%s %d" % (bid, tris(res)))
        artlib.join(res, "Back" + bid.title())
    artlib.export_glb("back_" + bid)


only = [a for a in artlib.script_args() if a in MAKERS]
for bid in (only or MAKERS):
    build(bid)
