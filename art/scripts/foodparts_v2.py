"""Food builders v2: patties, sausages, hot dog bun, burger buns (smooth-shaded, hand-sculpted look).

Everything is built from `skin` (rings of 3D points -> closed smooth surface) plus small "decals":
lens-shaped flecks and tapered ribbons that follow the surface. Models are built in Blender Z-up with the
base on z=0, centred on the origin; ingredients_v2.py fits them to the exact contract size.
Run through ingredients_v2.py / ingredients.py, not directly.
"""
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bmesh  # noqa: E402
from mathutils import Vector  # noqa: E402

import artlib  # noqa: E402
from shapes import _assign, _to_object, ball  # noqa: E402

PAL = {
    # burger / hot dog bun
    "BunCrust": ("#d28a2e", 0.5),
    "BunGloss": ("#e3a23d", 0.34),
    "BunLow": ("#bf7a28", 0.55),
    "BunFlour": ("#eec06c", 0.7),
    "BunCrumb": ("#f8e5b0", 0.9),
    "BunToast": ("#dca24e", 0.75),
    "BunPore": ("#e6cc8a", 0.9),
    "Sesame": ("#fff3cf", 0.5),
    "SesameToast": ("#f0d9a0", 0.5),
    # patty
    "PattyRaw": ("#b23744", 0.85),
    "PattyRawDark": ("#b53a4a", 0.8),
    "PattyFat": ("#e9a4a2", 0.6),
    "PattyCooked": ("#8c4a26", 0.36),
    "PattyCrust": ("#5b2d16", 0.6),
    "PattyGrill": ("#26110a", 0.55),
    "PattyJuice": ("#c27d43", 0.12),
    "PattyBurnt": ("#1e1a19", 0.95),
    "PattyBurntB": ("#322c29", 0.95),
    "Ember": ("#c4531a", 0.75),
    "Ash": ("#756e68", 1.0),
    "Char": ("#2b2523", 0.95),
    # sausage
    "SausageRaw": ("#eab9a3", 0.38),
    "SausageRawSpot": ("#d99a8c", 0.45),
    "SausageTie": ("#c58b74", 0.6),
    "SausageCooked": ("#a0412a", 0.28),
    "SausageMark": ("#3a160b", 0.55),
    "SausageBlister": ("#dc8a5e", 0.25),
    "SausageSlit": ("#43170b", 0.7),
    "SausageBurnt": ("#1c1716", 0.92),
    "SausageBurntB": ("#322a27", 0.92),
    "SausageInside": ("#8b3b1c", 0.7),
}


def m(name):
    hexc, rough = PAL[name]
    return artlib.material(name, hexc, roughness=rough)


def smoothstep(a, b, x):
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def bell(x):
    """Smooth bump: 1 at 0, 0 beyond |x| >= 1."""
    x = min(1.0, abs(x))
    return (1 - x * x) ** 2


class Noise:
    """Cheap smooth value noise from a few random sines (-1..1), 2D or 3D."""

    def __init__(self, seed, octaves=4, f0=1.4):
        r = random.Random(seed)
        self.w = []
        for i in range(octaves):
            f = f0 * (1.75 ** i) * r.uniform(0.9, 1.1)
            a, b = r.uniform(0, 6.283), r.uniform(0, 3.14159)
            self.w.append((f * math.cos(a) * math.sin(b), f * math.sin(a) * math.sin(b), f * math.cos(b),
                           r.uniform(0, 6.283), 1.0 / (1.55 ** i)))
        self.norm = sum(w[4] for w in self.w) * 0.62

    def __call__(self, x, y, z=0.0):
        v = sum(a * math.sin(kx * x + ky * y + kz * z + p) for kx, ky, kz, p, a in self.w) / self.norm
        return max(-1.0, min(1.0, v))


# ---------------------------------------------------------------------------
# mesh core
# ---------------------------------------------------------------------------
def skin(mats, rings, face_mat=None, name="Skin"):
    """Closed surface through `rings` (list of closed loops of 3D points).

    A ring with a single point is a pole (cone cap). `face_mat(ra, rb, k, face) -> slot` picks materials
    (ra/rb ring indices, k position in the loop).
    """
    mats = list(mats) if isinstance(mats, (list, tuple)) else [mats]
    bm = bmesh.new()
    vr = [[bm.verts.new(p) for p in ring] for ring in rings]
    made = []
    for i, (a, b) in enumerate(zip(vr[:-1], vr[1:])):
        na, nb = len(a), len(b)
        n = max(na, nb)
        for k in range(n):
            k2 = (k + 1) % n
            cand = [a[k if na > 1 else 0], a[k2 if na > 1 else 0], b[k2 if nb > 1 else 0], b[k if nb > 1 else 0]]
            uniq = []
            for v in cand:
                if v not in uniq:
                    uniq.append(v)
            if len(uniq) >= 3:
                made.append((bm.faces.new(uniq), i, k))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if face_mat:
        for f, i, k in made:
            f.material_index = face_mat(i, i + 1, k, f)
    return _finish(bm, mats, name)


def _finish(bm, mats, name):
    obj = _to_object(bm, name, (0, 0, 0))
    _assign(obj, mats)
    for p in obj.data.polygons:
        p.use_smooth = True
    return obj


def _add_face(bm, verts, hint):
    f = bm.faces.new(verts)
    f.normal_update()
    if f.normal.dot(hint(f.calc_center_median())) < 0:
        f.normal_flip()
    return f


def strip(mat, rows, hint, name="Strip"):
    """Open quad strip through `rows` (each a list of 3D points, same length), oriented along hint(point)."""
    bm = bmesh.new()
    vr = [[bm.verts.new(p) for p in row] for row in rows]
    for a, b in zip(vr[:-1], vr[1:]):
        for k in range(len(a) - 1):
            _add_face(bm, (a[k], a[k + 1], b[k + 1], b[k]), hint)
    return _finish(bm, [mat], name)


def lens_poly(mat, centre, rim, hint, name="Lens"):
    """Triangle fan from a raised centre to a rim polygon."""
    bm = bmesh.new()
    c = bm.verts.new(centre)
    vs = [bm.verts.new(p) for p in rim]
    for i in range(len(vs)):
        _add_face(bm, (c, vs[i], vs[(i + 1) % len(vs)]), hint)
    return _finish(bm, [mat], name)


def lens_uv(mat, F, u, v, ru, rv, rot, lift, peak, hint, n=7):
    """Lens on a parametric surface F(u, v) -> Vector; rim sampled in (u, v), raised centre."""
    cr, sr = math.cos(rot), math.sin(rot)
    rim = []
    for i in range(n):
        a = 2 * math.pi * i / n + 0.3
        du, dv = ru * math.cos(a), rv * math.sin(a)
        p = F(u + du * cr - dv * sr, v + du * sr + dv * cr)
        rim.append(p + hint(p).normalized() * lift)
    c = F(u, v)
    return lens_poly(mat, c + hint(c).normalized() * peak, rim, hint)


def ribbon_xy(mat, pts, width, zfn, lift, crown=0.01):
    """Ribbon over a height field: pts [(x, y)], width(t in 0..1) -> metres."""
    n = len(pts)
    rows = []
    for i, (x, y) in enumerate(pts):
        x0, y0 = pts[max(i - 1, 0)]
        x1, y1 = pts[min(i + 1, n - 1)]
        tx, ty = x1 - x0, y1 - y0
        ln = math.hypot(tx, ty) or 1.0
        nx, ny = -ty / ln, tx / ln
        w = width(i / (n - 1)) / 2
        row = []
        for off, c in ((-w, 0.0), (0.0, crown), (w, 0.0)):
            px, py = x + nx * off, y + ny * off
            row.append((px, py, zfn(px, py) + lift + c))
        rows.append(row)
    return strip(mat, rows, lambda p: Vector((0, 0, 1)))


def lens_xy(mat, cx, cy, rx, ry, rot, zfn, lift=0.002, peak=0.016, n=6):
    """Small flat lens (fat fleck, ash flake) lying on a height field."""
    cr, sr = math.cos(rot), math.sin(rot)
    rim = []
    for i in range(n):
        a = 2 * math.pi * i / n + 0.3
        px = cx + rx * math.cos(a) * cr - ry * math.sin(a) * sr
        py = cy + rx * math.cos(a) * sr + ry * math.sin(a) * cr
        rim.append((px, py, zfn(px, py) + lift))
    return lens_poly(mat, (cx, cy, zfn(cx, cy) + peak), rim, lambda p: Vector((0, 0, 1)))


def _col_to_rings(cols):
    """cols[k][j] -> rings[j][k], collapsing pole rings (rho 0) to a single point."""
    nj = len(cols[0])
    rings = []
    for j in range(nj):
        ring = [cols[k][j] for k in range(len(cols))]
        if max((p - ring[0]).length for p in ring) < 1e-6:
            ring = [ring[0]]
        rings.append(ring)
    return rings


# ---------------------------------------------------------------------------
# patties
# ---------------------------------------------------------------------------
def patty(kind, seed=3):
    rng = random.Random(seed * 31 + {"raw": 1, "cooked": 2, "burnt": 3}[kind])
    N1 = Noise(seed * 5 + 1, 4, 1.7)
    N2 = Noise(seed * 5 + 2, 3, 4.3)
    R = {"raw": 1.5, "cooked": 1.48, "burnt": 1.45}[kind]
    H0 = {"raw": 0.54, "cooked": 0.53, "burnt": 0.5}[kind]
    rb = 0.13
    rt = {"raw": 0.23, "cooked": 0.2, "burnt": 0.16}[kind]
    ph = [rng.uniform(0, 6.283) for _ in range(6)]
    amp = {"raw": (0.03, 0.02, 0.012, 0, 0), "cooked": (0.02, 0.012, 0.006, 0, 0),
           "burnt": (0.045, 0.03, 0.02, 0.026, 0.016)}[kind]

    def edge(th):
        return (1 + amp[0] * math.sin(3 * th + ph[0]) + amp[1] * math.sin(5 * th + ph[1])
                + amp[2] * math.sin(8 * th + ph[2]) + amp[3] * math.sin(13 * th + ph[3])
                + amp[4] * math.sin(21 * th + ph[4]))

    # grill marks (cooked): two sets of lines
    lines = []
    if kind == "cooked":
        for ang, cs in ((math.radians(32), (-0.78, -0.26, 0.26, 0.78)), (math.radians(122), (-0.52, 0.0, 0.52))):
            for c in cs:
                lines.append((ang, c, math.sqrt(max(0.05, 1.18 ** 2 - c * c))))

    def grill(x, y):
        g = 0.0
        for ang, c, smax in lines:
            s = x * math.cos(ang) + y * math.sin(ang)
            p = -x * math.sin(ang) + y * math.cos(ang)
            g = max(g, math.exp(-((p - c) / 0.085) ** 2) * smoothstep(smax, smax - 0.25, abs(s)))
        return g

    # cracks (burnt): jagged polylines from the middle outwards
    cracks = []
    if kind == "burnt":
        for i in range(6):
            a = 2 * math.pi * i / 6 + rng.uniform(-0.3, 0.3)
            r0 = rng.uniform(0.05, 0.4)
            ln = rng.uniform(0.75, 1.05)
            pts = []
            steps = 7
            ax = a
            px, py = r0 * math.cos(a), r0 * math.sin(a)
            for s in range(steps + 1):
                pts.append((px, py))
                ax += rng.uniform(-0.75, 0.75)
                px += math.cos(ax) * ln / steps * 1.25
                py += math.sin(ax) * ln / steps * 1.25
                if math.hypot(px, py) > 1.18:
                    pts.append((px, py))
                    break
            cracks.append(pts)

    def crack_dist(x, y):
        best = 9.0
        for pts in cracks:
            for (x0, y0), (x1, y1) in zip(pts[:-1], pts[1:]):
                dx, dy = x1 - x0, y1 - y0
                l2 = dx * dx + dy * dy or 1e-9
                t = max(0.0, min(1.0, ((x - x0) * dx + (y - y0) * dy) / l2))
                best = min(best, math.hypot(x - x0 - t * dx, y - y0 - t * dy))
        return best

    def top_z(x, y):
        r = math.hypot(x, y)
        u = r / R
        z = H0
        if kind == "raw":
            z += -0.11 * bell(r / 0.55) + 0.03 * bell((r - 0.85) / 0.4) + 0.034 * N1(x, y) + 0.02 * N2(x, y)
        elif kind == "cooked":
            z += 0.07 * (1 - u * u) + 0.008 * N1(x, y) - 0.04 * grill(x, y)
        else:
            z += 0.035 * N1(x, y) + 0.018 * N2(x, y) - 0.05 * math.exp(-(crack_dist(x, y) / 0.075) ** 2) * (1 if u < 1.0 else 0)
        return z

    segs = 52
    U = [0.94, 0.86, 0.78, 0.7, 0.62, 0.54, 0.46, 0.38, 0.3, 0.22, 0.14, 0.07]
    tags = ["bot", "bot", "bot", "arc", "arc", "arc", "side", "side", "arc", "arc", "arc", "arc"] + ["top"] * (len(U) + 1)
    cols = []
    for k in range(segs):
        th = 2 * math.pi * k / segs
        Rt = R * edge(th)
        c, s = math.cos(th), math.sin(th)

        def Z(rho):
            return top_z(rho * c, rho * s)

        rimr = Rt - rt
        Hl = Z(rimr)
        zst = Hl - rt
        pts = [(0, 0), (Rt * 0.55, 0), (Rt - rb, 0)]
        for a in (30, 60, 90):
            al = math.radians(a)
            pts.append((Rt - rb + rb * math.sin(al), rb - rb * math.cos(al)))
        pts.append((Rt, (rb + zst) / 2))
        pts.append((Rt, zst))
        for a in (68, 45, 22, 0):
            al = math.radians(a)
            pts.append((rimr + rt * math.sin(al), zst + rt * math.cos(al)))
        # last arc point is (rimr, Hl); remove duplicate side point list shape: tags aligned below
        for u in U:
            pts.append((rimr * u, Z(rimr * u)))
        pts.append((0, Z(0)))
        cols.append([Vector((rho * c, rho * s, z)) for rho, z in pts])
    # tags aligned to pts: 3 bot, 3 arc_b, 2 side, 4 arc_t, 12 top, 1 pole
    tg = ["bot"] * 3 + ["arc"] * 3 + ["side"] * 2 + ["arc"] * 4 + ["top"] * (len(U) + 1)
    rings = _col_to_rings(cols)

    mats = {
        "raw": [m("PattyRaw"), m("PattyRawDark"), m("PattyFat")],
        "cooked": [m("PattyCooked"), m("PattyCrust"), m("PattyGrill")],
        "burnt": [m("PattyBurnt"), m("PattyBurntB"), m("Char")],
    }[kind]
    nz = Noise(seed * 5 + 3, 3, 2.4)

    def fm(ra, rb_, k, f):
        c = f.calc_center_median()
        t = tg[rb_]
        if kind == "raw":
            return 0
        if kind == "cooked":
            if t in ("bot", "arc", "side") or rb_ <= 13:
                return 1
            return 0
        return 0

    parts = [skin(mats, rings, fm, "Patty")]

    if kind == "raw":
        placed = []
        tries = 0
        while len(placed) < 34 and tries < 600:
            tries += 1
            a, r = rng.uniform(0, 6.283), 1.28 * math.sqrt(rng.uniform(0.02, 1.0))
            x, y = r * math.cos(a), r * math.sin(a)
            if any(math.hypot(x - px, y - py) < 0.22 for px, py in placed):
                continue
            placed.append((x, y))
            parts.append(lens_xy(m("PattyFat"), x, y, rng.uniform(0.06, 0.15), rng.uniform(0.04, 0.08),
                                 rng.uniform(0, 3.14), top_z, lift=0.002, peak=0.012, n=6))
    elif kind == "cooked":
        for ang, c, smax in lines:
            pts = []
            n = 14
            for i in range(n + 1):
                s = -smax + 2 * smax * i / n
                pts.append((s * math.cos(ang) - c * math.sin(ang), s * math.sin(ang) + c * math.cos(ang)))
            parts.append(ribbon_xy(m("PattyGrill"), pts, lambda t: 0.15 * max(0.0, math.sin(math.pi * t)) ** 0.45,
                                   top_z, 0.012, 0.006))
        placed = []
        for _ in range(60):
            a, r = rng.uniform(0, 6.283), 1.1 * math.sqrt(rng.uniform(0.05, 1.0))
            x, y = r * math.cos(a), r * math.sin(a)
            if grill(x, y) > 0.05 or any(math.hypot(x - px, y - py) < 0.55 for px, py in placed):
                continue
            placed.append((x, y))
            parts.append(lens_xy(m("PattyJuice"), x, y, 0.1, 0.05, rng.uniform(0, 3.14), top_z, 0.004, 0.016, 7))
            if len(placed) >= 5:
                break
    else:
        for pts in cracks:
            parts.append(ribbon_xy(m("Ember"), pts, lambda t: 0.125 * (0.5 + 0.5 * math.sin(math.pi * min(1.0, t * 1.4))),
                                   top_z, 0.014, 0.012))
        for i in range(6):
            a, r = rng.uniform(0, 6.283), rng.uniform(0.3, 1.1)
            x, y = r * math.cos(a), r * math.sin(a)
            if crack_dist(x, y) < 0.15:
                continue
            parts.append(lens_xy(m("Ash"), x, y, rng.uniform(0.07, 0.14), rng.uniform(0.05, 0.09),
                                 rng.uniform(0, 3.14), top_z, 0.002, 0.02, 6))
        for i in range(9):  # crumbly bits around the rim
            a = 2 * math.pi * i / 9 + rng.uniform(-0.2, 0.2)
            rr = R * edge(a) - rng.uniform(0.04, 0.2)
            sz = rng.uniform(0.07, 0.15)
            parts.append(ball(m("Char" if i % 3 else "Ash"), (sz * 1.3, sz, sz * 0.8),
                              (rr * math.cos(a), rr * math.sin(a), top_z(rr * math.cos(a), rr * math.sin(a)) - 0.01),
                              rot=(0, 0, rng.uniform(0, 3.14)), seg=6, rings=4))
    return parts


# ---------------------------------------------------------------------------
# sausage
# ---------------------------------------------------------------------------
_SAUS_TAB = [(0.0, 0.0), (0.03, 0.2), (0.12, 0.22), (0.22, 0.26), (0.32, 0.42), (0.45, 0.62), (0.6, 0.8),
             (0.78, 0.91), (1.0, 0.97), (1.3, 1.0), (1.7, 1.0), (2.25, 1.02)]


def _sraw(d):
    for (d0, r0), (d1, r1) in zip(_SAUS_TAB[:-1], _SAUS_TAB[1:]):
        if d <= d1:
            t = (d - d0) / (d1 - d0)
            t = t * t * (3 - 2 * t) * 0.6 + t * 0.4
            return r0 + (r1 - r0) * t
    return _SAUS_TAB[-1][1]


def sausage(kind, seed=2):
    rng = random.Random(seed * 17 + {"raw": 1, "cooked": 2, "burnt": 3}[kind])
    HL = 2.25
    RY, RZ = (0.37, 0.39) if kind != "burnt" else (0.34, 0.36)
    BEND = 0.09
    ds = sorted(set([d for d, _ in _SAUS_TAB] + [round(0.11 * i, 3) for i in range(1, 21)]))
    ds = [d for d in ds if d <= HL + 1e-6]
    ts = list(ds) + [2 * HL - d for d in reversed(ds)][1:]
    NS = 18
    wr = Noise(seed + 40, 3, 5.0)

    def rm(t, phi=0.0):
        d = min(t, 2 * HL - t)
        r = _sraw(d) * (1.0 + 0.05 * math.sin(math.pi * t / (2 * HL)))
        if kind == "burnt" and d > 0.3:
            ph = 2 * math.pi * t / 0.62
            r *= 1 + 0.04 * math.sin(ph + 2.0 * phi + 1.2 * wr(t * 1.3, 0, phi)) * smoothstep(0.3, 0.7, d)
            r *= 1 + 0.025 * wr(t * 2.1, 1.0, phi * 1.7)
        return r

    def centre(t):
        u = t / (2 * HL)
        return Vector((t - HL, -BEND * (1 - (2 * u - 1) ** 2) + BEND * 0.5, 0.0))

    def P(t, phi, off=0.0):
        r = rm(t, phi)
        c = centre(t)
        return Vector((c.x, c.y + (RY * r + off) * math.cos(phi), RZ * r + (RZ * r + off) * math.sin(phi)))

    def N(t, phi):
        return Vector((0, math.cos(phi) / RY, math.sin(phi) / RZ)).normalized()

    rings = []
    for i, t in enumerate(ts):
        if i == 0 or i == len(ts) - 1:
            c = centre(t)
            rings.append([Vector((c.x, c.y, RZ * 0.2))])
        else:
            rings.append([P(t, 2 * math.pi * k / NS) for k in range(NS)])

    mats = {
        "raw": [m("SausageRaw"), m("SausageTie")],
        "cooked": [m("SausageCooked"), m("SausageTie")],
        "burnt": [m("SausageBurnt"), m("SausageBurntB")],
    }[kind]
    nz = Noise(seed + 7, 3, 2.0)

    def fm(ra, rb_, k, f):
        t = ts[rb_]
        d = min(t, 2 * HL - t)
        if d < 0.3:
            return 1
        return 0

    parts = [skin(mats, rings, fm, "Sausage")]
    hint = lambda p: Vector((0, p.y - centre(p.x + HL).y, p.z - RZ))  # noqa: E731

    def rib(mat, tphi, tw, lift, crown=0.008):
        """Ribbon through (t, phi) points; tw = half width along the length in metres (may be a function)."""
        rows = []
        n = len(tphi)
        for i, (t, phi) in enumerate(tphi):
            w = tw(i / (n - 1)) if callable(tw) else tw
            rows.append([P(t - w, phi, lift), P(t, phi, lift + crown), P(t + w, phi, lift)])
        return strip(mat, rows, hint)

    def lens3(mat, t, phi, rx, ry, peak, rot=0.0, n=7):
        c = P(t, phi, 0.0)
        nn = N(t, phi)
        T = Vector((1, 0, 0))
        B = Vector((0, -math.sin(phi), math.cos(phi)))
        rim = []
        for i in range(n):
            a = 2 * math.pi * i / n + 0.3
            ca, sa = rx * math.cos(a), ry * math.sin(a)
            vx, vb = ca * math.cos(rot) - sa * math.sin(rot), ca * math.sin(rot) + sa * math.cos(rot)
            tt = t + vx
            ph = phi + vb / (RY * rm(tt))
            rim.append(P(tt, ph, 0.004))
        return lens_poly(mat, c + nn * peak, rim, hint)

    if kind == "raw":
        for _ in range(14):
            t = rng.uniform(0.7, 2 * HL - 0.7)
            phi = rng.uniform(0.2, math.pi - 0.2)
            parts.append(lens3(m("SausageRawSpot"), t, phi, rng.uniform(0.05, 0.1), rng.uniform(0.04, 0.07), 0.012,
                               rng.uniform(0, 3), 6))
    elif kind == "cooked":
        for i in range(6):
            t0 = 0.85 + i * 0.5
            pts = []
            for j in range(9):
                phi = math.radians(10 + 160 * j / 8)
                pts.append((t0 + 0.34 * (phi - math.pi / 2) / (math.pi / 2), phi))
            parts.append(rib(m("SausageMark"), pts, lambda u: 0.055 * max(0.0, math.sin(math.pi * u)) ** 0.4 + 0.004, 0.015))
        for t, phi in ((1.35, math.radians(60)), (3.2, math.radians(115))):
            parts.append(lens3(m("SausageBlister"), t, phi, 0.3, 0.1, 0.05, 0.1, 8))
            parts.append(lens3(m("SausageSlit"), t, phi, 0.2, 0.026, 0.056, 0.1, 6))
    else:
        pts = []
        for i in range(21):
            t = 0.6 + (2 * HL - 1.2) * i / 20
            pts.append((t, math.radians(90 + 9 * math.sin(i * 0.9 + 1.0) + 4 * math.sin(i * 2.3))))
        wf = lambda u: 0.07 * (0.5 + 0.5 * math.sin(math.pi * u) ** 0.5) * (0.8 + 0.3 * math.sin(u * 17))  # noqa: E731
        parts.append(rib(m("SausageInside"), pts, wf, 0.012, 0.01))
        for sgn in (-1, 1):  # raised curled lips either side
            lp = [(t, phi + sgn * math.radians(17)) for t, phi in pts]
            parts.append(rib(m("SausageBurntB"), lp, lambda u: 0.05 * max(0.0, math.sin(math.pi * u)) ** 0.4 + 0.004,
                             0.012, 0.035))
        for t in (1.2, 2.3, 3.4):
            parts.append(lens3(m("Ember"), t, math.radians(92), 0.12, 0.03, 0.03, 0.05, 6))
    return parts


# ---------------------------------------------------------------------------
# hot dog bun
# ---------------------------------------------------------------------------
def hotdog_bun(seed=5):
    L = 5.0
    A, B = 0.8, 0.5
    NSL = 26
    n_exp = 2.5
    NF = Noise(seed, 3, 1.8)
    rng = random.Random(seed)

    def sup(w):
        return math.copysign(abs(w) ** (2 / n_exp), w)

    def sect(x):
        e = math.sqrt(max(0.0, 1 - min(1.0, abs(2 * x / L)) ** 3.2))
        o = smoothstep(0.0, 1.0, (L / 2 - abs(x) - 0.4) / 0.9)
        eh = e ** 0.6
        a, b = A * e, B * eh
        zb = 0.14 * (1 - eh)
        return e, o, eh, a, b, zb + b

    def outer(x, w):
        e, o, eh, a, b, zc = sect(x)
        wob = 1 + 0.025 * NF(x * 0.9, math.sin(w) * 1.5, math.cos(w) * 1.5)
        return Vector((x, a * sup(math.sin(w)) * wob, zc + b * sup(math.cos(w)) * wob))

    OUT = 17
    rings = []
    for i in range(NSL + 1):
        psi = math.pi * i / NSL
        x = -(L / 2) * math.cos(psi)
        if i == 0 or i == NSL:
            rings.append([Vector((x, 0.0, 0.18))])
            continue
        e, o, eh, a, b, zc = sect(x)
        om0 = 0.62 * o
        loop = [outer(x, om0 + (2 * math.pi - 2 * om0) * j / (OUT - 1)) for j in range(OUT)]
        lipR, lipL = loop[0], loop[-1]
        dv = 0.62 * o * eh
        for t in (-0.7, -0.35, 0.0, 0.35, 0.7):
            f = (t + 1) / 2
            yy = lipL.y + (lipR.y - lipL.y) * f
            zl = lipL.z + (lipR.z - lipL.z) * f
            loop.append(Vector((x, yy, zl - dv * (1 - abs(t) ** 1.1))))
        rings.append(loop)

    mats = [m("BunCrust"), m("BunGloss"), m("BunLow"), m("BunFlour"), m("BunCrumb"), m("BunToast"), m("BunPore")]

    def fm(ra, rb_, k, f):
        c = f.calc_center_median()
        if k >= OUT - 1:
            if k in (OUT - 1, OUT + 3):
                return 5
            return 4
        if c.z < 0.3:
            return 2
        return 1 if c.z > 0.5 else 0

    parts = [skin(mats, rings, fm, "HotdogBun")]
    hint = lambda p: Vector((0, p.y * 0.4, 1.0))  # noqa: E731
    for _ in range(11):  # flour dusting: slightly lighter patches on the shoulders
        x = rng.uniform(-1.9, 1.9)
        w = rng.uniform(0.85, 1.55)
        if rng.random() < 0.5:
            w = 2 * math.pi - w
        parts.append(lens_uv(m("BunFlour"), outer, x, w, rng.uniform(0.18, 0.38), rng.uniform(0.12, 0.26),
                             rng.uniform(0, 3.14), 0.004, 0.012, hint, 8))
    return parts


# ---------------------------------------------------------------------------
# burger buns
# ---------------------------------------------------------------------------
def _pores(rng, zfn, rmax, count, parts, mat):
    placed = []
    for _ in range(count * 4):
        a, r = rng.uniform(0, 6.283), rmax * math.sqrt(rng.uniform(0.0, 1.0))
        x, y = r * math.cos(a), r * math.sin(a)
        if any(math.hypot(x - px, y - py) < 0.22 for px, py in placed):
            continue
        placed.append((x, y))
        parts.append(lens_xy(mat, x, y, rng.uniform(0.04, 0.09), rng.uniform(0.025, 0.05), rng.uniform(0, 3.14),
                             zfn, 0.001, 0.004, 6))
        if len(placed) >= count:
            break


def bun_bottom(seed=4):
    rng = random.Random(seed)
    NZ = Noise(seed, 3, 2.2)
    ph = [rng.uniform(0, 6.283) for _ in range(3)]

    def edge(th):
        return 1 + 0.018 * math.sin(2 * th + ph[0]) + 0.012 * math.sin(3 * th + ph[1]) + 0.008 * math.sin(5 * th + ph[2])

    def crumb_z(x, y):
        r = math.hypot(x, y)
        return 0.63 + 0.05 * smoothstep(0.0, 1.35, r) + 0.01 * NZ(x * 1.5, y * 1.5)

    segs = 44
    cols = []
    for k in range(segs):
        th = 2 * math.pi * k / segs
        f = edge(th)
        c, s = math.cos(th), math.sin(th)
        pts = [(0, 0), (0.8, 0), (1.28, 0)]
        for a in (30, 60, 90):
            al = math.radians(a)
            pts.append((1.28 + 0.32 * math.sin(al), 0.32 - 0.32 * math.cos(al)))
        pts += [(1.64, 0.43), (1.62, 0.52)]
        for a in (62, 35, 10, 0):  # rolled lip, 1.42 -> top
            al = math.radians(a)
            pts.append((1.42 + 0.2 * math.sin(al) * 1.0, 0.5 + 0.2 * math.cos(al)))
        pts = [(rho * f, z) for rho, z in pts]
        for rho in (1.3, 1.1, 0.95, 0.8, 0.55, 0.3, 0.1):
            pts.append((rho * f, crumb_z(rho * c, rho * s)))
        pts.append((0, crumb_z(0, 0)))
        cols.append([Vector((rho * c, rho * s, z)) for rho, z in pts])
    rings = _col_to_rings(cols)
    tg = ["bot"] * 3 + ["arc"] * 3 + ["side"] * 2 + ["lip"] * 4 + ["toast", "toast", "toast", "crumb", "crumb", "crumb", "crumb", "crumb"]
    mats = [m("BunCrust"), m("BunGloss"), m("BunLow"), m("BunCrumb"), m("BunToast")]

    def fm(ra, rb_, k, f):
        t = tg[rb_]
        if t == "crumb":
            return 3
        if t == "toast":
            return 4
        if t in ("bot", "arc"):
            return 2
        return 1 if t == "lip" else 0

    parts = [skin(mats, rings, fm, "BunBottom")]
    _pores(rng, crumb_z, 1.0, 12, parts, m("BunPore"))
    return parts


def bun_top(seed=6):
    rng = random.Random(seed)
    NZ = Noise(seed, 3, 2.0)
    Rm, zs, Hd, p, q = 1.62, 0.3, 0.8, 2.3, 2.0
    ph = [rng.uniform(0, 6.283) for _ in range(3)]

    def edge(th):
        return 1 + 0.02 * math.sin(2 * th + ph[0]) + 0.012 * math.sin(3 * th + ph[1]) + 0.008 * math.sin(5 * th + ph[2])

    def dome_z(x, y):
        u = min(0.9999, math.hypot(x, y) / Rm)
        return zs + Hd * (1 - u ** p) ** (1 / q) + 0.014 * NZ(x * 1.4, y * 1.4)

    def under_z(x, y):
        r = math.hypot(x, y)
        return 0.075 - 0.05 * smoothstep(0.5, 1.3, r) + 0.008 * NZ(x * 1.7, y * 1.7)

    segs = 44
    cols = []
    betas = [8, 20, 34, 48, 62, 75, 86]
    for k in range(segs):
        th = 2 * math.pi * k / segs
        f = edge(th)
        c, s = math.cos(th), math.sin(th)
        pts = [(0, under_z(0, 0))]
        for rho in (0.3, 0.6, 0.9, 1.15, 1.34):
            pts.append((rho * f, under_z(rho * c, rho * s)))
        pts += [(1.46 * f, 0.0), (1.56 * f, 0.05), (1.61 * f, 0.13), (1.62 * f, 0.22), (Rm * f, zs)]
        for b_ in betas:
            u = math.cos(math.radians(b_)) ** (2 / p)
            rho = Rm * u * f
            pts.append((rho, dome_z(rho * c, rho * s)))
        pts.append((0, dome_z(0, 0)))
        cols.append([Vector((rho * c, rho * s, z)) for rho, z in pts])
    rings = _col_to_rings(cols)
    tg = ["crumb"] * 4 + ["toast", "toast"] + ["lip"] * 4 + ["side"] + ["dome"] * (len(betas) + 1)
    mats = [m("BunCrust"), m("BunGloss"), m("BunLow"), m("BunCrumb"), m("BunToast")]
    nf = Noise(seed + 3, 3, 2.6)

    def fm(ra, rb_, k, f):
        t = tg[rb_]
        if t == "crumb":
            return 3
        if t == "toast":
            return 4
        if t == "lip":
            return 2
        return 0 if t == "side" else 1

    parts = [skin(mats, rings, fm, "BunTop")]
    # sesame seeds: raised teardrops lying on the dome
    placed = []
    tries = 0
    while len(placed) < 17 and tries < 600:
        tries += 1
        a = rng.uniform(0, 6.283)
        r = Rm * 0.84 * math.sqrt(rng.uniform(0.0, 1.0))
        x, y = r * math.cos(a), r * math.sin(a)
        if any(math.hypot(x - px, y - py) < 0.4 for px, py in placed):
            continue
        placed.append((x, y))
        z = dome_z(x, y)
        e = 0.02
        gx = (dome_z(x + e, y) - dome_z(x - e, y)) / (2 * e)
        gy = (dome_z(x, y + e) - dome_z(x, y - e)) / (2 * e)
        nrm = Vector((-gx, -gy, 1.0)).normalized()
        yaw = rng.uniform(0, 6.283)
        T = Vector((math.cos(yaw), math.sin(yaw), 0.0))
        T = (T - nrm * T.dot(nrm)).normalized()
        Bv = nrm.cross(T)
        L_, W_, H_ = rng.uniform(0.32, 0.4), rng.uniform(0.18, 0.22), 0.1
        centre = Vector((x, y, z)) + nrm * 0.004
        rows = [[centre - T * 0.4 * L_ + nrm * 0.0]]
        for qq in (0.12, 0.3, 0.52, 0.74, 0.9):
            tt = qq ** 0.62
            w = math.sin(math.pi * tt) ** 0.85
            cq = centre + T * (qq - 0.4) * L_
            rows.append([cq + (Bv * math.cos(aa) * W_ / 2 + nrm * math.sin(aa) * H_) * w
                         for aa in [2 * math.pi * j / 5 for j in range(5)]])
        rows.append([centre + T * 0.6 * L_])
        parts.append(skin([m("Sesame" if rng.random() > 0.2 else "SesameToast")], rows, None, "Seed"))
    return parts
