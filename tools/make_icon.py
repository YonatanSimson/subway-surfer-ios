#!/usr/bin/env python3
"""Generate the app icon: a yellow capsule on a track converging to a
vanishing point, in the same palette the game renders with.

The icon is drawn at 4x and downsampled, which is cheaper than hand-rolling
antialiasing for the long diagonals of the track and stripes.

Ships a single 1024x1024 PNG into the asset catalog; Xcode derives the
per-device sizes at build time.

    python3 tools/make_icon.py              # write the shipped icon
    python3 tools/make_icon.py --preview    # also emit 96px and 60px copies

Judge any change at the preview sizes, not at 1024. Detail that looks good
large reliably turns to mush on a home screen — that is what ruled out the
busier candidates this one was chosen over.

Requires Pillow (pip install Pillow).
"""

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

SUPERSAMPLE = 4096
OUTPUT_SIZE = 1024

# Matches GameConfig / GameScene: the sky gradient, floor slate, and the
# player's yellow. Keep these in step with the game if its palette changes.
NAVY_TOP = (13, 17, 36)
NAVY_BOTTOM = (58, 50, 86)
FLOOR_NEAR = (58, 62, 88)
FLOOR_FAR = (38, 42, 64)
STRIPE = (232, 235, 245)
YELLOW = (255, 209, 64)
YELLOW_DARK = (206, 150, 22)
SHADOW = (6, 8, 20)
HIGHLIGHT = (255, 246, 208)
RIM = (150, 100, 10)

DEFAULT_OUT = Path("SubwaySurfer/Assets.xcassets/AppIcon.appiconset/Icon-1024.png")


def vertical_gradient(size, top, bottom):
    """A size x size image graded from `top` to `bottom`."""
    column = Image.new("RGB", (1, size), top)
    draw = ImageDraw.Draw(column)
    for y in range(size):
        t = y / (size - 1)
        draw.point((0, y), tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return column.resize((size, size), Image.BILINEAR)


def capsule_mask(size, cx, cy, w, h, value=255):
    """Mask of a capsule: a rounded rect whose corner radius is half its width."""
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [cx - w // 2, cy - h // 2, cx + w // 2, cy + h // 2], radius=w // 2, fill=value
    )
    return mask


def render():
    s = SUPERSAMPLE
    img = vertical_gradient(s, NAVY_TOP, NAVY_BOTTOM)
    draw = ImageDraw.Draw(img)

    # Vanishing point, high in frame so the track reads as receding.
    vx, vy = s // 2, int(s * 0.26)

    # Floor, graded so it fades out toward the vanishing point.
    floor = vertical_gradient(s, FLOOR_FAR, FLOOR_NEAR)
    floor_mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(floor_mask).polygon(
        [(-s * 0.30, s * 1.02), (s * 1.30, s * 1.02),
         (vx + s * 0.040, vy), (vx - s * 0.040, vy)], fill=255
    )
    img.paste(floor, (0, 0), floor_mask)

    # The two lane stripes, converging on the same point.
    for offset in (-0.255, 0.255):
        draw.polygon(
            [(s * 0.5 + offset * s - s * 0.030, s * 1.02),
             (s * 0.5 + offset * s + s * 0.030, s * 1.02),
             (vx + s * 0.0065, vy), (vx - s * 0.0065, vy)], fill=STRIPE
        )

    cx, cy = s // 2, int(s * 0.545)
    w, h = int(s * 0.270), int(s * 0.500)

    # Soft contact shadow, so the capsule sits on the track rather than floating.
    shadow = Image.new("L", (s, s), 0)
    ImageDraw.Draw(shadow).ellipse(
        [cx - w * 0.92, cy + h * 0.40, cx + w * 0.92, cy + h * 0.62], fill=175
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(s * 0.022))
    img.paste(Image.new("RGB", (s, s), SHADOW), (0, 0), shadow)

    # Capsule body, lit from the top.
    img.paste(vertical_gradient(s, YELLOW, YELLOW_DARK), (0, 0), capsule_mask(s, cx, cy, w, h))

    # Specular highlight down the left flank.
    highlight = capsule_mask(
        s, cx - int(w * 0.17), cy - int(h * 0.06), int(w * 0.34), int(h * 0.60), 92
    ).filter(ImageFilter.GaussianBlur(s * 0.008))
    img.paste(Image.new("RGB", (s, s), HIGHLIGHT), (0, 0), highlight)

    # Darkened right edge, clipped to the body, so it doesn't read as flat.
    rim = capsule_mask(
        s, cx + int(w * 0.30), cy, int(w * 0.40), int(h * 0.92), 70
    ).filter(ImageFilter.GaussianBlur(s * 0.012))
    rim = Image.composite(rim, Image.new("L", (s, s), 0), capsule_mask(s, cx, cy, w, h))
    img.paste(Image.new("RGB", (s, s), RIM), (0, 0), rim)

    return img.resize((OUTPUT_SIZE, OUTPUT_SIZE), Image.LANCZOS)


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT,
                        help=f"where to write the icon (default: {DEFAULT_OUT})")
    parser.add_argument("--preview", action="store_true",
                        help="also write 96px and 60px copies beside it, for legibility checks")
    args = parser.parse_args()

    icon = render()
    args.out.parent.mkdir(parents=True, exist_ok=True)
    icon.save(args.out)
    print(f"wrote {args.out} ({OUTPUT_SIZE}x{OUTPUT_SIZE})")

    if args.preview:
        for px in (96, 60):
            path = args.out.with_name(f"{args.out.stem}-{px}.png")
            icon.resize((px, px), Image.LANCZOS).save(path)
            print(f"wrote {path} ({px}x{px})")


if __name__ == "__main__":
    main()
