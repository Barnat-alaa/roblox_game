"""Slice the owner's icon sheet into per-button PNGs.

The sheet LOOKS transparent but the checkerboard is painted in as opaque pixels,
and each icon's glow is BLENDED with it. A hard colour key leaves a dirty ring,
so the background is un-mixed instead: every pixel reachable from the border
gets an alpha from how far it sits from the checker grey, and its colour is
un-premultiplied to take the grey back out. Glow stays soft, no halo.
"""
import math
import os
from collections import deque

from PIL import Image

IMAGE_PATH = r"C:\Users\barna\Downloads\Gemini_Generated_Image_obnpdkobnpdkobnp.png"
OUTPUT_DIR = "sheet_icons"
ROWS, COLS = 3, 4

ICON_NAMES = {
    (0, 0): "StarButton",
    (0, 1): "GoalsButton",
    (0, 2): "TrophiesButton",
    (0, 3): "MusicButton",
    (1, 0): "BuildButton",
    (1, 1): "StaffButton",
    (1, 2): "ShopButton",
    (1, 3): "UpgradesButton",
    (2, 0): "CoinsButton",
    (2, 1): "ProgressionButton",
    (2, 2): "MoneyButton",
    (2, 3): "RankingsButton",
}

# Distance from the checker grey at which a pixel counts as fully the icon.
# The white outline sits ~117 away, so 88 keeps outlines solid while letting the
# glow ramp.
FULL_AT = 105.0
# The checkerboard is TWO tones (~97 and ~135) plus compression noise, and the
# anti-aliased seam between squares lands midway. Anything within this distance
# of either tone is background outright — without the dead zone the squares
# survive at partial alpha and un-premultiply into muddy darks.
CLEAR_BELOW = 38.0


def unmix(img):
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()

    # Learn BOTH checker tones from a background-only strip. Sampling corners
    # alone found only the light squares, and the dark ones then survived.
    histogram = {}
    for y in range(0, 26):
        for x in range(0, w, 2):
            r, g, b, _ = px[x, y]
            if max(abs(r - g), abs(g - b), abs(r - b)) <= 12:
                histogram[r] = histogram.get(r, 0) + 1
    ranked = sorted(histogram.items(), key=lambda kv: -kv[1])
    greys = [ranked[0][0]]
    for tone, _count in ranked:
        if all(abs(tone - g) > 20 for g in greys):
            greys.append(tone)
            break
    print("checker tones:", greys)

    def distance(p):
        # Nearest of the two checker tones, in plain RGB distance.
        best = min(
            math.sqrt((p[0] - g) ** 2 + (p[1] - g) ** 2 + (p[2] - g) ** 2)
            for g in greys
        )
        return best

    # Flood from the border through everything that is still background-ish, so
    # greys INSIDE an icon (a silver trophy) are never touched.
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
            continue  # solid icon: stop, and leave it fully opaque
        alpha = (d - CLEAR_BELOW) / (FULL_AT - CLEAR_BELOW)
        alpha = max(0.0, min(1.0, alpha))
        if alpha <= 0.02:
            px[x, y] = (0, 0, 0, 0)
        else:
            # observed = fg*a + grey*(1-a)  ->  fg = (observed - grey*(1-a)) / a
            g = min(greys, key=lambda gg: abs(p[0] - gg))
            fg = []
            for c in range(3):
                v = (p[c] - g * (1 - alpha)) / alpha
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
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    sheet = unmix(Image.open(IMAGE_PATH))
    w, h = sheet.size
    tw, th = w / COLS, h / ROWS

    for row in range(ROWS):
        for col in range(COLS):
            box = (
                int(col * tw),
                int(row * th),
                int((col + 1) * tw),
                int((row + 1) * th),
            )
            tile = sheet.crop(box)
            bbox = tile.getbbox()
            if bbox:
                tile = tile.crop(bbox)
            side = max(tile.size)
            square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
            square.paste(
                tile, ((side - tile.width) // 2, (side - tile.height) // 2)
            )
            square = square.resize((256, 256), Image.LANCZOS)
            name = ICON_NAMES.get((row, col), f"Button_R{row + 1}_C{col + 1}")
            square.save(os.path.join(OUTPUT_DIR, f"{name}.png"), "PNG")
    print("sliced", ROWS * COLS, "icons")


if __name__ == "__main__":
    main()
