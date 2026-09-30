"""Ingredient models (carried by players). Run: tools/blender-run.ps1 art/scripts/ingredients.py"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import artlib  # noqa: E402
import foodparts as fp  # noqa: E402
from shapes import build_asset  # noqa: E402

MODELS = [
    ("bun_bottom", lambda: fp.bun_bottom(), (3.2, 0.7, 3.2)),
    ("bun_top", lambda: fp.bun_top(), (3.2, 1.1, 3.2)),
    ("patty_raw", lambda: fp.patty_raw(), (3.0, 0.6, 3.0)),
    ("patty_cooked", lambda: fp.patty_cooked(), (3.0, 0.6, 3.0)),
    ("patty_burnt", lambda: fp.patty_burnt(), (3.0, 0.6, 3.0)),
    ("cheese_slice", lambda: fp.cheese_slice(), (3.0, 0.15, 3.0)),
    ("lettuce_leaf", lambda: fp.lettuce_leaf(), (3.2, 0.35, 3.2)),
    ("tomato", lambda: fp.tomato(), (2.2, 2.2, 2.2)),
    ("tomato_slice", lambda: fp.tomato_slice(), (2.0, 0.3, 2.0)),
    ("sausage_raw", lambda: fp.sausage("raw"), (4.5, 0.8, 0.8)),
    ("sausage_cooked", lambda: fp.sausage("cooked"), (4.5, 0.8, 0.8)),
    ("sausage_burnt", lambda: fp.sausage("burnt"), (4.5, 0.8, 0.8)),
    ("hotdog_bun", lambda: fp.hotdog_bun(), (5.0, 1.0, 1.6)),
]

for name, make, size in MODELS:
    artlib.reset_scene()
    build_asset(name, make(), size)
