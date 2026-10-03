"""Chef customisation pieces: 4 hats + 2 face accessories. Run: tools/blender-run.ps1 art/scripts/hats.py

Attachment contract (Godot metres, relative to the chef origin at its feet; the chef faces +Z):
  HAT_ANCHOR  = (0, 0.981, 0.0388)   centre of the default toque base ring. hat_*.glb origins sit here.
  FACE_ANCHOR = (0, 0.906, 0.2568)   head surface between the eyes (x=0, eye height). acc_*.glb origins sit here.
Add a hat / accessory as a child of the chef at that one fixed local position, no rotation, no scale.
Hat rim radii: x 0.262, front y 0.237, back y 0.29 (egg shaped, hugs head + back hair); the toque is the original.
Materials: HatTint (beanie cloth, bandana cloth) is meant to take the player colour like ChefBody.
Geometry helpers: hats_parts.py.
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bpy  # noqa: E402,F401
import artlib  # noqa: E402
from hats_parts import (HAT_ANCHOR_BLENDER, FACE_ANCHOR_BLENDER, FACE_RAW, HAT_RAW, PI, Shell, V, clearance,  # noqa: E402
                        ellip, grid, surf_normal, tilt, to_godot, tube, xf)
from chef_parts import lathe  # noqa: E402
from mathutils import Matrix  # noqa: E402

M = artlib.material


def sgn(x):
    return 1.0 if x >= 0 else -1.0


# ------------------------------------------------------------------------------------------------ toque
def hat_toque():
    """Same shapes/colours/tilt as the toque baked into chef.glb (copied from characters.py)."""
    white = M("ChefWhite", "#fbf9f3", 0.72)
    N = 10
    DZ = 0.045
    HT = [
        (0.930, 0.0, 0.0, 0), (0.932, 0.17, 0.17, 0), (0.94, 0.208, 0.208, 0), (0.965, 0.224, 0.224, 0),
        (1.04, 0.228, 0.228, 0), (1.062, 0.222, 0.222, 0), (1.072, 0.20, 0.20, 0.004),
        (1.10, 0.212, 0.212, 0.012), (1.17, 0.238, 0.238, 0.02), (1.25, 0.268, 0.268, 0.026),
        (1.31, 0.284, 0.284, 0.028), (1.355, 0.278, 0.278, 0.024), (1.39, 0.245, 0.245, 0.014),
        (1.41, 0.17, 0.17, 0.006), (1.42, 0.08, 0.08, 0.0), (1.423, 0.0, 0.0, 0),
    ]
    HT = [(0.93 + DZ + (z - 0.93) * 0.96,) + tuple(row) for z, *row in HT]
    HT = [(z - HAT_RAW.z,) + tuple(row) for z, *row in HT]

    def pleat(th, amp):
        return 1.0 + amp * (2.0 * abs(math.cos(N * th / 2)) - 1.0) / 0.26
    toque = lathe(white, HT, nu=N * 4, nv=11, name="Toque", mod=pleat)
    piv = V((0, -0.02, HT[0][0]))
    xf(toque, Matrix.Translation(piv) @ Matrix.Rotation(-math.radians(9), 4, "X") @ Matrix.Translation(-piv))
    return [toque]


# ------------------------------------------------------------------------------------------------ beanie
def hat_beanie():
    tint = M("HatTint", "#d9483f", 0.9)
    pom = M("HatPompom", "#f6efe2", 0.96)
    sh = Shell()
    N = 30  # ribs
    P = []

    def dome(u, v):
        th = 2 * PI * u
        p = sh.pt(th, v)
        hn = sh.hnorm(th)
        return p + hn * (0.0055 * (1 - v * v) * math.cos(N * th))
    P.append(grid(tint, dome, N * 4, 12, closed=True, name="Dome"))

    def band(u, a):
        th = 2 * PI * u
        c, s = math.cos(2 * PI * a), math.sin(2 * PI * a)
        w = 0.02 * sgn(c) * abs(c) ** (2 / 3)
        h = 0.036 * sgn(s) * abs(s) ** (2 / 3)
        base = sh.pt(th, 0)
        p = V((base.x, base.y, 0)) + sh.hnorm(th) * (0.012 + w + 0.0035 * math.cos(N * th))
        p.z = base.z + 0.03 + h
        return p
    P.append(grid(tint, band, N * 4, 16, closed=True, name="Brim"))
    # pompom: fluffy cluster on top
    top = sh.top()
    cen = V((0, 0, top + 0.03))
    P.append(ellip(pom, cen, (0.047, 0.047, 0.045), nu=12, nv=7, name="PompomCore"))
    n = 14
    for i in range(n):
        y = 1 - 2 * (i + 0.5) / n
        r = math.sqrt(1 - y * y)
        a = i * 2.39996
        d = V((r * math.cos(a), r * math.sin(a), y))
        P.append(ellip(pom, cen + d * 0.034, (0.027, 0.027, 0.027), nu=8, nv=5, name="PompomTuft"))
    tilt(P, pitch_deg=-2.0)
    return P


# ------------------------------------------------------------------------------------------------ paper hat
def hat_paper():
    paper = M("HatPaper", "#f8f7f2", 0.92)
    fold = M("HatPaperFold", "#d4d0c4", 0.95)
    sh = Shell(rx=0.258, ryf=0.236, ryb=0.287, rz=0.242, zf=0.055, zb=-0.03)
    bandH = 0.06
    NP = 14
    crest = 0.21
    Lf, Lb = 0.215, 0.235

    def ring_pt(th, top):
        p0 = sh.pt(th, 0)
        pl = 0.007 * (2 * abs(math.cos(NP * th / 2)) - 1)
        q = V((p0.x, p0.y, 0)) + sh.hnorm(th) * (0.012 + pl)
        q.z = p0.z + (bandH if top else 0.0)
        return q

    def band(u, v):
        th = 2 * PI * u
        a, b = ring_pt(th, False), ring_pt(th, True)
        return a + (b - a) * v
    P = [grid(paper, band, NP * 4, 2, closed=True, name="Band")]

    def crown(u, v):
        th = 2 * PI * u
        r = ring_pt(th, True)
        s = sh.blend(th)
        L = Lb + (Lf - Lb) * s
        c = math.cos(th)
        # rounded fold: the ridge is an arch (high mid, low ends) so the front/back are soft, not horns
        ridge = V((0.0, -c * L * 0.9, crest * (1.0 - 0.5 * c * c)))
        w = v ** 0.8
        q = r + (ridge - r) * w
        q.x += 0.0045 * math.sin(NP * th) * math.sin(PI * v) * (1 - v)
        q.z += 0.004 * math.cos(NP * th) * math.sin(PI * v)
        return q
    P.append(grid(paper, crown, NP * 4, 10, closed=True, name="Crown"))
    hem = [ring_pt(2 * PI * i / 72, False) for i in range(72)]
    P.append(tube(paper, hem, 0.0045, seg=6, closed=True, name="Hem"))
    crest_pts = [V((0, y, crest + 0.001)) for y in (-Lf, -0.06, 0.05, 0.14, Lb)]
    P.append(tube(fold, crest_pts, 0.0035, samples=16, seg=5, name="CrestFold"))
    tilt(P, pitch_deg=-2.0, roll_deg=6.0)
    return P


# ------------------------------------------------------------------------------------------------ bandana
def hat_bandana():
    tint = M("HatTint", "#d9483f", 0.85)
    dot = M("BandanaDot", "#fbf3e2", 0.85)
    sh = Shell(rx=0.266, ryf=0.236, ryb=0.296, rz=0.252, zf=0.052, zb=-0.045)

    def cloth(u, v):
        th = 2 * PI * u
        p = sh.pt(th, v)
        hn = sh.hnorm(th)
        wr = 0.0035 * math.sin(7 * th + 4 * v) * math.sin(PI * min(v * 1.4, 1.0)) * (1 - 0.5 * v)
        p = p + hn * wr
        p.z += 0.003 * math.cos(5 * th) * v * (1 - v)
        return p
    P = [grid(tint, cloth, 72, 14, closed=True, name="Cloth")]
    hem = [cloth(i / 72.0, 0.0) + sh.hnorm(2 * PI * i / 72.0) * 0.004 for i in range(72)]
    P.append(tube(tint, hem, 0.0075, seg=6, closed=True, name="Hem"))
    # polka dots: flat discs lying in the cloth, staggered rows
    rows = [0.14, 0.29, 0.44, 0.59, 0.74, 0.88]
    for j, v in enumerate(rows):
        c = math.cos(PI / 2 * (0.25 + 0.75 * v))  # rough ring circumference factor
        cnt = max(3, int(round(16 * c)))
        for k in range(cnt):
            th = 2 * PI * (k + 0.5 * (j % 2)) / cnt
            if v < 0.35 and abs(math.atan2(math.sin(th - PI), math.cos(th - PI))) < 0.42:
                continue  # keep the knot area clear
            u = th / (2 * PI)
            p = cloth(u, v)
            n = surf_normal(cloth, u, v)
            P.append(ellip(dot, p + n * 0.0008, (0.0125, 0.0035, 0.0125), n=n, nu=10, nv=3, name="Dot"))
    # knot + tails at the back
    kp = cloth(0.5, 0.0) + V((0, 0.022, 0.004))
    P.append(ellip(tint, kp, (0.046, 0.034, 0.04), nu=12, nv=7, name="Knot"))
    for s in (-1, 1):
        P.append(ellip(tint, kp + V((s * 0.028, 0.012, 0.004)), (0.028, 0.026, 0.03), rot=(0, s * 0.4, 0), nu=8, nv=5, name="KnotLoop"))

        def tail(u, v, s=s):
            L = 0.17
            cpt = kp + V((s * (0.035 * v + 0.05 * v * v), 0.022 + 0.05 * v * v - 0.015 * v, -L * v))
            w = 0.034 * (1 - 0.88 * v ** 1.25) + 0.002
            ripple = 0.006 * math.sin(7 * v + s) * (u * 2 - 1)
            return cpt + V((1, 0, 0)) * ((u * 2 - 1) * w) + V((0, ripple + 0.01 * abs(u * 2 - 1) * (1 - v), 0))
        P.append(grid(tint, tail, 6, 10, closed=False, name="Tail"))
        for v in (0.25, 0.5):
            p = tail(0.5, v)
            P.append(ellip(dot, p + V((0, 0.0012, 0)), (0.011, 0.0035, 0.011), n=(0, 1, 0), nu=10, nv=3, name="Dot"))
    return P


# ------------------------------------------------------------------------------------------------ face
def fsurf(x, zw, off=0.0):
    """Point/normal on the chef's head front in the raw frame; zw = raw world height."""
    rx, ry, rz, cz = 0.238, 0.218, 0.212, 0.895
    dz = (zw - cz) / rz
    t = max(0.0, 1.0 - (x / rx) ** 2 - dz * dz)
    y = -ry * math.sqrt(t)
    p = V((x, y, zw))
    n = V((x / rx ** 2, y / ry ** 2, (zw - cz) / rz ** 2)).normalized()
    return p + n * off, n


def to_face_frame(parts):
    m = Matrix.Translation(-FACE_RAW)
    for o in parts:
        xf(o, m)
    return parts


def acc_glasses():
    frame = M("GlassesFrame", "#1d1b23", 0.35, metallic=0.25)
    lens = M("GlassesLens", "#b5dcef", 0.05, alpha=0.16)
    P = []
    R = 0.072
    inner_pts, outer_pts = {}, {}
    for s in (-1, 1):
        c0, n = fsurf(s * 0.088, 0.913)
        c = c0 + n * 0.045
        t2 = (V((0, 0, 1)) - n * n.z).normalized()
        t1 = t2.cross(n)
        pts = [c + (t1 * math.cos(2 * PI * i / 28) + t2 * math.sin(2 * PI * i / 28)) * R for i in range(28)]
        P.append(tube(frame, pts, 0.0065, seg=8, closed=True, name="Rim"))
        P.append(ellip(lens, c, (R - 0.002, 0.003, R - 0.002), n=n, nu=20, nv=3, name="Lens"))
        inner_pts[s] = min(pts, key=lambda p: abs(p.x))
        outer_pts[s] = max(pts, key=lambda p: abs(p.x))
    bl, br = inner_pts[-1], inner_pts[1]

    def mid(p, s):
        return V((s * 0.011, p.y + 0.02, p.z - 0.01))
    P.append(tube(frame, [bl, mid(bl, -1), V((0, -0.2265, 0.893)), mid(br, 1), br], 0.0055, samples=24, seg=6, name="Bridge"))
    for s in (-1, 1):
        o = outer_pts[s]
        side, _ = fsurf(s * 0.2, 0.915, 0.013)
        P.append(ellip(frame, o, (0.012, 0.012, 0.012), nu=8, nv=5, name="Hinge"))
        P.append(tube(frame, [o, side, V((s * 0.243, -0.02, 0.917)), V((s * 0.243, 0.04, 0.905))], 0.0055, samples=28, seg=6, name="Temple"))
    return to_face_frame(P)


def acc_moustache():
    wax = M("MoustacheWax", "#2e1c12", 0.32)
    P = []
    for s in (-1, 1):
        spec = [(0.0, 0.812, 0.05), (0.06, 0.803, 0.046), (0.112, 0.797, 0.038), (0.15, 0.803, 0.03),
                (0.172, 0.826, 0.028), (0.166, 0.853, 0.034), (0.146, 0.859, 0.04), (0.136, 0.842, 0.043)]
        pts = [fsurf(s * x, z, off)[0] for x, z, off in spec]
        P.append(tube(wax, pts, lambda t: 0.0085 + 0.022 * (1 - t) ** 1.25, samples=48, seg=8, name="Bar"))
    c, n = fsurf(0.0, 0.812, 0.046)
    P.append(ellip(wax, c, (0.03, 0.028, 0.03), n=n, nu=12, nv=7, name="Centre"))
    return to_face_frame(P)


# ------------------------------------------------------------------------------------------------ main
def build(name, obj_name, maker, check=True):
    artlib.reset_scene()
    parts = maker()
    if check:
        clearance(name, [p for p in parts if p.name.split(".")[0] in ("Dome", "Crown", "Cloth", "Band", "Toque")])
    artlib.join(parts, obj_name)
    artlib.export_glb(name)


print("HAT_ANCHOR godot", to_godot(HAT_ANCHOR_BLENDER))
print("FACE_ANCHOR godot", to_godot(FACE_ANCHOR_BLENDER))
build("hat_toque", "HatToque", hat_toque)
build("hat_beanie", "HatBeanie", hat_beanie)
build("hat_paper", "HatPaper", hat_paper)
build("hat_bandana", "HatBandana", hat_bandana)
build("acc_glasses", "AccGlasses", acc_glasses, check=False)
build("acc_moustache", "AccMoustache", acc_moustache, check=False)
