"""Food part builders shared by ingredients.py and dispensers.py.

Each builder takes an offset `o` (centre of the part's base) and a uniform scale `s`,
and returns a list of Blender objects (materials assigned, transforms not applied).
"""
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import artlib  # noqa: E402
from shapes import ball, box, cyl, lathe, dome_profile, roughen, sheet  # noqa: E402

PAL = {
    "Bun": ("#d4913a", 0.8),
    "BunPale": ("#f7e2ae", 0.9),
    "Sesame": ("#fff6d8", 0.6),
    "PattyRaw": ("#d9585a", 0.6),
    "PattyRawLump": ("#ee8f8b", 0.6),
    "PattyCooked": ("#7d4526", 0.85),
    "Grill": ("#2b150b", 0.9),
    "PattyBurnt": ("#1e1a18", 0.95),
    "Ash": ("#75706a", 1.0),
    "Ember": ("#c2440f", 0.7),
    "Cheese": ("#ffcf1c", 0.5),
    "Lettuce": ("#4fbf35", 0.7),
    "LettuceLight": ("#a6e36a", 0.7),
    "Tomato": ("#e0301f", 0.45),
    "TomatoDark": ("#b51d12", 0.5),
    "TomatoFlesh": ("#f57d55", 0.5),
    "TomatoSeed": ("#ffe9a0", 0.5),
    "Stem": ("#2f9a2a", 0.7),
    "SausageRaw": ("#f2a6a3", 0.5),
    "SausageCooked": ("#a5432a", 0.55),
    "SausageBurnt": ("#231a17", 0.9),
    "SausageMark": ("#45190d", 0.8),
}


def m(name):
    hexc, rough = PAL[name]
    return artlib.material(name, hexc, roughness=rough)


def _p(o, s, x, y, z):
    return (o[0] + x * s, o[1] + y * s, o[2] + z * s)


def _sp(s, pts):
    return [(r * s, z * s) for r, z in pts]


def bun_bottom(o=(0, 0, 0), s=1.0):
    prof = _sp(s, [(0, 0), (1.35, 0), (1.6, 0.22), (1.6, 0.5), (1.45, 0.7), (0, 0.7)])
    return [lathe([m("Bun"), m("BunPale")], prof, verts=16, loc=o,
                  face_mat=lambda c: 1 if c.z > 0.66 * s else 0)]


def bun_top(o=(0, 0, 0), s=1.0, seeds=True):
    parts = [lathe(m("Bun"), _sp(s, dome_profile(1.6, 1.0, base=0.25, steps=4)), verts=16, loc=o)]
    if seeds:
        rng = random.Random(4)
        spots = [(90, 0), (62, 20), (62, 110), (62, 200), (62, 290), (38, 65), (38, 155), (38, 245), (38, 335),
                 (20, 0), (20, 120), (20, 240)]
        for elev, phi in spots:
            t, ph = math.radians(elev), math.radians(phi + rng.uniform(-8, 8))
            r = 1.6 * math.cos(t) * 0.97
            z = 0.25 + 0.75 * math.sin(t) * 0.98
            parts.append(ball(m("Sesame"), (0.22 * s, 0.12 * s, 0.07 * s),
                              _p(o, s, r * math.cos(ph), r * math.sin(ph), z), rot=(0, 0, ph), seg=6, rings=4))
    return parts


def _patty(kind, o, s, seed, lumps):
    R, H = 1.5 * s, 0.56 * s
    j = {"raw": 0.08, "cooked": 0.035, "burnt": 0.10}[kind]
    col = {"raw": "PattyRaw", "cooked": "PattyCooked", "burnt": "PattyBurnt"}[kind]
    body = lathe(m(col), [(0, 0), (R, 0), (R, H), (0, H)], verts=18, loc=o)
    roughen(body, lambda a: 1 - j * (0.5 + 0.5 * math.sin(7 * a + seed * 1.3)) * (0.6 + 0.4 * math.cos(3 * a + seed)))
    parts = [body]
    top = o[2] + H
    if kind == "raw" and lumps:
        for i in range(6):
            a = 2 * math.pi * i / 6 + seed
            r = 0.55 * s if i % 2 else 0.95 * s
            parts.append(ball(m("PattyRawLump"), (0.3 * s, 0.26 * s, 0.09 * s),
                              (o[0] + r * math.cos(a), o[1] + r * math.sin(a), top), seg=6, rings=4))
        parts.append(ball(m("PattyRawLump"), (0.35 * s, 0.3 * s, 0.09 * s), (o[0], o[1], top), seg=6, rings=4))
    if kind == "cooked" and lumps:
        for d in (-0.95, -0.32, 0.32, 0.95):
            length = 2 * math.sqrt(max(0.0, (1.5 * 0.92) ** 2 - d * d)) * s
            ca, sa = math.cos(math.radians(45)), math.sin(math.radians(45))
            cx, cy = -sa * d * s, ca * d * s
            parts.append(box(m("Grill"), (length, 0.2 * s, 0.09 * s), (o[0] + cx, o[1] + cy, top - 0.005 * s),
                             rot=(0, 0, math.radians(45))))
    if kind == "burnt" and lumps:
        rng = random.Random(seed + 11)
        for i in range(5):  # glowing cracks
            a, r = rng.uniform(0, 6.28), rng.uniform(0.0, 0.8) * s
            parts.append(box(m("Ember"), (rng.uniform(0.6, 1.0) * s, 0.09 * s, 0.09 * s),
                             (o[0] + r * math.cos(a), o[1] + r * math.sin(a), top - 0.01 * s),
                             rot=(0, 0, rng.uniform(0, 3.14))))
        for i in range(6):  # ash flecks
            a, r = rng.uniform(0, 6.28), rng.uniform(0.2, 1.1) * s
            parts.append(ball(m("Ash"), (rng.uniform(0.15, 0.3) * s, rng.uniform(0.12, 0.2) * s, 0.07 * s),
                              (o[0] + r * math.cos(a), o[1] + r * math.sin(a), top - 0.005 * s), seg=6, rings=4))
    return parts


def patty_raw(o=(0, 0, 0), s=1.0, seed=0, lumps=True):
    return _patty("raw", o, s, seed, lumps)


def patty_cooked(o=(0, 0, 0), s=1.0, seed=0, lumps=True):
    return _patty("cooked", o, s, seed, lumps)


def patty_burnt(o=(0, 0, 0), s=1.0, seed=0, lumps=True):
    return _patty("burnt", o, s, seed, lumps)


def cheese_slice(o=(0, 0, 0)):
    def droop(x, y):
        u, v = abs(x) / 1.5, abs(y) / 1.5
        return -0.09 * u * v * (0.6 + 0.4 * (u + v) / 2)
    return [sheet(m("Cheese"), 3.0, 3.0, 0.06, 6, droop, loc=o)]


def lettuce_leaf(o=(0, 0, 0)):
    R = 1.6

    def wave(x, y):
        rn = math.hypot(x, y) / R
        th = math.atan2(y, x)
        return 0.29 * rn ** 1.4 * (0.5 + 0.5 * math.sin(4 * th + rn * 2.5))

    def vein(c):
        if c.z < 0.02:
            pass
        for a in (0.0, math.radians(32), math.radians(-32)):
            d = c.x * math.cos(a) + c.y * math.sin(a)
            perp = abs(-c.x * math.sin(a) + c.y * math.cos(a))
            if d > -1.0 and perp < 0.13 and math.hypot(c.x, c.y) < 1.4:
                return 1
        return 0

    return [sheet([m("Lettuce"), m("LettuceLight")], 2 * R, 2 * R, 0.06, 14, wave, disc=True, loc=o, face_mat=vein)]


def tomato(o=(0, 0, 0), s=1.0):
    R = 1.05
    parts = [ball(m("Tomato"), R * s, (o[0], o[1], o[2] + R * s), seg=12, rings=8)]
    for i in range(5):
        a = 2 * math.pi * i / 5 + 0.3
        parts.append(box(m("Stem"), (0.6 * s, 0.17 * s, 0.07 * s),
                         (o[0] + 0.26 * s * math.cos(a), o[1] + 0.26 * s * math.sin(a), o[2] + 2 * R * s - 0.03 * s),
                         rot=(0, math.radians(20), a)))
    parts.append(cyl(m("Stem"), 0.08 * s, 0.16 * s, (o[0], o[1], o[2] + 2 * R * s + 0.02 * s), verts=6))
    return parts


def tomato_slice(o=(0, 0, 0), s=1.0):
    H = 0.28 * s
    prof = _sp(s, [(0, 0), (1.0, 0), (1.0, 0.28), (0.88, 0.28), (0.5, 0.28), (0, 0.28)])

    def fm(c):
        r = math.hypot(c.x, c.y) / s
        if c.z > 0.27 * s:
            if r < 0.5:
                return 2
            if r < 0.9:
                return 1
        return 0

    parts = [lathe([m("TomatoDark"), m("Tomato"), m("TomatoFlesh")], prof, verts=14, loc=o, face_mat=fm)]
    for i in range(5):
        a = 2 * math.pi * i / 5 + 0.4
        parts.append(ball(m("TomatoSeed"), (0.17 * s, 0.11 * s, 0.045 * s),
                          (o[0] + 0.66 * s * math.cos(a), o[1] + 0.66 * s * math.sin(a), o[2] + H),
                          rot=(0, 0, a), seg=6, rings=4))
    return parts


def sausage(kind, o=(0, 0, 0), length=4.5, r=0.4, seed=0):
    col = {"raw": "SausageRaw", "cooked": "SausageCooked", "burnt": "SausageBurnt"}[kind]
    ox, oy, oz = o
    body_len = length - 2 * r
    parts = [cyl(m(col), r, body_len, (ox, oy, oz + r), rot=(0, math.pi / 2, 0), verts=8)]
    for sx in (-1, 1):
        parts.append(ball(m(col), r, (ox + sx * body_len / 2, oy, oz + r), seg=8, rings=4))
    if kind == "cooked":
        for f in (-0.32, -0.11, 0.1, 0.31):
            parts.append(cyl(m("SausageMark"), r * 1.04, 0.15 * length / 4.5,
                             (ox + f * length, oy, oz + r), rot=(0, math.pi / 2, 0), verts=8))
    if kind == "burnt":
        rng = random.Random(seed + 3)
        for f in (-0.32, -0.11, 0.1, 0.31):
            parts.append(ball(m("Ash"), (0.3 * r * 2, 0.2 * r * 1.4, 0.1 * r * 1.2),
                              (ox + f * length + rng.uniform(-0.1, 0.1), oy + rng.uniform(-0.1, 0.1), oz + 2 * r * 0.98),
                              seg=6, rings=4))
    return parts


def hotdog_bun(o=(0, 0, 0), s=1.0):
    """Two round lobes side by side (split along the top) with a pale cut strip between them."""
    ox, oy, oz = o
    r = 0.45 * s
    length = 5.0 * s - 2 * r
    parts = []
    for sy in (-1, 1):
        cy, cz = oy + sy * 0.38 * s, oz + 0.53 * s
        parts.append(cyl(m("Bun"), r, length, (ox, cy, cz), rot=(0, math.pi / 2, 0), verts=10))
        for sx in (-1, 1):
            parts.append(ball(m("Bun"), (r, r, r), (ox + sx * length / 2, cy, cz), seg=10, rings=5))
    parts.append(box(m("Bun"), (length + r, 0.6 * s, 0.4 * s), (ox, oy, oz + 0.25 * s)))
    parts.append(box(m("BunPale"), (length + 0.3 * s, 0.34 * s, 0.1 * s), (ox, oy, oz + 0.76 * s)))
    return parts
