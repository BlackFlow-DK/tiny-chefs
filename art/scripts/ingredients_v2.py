"""Rebuilt patty / sausage / bun models. Run: tools/blender-run.ps1 art/scripts/ingredients_v2.py [-- name ...]

Exports over the same file names as ingredients.py (which now calls these builders too).
Each model is joined, fitted to the exact contract size (X x Y x Z, Y up), grounded and exported.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bpy  # noqa: E402

import artlib  # noqa: E402
import foodparts_v2 as fp  # noqa: E402
import shapes  # noqa: E402

MODELS = [
    ("bun_bottom", lambda: fp.bun_bottom(), (3.2, 0.7, 3.2)),
    ("bun_top", lambda: fp.bun_top(), (3.2, 1.1, 3.2)),
    ("patty_raw", lambda: fp.patty("raw"), (3.0, 0.6, 3.0)),
    ("patty_cooked", lambda: fp.patty("cooked"), (3.0, 0.6, 3.0)),
    ("patty_burnt", lambda: fp.patty("burnt"), (3.0, 0.6, 3.0)),
    ("sausage_raw", lambda: fp.sausage("raw"), (4.5, 0.8, 0.8)),
    ("sausage_cooked", lambda: fp.sausage("cooked"), (4.5, 0.8, 0.8)),
    ("sausage_burnt", lambda: fp.sausage("burnt"), (4.5, 0.8, 0.8)),
    ("hotdog_bun", lambda: fp.hotdog_bun(), (5.0, 1.0, 1.6)),
]


def build(name, make, size):
    artlib.reset_scene()
    obj = artlib.join(make(), shapes._pascal(name))
    lo, hi = shapes.world_bounds([obj])
    got = (hi.x - lo.x, hi.z - lo.z, hi.y - lo.y)
    # contract (X, Y up, Z) -> Blender (X, Z, Y): fit the mesh to the exact size
    obj.scale = (size[0] / got[0], size[2] / got[2], size[1] / got[1])
    print(f"FIT {name}: scale {tuple(round(v, 3) for v in obj.scale)}")
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    shapes.build_asset(name, [obj], size)


if __name__ == "__main__":
    only = set(artlib.script_args())
    for name, make, size in MODELS:
        if only and name not in only:
            continue
        build(name, make, size)
