"""Splits the official logo into mountain / wordmark / tagline layers (same canvas crop) for animation."""
import sys
from PIL import Image
import numpy as np
src = Image.open(sys.argv[1]).convert('RGB')
a = np.asarray(src).astype(np.float32)
r, g, b = a[..., 0], a[..., 1], a[..., 2]
lum = a.max(axis=2)
blue = np.clip(b / np.maximum(lum, 1), 0, 1)
amber = (blue < 0.72) & (lum > 20)
box = (300, 870, 2700, 2210)
H = np.arange(a.shape[0])[:, None]
def save(mask, color, name):
    alpha = np.where(mask, np.where(lum > 24, lum, 0), 0).astype(np.uint8)
    out = np.zeros(a.shape[:2] + (4,), np.uint8)
    out[..., :3] = color
    out[..., 3] = alpha
    Image.fromarray(out).crop(box).resize((1200, 670), Image.LANCZOS).save(f'public/brand/{name}.png')
save(amber, (255, 181, 71), 'mountain')
save(~amber & (H < 2080), (255, 255, 255), 'wordmark')
save(~amber & (H >= 2080), (255, 255, 255), 'tagline')
