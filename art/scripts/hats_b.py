"""Chef hats, set B: cone, party, fez, beret, cap, santa, headphones, frog, halo.
Run: tools/blender-run.ps1 art/scripts/hats_b.py [-- id id ...]   (no ids = all nine)

Same contract as hats.py: origin = HatAnchor (centre of the toque base ring), front is Blender -Y (Godot +Z),
metres. Parts named "Body*" are checked against the head/hair ellipsoids (CLEARANCE lines).
HatTint takes the player colour (party, beret, cap, headphone cups).
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bpy  # noqa: E402,F401
import artlib  # noqa: E402
from mathutils import Matrix  # noqa: E402
from hats_b_parts import (DropShell, HEAD_C, HEAD_R, PI, Shell, V, bezier, clearance, disc, ellip, fuzz_ball,  # noqa: E402
                          grid, lath, lath_fn, sweep, tilt, tube, xf)
from hats_parts import surf_normal  # noqa: E402

M = artlib.material
D = math.radians


def sgn(x):
    return 1.0 if x >= 0 else -1.0


def spow(x, e):
    return sgn(x) * abs(x) ** e


def rot_about(objs, pivot, rx=0.0, ry=0.0, rz=0.0):
    pv = V(pivot)
    m = Matrix.Translation(pv) @ Matrix.Rotation(rz, 4, "Z") @ Matrix.Rotation(ry, 4, "Y") \
        @ Matrix.Rotation(rx, 4, "X") @ Matrix.Translation(-pv)
    for o in objs:
        xf(o, m)


def rim_tube(mat, sh, r, grow=0.004, dz=0.0, n=48, name="Hem"):
    pts = []
    for i in range(n):
        th = 2 * PI * i / n
        p = sh.pt(th, 0.0)
        p = V((p.x, p.y, 0)) + sh.hnorm(th) * grow
        p.z = sh.rim_z(th) + dz
        pts.append(p)
    return tube(mat, pts, r, seg=5, closed=True, name=name)


# ------------------------------------------------------------------------------------------------ cone
def hat_cone():
    orange = M("ConeOrange", "#ff6414", 0.55)
    white = M("ConeWhite", "#f5f4ee", 0.5)
    sh = Shell(rx=0.262, ryf=0.245, ryb=0.285, rz=0.25, zf=0.045, zb=-0.03)
    rows = [(0, 1.06, 1, 0.0), (0.05, 1.0, 1, 0.0), (0.09, 0.98, 0.9, 0.012), (0.35, 0.74, 0.0, 0.15),
            (0.7, 0.42, 0.0, 0.29), (0.93, 0.13, 0.0, 0.372), (0.985, 0.06, 0.0, 0.382), (1.0, 0.0, 0.0, 0.384)]
    P = [lath(sh, orange, rows, nu=36, nv=18, name="Body")]
    for (a, b) in ((0.24, 0.40), (0.52, 0.66)):
        P.append(lath(sh, white, rows, nu=36, nv=4, name="Stripe", grow=0.0035, v0=a, v1=b))
    P.append(rim_tube(orange, sh, 0.0085, grow=0.012, dz=0.003))
    tilt(P, pitch_deg=-1.5)
    return P


# ------------------------------------------------------------------------------------------------ party
def hat_party():
    col = M("HatTint", "#4aa3e8", 0.6)
    dot = M("PartyDot", "#fff6d8", 0.6)
    gold = M("PartyGold", "#ffd23a", 0.5)
    pom = M("PartyPompom", "#ffd23a", 0.95)
    elastic = M("PartyElastic", "#efe7d2", 0.8)
    z0 = 0.085
    sh = Shell(rx=0.2, ryf=0.19, ryb=0.19, rz=0.2, zf=z0, zb=z0)
    rows = [(0, 1.04, 1, 0.0), (0.04, 1.0, 1, 0.0), (0.3, 0.74, 1, 0.1), (0.62, 0.42, 1, 0.22),
            (0.9, 0.12, 1, 0.31), (1.0, 0.0, 1, 0.335)]
    f = lath_fn(sh, rows)
    P = [lath(sh, col, rows, nu=32, nv=16, name="Body")]
    P.append(lath(sh, gold, rows, nu=32, nv=2, name="Band", grow=0.003, v0=0.0, v1=0.07))
    # dots in staggered rows
    for j, v in enumerate((0.3, 0.46, 0.62, 0.78)):
        cnt = (9, 7, 6, 4)[j]
        for k in range(cnt):
            u = (k + 0.5 * (j % 2)) / cnt
            p = f(u, v)
            n = surf_normal(f, u, v)
            P.append(ellip(dot, p + n * 0.001, (0.0135, 0.0035, 0.0135), n=n, nu=8, nv=3, name="Dot"))
    tip = f(0, 1.0)
    P += fuzz_ball(pom, tip + V((0, 0, 0.012)), 0.052, n=10, name="Pompom")
    # elastic: from both rim sides, down the cheeks, under the chin
    for s in (-1, 1):
        pts = [V((s * 0.19, 0.0, z0 - 0.005)), V((s * 0.248, -0.02, -0.03))]
        for e in (-0.32, -0.7, -1.05, -1.3, -1.47):
            c = math.cos(e)
            pts.append(V((s * HEAD_R[0] * 1.07 * c, -0.04, HEAD_C.z + HEAD_R[2] * 1.07 * math.sin(e))))
        pts.append(V((0, -0.04, HEAD_C.z - HEAD_R[2] * 1.07)))
        P.append(tube(elastic, pts, 0.0045, samples=40, seg=5, name="Elastic"))
    tilt(P[:-2], pitch_deg=6.0, roll_deg=-9.0, pivot=(0, 0, z0))
    return P


# ------------------------------------------------------------------------------------------------ fez
def hat_fez():
    red = M("FezRed", "#b3221d", 0.85)
    black = M("FezBlack", "#1d1a1f", 0.7)
    gold = M("FezGold", "#e6b43a", 0.4, metallic=0.5)
    z0 = 0.048
    sh = Shell(rx=0.21, ryf=0.2, ryb=0.2, rz=0.2, zf=z0, zb=z0)
    H = 0.2
    rows = [(0, 1.03, 1, 0.0), (0.06, 1.0, 1, 0.012), (0.72, 0.82, 1, H - 0.03), (0.86, 0.79, 1, H - 0.005),
            (0.95, 0.68, 1, H + 0.004), (0.99, 0.4, 1, H + 0.007), (1.0, 0.0, 1, H + 0.008)]
    P = [lath(sh, red, rows, nu=36, nv=16, name="Body")]
    P.append(rim_tube(red, sh, 0.006, grow=0.003, dz=0.002))
    top = z0 + H + 0.008
    P.append(ellip(gold, V((0, 0, top)), (0.026, 0.026, 0.013), nu=12, nv=6, name="Button"))
    # cord over the side and the tassel
    cord = [V((0.0, 0, top + 0.004)), V((0.06, 0, top + 0.012)), V((0.125, 0, top - 0.005)),
            V((0.172, 0, z0 + H - 0.035)), V((0.2, 0, z0 + 0.1))]
    P.append(tube(gold, cord, 0.0065, samples=30, seg=6, name="Cord"))
    cx, cz = 0.205, z0 + 0.092
    P.append(ellip(gold, V((cx, 0, cz + 0.005)), (0.017, 0.017, 0.017), nu=10, nv=6, name="TasselCap"))
    P.append(ellip(black, V((cx, 0, cz - 0.04)), (0.024, 0.024, 0.052), nu=12, nv=8, name="TasselHead"))
    for i in range(7):
        a = 2 * PI * i / 7
        x0, y0 = cx + 0.02 * math.cos(a), 0.02 * math.sin(a)
        P.append(tube(black, [V((x0, y0, cz - 0.07)), V((x0 * 1.0 + 0.004 * math.cos(a), y0 + 0.004 * math.sin(a), cz - 0.105))],
                      0.0042, samples=6, seg=5, name="Strand"))
    tilt(P, pitch_deg=-4.0, roll_deg=-5.0, pivot=(0, 0, z0))
    return P


# ------------------------------------------------------------------------------------------------ beret
def hat_beret():
    col = M("HatTint", "#8a3fd0", 0.95)
    band = M("BeretBand", "#2f2420", 0.7)
    sh = Shell(rx=0.252, ryf=0.235, ryb=0.285, rz=0.24, zf=0.05, zb=-0.03)
    rows = [(0, 1.0, 1, 0.0), (0.1, 1.03, 1, 0.02), (0.28, 1.2, 0.5, 0.062), (0.5, 1.22, 0.1, 0.112),
            (0.74, 1.0, 0.0, 0.158), (0.92, 0.55, 0.0, 0.18), (1.0, 0.0, 0.0, 0.185)]

    def wob(th, v):  # soft pucker folds around the bulge
        return 1.0 + 0.012 * math.cos(9 * th) * math.sin(PI * min(1.0, v * 1.25)) * (1 - v)
    P = [lath(sh, col, rows, nu=48, nv=16, name="Body", wob=wob)]
    P.append(lath(sh, band, rows, nu=36, nv=2, name="Band", grow=0.004, v0=0.0, v1=0.085))
    P.append(ellip(col, V((0, 0, 0.19)), (0.017, 0.017, 0.026), nu=10, nv=6, name="Stalk"))
    rot_about(P, (0, 0, 0.0), ry=D(-11), rx=D(-3))
    for o in P:
        xf(o, Matrix.Translation(V((0.012, -0.005, 0.0))))
    return P


# ------------------------------------------------------------------------------------------------ cap
def hat_cap():
    tint = M("HatTint", "#e0463c", 0.8)
    peak_m = M("CapPeak", "#f3f0e8", 0.55)
    under = M("CapUnder", "#2a2a33", 0.7)
    sh = Shell(rx=0.266, ryf=0.242, ryb=0.3, rz=0.262, zc=-0.085, zf=0.048, zb=-0.035)

    def dome(u, v):
        th = 2 * PI * u
        return sh.pt(th, v)
    P = [grid(tint, dome, 48, 12, closed=True, name="Body")]
    # panel seams
    for i in range(6):
        th = D(30 + 60 * i)
        pts = [sh.pt(th, v, 0.0025) for v in (0.02, 0.18, 0.4, 0.62, 0.82, 0.97)]
        P.append(tube(tint, pts, 0.0045, samples=10, seg=4, name="Seam"))
    top = sh.pt(0, 1.0)
    P.append(ellip(tint, top + V((0, 0, 0.002)), (0.024, 0.024, 0.014), nu=12, nv=6, name="Button"))
    # hem band (sweatband look)
    P.append(rim_tube(tint, sh, 0.0075, grow=0.004, dz=0.004, name="Hem"))
    # front badge
    u0, v0 = 0.0, 0.5
    p = dome(u0, v0)
    n = surf_normal(dome, u0, v0)
    P.append(ellip(peak_m, p + n * 0.002, (0.036, 0.004, 0.036), n=n, nu=14, nv=3, name="Badge"))
    # peak: bent superellipse plate, pitched down, root hidden inside the crown
    peak = disc(peak_m, V((0, -0.31, 0.0)), 0.185, 0.17, 0.0105, name="Peak", sq=2.5)
    for v in peak.data.vertices:
        v.co.z -= 0.5 * v.co.x ** 2
    xf(peak, Matrix.Translation(V((0, 0, 0.04))))
    P.append(peak)
    ub = disc(under, V((0, -0.31, 0.0)), 0.181, 0.166, 0.004, name="PeakUnder", sq=2.5)
    for v in ub.data.vertices:
        v.co.z -= 0.5 * v.co.x ** 2 + 0.0072
    xf(ub, Matrix.Translation(V((0, 0, 0.04))))
    P.append(ub)
    rot_about([peak, ub], (0, -0.24, 0.045), rx=D(14))
    return P


# ------------------------------------------------------------------------------------------------ santa
def hat_santa():
    red = M("SantaRed", "#d52a2a", 0.85)
    white = M("SantaWhite", "#fbf8f0", 0.97)
    sh = Shell(rx=0.255, ryf=0.235, ryb=0.285, rz=0.25, zc=-0.08, zf=0.06, zb=-0.03)
    ztop = 0.14
    kq = 0.9
    rows = [(0, 1.0, 1, 0.0), (0.4, 0.99, 0.4, 0.062), (1.0, kq, 0.0, ztop)]
    P = [lath(sh, red, rows, nu=32, nv=4, name="Body")]
    spine = bezier((0, 0.012, ztop - 0.03), (0.0, 0.0, ztop + 0.25), (0.11, 0.22, ztop + 0.32), (0.205, 0.385, ztop + 0.06))

    def section(th, t):
        s = 1.012 - 0.9 * t ** 0.85
        return (sh.rx * kq * s * math.sin(th), -sh.ry(th) * kq * s * math.cos(th))
    P.append(sweep(red, spine, section, nv=16, nu=32, name="Body"))
    end = spine(1.0)
    P += fuzz_ball(white, end + V((0.0, 0.012, -0.0)), 0.076, n=10, name="Bobble")

    N = 16

    def trim(u, a):
        th = 2 * PI * u
        c, s = math.cos(2 * PI * a), math.sin(2 * PI * a)
        w = 0.026 * spow(c, 0.66)
        h = 0.04 * spow(s, 0.66)
        base = sh.pt(th, 0)
        p = V((base.x, base.y, 0)) + sh.hnorm(th) * (0.034 + w + 0.004 * math.cos(N * th))
        p.z = base.z + 0.004 + h
        return p
    P.append(grid(white, trim, 56, 10, closed=True, name="Trim"))
    tilt(P, pitch_deg=-1.0)
    return P


# ------------------------------------------------------------------------------------------------ headphones
def hat_headphones():
    band_m = M("PhoneBand", "#2c2b33", 0.45)
    tint = M("HatTint", "#e8483f", 0.4)
    cush = M("PhoneCushion", "#1f1e25", 0.9)
    ring_m = M("PhoneRing", "#f3f0ea", 0.35)
    c = V((0, 0.004, -0.075))
    rx_b, rz_b = 0.285, 0.232

    def spine(t):
        a = PI * t
        return c + V((rx_b * math.cos(a), 0.0, rz_b * math.sin(a)))

    def section(th, t):
        return (0.0145 * spow(math.cos(th), 2 / 4), 0.03 * spow(math.sin(th), 2 / 4))
    P = [sweep(band_m, spine, section, nv=26, nu=16, name="Band")]
    for s in (-1, 1):
        P.append(ellip(cush, V((s * 0.252, 0.01, -0.075)), (0.04, 0.108, 0.124), nu=18, nv=8, name="Cushion", sq=2.4))
        P.append(ellip(tint, V((s * 0.322, 0.01, -0.075)), (0.052, 0.12, 0.138), nu=22, nv=9, name="Cup", sq=2.5))
        P.append(ellip(ring_m, V((s * 0.368, 0.01, -0.075)), (0.012, 0.086, 0.1), nu=18, nv=5, name="Ring", sq=2.3))
        P.append(ellip(cush, V((s * 0.374, 0.01, -0.075)), (0.012, 0.06, 0.072), nu=16, nv=5, name="Plate", sq=2.3))
    return P


# ------------------------------------------------------------------------------------------------ frog
def hat_frog():
    green = M("FrogGreen", "#5bb83a", 0.7)
    light = M("FrogLight", "#9be05c", 0.7)
    dark = M("FrogDark", "#1f3014", 0.6)
    white = M("FrogEye", "#fbfbf3", 0.3)
    black = M("FrogPupil", "#15151a", 0.2)
    sh = DropShell(sd=0.05, rx=0.265, ryf=0.24, ryb=0.29, rz=0.248, zc=-0.08, zf=0.06, zb=-0.03)

    def dome(u, v):
        th = 2 * PI * u
        return sh.pt(th, v)
    P = [grid(green, dome, 48, 12, closed=True, name="Body")]
    P.append(rim_tube(light, sh, 0.0085, grow=0.004, dz=0.0, name="Hem"))
    for s in (-1, 1):
        ex, ey, ez = s * 0.1, -0.07, 0.19
        P.append(ellip(green, V((ex, ey + 0.012, ez - 0.03)), (0.09, 0.085, 0.08), nu=14, nv=7, name="Socket"))
        P.append(ellip(white, V((ex, ey - 0.012, ez + 0.004)), (0.07, 0.07, 0.07), nu=14, nv=7, name="Eye"))
        d = V((s * 0.05, -1.0, 0.18)).normalized()
        P.append(ellip(black, V((ex, ey - 0.012, ez + 0.004)) + d * 0.062, (0.032, 0.01, 0.04), n=d, nu=12, nv=5, name="Pupil"))
        P.append(ellip(green, V((ex, ey - 0.004, ez + 0.03)), (0.077, 0.075, 0.042), nu=14, nv=5, name="Lid"))
    # smile along the front of the hood
    pts = []
    for i in range(11):
        a = (i / 10 - 0.5) * 2 * D(52)
        v = 0.045 + 0.2 * (abs(a) / D(52)) ** 1.9
        pts.append(sh.pt(a, v, 0.0045))
    P.append(tube(dark, pts, 0.0072, samples=24, seg=5, name="Smile"))
    for s in (-1, 1):
        P.append(ellip(dark, sh.pt(s * D(9), 0.5, 0.002), (0.009, 0.006, 0.009), n=V((0, -1, 0.3)), nu=8, nv=4, name="Nostril"))
    return P


# ------------------------------------------------------------------------------------------------ halo
def hat_halo():
    gold = M("HaloGold", "#ffd84a", 0.3, emission="#ffc21a", emission_strength=4.0)
    R, r = 0.19, 0.04
    cz = 0.27

    def f(u, v):
        th, ph = 2 * PI * u, 2 * PI * v
        rr = R + r * math.cos(ph)
        return V((rr * math.cos(th), rr * math.sin(th), r * 0.82 * math.sin(ph)))
    ring = grid(gold, f, 40, 12, closed=True, name="Float")
    xf(ring, Matrix.Translation(V((0, 0.02, cz))) @ Matrix.Rotation(D(-6), 4, "X") @ Matrix.Rotation(D(4), 4, "Y"))
    return [ring]


HATS = {"cone": hat_cone, "party": hat_party, "fez": hat_fez, "beret": hat_beret, "cap": hat_cap,
        "santa": hat_santa, "headphones": hat_headphones, "frog": hat_frog, "halo": hat_halo}


def build(hid):
    artlib.reset_scene()
    parts = HATS[hid]()
    if hid not in ("headphones", "halo"):
        clearance(hid, [p for p in parts if p.name.split(".")[0] == "Body"])
    tris = sum(len(q.vertices) - 2 for p in parts for q in p.data.polygons)
    print("HAT %s: %d parts, ~%d faces" % (hid, len(parts), tris))
    if hid == "halo":
        parts[0].name = "Float"
        parts[0].data.name = "Float"
        for o in parts:
            bpy.context.view_layer.objects.active = o
        artlib.export_glb("hat_halo")
        return
    artlib.join(parts, "Hat" + hid.title().replace("_", ""))
    artlib.export_glb("hat_" + hid)


ids = artlib.script_args() or list(HATS)
for i in ids:
    build(i)
