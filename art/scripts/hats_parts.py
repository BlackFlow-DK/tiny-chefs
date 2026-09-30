"""Geometry helpers for chef hats and face accessories (own helper file; chef_parts.py/shapes.py untouched).

All geometry is authored in the chef's RAW authoring frame (characters.py before `shapes.settle`), relative to
the anchor, so a model's origin is its anchor. `shapes.settle` later shifts the real chef by CHEF_SHIFT; the
anchors reported to the game are the raw anchors plus that shift. Blender Z-up, front is -Y.
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bpy  # noqa: E402,F401
from mathutils import Matrix  # noqa: E402
from chef_parts import V, grid, ellip, tube, xf  # noqa: E402,F401

PI = math.pi

# settle shift applied to the chef by characters.py (measured by hats_preview_chef.py: CHEF_SHIFT)
CHEF_SHIFT = V((0.0, -0.03881, 0.006))
# raw authoring-frame anchors (toque base ring centre; head surface at x=0 at eye height)
HAT_RAW = V((0.0, 0.0, 0.975))
FACE_RAW = V((0.0, -0.21795, 0.90))
HAT_ANCHOR_BLENDER = HAT_RAW + CHEF_SHIFT
FACE_ANCHOR_BLENDER = FACE_RAW + CHEF_SHIFT


def to_godot(p):
    return (round(p.x, 4), round(p.z, 4), round(-p.y, 4))


# head + hair in the hat frame (origin = HAT_RAW)
HEAD_C = V((0, 0, 0.895 - 0.975))
HEAD_R = (0.238, 0.218, 0.212)
HAIR_C = V((0, 0.05, 0.96 - 0.975))
HAIR_R = (0.236, 0.215, 0.092)


def g_ell(p, c, r):
    return ((p.x - c.x) / r[0]) ** 2 + ((p.y - c.y) / r[1]) ** 2 + ((p.z - c.z) / r[2]) ** 2


def clearance(label, objs, zmin=-0.04):
    """Min ellipsoid value of head/hair over the hat vertices above zmin. <1 = vertex inside the head or hair."""
    worst, bad, n = 9.0, 0, 0
    for o in objs:
        for v in o.data.vertices:
            p = o.matrix_world @ v.co
            if p.z < zmin:
                continue
            g = min(g_ell(p, HEAD_C, HEAD_R), g_ell(p, HAIR_C, HAIR_R))
            n += 1
            worst = min(worst, g)
            if g < 1.0:
                bad += 1
    print("CLEARANCE %s: min g=%.3f (1=on the head) inside=%d of %d" % (label, worst, bad, n))
    return worst, bad


def tilt(objs, pitch_deg=0.0, roll_deg=0.0, pivot=(0, 0, 0)):
    """Rotate parts about the anchor: pitch (+ = top tips forward), roll (+ = top tips to +X)."""
    pv = V(pivot)
    m = Matrix.Translation(pv) @ Matrix.Rotation(math.radians(roll_deg), 4, "Y") @ Matrix.Rotation(
        math.radians(-pitch_deg), 4, "X") @ Matrix.Translation(-pv)
    for o in objs:
        xf(o, m)


class Shell:
    """Egg-shaped dome that hugs the head: an ellipsoid scaled about the head centre, cut by a rim plane whose
    height follows the head tilt (high in front over the brows, low behind over the hair).
    theta: 0 = front (-Y), pi = back; v: 0 at the rim, 1 at the crown."""

    def __init__(self, rx=0.262, ryf=0.237, ryb=0.29, rz=0.242, zc=-0.08, zf=0.058, zb=-0.035):
        self.rx, self.ryf, self.ryb, self.rz, self.zc, self.zf, self.zb = rx, ryf, ryb, rz, zc, zf, zb

    def blend(self, th):
        return (1.0 + math.cos(th)) / 2.0  # 1 front, 0 back

    def rim_z(self, th):
        s = self.blend(th)
        return self.zb + (self.zf - self.zb) * s

    def ry(self, th):
        s = self.blend(th)
        return self.ryb + (self.ryf - self.ryb) * s

    def top(self):
        return self.zc + self.rz

    def pt(self, th, v, grow=0.0):
        rx, ry, rz = self.rx + grow, self.ry(th) + grow, self.rz + grow
        zr = self.rim_z(th)
        el0 = math.asin(max(-1.0, min(1.0, (zr - self.zc) / rz)))
        el = el0 + (PI / 2 - el0) * v
        c = math.cos(el)
        return V((rx * c * math.sin(th), -ry * c * math.cos(th), self.zc + rz * math.sin(el)))

    def hnorm(self, th):
        """Horizontal outward direction at the rim."""
        rx, ry = self.rx, self.ry(th)
        p = V((math.sin(th), -math.cos(th), 0.0))
        n = V((p.x / rx, p.y / ry, 0.0))
        return n.normalized()


def surf_normal(f, u, v, du=1e-3, dv=1e-3):
    """Outward normal of a parametric surface f(u, v) on a dome around the head centre."""
    p = f(u, v)
    a = f(u + du, v) - f(u - du, v)
    v2 = min(v + dv, 1.0)
    v1 = max(v - dv, 0.0)
    b = f(u, v2) - f(u, v1)
    n = a.cross(b)
    if n.length < 1e-9:
        return V((0, 0, 1))
    n.normalize()
    if n.dot(p - V((0, 0, -0.08))) < 0:
        n = -n
    return n
