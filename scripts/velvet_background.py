"""Draws the app background (EncoreVelvetBackground): crimson velvet with a soft stage light above the middle.

Pressed creases (ridged noise), a short diagonal pile and fine grain make it look like real fabric up close.
Usage: python3 scripts/velvet_background.py Encore/Assets.xcassets/EncoreVelvetBackground.imageset/EncoreVelvetBackground.jpg
Needs numpy and Pillow. The seed is fixed, so the picture comes out the same every time.
"""
import sys
import numpy as np
from PIL import Image

W, H = 1320, 2868  # the largest iPhone screen; smaller ones fill and crop
rng = np.random.default_rng(7)
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
u, v = xx / W, yy / H

# Brightness 0…1 to colour; 0.55 is Encore Crimson (#780514).
CRIMSON = [(0.0, (14, 1, 4)), (0.28, (58, 3, 12)), (0.55, (120, 5, 20)), (0.78, (170, 16, 34)), (1.0, (222, 52, 58))]


def noise(cells_x, seed):
    """Smooth value noise in -1…1 with about cells_x features across the width."""
    cx = max(2, int(cells_x)); cy = max(2, int(cells_x * H / W))
    grid = (np.random.default_rng(seed).random((cy, cx)) * 255).astype(np.uint8)
    return np.asarray(Image.fromarray(grid).resize((W, H), Image.BICUBIC), dtype=np.float32) / 127.5 - 1


def fbm(base, octaves, seed):
    total, amp, norm = 0, 1.0, 0
    for o in range(octaves):
        total = total + amp * noise(base * 2 ** o, seed + o)
        norm += amp; amp *= 0.5
    return total / norm


def sample(field, dx, dy):
    """The field read at (x + dx, y + dy), bilinear: bends the creases like pressed fabric."""
    x = np.clip(xx + dx, 0, W - 1.001); y = np.clip(yy + dy, 0, H - 1.001)
    x0 = x.astype(np.int32); y0 = y.astype(np.int32); fx = x - x0; fy = y - y0
    a, b = field[y0, x0], field[y0, x0 + 1]
    c, d = field[y0 + 1, x0], field[y0 + 1, x0 + 1]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


light = np.exp(-(((u - 0.5) / 0.62) ** 2 + ((v - 0.34) / 0.36) ** 2))
edge = np.sqrt(((u - 0.5) / 0.75) ** 2 + ((v - 0.42) / 0.9) ** 2)
vignette = np.clip(1 - 0.55 * np.clip(edge - 0.35, 0, None) ** 1.4, 0, 1) * (1 - 0.45 * np.clip(v - 0.6, 0, None) / 0.4)

warp = fbm(3, 3, 11) * 72, fbm(3, 3, 21) * 72
crease = np.clip(1 - np.abs(sample(fbm(5, 4, 81), *warp)) * 2.2, -1, 1)

fibres = rng.normal(0, 1, (H, W)).astype(np.float32)
pile = sum(np.roll(np.roll(fibres, k, axis=0), k // 2, axis=1) for k in range(9)) / 3

L = np.clip((0.30 + 0.50 * light + 0.07 * crease * (0.6 + 0.6 * light) + 0.025 * pile) * vignette, 0, 1)
rgb = np.stack([np.interp(L, [s[0] for s in CRIMSON], [s[1][ch] for s in CRIMSON]) for ch in range(3)], axis=-1)
rgb += rng.normal(0, 8, (H, W, 1)) + rng.normal(0, 2, (H, W, 3))  # grain, slightly coloured
Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)).save(sys.argv[1], quality=88, optimize=True, progressive=True)
