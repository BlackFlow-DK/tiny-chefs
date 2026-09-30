"""Second batch of ingredient models. Run: tools/blender-run.ps1 art/scripts/ingredients2.py [-- name ...]

Each model is joined, scaled to the exact contract size (X x Y x Z, Y up), grounded and exported.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bpy  # noqa: E402

import artlib  # noqa: E402
import foodparts2 as fp  # noqa: E402
import shapes  # noqa: E402

MODELS = [
    ("bacon_raw", lambda: fp.bacon("raw"), (4.0, 0.3, 1.2)),
    ("bacon_cooked", lambda: fp.bacon("cooked"), (4.0, 0.3, 1.2)),
    ("bacon_burnt", lambda: fp.bacon("burnt"), (4.0, 0.3, 1.2)),
    ("egg", lambda: fp.egg(), (1.8, 2.2, 1.8)),
    ("fried_egg", lambda: fp.fried_egg("fried"), (3.0, 0.4, 3.0)),
    ("egg_burnt", lambda: fp.fried_egg("burnt"), (3.0, 0.4, 3.0)),
    ("onion", lambda: fp.onion(), (2.4, 2.4, 2.4)),
    ("onion_slice", lambda: fp.onion_slice(), (2.2, 0.3, 2.2)),
    ("onion_rings", lambda: fp.onion_rings("fried"), (2.6, 0.8, 2.6)),
    ("onion_rings_burnt", lambda: fp.onion_rings("burnt"), (2.6, 0.8, 2.6)),
    ("pickle_slice", lambda: fp.pickle_slice(), (1.6, 0.25, 1.6)),
    ("potato", lambda: fp.potato(), (2.6, 2.0, 2.0)),
    ("fries_raw", lambda: fp.fries_raw(), (2.8, 1.2, 2.8)),
    ("fries", lambda: fp.fries("fried"), (2.8, 2.5, 2.8)),
    ("fries_burnt", lambda: fp.fries("burnt"), (2.8, 2.5, 2.8)),
    ("chicken_raw", lambda: fp.chicken("raw"), (3.0, 0.7, 3.0)),
    ("chicken_cooked", lambda: fp.chicken("cooked"), (3.0, 0.7, 3.0)),
    ("chicken_burnt", lambda: fp.chicken("burnt"), (3.0, 0.7, 3.0)),
    ("soda_cup", lambda: fp.soda_cup(), (2.2, 3.0, 2.2)),
]

only = set(artlib.script_args())
for name, make, size in MODELS:
    if only and name not in only:
        continue
    artlib.reset_scene()
    obj = artlib.join(make(), shapes._pascal(name))
    lo, hi = shapes.world_bounds([obj])
    got = (hi.x - lo.x, hi.z - lo.z, hi.y - lo.y)
    # contract (X, Y up, Z) -> Blender (X, Z, Y): fit the mesh to the exact size
    obj.scale = (size[0] / got[0], size[2] / got[2], size[1] / got[1])
    print(f"FIT {name}: scale {tuple(round(v, 2) for v in obj.scale)}")
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    shapes.build_asset(name, [obj], size)
