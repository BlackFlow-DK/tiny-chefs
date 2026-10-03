"""Hats, set A: cowboy, crown, viking, top_hat, propeller, sombrero, pirate, wizard, pot.
Run: tools/blender-run.ps1 art/scripts/hats_a.py      (optional arg after --: one hat id to build)

Same contract as hats.py: origin at the HatAnchor, facing -Y in Blender (+Z in Godot), HatTint = player colour.
Head top is at z = 0.132 above the anchor; rims sit near z = 0 (pitched -4 deg: front up over the brows).
Geometry helpers: hats_a_parts.py.
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bpy  # noqa: E402,F401
import artlib  # noqa: E402
from chef_parts import join_named  # noqa: E402
from hats_a_parts import (PI, Frame, Rev, clamp, clearance, ellip, grid, paint_panels, smoothstep,  # noqa: E402
                          star, tilt, tri_count, tube, V)

M = artlib.material
PITCH = -4.0


# ------------------------------------------------------------------------------------------------ cowboy
def hat_cowboy():
    felt = M("CowboyFelt", "#a9733f", 0.85)
    tint = M("HatTint", "#d9483f", 0.8)

    def crown_warp(p, th):
        s = clamp((p.z - 0.12) / 0.1)
        p.z -= 0.062 * s * math.exp(-(p.x / 0.075) ** 2)          # the crease down the top
        if p.y < 0:
            p.x *= 1 - 0.14 * s * smoothstep(0.0, 0.2, -p.y)      # pinched front
        return p
    crown = Rev([(0.256, -0.012), (0.262, 0.05), (0.252, 0.13), (0.236, 0.20), (0.19, 0.25), (0.10, 0.272),
                 (0.0, 0.276)], per=2, warp=crown_warp)

    def brim_warp(p, th):
        rr = math.hypot(p.x, p.y)
        t = clamp((rr - 0.28) / 0.15)
        side = (p.x / rr) ** 2 if rr > 1e-6 else 0.0
        p.z += t * t * (0.115 * side - 0.025 * (1 - side))
        return p
    brim = Rev([(0.24, 0.024), (0.31, 0.02), (0.38, 0.024), (0.416, 0.022), (0.424, 0.01), (0.412, -0.002),
                (0.38, -0.006), (0.31, -0.006), (0.24, -0.006)], per=1, warp=brim_warp)
    band = Rev([(0.2605, 0.03), (0.2685, 0.036), (0.2685, 0.074), (0.2615, 0.08)], per=2)
    P = [crown.mesh(felt, 36, "ShellCrown"), brim.mesh(felt, 40, "Brim"), band.mesh(tint, 36, "Band")]
    return P, True


# ------------------------------------------------------------------------------------------------ crown
def hat_crown():
    gold = M("CrownGold", "#f0bb2c", 0.32, 0.35)
    fur = M("CrownFur", "#f8f5ee", 0.95)
    spot = M("CrownSpot", "#26232b", 0.9)
    velvet = M("CrownVelvet", "#b3202f", 0.85)
    tint = M("HatTint", "#3b9be0", 0.2)
    R = 0.276
    base = Rev([(R, 0), (R, 0.1)], smooth=False)

    def ztop(u):
        f = (5 * u + 0.5) % 1.0
        return 0.075 + 0.2 * (1 - abs(2 * f - 1)) ** 1.1
    zb = 0.012
    P = [grid(gold, lambda u, v: base.at(u, R, zb + v * (ztop(u) - zb)), 60, 2, closed=True, name="Wall")]
    edge = [base.at(i / 60.0, R + 0.001, ztop(i / 60.0)) for i in range(60)]
    P.append(tube(gold, edge, 0.0085, seg=5, closed=True, name="EdgeTube"))
    for k in range(5):
        u = k / 5.0
        P.append(ellip(gold, base.at(u, R, ztop(u) + 0.004), (0.027, 0.027, 0.027), nu=8, nv=5, name="Tip"))
        pg = base.at(u, R + 0.002, 0.105)
        P.append(ellip(tint, pg, (0.02, 0.011, 0.03), n=V((pg.x, pg.y, 0)), nu=8, nv=5, name="Gem"))
    furr = Rev([(0.262, -0.03), (0.285, -0.022), (0.294, 0.0), (0.285, 0.026), (0.268, 0.036)], per=2)
    P.append(furr.mesh(fur, 36, "Fur"))
    jm = furr.j_near(0.294, 0.0)
    for i in range(9):
        u = (i + 0.5) / 9.0
        p, n = furr.pt(u, jm), furr.normal(u, jm)
        P.append(ellip(spot, p, (0.011, 0.005, 0.017), n=n, nu=6, nv=4, name="FurSpot"))
    cush = Rev([(0.26, 0.02), (0.254, 0.1), (0.222, 0.16), (0.14, 0.205), (0.0, 0.222)], per=2)
    shell = cush.mesh(velvet, 32, "ShellCushion")
    P.append(shell)
    return P, True


# ------------------------------------------------------------------------------------------------ viking
def hat_viking():
    steel = M("VikingSteel", "#a4acb9", 0.38, 0.35)
    dark = M("VikingRidge", "#7a8493", 0.4, 0.35)
    horn = M("VikingHorn", "#f3e8cb", 0.5)
    gold = M("VikingRivet", "#e0b03a", 0.35, 0.3)
    tint = M("HatTint", "#8c4a2f", 0.8)
    dome = Rev([(0.262, -0.01), (0.268, 0.03), (0.256, 0.09), (0.218, 0.15), (0.145, 0.192), (0.065, 0.212),
                (0.0, 0.217)], per=2)
    P = [dome.mesh(steel, 36, "ShellDome")]
    band = Rev([(0.2655, -0.024), (0.2785, -0.016), (0.2825, 0.012), (0.2785, 0.04), (0.2665, 0.05)], per=2)
    P.append(band.mesh(tint, 36, "Band"))
    jb = band.j_near(0.2825, 0.012)
    for i in range(12):
        u = (i + 0.5) / 12.0
        if 0.38 < u < 0.62:
            continue
        P.append(ellip(gold, band.pt(u, jb), (0.011, 0.011, 0.011), n=band.normal(u, jb), nu=6, nv=4, name="Rivet"))
    js = list(range(2, dome.nv + 1))
    ridge = [dome.pt(0.0, j) + dome.normal(0.0, j) * 0.004 for j in js] + \
            [dome.pt(0.5, j) + dome.normal(0.5, j) * 0.004 for j in reversed(js[:-1])]
    P.append(tube(dark, ridge, 0.0105, samples=len(ridge) * 2, seg=5, name="Ridge"))
    for s in (-1, 1):
        pts = [V((s * x, y, z)) for x, y, z in [(0.2, 0.0, 0.05), (0.31, 0.0, 0.055), (0.41, -0.005, 0.09),
                                                   (0.47, -0.02, 0.18), (0.475, -0.05, 0.285), (0.43, -0.09, 0.375)]]
        P.append(tube(horn, pts, lambda t: 0.066 * (1 - t) ** 0.8 + 0.012, samples=28, seg=7, name="Horn"))
        P.append(ellip(gold, V((s * 0.272, 0.0, 0.055)), (0.034, 0.058, 0.058), rot=(0, 0, 0), nu=10, nv=6, name="Socket"))
    return P, True


# ------------------------------------------------------------------------------------------------ top hat
def hat_top_hat():
    black = M("TopHatBlack", "#25232c", 0.38)
    gold = M("TopHatBuckle", "#e8b830", 0.3, 0.35)
    tint = M("HatTint", "#d9483f", 0.55)
    crown = Rev([(0.258, -0.014), (0.256, 0.08), (0.25, 0.2), (0.254, 0.31), (0.262, 0.372), (0.248, 0.402),
                 (0.2, 0.41), (0.0, 0.41)], per=2)

    def brim_warp(p, th):
        rr = math.hypot(p.x, p.y)
        t = clamp((rr - 0.3) / 0.15)
        side = (p.x / rr) ** 2 if rr > 1e-6 else 0.0
        p.z += 0.045 * t * t * side
        return p
    brim = Rev([(0.24, 0.016), (0.32, 0.012), (0.385, 0.018), (0.42, 0.024), (0.428, 0.012), (0.415, 0.0),
                (0.38, -0.004), (0.32, -0.006), (0.24, -0.008)], per=1, warp=brim_warp)
    band = Rev([(0.2585, 0.01), (0.2655, 0.018), (0.2665, 0.082), (0.259, 0.09)], per=2)
    P = [crown.mesh(black, 36, "ShellCrown"), brim.mesh(black, 40, "Brim"), band.mesh(tint, 36, "Band")]
    pb = band.pt(0.0, band.j_near(0.2665, 0.05))
    nb = V((0, -1, 0))
    P.append(ellip(gold, pb + nb * 0.004, (0.04, 0.008, 0.043), n=nb, sq=4.5, nu=10, nv=6, name="Buckle"))
    P.append(ellip(black, pb + nb * 0.011, (0.024, 0.006, 0.027), n=nb, sq=4.5, nu=10, nv=6, name="BuckleHole"))
    return P, True


# ------------------------------------------------------------------------------------------------ propeller
def hat_propeller():
    tint = M("HatTint", "#d9483f", 0.85)
    cream = M("PropCream", "#f6efe2", 0.85)
    yellow = M("PropYellow", "#f4c430", 0.6)
    z0 = 0.008  # untilted: the propeller axis stays vertical
    dome = Rev([(0.262, z0 - 0.01), (0.27, z0 + 0.04), (0.256, z0 + 0.1), (0.21, z0 + 0.155), (0.13, z0 + 0.19),
                (0.055, z0 + 0.205), (0.0, z0 + 0.208)], per=2)
    d = dome.mesh(tint, 36, "ShellDome")
    paint_panels(d, [tint, cream], 6)
    band = Rev([(0.266, z0 - 0.03), (0.281, z0 - 0.02), (0.285, z0 + 0.01), (0.275, z0 + 0.036), (0.262, z0 + 0.04)], per=2)
    top = z0 + 0.208
    P = [d, band.mesh(yellow, 36, "Band")]
    P.append(ellip(yellow, V((0, 0, top + 0.005)), (0.034, 0.034, 0.03), nu=12, nv=7, name="Button"))
    P.append(tube(M("PropStem", "#4a4a55", 0.5), [V((0, 0, top + 0.01)), V((0, 0, top + 0.07)), V((0, 0, top + 0.115))],
                  0.012, samples=6, seg=6, name="Stem"))
    red, blue = M("PropRed", "#e8402f", 0.5), M("PropBlue", "#2f6fd6", 0.5)
    hubm = M("PropHub", "#f4c430", 0.5)
    S = [ellip(red, V((0.15, 0, 0)), (0.16, 0.05, 0.008), rot=(0.34, 0, 0), nu=14, nv=6, name="BladeA"),
         ellip(blue, V((-0.15, 0, 0)), (0.16, 0.05, 0.008), rot=(-0.34, 0, 0), nu=14, nv=6, name="BladeB"),
         ellip(hubm, V((0, 0, 0)), (0.03, 0.03, 0.026), nu=10, nv=6, name="Hub")]
    return P, False, {"spin": S, "spin_z": top + 0.125}


# ------------------------------------------------------------------------------------------------ sombrero
def hat_sombrero():
    straw = M("SombreroStraw", "#ebc864", 0.88)
    tint = M("HatTint", "#d9483f", 0.8)
    green = M("SombreroGreen", "#2f9e5c", 0.8)
    crown = Rev([(0.258, -0.012), (0.25, 0.07), (0.216, 0.15), (0.16, 0.225), (0.1, 0.285), (0.045, 0.318),
                 (0.0, 0.326)], per=2)

    def brim_warp(p, th):
        rr = math.hypot(p.x, p.y)
        t = clamp((rr - 0.3) / 0.18)
        p.z += 0.03 * t * t + 0.008 * math.sin(7 * th) * t
        return p
    brim = Rev([(0.24, 0.024), (0.32, 0.01), (0.39, 0.004), (0.445, 0.014), (0.48, 0.036), (0.478, 0.05),
                (0.455, 0.036), (0.39, -0.014), (0.32, -0.02), (0.24, -0.014)], per=1, warp=brim_warp)
    band = Rev([(crown.r_at_z(0.04) + 0.006, 0.04), (crown.r_at_z(0.05) + 0.012, 0.05),
                (crown.r_at_z(0.13) + 0.012, 0.13), (crown.r_at_z(0.14) + 0.006, 0.14)], per=2)
    P = [crown.mesh(straw, 36, "ShellCrown"), brim.mesh(straw, 44, "Brim"), band.mesh(tint, 36, "Band")]
    je = brim.j_near(0.478, 0.05)
    P.append(tube(tint, brim.ring(je, 48), 0.0115, seg=4, closed=True, name="Trim"))
    jr = brim.j_near(0.39, 0.004)
    P.append(tube(green, brim.ring(jr, 40), 0.0085, seg=4, closed=True, name="Stripe"))
    P.append(ellip(tint, V((0, 0, 0.33)), (0.026, 0.026, 0.026), nu=8, nv=5, name="Pom"))
    return P, True


# ------------------------------------------------------------------------------------------------ pirate
def hat_pirate():
    black = M("PirateBlack", "#26232d", 0.5)
    gold = M("PirateGold", "#e0ac35", 0.32, 0.3)
    bone = M("PirateBone", "#f5f1e4", 0.6)
    eye = M("PirateEye", "#14121a", 0.8)
    tint = M("HatTint", "#d9483f", 0.7)

    def fold_of(th):
        return (0.5 * (1 - math.cos(3 * th))) ** 0.85       # 1 at 60/180/300 deg (the folded sides), 0 at the corners

    def brim_warp(p, th):
        rr = math.hypot(p.x, p.y)
        t = clamp((rr - 0.27) / 0.24)
        f = fold_of(th)
        k = 1 - 0.42 * f * t * t
        p.x *= k
        p.y = p.y * k
        p.z += 0.2 * f * t ** 1.6
        return p
    brim = Rev([(0.24, 0.0), (0.33, 0.002), (0.42, 0.008), (0.49, 0.018), (0.506, 0.014), (0.498, 0.002),
                (0.42, -0.006), (0.33, -0.006), (0.24, -0.006)], per=1, warp=brim_warp)
    crown = Rev([(0.258, -0.012), (0.264, 0.05), (0.254, 0.11), (0.212, 0.16), (0.13, 0.186), (0.0, 0.196)], per=2)
    P = [crown.mesh(black, 36, "ShellCrown"), brim.mesh(black, 40, "Brim")]
    je = brim.j_near(0.506, 0.014)
    P.append(tube(gold, brim.ring(je, 48), 0.0095, seg=4, closed=True, name="Trim"))
    # skull badge on the crown front
    j = crown.j_near(0.254, 0.11)
    pf, nf = crown.pt(0.0, j), crown.normal(0.0, j)
    fr = Frame(pf, nf)
    P.append(ellip(bone, fr.P(0, 0.012, 0.002), (0.046, 0.026, 0.04), n=nf, nu=12, nv=7, name="Skull"))
    P.append(ellip(bone, fr.P(0, -0.034, 0.004), (0.028, 0.02, 0.02), n=nf, nu=10, nv=6, name="Jaw"))
    for s in (-1, 1):
        P.append(ellip(eye, fr.P(s * 0.0185, 0.014, 0.022), (0.0125, 0.01, 0.0135), n=nf, nu=8, nv=5, name="Socket"))
    P.append(ellip(eye, fr.P(0, -0.008, 0.026), (0.006, 0.006, 0.01), n=nf, nu=6, nv=4, name="Nose"))
    for s in (-1, 1):  # crossbones behind the skull
        a, b = fr.P(-s * 0.075, 0.062, -0.002), fr.P(s * 0.075, -0.062, -0.002)
        P.append(tube(bone, [a, (a + b) * 0.5, b], 0.0105, samples=8, seg=6, name="Bone"))
        for e in (a, b):
            P.append(ellip(bone, e, (0.016, 0.014, 0.016), nu=7, nv=5, name="BoneEnd"))
    # tinted ribbon round the crown base + a rosette on the side
    rib = Rev([(crown.r_at_z(0.03) + 0.004, 0.03), (crown.r_at_z(0.04) + 0.01, 0.04),
               (crown.r_at_z(0.075) + 0.01, 0.075), (crown.r_at_z(0.085) + 0.004, 0.085)], per=2)
    P.append(rib.mesh(tint, 36, "Ribbon"))
    for s_ in (-1, 1):
        pr = rib.pt(0.25 if s_ > 0 else 0.75, rib.j_near(crown.r_at_z(0.055) + 0.01, 0.055))
        P.append(ellip(gold, pr, (0.014, 0.014, 0.014), n=V((pr.x, pr.y, 0)), nu=8, nv=5, name="Stud"))
    return P, True


# ------------------------------------------------------------------------------------------------ wizard
def hat_wizard():
    tint = M("HatTint", "#6a3fb5", 0.75)
    band_m = M("WizardBand", "#2a2146", 0.6)
    gold = M("WizardGold", "#ffd23f", 0.4, 0.2)
    H = 0.5

    def prof(z):
        return 0.262 * max(0.0, 1 - (z + 0.01) / (H + 0.01)) ** 1.25
    zs = [-0.01, 0.04, 0.1, 0.17, 0.25, 0.33, 0.4, 0.45, 0.48, H]

    def bend(p, th):
        s = clamp((p.z - 0.18) / 0.32)
        p.y += 0.15 * s * s
        p.z -= 0.06 * s * s
        return p
    cone = Rev([(prof(z), z) for z in zs], per=2, warp=bend)

    def brim_warp(p, th):
        rr = math.hypot(p.x, p.y)
        t = clamp((rr - 0.3) / 0.12)
        p.z -= 0.03 * t * t * (1.0 + 0.6 * math.cos(th))
        return p
    brim = Rev([(0.235, 0.014), (0.31, 0.01), (0.365, -0.004), (0.4, -0.022), (0.404, -0.034), (0.39, -0.034),
                (0.36, -0.018), (0.31, -0.006), (0.235, -0.006)], per=1, warp=brim_warp)
    band = Rev([(prof(0.025) + 0.007, 0.025), (prof(0.035) + 0.012, 0.035), (prof(0.085) + 0.012, 0.085),
                (prof(0.095) + 0.007, 0.095)], per=2)
    P = [cone.mesh(tint, 32, "ShellCone"), brim.mesh(tint, 40, "Brim"), band.mesh(band_m, 36, "Band")]
    pb = band.pt(0.0, band.j_near(prof(0.06) + 0.012, 0.06))
    nb = V((0, -1, 0))
    P.append(ellip(gold, pb + nb * 0.003, (0.04, 0.009, 0.04), n=nb, sq=4.0, nu=10, nv=6, name="Buckle"))
    P.append(ellip(band_m, pb + nb * 0.011, (0.024, 0.006, 0.024), n=nb, sq=4.0, nu=10, nv=6, name="BuckleHole"))
    # stars on the cone: (turn fraction, height, size)
    for u, z, sz in [(0.955, 0.16, 0.052), (0.045, 0.255, 0.04), (0.925, 0.3, 0.034), (0.1, 0.17, 0.045),
                     (0.01, 0.37, 0.03), (0.28, 0.13, 0.05), (0.72, 0.15, 0.048), (0.5, 0.2, 0.05),
                     (0.3, 0.27, 0.036), (0.66, 0.28, 0.036), (0.42, 0.34, 0.03), (0.58, 0.36, 0.03)]:
        j = cone.j_near(prof(z), z)
        pnt, nrm = cone.pt(u, j), cone.normal(u, j)
        P.append(star(gold, Frame(pnt + nrm * 0.002, nrm), sz, name="Star"))
    return P, True


# ------------------------------------------------------------------------------------------------ pot
def hat_pot():
    steel = M("PotSteel", "#c3c8d2", 0.3, 0.4)
    handle = M("PotHandle", "#2f2b33", 0.55)
    tint = M("HatTint", "#d9483f", 0.5)
    R = 0.272
    body = Rev([(R - 0.003, -0.022), (R, 0.0), (R, 0.17), (R - 0.006, 0.225), (R - 0.028, 0.258), (0.2, 0.272),
                (0.0, 0.274)], per=2)
    P = [body.mesh(steel, 40, "ShellPot")]
    jl = body.j_near(R - 0.003, -0.022)
    P.append(tube(steel, body.ring(jl, 40), 0.0125, seg=6, closed=True, name="Lip"))
    stripe = Rev([(R + 0.0015, 0.082), (R + 0.007, 0.088), (R + 0.007, 0.138), (R + 0.0015, 0.144)], per=2)
    P.append(stripe.mesh(tint, 40, "Stripe"))
    ringtop = [V((0.17 * math.cos(2 * PI * i / 32), 0.17 * math.sin(2 * PI * i / 32), 0.2745)) for i in range(32)]
    P.append(tube(steel, ringtop, 0.005, seg=4, closed=True, name="TopRing"))
    for s in (-1, 1):
        pts = [V((s * x, 0.0, z)) for x, z in [(0.255, 0.03), (0.34, 0.022), (0.405, 0.06), (0.405, 0.118),
                                                (0.345, 0.155), (0.255, 0.135)]]
        P.append(tube(handle, pts, 0.021, seg=6, closed=True, name="Handle"))
    return P, True


# ------------------------------------------------------------------------------------------------ main
HATS = {"cowboy": hat_cowboy, "crown": hat_crown, "viking": hat_viking, "top_hat": hat_top_hat,
        "propeller": hat_propeller, "sombrero": hat_sombrero, "pirate": hat_pirate, "wizard": hat_wizard,
        "pot": hat_pot}


def build(hid):
    artlib.reset_scene()
    res = HATS[hid]()
    parts, pitch = res[0], res[1]
    extra = res[2] if len(res) > 2 else {}
    shell = [p for p in parts if p.name.startswith("Shell")]
    clearance(hid, shell)
    print("TRIS %s: %d + spin %d" % (hid, tri_count(parts), tri_count(extra.get("spin", []))))
    if pitch:
        tilt(parts + extra.get("spin", []), pitch_deg=PITCH)
    spin = None
    if "spin" in extra:
        spin = join_named(extra["spin"], "Spin")
        spin.location = (0, 0, extra["spin_z"])
    artlib.join(parts, "Hat" + "".join(w.capitalize() for w in hid.split("_")))
    artlib.export_glb("hat_" + hid)


args = artlib.script_args()
for hid in (args or HATS.keys()):
    build(hid)
