"""Geometry helpers for hats_b.py (cone, party, fez, beret, cap, santa, headphones, frog, halo).

Builds on hats_parts.py (Shell, clearance, tilt) and chef_parts.py. Hat frame: origin = HatAnchor, Blender
Z-up, front is -Y. Head ellipsoid centre (0,0,-0.08), radii (0.238,0.218,0.212); hair is behind/above.
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bmesh  # noqa: E402,F401
import bpy  # noqa: E402,F401
from mathutils import Matrix  # noqa: E402,F401
from chef_parts import V, _interp, ellip, grid, tube, xf  # noqa: E402,F401
from hats_parts import (HEAD_C, HEAD_R, PI, Shell, clearance, g_ell, tilt)  # noqa: E402,F401


def head_pt(az, el, off=1.0):
    """Point on the head ellipsoid scaled by `off` (az: 0 = front, pi = back; el: elevation rad)."""
    c = math.cos(el)
    return V((HEAD_R[0] * c * math.sin(az), -HEAD_R[1] * c * math.cos(az), HEAD_C.z + HEAD_R[2] * math.sin(el))) * 1.0 \
        if off == 1.0 else V((HEAD_R[0] * off * c * math.sin(az), -HEAD_R[1] * off * c * math.cos(az),
                              HEAD_C.z + HEAD_R[2] * off * math.sin(el)))


class DropShell(Shell):
    """Shell whose rim also drops at the sides (hood over the ears): rim z minus sd * sin^2(theta)."""

    def __init__(self, sd=0.0, **kw):
        super().__init__(**kw)
        self.sd = sd

    def rim_z(self, th):
        return super().rim_z(th) - self.sd * math.sin(th) ** 2


def lath_fn(sh, rows, grow=0.0, wob=None, v0=0.0, v1=1.0):
    def f(u, v):
        th = 2 * PI * u
        k, hr, hz = _interp(rows, v0 + (v1 - v0) * v)
        w = wob(th, v0 + (v1 - v0) * v) if wob else 1.0
        x = (sh.rx + grow) * k * w * math.sin(th)
        y = -(sh.ry(th) + grow) * k * w * math.cos(th)
        return V((x, y, hr * sh.rim_z(th) + hz))
    return f


def lath(sh, mat, rows, nu=48, nv=18, name="Lath", grow=0.0, wob=None, v0=0.0, v1=1.0):
    """Egg-shaped surface of revolution following the shell footprint.

    rows: [(t, k, hr, hz)] ascending in t (0..1). k scales the shell footprint (rx, ry(theta)),
    z = hr * rim_z(theta) + hz  (hr 1 follows the tilted rim, 0 is a flat level). wob(th, v) -> radial factor."""
    f = lath_fn(sh, rows, grow, wob, v0, v1)
    return grid(mat, f, nu, nv, closed=True, name=name)


def bishop(spine, nv):
    """Parallel-transport frames along spine(t) sampled at nv+1 points. Returns [(p, e1, e2)]."""
    pts = [spine(j / nv) for j in range(nv + 1)]
    out = []
    e1 = V((1, 0, 0))
    for j, p in enumerate(pts):
        a = pts[max(j - 1, 0)]
        b = pts[min(j + 1, nv)]
        t = (b - a).normalized()
        e1 = (e1 - t * e1.dot(t)).normalized()
        e2 = t.cross(e1)
        out.append((p, e1, e2))
    return out


def sweep(mat, spine, section, nv=24, nu=36, name="Sweep", cap_start=False, cap_end=False):
    """Tube-like surface: section(th, t) -> (a, b) offset along (e1, e2) of the bishop frame at spine(t)."""
    fr = bishop(spine, nv)

    def f(u, v):
        p, e1, e2 = fr[int(round(v * nv))]
        a, b = section(2 * PI * u, v)
        return p + e1 * a + e2 * b
    return grid(mat, f, nu, nv, closed=True, name=name, cap=False)


def bezier(p0, p1, p2, p3):
    p0, p1, p2, p3 = V(p0), V(p1), V(p2), V(p3)

    def f(t):
        s = 1 - t
        return p0 * (s ** 3) + p1 * (3 * s * s * t) + p2 * (3 * s * t * t) + p3 * (t ** 3)
    return f


def fuzz_ball(mat, c, r, n=14, tuft=0.58, name="Fuzz"):
    """A pompom: smooth core plus a ring of overlapping tufts."""
    c = V(c)
    P = [ellip(mat, c, (r * 0.92,) * 3, nu=12, nv=7, name=name + "Core")]
    for i in range(n):
        y = 1 - 2 * (i + 0.5) / n
        rr = math.sqrt(1 - y * y)
        a = i * 2.39996
        d = V((rr * math.cos(a), rr * math.sin(a), y))
        P.append(ellip(mat, c + d * (r * 0.72), (r * tuft,) * 3, nu=7, nv=4, name=name + "Tuft"))
    return P


def disc(mat, c, rx, ry, thick, n=None, rot=None, name="Disc", sq=2.6):
    """Flattened superellipsoid plate (local Z is the thin axis)."""
    return ellip(mat, c, (rx, ry, thick), n=n, rot=rot, nu=24, nv=6, name=name, sq=sq)


def surf_pt(sh, th, v, grow=0.0):
    return sh.pt(th, v, grow)
