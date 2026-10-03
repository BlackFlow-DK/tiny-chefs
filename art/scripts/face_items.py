"""Chef beards (beard_<id>.glb, origin = BeardAnchor) and face accessories (acc_<id>.glb, origin = FaceAnchor).

Run: tools/blender-run.ps1 art/scripts/face_items.py [-- id id ...]   (ids: beard ids and acc_ ids; none = all)
Contract: docs/design/cosmetics.md. Authored in the chef raw frame on the standard head (face_parts.py), moved so the
model origin is its anchor: BeardAnchor (0, 0.823, 0.2415), FaceAnchor (0, 0.906, 0.2568), facing +Z in Godot.
The head scales about the neck for body shape big_head and the anchors scale with it, so nothing here needs to change.
"""
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bpy  # noqa: E402,F401
import artlib  # noqa: E402
from face_parts import (BEARD_RAW, FACE_RAW, HR, PI, V, disc_on_head, ellip, frame_ring, grid, hang_sheet, head_az,  # noqa: E402
                        head_norm, head_xz, hug_sheet, loft, report, rrect_loop, sm, solid_patch, tube, tube_on_head,
                        to_anchor)

M = artlib.material
HAIR = "#5a3a26"
WAX = "#34200f"


def mirrored(fn):
    return [fn(-1), fn(1)]


# ================================================================================================ beards
def moustache_tubes(mat, scale=1.0, drop=0.0, name="Mous"):
    out = []
    for s in (-1, 1):
        spec = [(0.0, 0.806, 0.044), (0.05 * s, 0.804, 0.048), (0.1 * s, 0.795, 0.044), (0.145 * s, 0.775 - drop, 0.036)]
        pts = [head_xz(x * scale if i else 0.0, z, o)[0] for i, (x, z, o) in enumerate(spec)]
        out.append(tube(mat, pts, lambda t: 0.009 + 0.02 * (1 - t) ** 1.2, samples=22, seg=7, name=name))
    return out


def beard_handlebar():
    wax = M("BeardWax", WAX, 0.3)
    P = []
    for s in (-1, 1):
        spec = [(0.0, 0.812, 0.056), (0.065, 0.804, 0.058), (0.125, 0.797, 0.052), (0.175, 0.808, 0.046),
                (0.2, 0.84, 0.042), (0.188, 0.874, 0.046), (0.158, 0.886, 0.05), (0.138, 0.868, 0.054),
                (0.148, 0.848, 0.056)]
        pts = [head_xz(s * x, z, o)[0] for x, z, o in spec]
        P.append(tube(wax, pts, lambda t: 0.0075 + 0.026 * (1 - t) ** 1.35, samples=34, seg=8, name="Bar"))
    P.append(ellip(wax, head_xz(0.0, 0.806, 0.058)[0], (0.046, 0.03, 0.034), n=(0, -1, 0), nu=12, nv=7, name="Centre"))
    return to_anchor(P, BEARD_RAW)


def cheek_pads(mat, z=0.785, rx=0.062, rz=0.09, x=0.172, off=0.004):
    out = []
    for s in (-1, 1):
        c, n = head_xz(s * x, z, off)
        out.append(ellip(mat, c, (rx, 0.045, rz), n=n, nu=14, nv=8, name="Cheek"))
    return out


def beard_full():
    hair = M("BeardHair", HAIR, 0.75)
    rows = [(0.75, 0.12, 0.08, -0.075), (0.745, 0.13, 0.085, -0.07), (0.725, 0.19, 0.1, -0.11), (0.69, 0.205, 0.12, -0.12),
            (0.65, 0.18, 0.11, -0.125), (0.605, 0.12, 0.085, -0.14), (0.565, 0.055, 0.045, -0.15), (0.54, 0.0, 0.02, -0.15)]

    def mod(t, z):
        return 1.0 + 0.035 * math.cos(6 * t) * (1.0 if z < 0.7 else 0.0)
    P = [loft(hair, rows, nu=28, nv=12, mod=mod, name="Beard")]
    P += cheek_pads(hair)
    P += moustache_tubes(hair, drop=0.01)
    return to_anchor(P, BEARD_RAW)


def beard_goatee():
    hair = M("BeardHair", HAIR, 0.75)
    rows = [(0.745, 0.04, 0.04, -0.1), (0.73, 0.055, 0.05, -0.12), (0.71, 0.07, 0.065, -0.145), (0.68, 0.065, 0.065, -0.15),
            (0.645, 0.045, 0.05, -0.15), (0.61, 0.022, 0.03, -0.15), (0.59, 0.0, 0.012, -0.15)]
    P = [loft(hair, rows, nu=18, nv=10, name="Goatee")]
    return to_anchor(P, BEARD_RAW)


def beard_mutton():
    hair = M("BeardHair", HAIR, 0.75)
    P = []
    for s in (-1, 1):
        def ztop(th, u):
            return 0.9

        def rng(v):
            mid = 1.37 - 0.38 * v
            hw = 0.075 + 0.5 * sm(v / 0.55)
            if v > 0.78:
                hw *= math.sqrt(max(0.0, 1.0 - ((v - 0.78) / 0.22) ** 2))
            return mid, hw

        def f(u, v, s=s):
            mid, hw = rng(v)
            th = s * (mid + hw * (2 * u - 1))
            z = 0.9 - 0.2 * v
            env = math.sin(PI * u) ** 0.6 * sm(v / 0.12) * max(0.0, 1.0 - v ** 6)
            return head_az(th, z, 0.003 + 0.034 * env)[0]
        P.append(grid(hair, f, 16, 12, closed=False, name="Chop", outward=(0, 0, 0.9)))
    return to_anchor(P, BEARD_RAW)


def beard_wizard():
    white = M("BeardWhite", "#ece8de", 0.8)
    rows = [(0.75, 0.12, 0.08, -0.07), (0.745, 0.13, 0.085, -0.07), (0.725, 0.195, 0.1, -0.11), (0.66, 0.215, 0.1, -0.19),
            (0.56, 0.205, 0.09, -0.205), (0.46, 0.185, 0.08, -0.22), (0.38, 0.135, 0.07, -0.225), (0.32, 0.07, 0.045, -0.225),
            (0.28, 0.0, 0.02, -0.22)]

    def mod(t, z):
        k = 1.0 + 0.07 * math.cos(5 * t + 5 * z) * sm((0.72 - z) / 0.1)
        return k * (1.0 + 0.05 * math.sin(z * 38))
    P = [loft(white, rows, nu=26, nv=19, mod=mod, name="Beard")]
    P += cheek_pads(white)
    for s in (-1, 1):
        spec = [(0.0, 0.808, 0.046), (0.055, 0.8, 0.054), (0.115, 0.775, 0.056), (0.15, 0.735, 0.05)]
        pts = [head_xz(s * x, z, o)[0] for x, z, o in spec]
        pts.append(V((s * 0.17, -0.17, 0.68)))
        pts.append(V((s * 0.155, -0.21, 0.62)))
        P.append(tube(white, pts, lambda t: 0.01 + 0.022 * (1 - t) ** 0.9, samples=26, seg=7, name="Mous"))
    return to_anchor(P, BEARD_RAW)


def beard_stubble():
    shade = M("StubbleShade", "#8c6c5a", 0.95)
    dot = M("StubbleDot", "#2c1d15", 0.9)

    def ztop(th, u):
        return 0.735 + 0.07 * sm(abs(th) / 1.3)

    def f(u, v):
        th = (2 * u - 1) * 1.6
        zt = ztop(th, u)
        z = zt + (0.687 - zt) * v
        return head_az(th, z, 0.0035)[0]
    P = [grid(shade, f, 26, 8, closed=False, name="Shade", outward=(0, 0, 0.9))]
    rnd = random.Random(11)
    n = 0
    while n < 70:
        th = rnd.uniform(-1.75, 1.75)
        z = rnd.uniform(0.69, 0.81)
        edge = ztop(th, 0)
        if z > edge + 0.035:
            continue
        if z < 0.7 and abs(th) < 0.6:
            pass
        p, nrm = head_az(th, z, 0.004)
        P.append(ellip(dot, p, (0.0055, 0.0045, 0.0055), n=nrm, nu=5, nv=3, name="Dot"))
        n += 1
    # upper lip shadow dots
    for _ in range(8):
        x = rnd.uniform(-0.1, 0.1)
        z = rnd.uniform(0.79, 0.805)
        p, nrm = head_xz(x, z, 0.004)
        P.append(ellip(dot, p, (0.0055, 0.0045, 0.0055), n=nrm, nu=5, nv=3, name="Dot"))
    return to_anchor(P, BEARD_RAW)


def beard_soul_patch():
    hair = M("BeardHair", HAIR, 0.75)
    rows = [(0.75, 0.02, 0.02, -0.1), (0.738, 0.034, 0.035, -0.15), (0.715, 0.042, 0.04, -0.155), (0.69, 0.034, 0.036, -0.155),
            (0.67, 0.017, 0.022, -0.155), (0.655, 0.0, 0.01, -0.155)]
    P = [loft(hair, rows, nu=14, nv=9, name="Patch")]
    return to_anchor(P, BEARD_RAW)


def beard_walrus():
    hair = M("BeardHair", HAIR, 0.75)
    dark = M("BeardHairDark", "#46291a", 0.75)
    P = []
    for s in (-1, 1):
        # thick moustache: from under the nose, over the mouth, drooping to just past the chin sides
        spine = [head_xz(s * 0.012, 0.803, 0.05)[0], head_xz(s * 0.06, 0.789, 0.062)[0],
                 head_xz(s * 0.11, 0.766, 0.062)[0], head_az(s * 0.58, 0.765, 0.056)[0],
                 head_az(s * 0.74, 0.755, 0.05)[0], head_az(s * 0.84, 0.745, 0.04)[0]]
        P.append(tube(hair, spine, lambda t: 0.012 + 0.05 * math.sin(PI * min(1.0, 0.3 + 0.95 * (1 - t))) ** 0.8,
                      samples=34, seg=9, name="Walrus"))
        # sculpted strands: tapered locks along the droop, poking out past the end
        for k, (dz, dth, oo) in enumerate(((0.0, 0.0, 0.082), (-0.012, 0.1, 0.07), (0.012, -0.08, 0.066))):
            st = [head_xz(s * 0.07, 0.784 + dz, oo)[0], head_xz(s * 0.12, 0.76 + dz, oo)[0],
                  head_az(s * (0.64 + dth), 0.756 + dz, oo - 0.006)[0], head_az(s * (0.78 + dth), 0.744 + dz, oo - 0.016)[0],
                  head_az(s * (0.86 + dth), 0.73 + dz, oo - 0.024)[0]]
            P.append(tube(dark if k == 1 else hair, st, lambda t: 0.0065 * (1 - t) ** 0.6 + 0.002, samples=18, seg=6,
                          name="Strand"))
    c, n = head_xz(0.0, 0.795, 0.045)
    P.append(ellip(hair, c, (0.085, 0.04, 0.045), n=n, nu=14, nv=8, name="Mass"))
    return to_anchor(P, BEARD_RAW)


# ================================================================================================ accessories
def temples(mat, loop_outer, r, z=0.915, back_y=0.04):
    P = []
    for s in (-1, 1):
        o = max(loop_outer[s], key=lambda p: abs(p.x))
        side = head_xz(s * 0.2, z, 0.013)[0]
        P.append(tube(mat, [o, side, V((s * 0.243, -0.02, z + 0.002)), V((s * 0.243, back_y, z - 0.01))], r,
                      samples=26, seg=6, name="Temple"))
    return P


def acc_sunglasses():
    frame = M("SunFrame", "#1d1c22", 0.28, metallic=0.1)
    lens = M("SunLens", "#0b1018", 0.06, metallic=0.5)
    glint = M("SunGlint", "#b9d3ee", 0.2)
    P = []
    loops = {}
    for s in (-1, 1):
        cx, cz = s * 0.088, 0.903
        loop = rrect_loop(cx, cz, 0.078, 0.062, 3.0, 32, 0.043)
        loops[s] = loop
        P.append(tube(frame, loop, 0.0105, seg=8, closed=True, name="Rim"))
        P.append(disc_on_head(lens, cx, cz, 0.074, 0.058, 3.0, 0.043, nu=24, nv=3, name="Lens"))
        for dx, wd in ((-0.03, 0.009), (-0.012, 0.004)):
            P.append(disc_on_head(glint, cx + dx * s, cz + 0.014, wd, 0.02, 2.2, 0.0475, nu=10, nv=1, rot=0.7 * s,
                                  name="Glint"))
    bl = min(loops[-1], key=lambda p: abs(p.x))
    br = min(loops[1], key=lambda p: abs(p.x))
    top = head_xz(0.0, 0.925, 0.057)[0]
    P.append(tube(frame, [bl, V((-0.02, top.y, top.z - 0.004)), V((0.02, top.y, top.z - 0.004)), br], 0.01, samples=18,
                  seg=7, name="Bridge"))
    P += temples(frame, loops, 0.0085)
    return to_anchor(P, FACE_RAW)


def acc_monocle():
    gold = M("MonocleGold", "#d9ac38", 0.28, metallic=0.85)
    glass = M("MonocleGlass", "#cfe8f4", 0.05, alpha=0.18)
    P = []
    cx, cz = 0.088, 0.905
    loop = rrect_loop(cx, cz, 0.086, 0.086, 2.0, 32, 0.046)
    P.append(tube(gold, loop, 0.0085, seg=8, closed=True, name="Ring"))
    P.append(disc_on_head(glass, cx, cz, 0.082, 0.082, 2.0, 0.046, nu=24, nv=3, name="Glass"))
    # little eyelet where the chain hangs
    a = min(loop, key=lambda p: p.z + 0.4 * abs(p.x - 0.12))
    chain_pts = [a, head_az(0.58, 0.815, 0.032)[0], head_az(0.92, 0.79, 0.03)[0], head_az(1.18, 0.745, 0.026)[0],
                 V((0.2, -0.045, 0.7)), V((0.19, -0.02, 0.69))]
    P.append(ellip(gold, a, (0.011, 0.011, 0.011), nu=8, nv=5, name="Eyelet"))
    P.append(tube(gold, chain_pts, 0.0042, samples=30, seg=5, name="Chain"))
    for t in (0.2, 0.4, 0.6, 0.8):
        pass
    return to_anchor(P, FACE_RAW)


def acc_eyepatch():
    black = M("PatchBlack", "#17151b", 0.55)
    strap_m = M("PatchStrap", "#26222b", 0.6)
    P = []
    cx, cz = -0.088, 0.908
    c, n = head_xz(cx, cz, 0.03)
    P.append(ellip(black, c, (0.082, 0.017, 0.092), n=n, sq=2.6, nu=18, nv=7, name="Patch"))
    # small sheen on the patch
    c2, n2 = head_xz(cx + 0.02, cz + 0.03, 0.0455)
    P.append(ellip(M("PatchSheen", "#3d3a47", 0.3), c2, (0.016, 0.003, 0.02), n=n2, nu=8, nv=3, name="Sheen"))

    def g(th):
        v = sm((th + 0.3) / 0.8)
        if th > 1.5:
            v *= 1.0 - sm((th - 1.9) / 1.2)
        return v

    from face_parts import strip_on_head
    P.append(strip_on_head(strap_m, lambda t: (-PI + 2 * PI * t, 0.945 + 0.08 * g(-PI + 2 * PI * t)), 0.02, 0.008,
                           0.014, n=56, name="Strap", closed=True))
    return to_anchor(P, FACE_RAW)


def acc_clown_nose():
    red = M("NoseRed", "#e3262b", 0.28)
    hi = M("NoseShine", "#ffd9d4", 0.2)
    c = V((0.0, -0.262, 0.848))
    P = [ellip(red, c, 0.06, nu=18, nv=11, name="Ball")]
    d = V((-0.35, -0.8, 0.5)).normalized()
    P.append(ellip(hi, c + d * 0.055, (0.015, 0.006, 0.02), n=d, nu=8, nv=4, name="Shine"))
    return to_anchor(P, FACE_RAW)


def acc_goggles():
    frame = M("GoggleFrame", "#f0701c", 0.4)
    foam = M("GoggleFoam", "#26242b", 0.9)
    lens = M("GoggleLens", "#3aa0e8", 0.08, metallic=0.4)
    strap = M("GoggleStrap", "#232128", 0.8)
    stripe = M("GoggleStripe", "#f6f3ea", 0.7)
    shine = M("GoggleShine", "#d9efff", 0.2)
    from face_parts import strip_on_head
    cz = 0.905
    P = []
    P.append(tube(frame, rrect_loop(0.0, cz, 0.172, 0.078, 3.6, 44, 0.04), 0.0135, seg=8, closed=True, name="Frame"))
    P.append(tube(foam, rrect_loop(0.0, cz, 0.165, 0.071, 3.6, 44, 0.018), 0.011, seg=6, closed=True, name="Foam"))
    P.append(disc_on_head(lens, 0.0, cz, 0.16, 0.069, 3.6, 0.04, nu=44, nv=3, name="Lens"))
    P.append(disc_on_head(shine, -0.07, cz + 0.026, 0.05, 0.007, 2.0, 0.0425, nu=10, nv=1, rot=0.12, name="Shine"))
    th0 = math.asin(0.172 / HR[0] * 0.99) + 0.02
    th1 = 2 * PI - th0

    def path(t):
        return (th0 + (th1 - th0) * t, 0.948)
    # strap lifts off the head over the ears
    side = lambda t: math.sin(th0 + (th1 - th0) * t) ** 2  # noqa: E731
    P.append(strip_on_head(strap, path, 0.048, 0.012, lambda t: 0.022 + 0.016 * side(t), n=48, name="Strap"))
    P.append(strip_on_head(stripe, path, 0.01, 0.006, lambda t: 0.031 + 0.02 * side(t),
                           n=48, name="Stripe"))
    return to_anchor(P, FACE_RAW)


def acc_mask():
    blue = M("MaskBlue", "#2848c8", 0.4)
    rim = M("MaskRim", "#1a2a86", 0.45)
    P = []
    for s in (-1, 1):
        ex, ez = s * 0.088, 0.913
        ia, ib = 0.07, 0.083
        n = 36
        inner, outer = [], []
        for i in range(n):
            a = 2 * PI * i / n
            ca, sa = math.cos(a), math.sin(a)
            # outward direction in (x*s, z): wings up-out and down-out, solid bridge towards the nose
            ox = ca * s
            wing_u = max(0.0, math.cos(a - 0.7)) ** 3
            wing_d = max(0.0, math.cos(a + 0.55)) ** 4
            w = 0.022 + 0.05 * wing_u + 0.028 * wing_d + 0.014 * max(0.0, -ca) ** 2 + 0.01 * max(0.0, sa)
            inner.append(head_xz(ex + s * ia * ca, ez + ib * sa, 0.0)[0])
            outer.append(head_xz(ex + s * (ia + w) * ca * 1.0 + s * 0.0, ez + (ib + w) * sa, 0.0)[0])
        # lift the rows off the head
        inner = [p + head_norm(p) * 0.019 for p in inner]
        outer = [p + head_norm(p) * 0.019 for p in outer]
        P.append(solid_patch(blue, [inner, outer], head_norm, 0.009, closed_u=True, name="Mask", smooth=True))
        P.append(tube(rim, inner, 0.0042, seg=6, closed=True, name="Hole"))
    return to_anchor(P, FACE_RAW)


def acc_3d_glasses():
    card = M("CardWhite", "#f6f3ea", 0.85)
    red = M("LensRed", "#e5232b", 0.15, alpha=0.78)
    cyan = M("LensBlue", "#1f7be8", 0.15, alpha=0.78)
    ink = M("CardInk", "#1b1b22", 0.8)
    from face_parts import strip_on_head
    P = []
    off = 0.04
    for s, lm in ((-1, red), (1, cyan)):
        cx, cz = s * 0.087, 0.905
        P.append(frame_ring(card, cx, cz, 0.064, 0.05, 0.026, 3.5, 32, off, 0.009, name="Card"))
        P.append(disc_on_head(lm, cx, cz, 0.066, 0.052, 3.5, off, nu=28, nv=3, name="Lens"))
        P.append(tube(ink, rrect_loop(cx, cz, 0.066, 0.052, 3.5, 32, off + 0.003), 0.0028, seg=5, closed=True,
                      name="Edge"))
    # temple arms (card strips)
    th0 = math.asin(0.18 / HR[0]) - 0.04
    for s in (-1, 1):
        def path(t, s=s):
            return (s * (th0 + (1.38 - th0) * t), 0.915)
        P.append(strip_on_head(card, path, 0.02, 0.008, lambda t: 0.04 - 0.02 * t, n=14, name="Arm"))
    return to_anchor(P, FACE_RAW)


# ================================================================================================ main
BEARDS = {"handlebar": beard_handlebar, "full": beard_full, "goatee": beard_goatee, "mutton": beard_mutton,
          "wizard": beard_wizard, "stubble": beard_stubble, "soul_patch": beard_soul_patch, "walrus": beard_walrus}
ACCS = {"sunglasses": acc_sunglasses, "monocle": acc_monocle, "eyepatch": acc_eyepatch, "clown_nose": acc_clown_nose,
        "goggles": acc_goggles, "mask": acc_mask, "3d_glasses": acc_3d_glasses}


def build(prefix, ident, maker, anchor):
    artlib.reset_scene()
    parts = maker()
    name = "%s_%s" % (prefix, ident)
    report(name, parts, anchor, check_head=(prefix == "acc"))
    obj = artlib.join(parts, "".join(w.capitalize() for w in name.split("_")))
    artlib.export_glb(name)


want = [a for a in artlib.script_args() if a]
for ident, fn in BEARDS.items():
    if not want or ident in want or "beard_" + ident in want:
        build("beard", ident, fn, BEARD_RAW)
for ident, fn in ACCS.items():
    if not want or ident in want or "acc_" + ident in want:
        build("acc", ident, fn, FACE_RAW)
