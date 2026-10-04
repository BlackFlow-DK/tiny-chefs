"""Converts the postcard renders (2048x1024 PNG) to the shipped lobby map pictures:
game/assets/ui/maps/<map_id>_<n>.webp, 1024x512, lossy quality 85.
Usage: python tools/map_thumbs.py <render dir> [map ids...]"""
import os, sys
from PIL import Image

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
out = os.path.join(root, "game", "assets", "ui", "maps")
src = sys.argv[1]
ids = sys.argv[2:] or ["diner", "food_truck", "picnic", "twin_islands"]
os.makedirs(out, exist_ok=True)
for m in ids:
    for n in range(1, 9):
        f = os.path.join(src, "%s_%d.png" % (m, n))
        if not os.path.exists(f):
            break
        Image.open(f).convert("RGB").resize((1024, 512), Image.LANCZOS).save(os.path.join(out, "%s_%d.webp" % (m, n)), quality=85, method=6)
        print("wrote", m, n)
