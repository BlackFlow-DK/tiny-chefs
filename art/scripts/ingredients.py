"""Ingredient models (carried by players). Run: tools/blender-run.ps1 art/scripts/ingredients.py"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import artlib  # noqa: E402
import foodparts as fp  # noqa: E402
import ingredients_v2 as v2  # noqa: E402
from shapes import build_asset  # noqa: E402

MODELS = [
    ("cheese_slice", lambda: fp.cheese_slice(), (3.0, 0.15, 3.0)),
    ("lettuce_leaf", lambda: fp.lettuce_leaf(), (3.2, 0.35, 3.2)),
    ("tomato", lambda: fp.tomato(), (2.2, 2.2, 2.2)),
    ("tomato_slice", lambda: fp.tomato_slice(), (2.0, 0.3, 2.0)),
]

for name, make, size in MODELS:
    artlib.reset_scene()
    build_asset(name, make(), size)

# patty / sausage / bun models were rebuilt in ingredients_v2.py (same file names)
for name, make, size in v2.MODELS:
    v2.build(name, make, size)
