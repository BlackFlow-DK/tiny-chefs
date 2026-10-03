"""Chef outfits: outfit_<id>.glb, authored in chef space (origin at the chef's feet), worn over the body.
Run: tools/blender-run.ps1 art/scripts/outfits.py   (optional arg: one outfit id)

Built on the chef's jacket shape (wear_parts.py); every piece sits 1 to 6 cm off the jacket so it never z-fights
or sinks into the body, and the tinted jacket stays visible from above and behind (bibs, belts, collars, shoulder
pieces; no full covers).
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import artlib  # noqa: E402
from mathutils import Vector  # noqa: E402
from wear_parts import (PI, cyl, ellip, jang, jnormal, jpt, loop_ribbon, prism, rbox, sheet, star_outline,  # noqa: E402
                        strip, to_chef, tris, tube, waist_band, wrap_pt, smooth, jr)

M = artlib.material


def V(*a):
    return Vector(a[0] if len(a) == 1 else a)


def smoothstep(a, b, x):
    return smooth(a, b, x)


# ------------------------------------------------------------------ shared pieces
def apron_f(span=70, z_top=0.405, z_bot=0.165, off0=0.05, off1=0.026):
    def f(u, v):
        th = (u - 0.5) * 2 * math.radians(span)
        z = z_top - (z_top - z_bot) * v - 0.02 * abs(u * 2 - 1) ** 2 * v
        off = off0 + off1 * math.sqrt(v)
        p = jang(th, min(max(z, 0.19), 0.42), off)
        p.z = z
        return p
    return f


def apron_shell(mat, f, name="ApronShell", inner=None):
    return sheet(mat, f, 14, 8, 0.012, name=name, inner=inner, flip=False)


def on_jacket(x, z, off):
    p = jpt(x, z, off)
    q = jpt(x, z, off + 0.01)
    return p, (q - p).normalized()


# ------------------------------------------------------------------ stripes
def outfit_stripes():
    cream = M("StripeCream", "#f6f0e1", 0.8)
    red = M("StripeRed", "#d33a2c", 0.78)
    P = []
    f = apron_f()
    P.append(apron_shell(cream, f))
    n = 7
    for k in range(n):
        u0, u1 = (2 * k + 0.4) / (2 * n), (2 * k + 1.6) / (2 * n)  # red stripes between cream gaps
        P.append(sheet(red, lambda u, v, u0=u0, u1=u1: f(u0 + (u1 - u0) * u, v) + (jnormal(f(u0 + (u1 - u0) * u, v)) * 0.0), 1, 8,
                       0.01, name="Stripe", flip=False))
    # shift stripes slightly outward by rebuilding with bigger offset
    for o in P[1:]:
        for v in o.data.vertices:
            p = V((v.co.x, v.co.y, 0))
            if p.length > 1e-6:
                v.co += p.normalized() * 0.0035
    hem = [f(u / 12.0, 1.0) + V((0, 0, 0.0)) for u in range(13)]
    P.append(tube(red, hem, 0.012, samples=24, seg=8, name="Hem"))
    P.append(waist_band(red, 0.385, 0.43, 0.042, 0.042, -PI * 0.55, PI * 0.55, bulge=0.008, nu=22, name="Waist"))
    # bib-less apron: a front pocket in stripe colour
    p, nrm = on_jacket(0.0, 0.29, 0.082)
    P.append(prism(red, [(-0.07, 0.04), (0.07, 0.04), (0.07, -0.035), (0.0, -0.06), (-0.07, -0.035)], p, nrm, depth=0.012,
                   name="Pocket", round_iters=1))
    return P


# ------------------------------------------------------------------ tuxedo
def outfit_tuxedo():
    black = M("TuxBlack", "#1c1c23", 0.4)
    white = M("TuxShirt", "#fbfaf4", 0.7)
    crim = M("TuxCrimson", "#b3213a", 0.45)
    P = []
    ztop, zbot = 0.742, 0.44

    def shirt(u, v):
        z = ztop - (ztop - zbot) * v
        w = 0.112 * (1 - v) ** 0.85 + 0.018
        return jpt((u * 2 - 1) * w, z, 0.03 + 0.008 * math.sin(PI * min(v * 1.5, 1)))
    P.append(sheet(white, shirt, 8, 10, 0.008, name="Shirt", flip=False))
    for s in (-1, 1):
        def lap(u, v, s=s):
            z = 0.75 - 0.30 * v
            xc = s * (0.15 - 0.115 * v ** 1.1)
            w = 0.07 * (1 - v ** 1.6) + 0.004
            return jpt(xc + (u - 0.5) * w * s, z, 0.036 + 0.006 * math.sin(PI * v))
        P.append(sheet(black, lap, 3, 10, 0.009, name="Lapel", flip=False))
        # lapel peak notch
        p = jpt(s * 0.118, 0.7, 0.045)
        P.append(ellip(black, p, (0.026, 0.012, 0.018), rot=(0, s * 0.5, 0), nu=8, nv=4, name="Notch"))
    for z in (0.64, 0.57, 0.50):
        p = jpt(0.0, z, 0.04)
        P.append(ellip(black, p, (0.012, 0.007, 0.012), nu=6, nv=4, name="Stud"))
    # bow tie
    c = V((0.0, jpt(0, 0.738, 0.03).y - 0.022, 0.738))
    for s in (-1, 1):
        P.append(ellip(crim, c + V((s * 0.052, 0.0, 0.0)), (0.056, 0.02, 0.034), rot=(0, s * 0.18, 0), nu=10, nv=6, name="BowWing"))
    P.append(ellip(M("TuxKnot", "#8f1a2e", 0.45), c + V((0, -0.006, 0)), (0.024, 0.022, 0.028), nu=8, nv=5, name="BowKnot"))
    # cummerbund with pleats
    P.append(waist_band(crim, 0.335, 0.445, 0.038, 0.038, -PI * 0.66, PI * 0.66, bulge=0.008, nu=30, nv=5, name="Cummerbund"))
    for z in (0.375, 0.40, 0.425):
        pts = [jang(th, z, 0.056) for th in [math.radians(a) for a in range(-52, 53, 13)]]
        P.append(tube(M("TuxPleat", "#8f1a2e", 0.5), pts, 0.004, samples=10, seg=5, name="Pleat"))
    return P


# ------------------------------------------------------------------ overalls
def outfit_overalls():
    denim = M("OverallDenim", "#2f5384", 0.85)
    dark = M("OverallDenimDark", "#223e66", 0.85)
    gold = M("OverallButton", "#e5b43c", 0.3, metallic=0.6)
    stitch = M("OverallStitch", "#f0b457", 0.7)
    P = []
    zt, zb = 0.668, 0.49

    def bib(u, v):
        z = zt - (zt - zb) * v
        w = 0.105 + 0.03 * v
        return jpt((u * 2 - 1) * w, z, 0.032 + 0.006 * math.sin(PI * v))
    P.append(sheet(denim, bib, 8, 8, 0.01, name="Bib", flip=False))
    # top border + stitching
    top = [jpt(x, zt + 0.002, 0.04) for x in (-0.092, -0.046, 0.0, 0.046, 0.092)]
    P.append(tube(dark, top, 0.008, samples=10, seg=6, name="BibTop"))
    # pocket
    def pocket(u, v):
        return jpt((u * 2 - 1) * 0.052, 0.608 - 0.07 * v, 0.047)
    P.append(sheet(dark, pocket, 2, 4, 0.008, name="Pocket", flip=False))
    pk = [jpt(x, 0.608, 0.056) for x in (-0.046, 0.0, 0.046)]
    P.append(tube(stitch, pk, 0.004, samples=6, seg=4, name="PocketStitch"))
    # waistband all round (above the apron bow)
    P.append(waist_band(dark, 0.45, 0.505, 0.036, 0.036, -PI, PI, bulge=0.008, nu=40, name="Waistband"))
    # shoulder straps, front to back
    for s in (-1, 1):
        def xc(a, s=s):
            return s * (0.108 + 0.098 * math.sin(PI * (a - 24) / 176))
        P.append(strip(denim, xc, 24, 200, 0.05, off=0.03, thick=0.01, n=18, name="Strap"))
        P.append(ellip(gold, jpt(s * 0.115, 0.655, 0.05), (0.017, 0.01, 0.017), n=(0, -1, 0.2), nu=8, nv=4, name="Button"))
        p, _n = wrap_pt(s * 0.13, 196, 0.04)
        P.append(ellip(gold, p, (0.017, 0.012, 0.017), n=(0, 1, -0.2), nu=8, nv=4, name="BackButton"))
    return P


# ------------------------------------------------------------------ hero
def outfit_hero():
    red = M("HeroRed", "#d62839", 0.45)
    gold = M("HeroGold", "#f2b926", 0.35, metallic=0.4)
    belt = M("HeroBelt", "#ecc331", 0.5)
    pouch = M("HeroPouch", "#b8841e", 0.6)
    black = M("HeroBuckle", "#2a2630", 0.4)
    P = []
    zc = 0.545
    p0 = jpt(0.0, zc, 0.034)
    nrm = jnormal(jpt(0.0, zc, 0.0))
    shield = [(-0.082, 0.082), (0.082, 0.082), (0.09, -0.01), (0.0, -0.09), (-0.09, -0.01)]
    P.append(prism(gold, shield, p0, nrm, depth=0.016, inset=0.1, name="EmblemRim", round_iters=1, scale=1.0))
    P.append(prism(red, shield, p0 + nrm * 0.012, nrm, depth=0.014, inset=0.1, name="EmblemField", round_iters=1, scale=0.8))
    P.append(prism(gold, star_outline(5, 0.058, 0.026), p0 + nrm * 0.024, nrm, depth=0.014, inset=0.15, name="EmblemStar",
                   round_iters=0, scale=1.0))
    # utility belt over the apron band, bulging at the back to cover the bow
    P.append(waist_band(belt, 0.335, 0.405, 0.046, 0.095, -PI, PI, bulge=0.01, nu=40, name="Belt"))
    # buckle
    bp = jang(0.0, 0.37, 0.066)
    P.append(prism(black, [(-0.036, 0.034), (0.036, 0.034), (0.036, -0.034), (-0.036, -0.034)], bp, jnormal(jang(0, 0.375, 0.0)),
                   depth=0.012, name="Buckle", round_iters=1))
    P.append(prism(gold, star_outline(5, 0.026, 0.012), bp + jnormal(jang(0, 0.375, 0.0)) * 0.012, jnormal(jang(0, 0.375, 0.0)),
                   depth=0.008, name="BuckleStar", round_iters=0))
    # pouches
    for deg in (-62, -92, 62, 92, 150, -150):
        th = math.radians(deg)
        c = jang(th, 0.36, 0.075)
        n = jnormal(jang(th, 0.36, 0.0))
        P.append(rbox(pouch, c, (0.07, 0.05, 0.075), n=n, sq=3.5, nu=10, nv=6, name="Pouch"))
        P.append(rbox(belt, c + n * 0.022 + V((0, 0, 0.032)), (0.07, 0.012, 0.022), n=n, sq=3.5, nu=8, nv=4, name="PouchFlap"))
    return P


# ------------------------------------------------------------------ bbq
def flame_outline():
    return [(0.0, 0.12), (0.02, 0.07), (0.05, 0.095), (0.062, 0.03), (0.085, 0.0), (0.08, -0.05), (0.04, -0.095),
            (0.0, -0.105), (-0.04, -0.095), (-0.08, -0.05), (-0.085, -0.005), (-0.05, 0.02), (-0.04, 0.07), (-0.015, 0.045)]


def outfit_bbq():
    char = M("BbqApron", "#3a3a42", 0.85)
    trim = M("BbqTrim", "#c8352b", 0.75)
    orange = M("BbqFlameOrange", "#ff7a1a", 0.5)
    yellow = M("BbqFlameYellow", "#ffd23a", 0.5)
    mitt = M("BbqMitt", "#d9532a", 0.8)
    mitt2 = M("BbqMittCuff", "#f1e7cf", 0.8)
    P = []
    f = apron_f()
    P.append(apron_shell(char, f))
    hem = [f(u / 12.0, 1.0) for u in range(13)]
    P.append(tube(trim, hem, 0.012, samples=24, seg=8, name="Hem"))
    P.append(waist_band(trim, 0.385, 0.43, 0.045, 0.045, -PI * 0.55, PI * 0.55, bulge=0.008, nu=22, name="Waist"))
    # flame
    zc = 0.29
    p0 = jang(0.0, zc, 0.074)
    p0.z = zc
    nrm = (jnormal(jang(0.0, zc, 0.0)) + V((0, 0, 0.22))).normalized()
    P.append(prism(orange, flame_outline(), p0, nrm, depth=0.018, inset=0.12, name="Flame", scale=1.3))
    P.append(prism(yellow, flame_outline(), p0 + nrm * 0.015, nrm, depth=0.014, inset=0.12, name="FlameCore", scale=0.8))
    # side pocket + hanging mitt
    sx = -0.16
    pp, pn = on_jacket(sx, 0.285, 0.085)
    P.append(prism(M("BbqPocket", "#2b2b32", 0.85), [(-0.05, 0.04), (0.05, 0.04), (0.05, -0.04), (-0.05, -0.04)], pp, pn,
                   depth=0.01, name="Pocket", round_iters=1))
    mp = V(pp) + pn * 0.03 + V((0.0, 0.0, 0.012))
    P.append(ellip(mitt, mp + V((0, 0, -0.045)), (0.05, 0.02, 0.07), n=pn, rot=(0, 0.1, 0), nu=10, nv=6, name="Mitt"))
    P.append(ellip(mitt, mp + V((-0.04 * -1 * -1, 0.0, -0.065)), (0.02, 0.016, 0.035), n=pn, rot=(0, -0.7, 0), nu=8, nv=5, name="MittThumb"))
    P.append(ellip(mitt2, mp + V((0, 0, 0.015)), (0.052, 0.022, 0.018), n=pn, nu=10, nv=5, name="MittCuff"))
    for dz in (-0.03, -0.075):
        P.append(tube(M("BbqQuilt", "#b8431f", 0.8), [mp + V((-0.04, 0, dz)), mp + V((0.0, -0.008, dz - 0.004)), mp + V((0.04, 0, dz))],
                      0.0032, samples=6, seg=4, name="Quilt"))
    return P


# ------------------------------------------------------------------ knight
def outfit_knight():
    steel = M("KnightSteel", "#b3bcc9", 0.32, metallic=0.75)
    dark = M("KnightSteelDark", "#7e8794", 0.4, metallic=0.7)
    gold = M("KnightGold", "#e3b13a", 0.3, metallic=0.8)
    leather = M("KnightLeather", "#5a3a26", 0.7)
    P = []
    z0, z1 = 0.47, 0.70
    th_span = math.radians(56)

    def plate(u, v):
        th = (u - 0.5) * 2 * th_span * (1.0 - 0.22 * v)
        z = z1 - (z1 - z0) * v
        # waist taper: plate hugs the torso, a little proud at the chest
        off = 0.03 + 0.016 * math.sin(PI * min(v * 1.2, 1.0)) ** 0.7
        x_, _y = jang(th, z, off).x, 0
        ridge = 0.016 * math.exp(-(x_ / 0.045) ** 2)
        p = jang(th, z, off + ridge)
        p.z = z
        return p
    P.append(sheet(steel, plate, 18, 8, 0.014, name="Breastplate", flip=False))
    # gold trim along the bottom + neck edge, central ridge, rivets
    bot = [plate(u / 16.0, 1.0) + V((0, -0.002, 0)) for u in range(17)]
    P.append(tube(gold, bot, 0.009, samples=20, seg=6, name="TrimBottom"))
    topp = [plate(u / 16.0, 0.0) for u in range(17)]
    P.append(tube(gold, topp, 0.009, samples=20, seg=6, name="TrimTop"))
    for ue in (0.0, 1.0):
        P.append(tube(gold, [plate(ue, v / 6.0) for v in range(7)], 0.008, samples=10, seg=5, name="TrimSide"))
    P.append(tube(dark, [plate(0.5, v / 6.0) for v in range(1, 6)], 0.007, samples=10, seg=5, name="Ridge"))
    for u in (0.12, 0.3, 0.7, 0.88):
        P.append(ellip(gold, plate(u, 0.12) + V((0, -0.006, 0)), (0.011, 0.008, 0.011), nu=6, nv=4, name="Rivet"))
    # pauldrons
    for s in (-1, 1):
        c = V((s * 0.272, -0.005, 0.655))
        P.append(ellip(steel, c, (0.118, 0.105, 0.092), rot=(0, s * -0.55, 0), nu=14, nv=8, name="Pauldron"))
        P.append(ellip(dark, c + V((s * 0.012, 0, 0.034)), (0.08, 0.074, 0.056), rot=(0, s * -0.55, 0), nu=12, nv=6, name="PauldronTop"))
        P.append(ellip(gold, c + V((s * 0.013, 0, 0.074)), (0.016, 0.016, 0.012), nu=6, nv=4, name="Stud"))
        pts = [c + V((s * 0.0, 0.0, 0.0)) + V(math.cos(a) * 0.098 * 0.0, 0, 0) for a in (0,)]
        # lower gold rim (ring tilted with the plate)
        ring_pts = []
        for i in range(18):
            a = 2 * PI * i / 18
            q = V((math.cos(a) * 0.118, math.sin(a) * 0.105, 0.0))
            # tilt about Y by -0.55*s
            t = s * -0.55
            qx, qz = q.x * math.cos(t) + 0.0, -q.x * math.sin(t)
            ring_pts.append(c + V((qx, q.y, qz - 0.006)))
        P.append(tube(gold, ring_pts, 0.007, seg=6, closed=True, name="PauldronRim"))
    # leather straps over the back
    for s in (-1, 1):
        P.append(strip(leather, lambda a, s=s: s * (0.12 + 0.02 * math.sin(PI * (a - 90) / 100)), 95, 195, 0.03, off=0.022, thick=0.008, n=8, name="Strap"))
    return P


# ------------------------------------------------------------------ scarf
def outfit_scarf():
    red = M("ScarfRed", "#c9402f", 0.95)
    cream = M("ScarfCream", "#f4e7c9", 0.95)
    P = []
    # wrapped around the neck: about 1.4 turns, ribbed
    pts = []
    for i in range(0, 41):
        t = i / 40.0
        th = 2 * PI * 1.4 * t + PI
        z = 0.742 + 0.014 * math.sin(PI * t) + 0.012 * t
        pts.append(V((0.162 * math.sin(th) * 1.0, -0.14 * math.cos(th), z)))
    P.append(tube(red, pts, lambda t: 0.042 + 0.004 * math.cos(t * 60), samples=60, seg=8, name="Wrap"))
    # stripe rings
    for z, dr in ((0.742, 0.0),):
        pass
    # knot at the front-right and tails
    kc = V((0.075, jpt(0.075, 0.715, 0.05).y, 0.715))
    P.append(ellip(red, kc, (0.05, 0.036, 0.042), nu=10, nv=6, name="Knot"))
    # long tail down the front, stripes
    def tail(x0, x1, ztop, zbot, w, off, phase):
        def f(u, v, a=0.0, b=1.0):
            vv = a + (b - a) * v
            z = ztop - (ztop - zbot) * vv
            x = x0 + (x1 - x0) * vv + 0.012 * math.sin(vv * 5 + phase)
            ww = w * (1.0 + 0.1 * vv)
            return jpt(x + (u - 0.5) * ww, z, off + 0.012 * math.sin(PI * min(vv * 1.4, 1.0)) + 0.006 * vv)
        return f
    f_long = tail(0.07, 0.03, 0.70, 0.30, 0.085, 0.052, 0.0)
    bands = [(0.0, 0.2, red), (0.2, 0.28, cream), (0.28, 0.62, red), (0.62, 0.7, cream), (0.7, 0.9, red), (0.9, 1.0, cream)]
    for a, b, m in bands:
        n = max(2, int((b - a) * 10))
        P.append(sheet(m, lambda u, v, a=a, b=b: f_long(u, a + (b - a) * v), 3, n, 0.012, name="Tail", flip=False))
    # fringe
    for k in range(6):
        u = (k + 0.5) / 6
        p = f_long(u, 1.0)
        P.append(tube(cream, [p, p + V(0, 0, -0.03)], 0.0055, samples=3, seg=4, name="Fringe"))
    f_short = tail(0.1, 0.14, 0.70, 0.5, 0.07, 0.046, 1.5)
    for a, b, m in ((0.0, 0.55, red), (0.55, 0.7, cream), (0.7, 1.0, red)):
        n = max(2, int((b - a) * 6))
        P.append(sheet(m, lambda u, v, a=a, b=b: f_short(u, a + (b - a) * v), 3, n, 0.012, name="Tail2", flip=False))
    for k in range(4):
        u = (k + 0.5) / 4
        p = f_short(u, 1.0)
        P.append(tube(cream, [p, p + V(0, 0, -0.026)], 0.005, samples=3, seg=4, name="Fringe"))
    return P


# ------------------------------------------------------------------ hawaiian
def flower(mat, mat2, p, n, size):
    out = [prism(mat, star_outline(5, size, size * 0.62), p, n, depth=size * 0.5, inset=0.2, round_iters=0, name="Flower",
                 rot=(hash(round(p.x * 1000)) % 70) / 10.0)]
    out.append(ellip(mat2, V(p) + V(n) * size * 0.5, (size * 0.34, size * 0.34, size * 0.3), n=n, nu=6, nv=3, name="FlowerEye"))
    return out


def outfit_hawaiian():
    green = M("LeiLeaf", "#2f9a4a", 0.7)
    cols = [M("LeiPink", "#f0539a", 0.6), M("LeiOrange", "#ff8a2b", 0.6), M("LeiYellow", "#ffd84a", 0.6),
            M("LeiWhite", "#fff4f0", 0.6)]
    eye = M("LeiEye", "#ffd84a", 0.6)
    grass_a = M("GrassA", "#7bbf3d", 0.85)
    grass_b = M("GrassB", "#c4cf4b", 0.85)
    band = M("GrassBand", "#a5774a", 0.8)
    P = []

    def lei_pt(psi):
        d = abs((psi + PI) % (2 * PI) - PI)
        z = 0.738 - 0.145 * math.exp(-(d / 0.78) ** 2)
        off = 0.05 + 0.006 * (0.738 - z) / 0.14
        p = jang(psi, z, off)
        p.z = z
        return p, z
    N = 15
    path = [lei_pt(2 * PI * i / 40)[0] for i in range(41)]
    P.append(tube(green, path, 0.007, samples=60, seg=5, name="LeiString"))
    for i in range(N):
        psi = 2 * PI * (i + 0.5) / N
        p, z = lei_pt(psi)
        n = jnormal(p - V(0, 0, 0)) if False else jnormal(jang(psi, z, 0.0))
        n = (n + V(0, 0, 0.35 if z > 0.7 else 0.15)).normalized()
        P += flower(cols[i % 4], eye, p, n, 0.038)
    # grass skirt
    P.append(waist_band(band, 0.382, 0.418, 0.058, 0.098, -PI, PI, bulge=0.012, nu=32, name="GrassBand", thick=0.014))
    nb = 28
    for k in range(nb):
        th = 2 * PI * k / nb
        long = k % 2 == 0
        zb = 0.40
        zt = 0.205 if long else 0.255
        rot = th

        def f(u, v, th=th, zt=zt, long=long):
            z = 0.40 - (0.40 - zt) * v
            w = 0.034 * (1 - 0.35 * v)
            t_ = th + (u - 0.5) * 2 * w / 0.31
            off = 0.066 + 0.075 * v ** 1.5 + (0.01 if long else 0.0)
            p = jang(t_, z, off)
            p.z = z - 0.006 * math.sin(th * 3)
            return p
        P.append(sheet(grass_a if long else grass_b, f, 1, 2, 0.006, name="Blade", flip=False))
    return P


# ------------------------------------------------------------------ sash
def outfit_sash():
    purple = M("SashPurple", "#7a3fb0", 0.55)
    gold = M("SashGold", "#f1bd2c", 0.3, metallic=0.5)
    red = M("SashRibbon", "#d1303f", 0.6)
    P = []
    th0, amp, zc = -78, 0.185, 0.505
    P.append(loop_ribbon(purple, th0, amp, zc, 0.105, off=0.034, nu=34, name="Sash"))
    P.append(loop_ribbon(gold, th0, amp, zc, 0.012, off=0.04, nu=34, name="SashTrimA"))
    # gold edge stripes via two narrow ribbons offset by width
    for sgn in (-1, 1):
        th0r = math.radians(th0)
        def f(u, v, sgn=sgn):
            th = -PI + 2 * PI * u
            z = zc + amp * math.cos(th - th0r)
            p = jang(th, z, 0.037)
            p.z = z
            t = (jang(th + 0.01, zc + amp * math.cos(th + 0.01 - th0r), 0.037) - jang(th - 0.01, zc + amp * math.cos(th - 0.01 - th0r), 0.037))
            t.normalize()
            n = jnormal(jang(th, z, 0.0))
            w = t.cross(n).normalized()
            return p + w * (sgn * 0.04 + (v - 0.5) * 0.009) + n * 0.003
        P.append(sheet(gold, f, 34, 1, 0.006, closed_u=True, name="Edge"))
    # medal on the front crossing
    thm = math.radians(18)
    zs = zc + amp * math.cos(thm - math.radians(th0))
    c = jang(thm, zs - 0.075, 0.052)
    c.z = zs - 0.075
    n = jnormal(jang(thm, zs - 0.075, 0.0))
    disc = [(0.062 * math.cos(2 * PI * i / 12), 0.062 * math.sin(2 * PI * i / 12)) for i in range(12)]
    P.append(prism(gold, disc, c, n, depth=0.016, inset=0.1, round_iters=0, name="Medal"))
    P.append(prism(red, star_outline(5, 0.034, 0.015), c + n * 0.014, n, depth=0.01, inset=0.1, round_iters=0, name="MedalStar"))
    # medal ribbon (two short tails up to the sash)
    top = jang(thm, zs - 0.02, 0.045)
    top.z = zs - 0.02
    for s in (-1, 1):
        P.append(tube(red, [top + V(s * 0.012, 0, 0), c + V(s * 0.016, 0, 0.034) + n * 0.006], 0.008, samples=4, seg=5, name="MedalRibbon"))
    # bow + tails at the low hip
    thb = math.radians(th0 + 180)
    zb = zc - amp
    bc = jang(thb, zb, 0.06)
    bc.z = zb
    bn = jnormal(jang(thb, zb, 0.0))
    for s in (-1, 1):
        P.append(ellip(purple, bc + V(0, 0, s * 0.0) + V(s * bn.y * 0.04, -s * bn.x * 0.04, 0), (0.045, 0.02, 0.03), n=bn, nu=10, nv=6, name="BowLoop"))
    P.append(ellip(gold, bc + bn * 0.012, (0.024, 0.016, 0.024), n=bn, nu=8, nv=5, name="BowKnot"))
    for s in (-1, 1):
        a = bc + bn * 0.006 + V(0, 0, -0.01)
        P.append(tube(purple, [a, a + V(s * 0.02, 0, -0.07), a + V(s * 0.03, 0, -0.12)], 0.016, samples=6, seg=5, name="BowTail"))
    return P


MAKERS = {
    "stripes": outfit_stripes, "tuxedo": outfit_tuxedo, "overalls": outfit_overalls, "hero": outfit_hero,
    "bbq": outfit_bbq, "knight": outfit_knight, "scarf": outfit_scarf, "hawaiian": outfit_hawaiian, "sash": outfit_sash,
}


def build(oid):
    artlib.reset_scene()
    parts = MAKERS[oid]()
    to_chef(parts)
    t = tris(parts)
    artlib.join(parts, "Outfit" + oid.title().replace("_", ""))
    print("TRIS outfit_%s %d" % (oid, t))
    artlib.export_glb("outfit_" + oid)


only = [a for a in artlib.script_args() if a in MAKERS]
for oid in (only or MAKERS):
    build(oid)
