"""Character models: chef (player) and boxing_glove (upgrade). Run: tools/blender-run.ps1 art/scripts/characters.py

Vinyl-toy style chef. Contract with the game code (rig v2, see finish_chef and docs/design/polish-2.md 4):
- chef.glb: empty root `Chef` -> `Body` (hips; material `ChefBody` = jacket, collar, sleeves, tinted per player)
  -> `Head` (neck) -> `Eyes`, `Brows`, `Mouth`, `Toque` (default hat, origin at HatAnchor; hidden for other hats),
  anchors `HatAnchor`, `FaceAnchor`, `BeardAnchor`; `Body` -> anchors `BackAnchor`, `NeckAnchor`; `Chef` -> `HandL` /
  `HandR` (origin = hand centre, HandL at +X), `FootL` / `FootR` (ankle) -> `LegL` / `LegR`, `ArmL` / `ArmR` (shoulder;
  sleeve segments `UpperArm*` / `Forearm*` in ChefBody + white `Cuff*`, posed by ChefAnim). Faces Blender -Y (Godot +Z).
  Same size and look as v1: the settle shift is fixed (CHEF_SHIFT) so hats and anchors keep their positions.
- beard_moustache.glb: the built-in moustache, origin at BeardAnchor (default beard).
- boxing_glove.glb: about 0.5 m, cuff toward +Y, fist toward -Y.
Geometry helpers live in chef_parts.py (smooth parametric surfaces).
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bpy  # noqa: E402
import artlib  # noqa: E402
import shapes  # noqa: E402
from chef_parts import V, curve, ellip, grid, join_named, lathe, ring, superxy, tri_count, tube, xf, _interp  # noqa: E402
from mathutils import Matrix  # noqa: E402

M = artlib.material
PI = math.pi
E = 2.4  # jacket section exponent

# ---------------------------------------------------------------- jacket profile
JT = [  # z, rx, ry
    (0.18, 0.0, 0.0), (0.185, 0.215, 0.18), (0.20, 0.255, 0.215), (0.24, 0.268, 0.225), (0.34, 0.272, 0.228),
    (0.44, 0.266, 0.226), (0.54, 0.262, 0.222), (0.62, 0.256, 0.214), (0.68, 0.225, 0.19),
    (0.725, 0.165, 0.14), (0.755, 0.12, 0.10), (0.77, 0.10, 0.085), (0.775, 0.0, 0.0),
]


def jr(z):
    return _interp(JT, z)


def jpt(x, z, off=0.0, back=False):
    """Point on (or off) the jacket surface at lateral x, height z."""
    rx, ry = jr(z)
    rx += off
    ry += off
    q = max(0.0, 1.0 - min(abs(x) / rx, 1.0) ** E)
    y = ry * q ** (1.0 / E)
    return V((x, y if back else -y, z))


def jang(th, z, off=0.0):
    rx, ry = jr(z)
    x, y = superxy(rx + off, ry + off, th + PI / 2, E)
    return V((x, -y, z))


# ---------------------------------------------------------------- head helpers
DZ = 0.045
HC = V((0.0, 0.0, 0.85 + DZ))
HR = (0.238, 0.218, 0.212)


def hp(x, z, off=0.0):
    """Point on the head ellipsoid front at (x, z), pushed out by off. Returns (pos, normal)."""
    z += DZ
    dx, dz = x / HR[0], (z - HC.z) / HR[2]
    t = max(0.0, 1.0 - dx * dx - dz * dz)
    y = -HR[1] * math.sqrt(t)
    p = V((x, y, z))
    n = V((x / HR[0] ** 2, y / HR[1] ** 2, (z - HC.z) / HR[2] ** 2)).normalized()
    return p + n * off, n


def chef():
    # materials
    body = M("ChefBody", "#f1f1f1", 0.62)
    white = M("ChefWhite", "#fbf9f3", 0.72)
    apron_m = M("ChefApron", "#eee4cf", 0.8)
    skin = M("ChefSkin", "#f6c7a1", 0.5)
    blush = M("ChefCheek", "#f29a8c", 0.6)
    eye_w = M("ChefEyeWhite", "#ffffff", 0.12)
    pupil = M("ChefPupil", "#1a1420", 0.08)
    shine = M("ChefShine", "#ffffff", 0.05)
    hair = M("ChefHair", "#5c3b26", 0.7)
    mouth = M("ChefMouth", "#7a2a2c", 0.4)
    scarf = M("ChefNeckerchief", "#3f4757", 0.75)
    button = M("ChefButton", "#efe7d2", 0.25)
    shoe = M("ChefShoe", "#3a2a25", 0.32)
    sole = M("ChefSole", "#e8dfcc", 0.5)
    pants = M("ChefPants", "#59606e", 0.8)
    P = []

    # ---- jacket + double-breasted flap (the sleeves are separate animated parts: ArmL / ArmR, see _arm)
    P.append(lathe(body, JT, nu=22, nv=10, name="Jacket", e=E))

    def flap_x(z):
        if z < 0.655:
            return -0.155, 0.115
        t = min((z - 0.655) / 0.09, 1.0)
        return -0.155 + 0.11 * t, 0.115 - 0.06 * t

    def f_flap(u, v):
        z = 0.20 + (0.735 - 0.20) * v
        xl, xr = flap_x(z)
        return jpt(xl + (xr - xl) * u, z, 0.010)
    P.append(grid(body, f_flap, 6, 10, closed=False, outward=(0, 0, 0.45), name="Flap"))
    # piping along the flap edge
    edge = [jpt(flap_x(z)[0], z, 0.012) for z in (0.215, 0.32, 0.45, 0.58, 0.655)]
    edge += [jpt(-0.11, 0.705, 0.012), jpt(-0.06, 0.74, 0.012)]
    P.append(tube(white, edge, 0.0075, samples=26, seg=6, name="Piping"))
    # hem piping
    # buttons: two rows of three
    for bx in (-0.075, 0.055):
        for bz in (0.46, 0.545, 0.625):
            p = jpt(bx, bz, 0.013)
            n = V((bx / 0.4, -1.0, 0.05))
            P.append(ellip(button, p, (0.021, 0.011, 0.021), n=n, nu=8, nv=4, name="Button"))
    # back seam
    P.append(tube(white, [jpt(0.0, z, 0.006, back=True) for z in (0.22, 0.36, 0.5, 0.62, 0.71)], 0.0065, samples=16, seg=6, name="Seam"))
    # collar (stand-up) and neckerchief
    P.append(ring(body, (0, 0.0, 0.77), 0.118, 0.098, 0.03, seg=6, n=16, name="Collar"))
    P.append(ring(scarf, (0, -0.002, 0.735), 0.135, 0.112, 0.024, seg=6, n=16, name="ScarfRing"))

    def f_scarf(u, v):
        z = 0.735 - 0.115 * v
        w = 0.125 * (1 - v) ** 0.85 + 0.008
        x = (u * 2 - 1) * w
        p = jpt(x, z, 0.016 + 0.014 * math.sin(PI * min(v * 1.6, 1.0)) * (1 - abs(u * 2 - 1) * 0.5))
        return p
    P.append(grid(scarf, f_scarf, 10, 10, closed=False, outward=(0, 0, 0.6), name="ScarfTri"))
    P.append(ellip(scarf, (0.0, -0.148, 0.712), (0.04, 0.026, 0.034), nu=12, nv=7, name="ScarfKnot"))

    P.append(ellip(scarf, (0.0, 0.118, 0.735), (0.034, 0.03, 0.03), nu=8, nv=5, name="ScarfBackKnot"))
    for sx in (-1, 1):
        P.append(ellip(scarf, (sx * 0.03, 0.128, 0.705), (0.018, 0.012, 0.045), rot=(0, sx * 0.25, 0), nu=8, nv=5, name="ScarfTail"))

    # ---- apron (half apron with waist band and bow)
    def f_apron(u, v):
        th = (u - 0.5) * 2 * math.radians(70)
        z = 0.405 - (0.405 - 0.165) * v
        off = 0.014 + 0.032 * v ** 1.4
        # droop the skirt hem a little at the sides
        z -= 0.02 * abs(u * 2 - 1) ** 2 * v
        p = jang(th, min(max(z, 0.19), 0.42), off)
        p.z = z
        return p
    P.append(grid(apron_m, f_apron, 14, 6, closed=False, outward=(0, 0, 0.3), name="Apron"))
    # rounded hem: a soft tube along the bottom edge
    hem = [f_apron(u / 12.0, 1.0) for u in range(13)]
    P.append(tube(apron_m, hem, 0.011, samples=24, seg=8, name="ApronHem"))
    for ue in (0.0, 1.0):
        P.append(tube(apron_m, [f_apron(ue, v / 6.0) for v in range(7)], 0.010, samples=8, seg=5, name="ApronEdge"))
    # waist band and ties
    band_pts = [jang(th, 0.405, 0.020) for th in [math.radians(a) for a in range(0, 360, 24)]]
    P.append(tube(apron_m, band_pts, 0.015, seg=6, closed=True, name="Band"))
    # pocket
    P.append(ellip(apron_m, (0.0, jpt(0, 0.30, 0.046).y, 0.29), (0.085, 0.012, 0.055), n=(0, -1, 0.15), sq=3.4, nu=12, nv=6, name="Pocket"))
    P.append(tube(white, [V((-0.075, jpt(0, 0.33, 0.058).y, 0.335)), V((0.075, jpt(0, 0.33, 0.058).y, 0.335))], 0.006, samples=6, seg=6, name="PocketTop"))
    # bow at the back
    by = jpt(0, 0.405, 0.03, back=True).y
    for s in (-1, 1):
        P.append(ellip(apron_m, (s * 0.055, by + 0.018, 0.41), (0.062, 0.02, 0.036), rot=(0, s * 0.35, 0), nu=10, nv=6, name="BowLoop"))
        P.append(ellip(apron_m, (s * 0.03, by + 0.018, 0.35), (0.028, 0.014, 0.075), rot=(0, s * 0.18, 0), nu=10, nv=6, name="BowTail"))
    P.append(ellip(apron_m, (0, by + 0.024, 0.405), (0.03, 0.026, 0.03), nu=10, nv=6, name="BowKnot"))

    # ---- legs and shoes
    for s in (-1, 1):
        P.append(tube(pants, [V((s * 0.13, 0.0, 0.24)), V((s * 0.13, -0.005, 0.11))], 0.072, samples=4, seg=6, name="Leg"))
        P.append(ellip(shoe, (s * 0.135, -0.05, 0.062), (0.098, 0.15, 0.062), nu=12, nv=6, name="Shoe"))
        P.append(ellip(sole, (s * 0.135, -0.05, 0.02), (0.104, 0.158, 0.026), nu=12, nv=4, sq=3.0, name="Sole"))

    # ---- head
    P.append(ellip(skin, HC, HR, nu=22, nv=9, name="Head"))
    for s in (-1, 1):
        P.append(ellip(skin, (s * 0.232, 0.01, 0.83 + DZ), (0.03, 0.04, 0.05), nu=8, nv=5, name="Ear"))
        # cheeks
        p, n = hp(s * 0.165, 0.775, 0.002)
        P.append(ellip(blush, p, (0.045, 0.012, 0.032), n=n, nu=10, nv=5, name="Cheek"))
        # eyes
        ex, ez = s * 0.088, 0.868
        p, n = hp(ex, ez, -0.006)
        P.append(ellip(eye_w, p, (0.056, 0.03, 0.068), n=n, nu=12, nv=7, name="EyeWhite"))
        p2, n2 = hp(ex - s * 0.004, ez - 0.006, 0.012)
        P.append(ellip(pupil, p2, (0.037, 0.02, 0.048), n=n2, nu=10, nv=5, name="Pupil"))
        p3, n3 = hp(ex + s * 0.012, ez + 0.02, 0.026)
        P.append(ellip(shine, p3, (0.014, 0.008, 0.016), n=n3, nu=8, nv=5, name="Shine"))
        p4, n4 = hp(ex - s * 0.013, ez - 0.02, 0.028)
                # brows
        bp = [hp(s * 0.135, 0.945, 0.006)[0], hp(s * 0.095, 0.962, 0.008)[0], hp(s * 0.052, 0.958, 0.006)[0]]
        P.append(tube(hair, bp, lambda t: 0.0115 - 0.003 * abs(t - 0.4), samples=8, seg=8, name="Brow"))
        # sideburn tuft under the hat
        P.append(ellip(hair, (s * 0.205, 0.02, 0.945 + DZ), (0.032, 0.05, 0.045), nu=8, nv=5, name="Tuft"))
    # nose
    p, n = hp(0.0, 0.808, 0.0)
    P.append(ellip(M("ChefNose", "#f2a58c", 0.45), p + n * 0.008, (0.036, 0.032, 0.03), n=n, nu=10, nv=6, name="Nose"))
    # moustache: two curled lobes
    for s in (-1, 1):
        p, n = hp(s * 0.052, 0.772, 0.004)
        P.append(ellip(hair, p, (0.062, 0.024, 0.026), n=n, rot=(0, s * -0.45, 0), nu=10, nv=6, name="Moustache"))
        p, n = hp(s * 0.104, 0.762, 0.005)
        P.append(ellip(hair, p, (0.026, 0.018, 0.022), n=n, nu=8, nv=5, name="Curl"))
    # smile
    sm = [hp(x, z, 0.004)[0] for x, z in ((-0.06, 0.728), (-0.028, 0.708), (0.0, 0.702), (0.028, 0.708), (0.06, 0.728))]
    P.append(tube(mouth, sm, 0.0075, samples=14, seg=6, name="Smile"))
    # hair tuft at the back under the hat
    P.append(ellip(hair, (0.0, 0.05, 0.915 + DZ), (0.236, 0.215, 0.092), nu=16, nv=7, name="BackHair"))

    # ---- toque with pleats
    N = 10
    HT = [  # z, rx, ry, pleat amplitude
        (0.930, 0.0, 0.0, 0), (0.932, 0.17, 0.17, 0), (0.94, 0.208, 0.208, 0), (0.965, 0.224, 0.224, 0),
        (1.04, 0.228, 0.228, 0), (1.062, 0.222, 0.222, 0), (1.072, 0.20, 0.20, 0.004),
        (1.10, 0.212, 0.212, 0.012), (1.17, 0.238, 0.238, 0.02), (1.25, 0.268, 0.268, 0.026),
        (1.31, 0.284, 0.284, 0.028), (1.355, 0.278, 0.278, 0.024), (1.39, 0.245, 0.245, 0.014),
        (1.41, 0.17, 0.17, 0.006), (1.42, 0.08, 0.08, 0.0), (1.423, 0.0, 0.0, 0),
    ]

    HT = [(0.93 + DZ + (z - 0.93) * 0.96,) + tuple(row) for z, *row in HT]

    def pleat(th, amp):
        return 1.0 + amp * (2.0 * abs(math.cos(N * th / 2)) - 1.0) / 0.26
    toque = lathe(white, HT, nu=N * 4, nv=11, name="Toque", mod=pleat)
    piv = V((0, -0.02, HT[0][0]))
    xf(toque, Matrix.Translation(piv) @ Matrix.Rotation(-math.radians(9), 4, "X") @ Matrix.Translation(-piv))
    P.append(toque)
    # a stitched-in top puff seam
    return P


def _hand(name, mat, side):
    """Mitten with thumb, origin at hand centre; built at origin, placed by the caller."""
    parts = [ellip(mat, (0, 0, 0), (0.072, 0.062, 0.08), nu=12, nv=7, name=name + "Palm"),
             ellip(mat, (side * -0.05, -0.048, 0.022), (0.03, 0.036, 0.048), rot=(0.4, 0, side * -0.5), nu=10, nv=6, name=name + "Thumb")]
    o = join_named(parts, name)
    return o


def boxing_glove():
    red = M("GloveRed", "#d9252c", 0.3)
    shade = M("GloveShade", "#a11a20", 0.45)
    white = M("GloveCuff", "#f6f4ee", 0.65)
    lace = M("GloveLace", "#e9e0c8", 0.55)
    stitch = M("GloveStitch", "#f4dcc0", 0.6)
    P = []
    zc = 0.27
    # padded fist: a superelliptic loft along Y (front at -Y), squarer than a sphere so it reads as padding
    FT = [(0.0, 0.0, 0.0), (0.008, 0.075, 0.08), (0.04, 0.15, 0.16), (0.10, 0.19, 0.205), (0.20, 0.196, 0.212),
          (0.29, 0.185, 0.2), (0.36, 0.16, 0.17), (0.41, 0.13, 0.135), (0.42, 0.0, 0.0)]
    fist = lathe(red, FT, nu=28, nv=16, name="Fist", e=2.7)
    xf(fist, Matrix.Translation(V((0, -0.235, zc))) @ Matrix.Rotation(-PI / 2, 4, "X"))
    P.append(fist)

    def ftop(y):
        t = y + 0.235
        rx, rz = _interp(FT, t)
        return zc + rz
    # thumb hugging the side, pointing forward
    P.append(ellip(red, (0.19, -0.085, zc - 0.05), (0.066, 0.125, 0.072), rot=(0, 0, -0.10), nu=16, nv=9, name="Thumb"))
    # stitched seam over the top, front to back
    for k in range(10):
        y = -0.20 + k * 0.03
        P.append(ellip(stitch, (0, y + 0.012, ftop(y) - 0.001), (0.024, 0.008, 0.006), nu=6, nv=4, name="Stitch"))
    P.append(tube(shade, [V((0, -0.226, zc + 0.05)), V((0, -0.222, zc + 0.02))], 0.0, samples=2, seg=3, name="Dummy")) if False else None
    # white cuff (axis along Y) with ribbing and laces
    cuff = lathe(white, [(0.0, 0.0, 0.0), (0.004, 0.10, 0.10), (0.02, 0.135, 0.135), (0.05, 0.146, 0.146), (0.13, 0.143, 0.143),
                         (0.16, 0.14, 0.14), (0.166, 0.10, 0.10), (0.167, 0.0, 0.0)], nu=32, nv=14, name="Cuff")
    xf(cuff, Matrix.Translation(V((0, 0.112, zc))) @ Matrix.Rotation(-PI / 2, 4, "X"))
    P.append(cuff)
    # laces: eyelets and a criss-cross over the top of the cuff, plus a bow
    def cz(x, extra=0.0):
        return zc + math.sqrt(0.146 ** 2 - x * x) + extra
    yy = [0.155, 0.195, 0.235]
    zig = []
    for k, y in enumerate(yy):
        a, b2 = (-1, 1) if k % 2 == 0 else (1, -1)
        zig += [V((a * 0.062, y, cz(0.062, 0.006))), V((0, y + 0.02, cz(0.0, 0.008))), V((b2 * 0.062, y + 0.04, cz(0.062, 0.006)))]
    P.append(tube(lace, zig, 0.0085, samples=14, seg=5, name="Lace"))
    for y in yy + [0.275]:
        for sx in (-1, 1):
            P.append(ellip(shade, (sx * 0.064, y + (0.04 if y != 0.275 else 0.0), cz(0.064, 0.002)), (0.014, 0.014, 0.006), rot=(0, sx * 0.4, 0), nu=8, nv=4, name="Eyelet"))
    for sx in (-1, 1):
        P.append(ellip(lace, (sx * 0.032, 0.262, cz(0.03, 0.01)), (0.034, 0.014, 0.012), rot=(0, sx * 0.4, 0), nu=8, nv=5, name="LaceBow"))
    return P


# ---------------------------------------------------------------- rig v2: parts, pivots, anchors
# Raw authoring frame (before the settle shift). Godot = (x, z + SHIFT.z, -(y + SHIFT.y)).
CHEF_SHIFT = V((0.0, -0.03881, 0.006))   # what shapes.settle used to apply (hats_parts.CHEF_SHIFT)
GROUPS = {  # part -> object base names (as created in chef())
    "Body": {"Jacket", "Flap", "Piping", "Button", "Seam", "Collar", "ScarfRing", "ScarfTri",
             "ScarfKnot", "ScarfBackKnot", "ScarfTail", "Apron", "ApronHem", "ApronEdge", "Band", "Pocket",
             "PocketTop", "BowLoop", "BowTail", "BowKnot"},
    "Head": {"Head", "Ear", "Cheek", "Tuft", "Nose", "BackHair"},
    "Eyes": {"EyeWhite", "Pupil", "Shine"},
    "Brows": {"Brow"},
    "Mouth": {"Smile"},
    "Toque": {"Toque"},
    "Beard": {"Moustache", "Curl"},
    "Leg": {"Leg"},
    "Foot": {"Shoe", "Sole"},
}
PIV_BODY = V((0.0, 0.0, 0.24))      # hips (top of the legs)
PIV_HEAD = V((0.0, 0.0, 0.77))      # neck (collar ring centre)
PIV_FOOT = (0.13, -0.005, 0.11)     # ankle (x sign per side)
PIV_HAND = (0.335, -0.075, 0.5)     # hand centre (x sign per side)
PIV_SHOULDER = (0.19, 0.0, 0.65)    # arm root inside the jacket (x sign per side); ChefAnim.SHOULDER = this, Body-local
ARM_SEG = 0.08                      # authored length of UpperArm / Forearm (ChefAnim.ARM_SEG)
WRIST_OFF = 0.075                   # cuff centre to hand centre (ChefAnim.WRIST_OFF)
HAT_RAW = V((0.0, 0.0, 0.975))      # toque base ring centre (hats_parts.HAT_RAW)
FACE_RAW = V((0.0, -0.21795, 0.90))  # head front between the eyes (hats_parts.FACE_RAW)


def _beard_raw():
    p, _n = hp(0.0, 0.772, 0.0)     # head front under the nose, moustache height
    return p


def _back_raw():
    return jpt(0.0, 0.60, 0.0, back=True)  # jacket back between the shoulder blades


def _godot(p):
    q = V(p) + CHEF_SHIFT
    return (round(q.x, 4), round(q.z, 4), round(-q.y, 4))


def _bbox_centre(o):
    lo = V((1e9, 1e9, 1e9))
    hi = V((-1e9, -1e9, -1e9))
    for v in o.data.vertices:
        for a in range(3):
            lo[a] = min(lo[a], v.co[a])
            hi[a] = max(hi[a], v.co[a])
    return (lo + hi) / 2


def _centroid_x(o):
    return sum(v.co.x for v in o.data.vertices) / max(1, len(o.data.vertices))


def _part(objs, name, pivot_raw):
    """Join objs (raw frame, transforms applied) into `name`, mesh re-centred on pivot_raw.
    The caller sets .location relative to the parent."""
    o = artlib.join(objs, name)
    o.data.transform(Matrix.Translation(-V(pivot_raw)))
    o.location = (0, 0, 0)
    return o


def _child(o, parent, at_raw, parent_raw):
    """Parent o (origin at at_raw) under parent (origin at parent_raw; None = the root, which is at the
    settled origin, so raw positions get the settle shift). No parent inverse: location is local."""
    o.parent = parent
    o.location = V(at_raw) + CHEF_SHIFT if parent_raw is None else V(at_raw) - V(parent_raw)
    return o


def _empty(name):
    e = bpy.data.objects.new(name, None)
    e.empty_display_size = 0.05
    bpy.context.collection.objects.link(e)
    return e


def _chef_raw_parts():
    """Build the raw chef + hands, check the settle shift, return ({base name: [objects]}, HandL, HandR)."""
    artlib.reset_scene()
    parts = chef()
    skin = bpy.data.materials["ChefSkin"]
    hl = _hand("HandL", skin, 1)
    hr = _hand("HandR", skin, -1)
    hl.location = PIV_HAND
    hr.location = (-PIV_HAND[0], PIV_HAND[1], PIV_HAND[2])
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    lo, hi = shapes.world_bounds(meshes)
    shift = V((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))
    print("CHEF_SHIFT measured %.5f %.5f %.5f" % tuple(shift))
    if (shift - CHEF_SHIFT).length > 0.002:
        raise RuntimeError(f"chef settle shift moved: {tuple(shift)} vs {tuple(CHEF_SHIFT)}; update CHEF_SHIFT + anchors")
    by = {}
    for o in parts:
        by.setdefault(o.name.split(".")[0], []).append(o)
    known = set().union(*GROUPS.values())
    stray = [k for k in by if k not in known]
    if stray:
        raise RuntimeError(f"chef parts not in any group: {stray}")
    print("CHEF TRIS", tri_count(meshes))
    return by, hl, hr


def _arm(side, s, root):
    """ArmL / ArmR: an empty at the shoulder (root child) -> UpperArm<side> (origin shoulder), Forearm<side>
    (origin elbow), Cuff<side> (origin wrist). Each segment mesh runs from its origin along local -Z (Godot -Y),
    ARM_SEG long, round so the animator may spin it freely; ChefAnim aims and stretches the three every frame.
    The glb rest pose already points them at the hand (slight elbow), for any instance nobody animates."""
    body = bpy.data.materials["ChefBody"]
    white = bpy.data.materials["ChefWhite"]
    L = ARM_SEG
    up = lathe(body, [(-L - 0.034, 0.0, 0.0), (-L - 0.028, 0.036, 0.036), (-L - 0.014, 0.054, 0.054), (-L, 0.06, 0.06),
                      (-L * 0.5, 0.065, 0.065), (0.0, 0.07, 0.07), (0.016, 0.062, 0.062), (0.03, 0.04, 0.04), (0.036, 0.0, 0.0)],
               nu=14, nv=10, name="UpperArm" + side)
    fo = lathe(body, [(-L - 0.012, 0.0, 0.0), (-L - 0.008, 0.04, 0.04), (-L, 0.055, 0.055), (-L * 0.5, 0.057, 0.057),
                      (0.0, 0.06, 0.06), (0.018, 0.052, 0.052), (0.03, 0.034, 0.034), (0.035, 0.0, 0.0)],
               nu=14, nv=9, name="Forearm" + side)
    cu = lathe(white, [(-0.017, 0.0, 0.0), (-0.015, 0.05, 0.05), (-0.009, 0.066, 0.066), (0.008, 0.066, 0.066),
                       (0.014, 0.052, 0.052), (0.016, 0.0, 0.0)], nu=14, nv=6, name="Cuff" + side)
    sh = V((s * PIV_SHOULDER[0], PIV_SHOULDER[1], PIV_SHOULDER[2]))
    hand = V((s * PIV_HAND[0], PIV_HAND[1], PIV_HAND[2]))
    wr = hand - (hand - sh).normalized() * WRIST_OFF
    d = (wr - sh).length
    a = d * 0.55                                    # ChefAnim: segment length = 1.1 x half the rest reach
    dirv = (wr - sh).normalized()
    pole = V((s * 0.75, 0.6, -0.25))                # raw frame: out, back (+Y), down
    perp = (pole - dirv * pole.dot(dirv)).normalized()
    x = d * 0.5
    el = sh + dirv * x + perp * math.sqrt(max(a * a - x * x, 0.0))
    arm = _child(_empty("Arm" + side), root, sh, None)
    down = V((0.0, 0.0, -1.0))
    for o, at, to in ((up, sh, el), (fo, el, wr), (cu, wr, wr + (wr - el))):
        o.parent = arm
        o.location = at - sh
        o.rotation_mode = "QUATERNION"
        o.rotation_quaternion = down.rotation_difference((to - at).normalized())
    print("ARM %s shoulder godot %s elbow %s wrist %s" % (side, _godot(sh), _godot(el), _godot(wr)))
    return arm


def finish_chef():
    """chef.glb (rig v2): root `Chef` (empty, at the settled origin = the feet) ->
         Body (hips) -> Head (neck) -> Eyes, Brows, Mouth, Toque, HatAnchor, FaceAnchor, BeardAnchor
                     -> BackAnchor, NeckAnchor
         HandL, HandR (hand centre), FootL, FootR (ankle) -> LegL, LegR (ankle)
         ArmL, ArmR (shoulder) -> UpperArm*, Forearm*, Cuff* (see _arm)
    The built-in moustache is beard_moustache.glb (origin = BeardAnchor)."""
    by, hl, hr = _chef_raw_parts()
    for o in by.pop("Moustache") + by.pop("Curl"):
        bpy.data.objects.remove(o, do_unlink=True)

    def grab(part):
        out = []
        for k in GROUPS[part]:
            out += by.get(k, [])
        return out
    root = _empty("Chef")
    pivots = {}

    def part(objs, name, piv, parent, parent_piv):
        o = artlib.join(objs, name)  # applies transforms: mesh in the raw frame
        piv = V(piv) if piv is not None else _bbox_centre(o)
        o = _part([o], name, piv)
        pivots[name] = piv
        return _child(o, parent, piv, parent_piv)
    body = part(grab("Body"), "Body", PIV_BODY, root, None)
    head = part(grab("Head"), "Head", PIV_HEAD, body, PIV_BODY)
    for nm in ("Eyes", "Brows", "Mouth"):
        part(grab(nm), nm, None, head, PIV_HEAD)
    part(grab("Toque"), "Toque", HAT_RAW, head, PIV_HEAD)
    part([hl], "HandL", PIV_HAND, root, None)
    part([hr], "HandR", (-PIV_HAND[0], PIV_HAND[1], PIV_HAND[2]), root, None)
    sides = {s: ([o for o in grab("Foot") if _centroid_x(o) * s > 0], [o for o in grab("Leg") if _centroid_x(o) * s > 0])
             for s in (1, -1)}
    for side, s in (("L", 1), ("R", -1)):
        piv = (s * PIV_FOOT[0], PIV_FOOT[1], PIV_FOOT[2])
        foot = part(sides[s][0], "Foot" + side, piv, root, None)
        part(sides[s][1], "Leg" + side, piv, foot, piv)
    _arm("L", 1, root)
    _arm("R", -1, root)
    anchors ={"HatAnchor": (head, PIV_HEAD, HAT_RAW), "FaceAnchor": (head, PIV_HEAD, FACE_RAW),
               "BeardAnchor": (head, PIV_HEAD, _beard_raw()), "BackAnchor": (body, PIV_BODY, _back_raw()),
               "NeckAnchor": (body, PIV_BODY, PIV_HEAD)}
    for name, (parent, ppiv, at) in anchors.items():
        _child(_empty(name), parent, at, ppiv)
        print("ANCHOR %s godot %s" % (name, _godot(at)))
    for name, at in pivots.items():
        print("PIVOT %s godot %s" % (name, _godot(at)))
    # size check against the old contract (same limits as before)
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    lo, hi = shapes.world_bounds(meshes)
    got = (hi.x - lo.x, hi.z - lo.z, hi.y - lo.y)
    print("SIZE chef: %.3f x %.3f x %.3f  base z %.4f  centre xy %.4f %.4f" % (got + (lo.z, (lo.x + hi.x) / 2, (lo.y + hi.y) / 2)))
    lim = ((0.72, 0.9), (1.3, 1.5), (0.45, 0.85))
    if not all(a <= g <= b for g, (a, b) in zip(got, lim)) or abs(lo.z) > 0.002:
        raise RuntimeError(f"chef size {got} / base {lo.z} outside contract")
    artlib.export_glb("chef")


def finish_beard():
    """beard_moustache.glb: the chef's own moustache, origin at BeardAnchor (default beard)."""
    by, hl, hr = _chef_raw_parts()
    keep = by["Moustache"] + by["Curl"]
    for o in list(bpy.data.objects):
        if o not in keep:
            bpy.data.objects.remove(o, do_unlink=True)
    b = artlib.join(keep, "BeardMoustache")
    b.data.transform(Matrix.Translation(-_beard_raw()))
    artlib.export_glb("beard_moustache")


finish_chef()
finish_beard()

artlib.reset_scene()
gparts = boxing_glove()
print("GLOVE TRIS", tri_count(gparts))
artlib.join(gparts, "BoxingGlove")
shapes.settle("boxing_glove", (0.5, 0.5, 0.5), limits=((0.3, 0.55), (0.38, 0.55), (0.4, 0.6)))
artlib.export_glb("boxing_glove")
