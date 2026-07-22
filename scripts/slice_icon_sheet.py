"""Slice an icon sheet into per-button PNGs ready to upload to Roblox.

The sheets we get back from image generators LOOK transparent but the
checkerboard is painted in as opaque pixels, and each icon's glow is BLENDED
with it. A flat colour key leaves a dirty ring, so the background is un-mixed
instead: every pixel reachable from the border gets an alpha from how far it
sits from the nearer checker tone, and its colour is un-premultiplied to take
that tone back out. Glow stays soft, no halo.

Interior detail is safe because the fill can only travel through background —
an icon's white sticker outline stops it, so dark pixels inside an icon are
never mistaken for the dark checker squares.

Usage:
    python scripts/slice_icon_sheet.py SHEET.png --rows 3 --cols 4 \
        --names StarButton,GoalsButton,...   # row-major, one name per cell
"""

import argparse
import math
import os
from collections import deque

from PIL import Image

# Distance from a checker tone at which a pixel counts as fully the icon.
FULL_AT = 130.0
# Everything this close to either tone is background outright. The two tones
# plus compression noise need a dead zone, or the squares survive at partial
# alpha and un-premultiply into muddy darks.
CLEAR_BELOW = 58.0


def checker_tones(px, width):
    """Learn BOTH checker tones from a background-only strip along the top."""
    histogram = {}
    for y in range(0, 24):
        for x in range(0, width, 2):
            r, g, b, _ = px[x, y]
            if max(abs(r - g), abs(g - b), abs(r - b)) <= 14:
                histogram[r] = histogram.get(r, 0) + 1
    ranked = sorted(histogram.items(), key=lambda kv: -kv[1])
    if not ranked:
        return [136]
    tones = [ranked[0][0]]
    for tone, _count in ranked:
        if all(abs(tone - t) > 20 for t in tones):
            tones.append(tone)
            break
    return tones


def unmix(img):
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()
    tones = checker_tones(px, w)
    print("checker tones:", tones)

    def distance(p):
        return min(
            math.sqrt((p[0] - t) ** 2 + (p[1] - t) ** 2 + (p[2] - t) ** 2)
            for t in tones
        )

    seen = bytearray(w * h)
    queue = deque()
    for x in range(w):
        queue.append((x, 0))
        queue.append((x, h - 1))
    for y in range(h):
        queue.append((0, y))
        queue.append((w - 1, y))

    touched = 0
    while queue:
        x, y = queue.popleft()
        if x < 0 or y < 0 or x >= w or y >= h:
            continue
        idx = y * w + x
        if seen[idx]:
            continue
        seen[idx] = 1
        p = px[x, y]
        d = distance(p)
        if d >= FULL_AT:
            continue  # solid icon: stop here and leave it opaque
        alpha = max(0.0, min(1.0, (d - CLEAR_BELOW) / (FULL_AT - CLEAR_BELOW)))
        if alpha <= 0.02:
            px[x, y] = (0, 0, 0, 0)
        else:
            tone = min(tones, key=lambda t: abs(p[0] - t))
            fg = []
            for c in range(3):
                v = (p[c] - tone * (1 - alpha)) / alpha
                fg.append(max(0, min(255, int(round(v)))))
            px[x, y] = (fg[0], fg[1], fg[2], int(round(alpha * 255)))
        touched += 1
        queue.append((x + 1, y))
        queue.append((x - 1, y))
        queue.append((x, y + 1))
        queue.append((x, y - 1))
    print(f"un-mixed {touched} background/glow pixels of {w * h}")
    return img


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("image")
    parser.add_argument("--rows", type=int, default=3)
    parser.add_argument("--cols", type=int, default=4)
    parser.add_argument("--names", default="", help="comma separated, row-major")
    parser.add_argument("--out", default="cropped_icons")
    parser.add_argument("--size", type=int, default=256)
    args = parser.parse_args()

    names = [n.strip() for n in args.names.split(",") if n.strip()]
    os.makedirs(args.out, exist_ok=True)
    sheet = unmix(Image.open(args.image))
    w, h = sheet.size
    tw, th = w / args.cols, h / args.rows

    for row in range(args.rows):
        for col in range(args.cols):
            tile = sheet.crop(
                (
                    int(col * tw),
                    int(row * th),
                    int((col + 1) * tw),
                    int((row + 1) * th),
                )
            )
            bbox = tile.getbbox()
            if bbox:
                tile = tile.crop(bbox)
            # Re-pad square so every button gets the same visual weight
            # regardless of the artwork's own margins.
            side = max(tile.size)
            square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
            square.paste(
                tile, ((side - tile.width) // 2, (side - tile.height) // 2)
            )
            square = square.resize((args.size, args.size), Image.LANCZOS)
            index = row * args.cols + col
            name = names[index] if index < len(names) else f"R{row + 1}_C{col + 1}"
            path = os.path.join(args.out, f"{name}.png")
            square.save(path, "PNG")
            print("saved", path)


if __name__ == "__main__":
    main()
