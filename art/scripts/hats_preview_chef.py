"""Preview-only helper: builds chef_bare.glb (the chef WITHOUT the built-in toque) next to a record of the chef's
settle shift, by running characters.py's source with small patches (characters.py itself is not modified).

Output: game/assets/dev/chef_bare.glb (dev preview only, do not ship). Prints CHEF_SHIFT x y z: the translation
`shapes.settle` applies to the raw authoring coordinates of the real chef (toque included).
Run: tools/blender-run.ps1 art/scripts/hats_preview_chef.py
"""
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import bpy  # noqa: E402
import artlib  # noqa: E402
import shapes  # noqa: E402

SRC = (HERE / "characters.py").read_text()
SRC = SRC[:SRC.index("artlib.reset_scene()\ngparts")]  # chef only, no glove

state = {"shift": None, "apply": None}
real_export = artlib.export_glb


def fake_export(name, out_dir=artlib.MODELS_DIR):
    print("(skipped export", name, ")")


def settle(name, expect, keep=(), tol=0.10, limits=None):
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    lo, hi = shapes.world_bounds(meshes)
    from mathutils import Vector
    shift = Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))
    if state["apply"] is not None:
        shift = state["apply"]
    else:
        state["shift"] = shift.copy()
        print("CHEF_SHIFT %.5f %.5f %.5f" % tuple(shift))
    for o in meshes:
        o.location += shift
    for o in meshes:
        if o not in keep:
            bpy.ops.object.select_all(action="DESELECT")
            o.select_set(True)
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


shapes.settle = settle
artlib.export_glb = fake_export
ns = {"__file__": str(HERE / "characters.py"), "__name__": "chef_exec"}
exec(compile(SRC, str(HERE / "characters.py"), "exec"), ns)  # pass 1: real chef, learn the shift

state["apply"] = state["shift"]
bare = SRC.replace("P.append(toque)", "bpy.data.objects.remove(toque, do_unlink=True)")
assert bare != SRC
ns = {"__file__": str(HERE / "characters.py"), "__name__": "chef_exec"}
exec(compile(bare, str(HERE / "characters.py"), "exec"), ns)  # pass 2: no toque, same frame
real_export("chef_bare", out_dir=artlib.REPO_ROOT / "game" / "assets" / "dev")
