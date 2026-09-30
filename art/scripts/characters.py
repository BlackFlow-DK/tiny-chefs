"""Character models: chef (player) and boxing_glove (upgrade). Run: tools/blender-run.ps1 art/scripts/characters.py

The chef keeps HandL / HandR as separate objects whose origin is the hand centre (so the game can
animate each hand by moving its node). Everything else is one mesh named Chef with material ChefBody
on the capsule (code tints it per player). Character faces Blender -Y (Godot +Z); HandL is at +X.
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bpy  # noqa: E402
import artlib  # noqa: E402
from shapes import ball, box, build_asset, cyl  # noqa: E402

M = artlib.material


def _hand(name, mat, x):
    o = ball(mat, 0.085, (x, -0.04, 0.5), seg=8, rings=5)
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    o.name = name
    o.data.name = name
    return o


def chef():
    body = M("ChefBody", "#f1f1f1", 0.6)
    hat = M("ChefHat", "#ffffff", 0.7)
    skin = M("ChefHand", "#f3c8a0", 0.6)
    eye_w = M("ChefEyeWhite", "#ffffff", 0.4)
    eye_b = M("ChefPupil", "#15151a", 0.4)
    shoe = M("ChefShoe", "#3a2a22", 0.7)

    r = 0.3
    parts = [ball(body, r, (0, 0, 0.4), seg=12, rings=6),
             cyl(body, r, 0.3, (0, 0, 0.55), verts=12),
             ball(body, r, (0, 0, 0.7), seg=12, rings=6)]
    for sx in (-1, 1):
        parts.append(ball(shoe, (0.13, 0.19, 0.08), (sx * 0.14, -0.08, 0.08), seg=8, rings=4))
        parts.append(ball(eye_w, (0.09, 0.055, 0.105), (sx * 0.11, -0.262, 0.74), seg=8, rings=5))
        parts.append(ball(eye_b, (0.05, 0.03, 0.06), (sx * 0.11, -0.30, 0.73), seg=6, rings=4))
    parts.append(cyl(hat, 0.26, 0.24, (0, 0, 1.05), verts=12))
    parts.append(ball(hat, (0.38, 0.38, 0.27), (0, 0, 1.13), seg=12, rings=6))
    parts.append(ball(hat, (0.2, 0.2, 0.12), (0, 0, 1.3), seg=8, rings=4))
    hand_l = _hand("HandL", skin, 0.32)
    hand_r = _hand("HandR", skin, -0.32)
    return parts + [hand_l, hand_r], (hand_l, hand_r)


def boxing_glove():
    red = M("GloveRed", "#d8232a", 0.45)
    white = M("GloveCuff", "#f6f6f2", 0.6)
    dark = M("GloveShade", "#a51a20", 0.5)
    parts = [ball(red, (0.24, 0.2, 0.25), (0, -0.05, 0.25), seg=10, rings=6),
             ball(red, (0.2, 0.16, 0.17), (0.0, -0.13, 0.31), seg=8, rings=5),
             ball(dark, (0.08, 0.13, 0.08), (0.19, -0.1, 0.17), seg=6, rings=4),
             cyl(white, 0.17, 0.13, (0, 0.19, 0.25), rot=(math.pi / 2, 0, 0), verts=10)]
    return parts


artlib.reset_scene()
parts, hands = chef()
build_asset("chef", parts, (0.8, 1.4, 0.8), separate=hands)

artlib.reset_scene()
build_asset("boxing_glove", boxing_glove(), (0.5, 0.5, 0.5))
