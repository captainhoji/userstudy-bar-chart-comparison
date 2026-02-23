#!/usr/bin/env python3
"""Crop fixed margins from colormap images.

Example:
  python tools/crop_colormap_top.py \
    --input-glob "static/stimuli/ColorBrewerBlue_white_*.png" \
    --in-place
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError as exc:  # pragma: no cover
    raise SystemExit(
        "Missing dependency: Pillow. Install with `pip install Pillow`."
    ) from exc


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Crop margins from colormap stimulus images."
    )
    parser.add_argument(
        "--input-glob",
        default="static/stimuli/ColorBrewerBlue_white_*.png",
        help="Glob pattern for source images.",
    )
    parser.add_argument("--crop-top", type=int, default=75, help="Pixels to remove from top.")
    parser.add_argument("--crop-right", type=int, default=75, help="Pixels to remove from right.")
    parser.add_argument("--crop-left", type=int, default=35, help="Pixels to remove from left.")
    parser.add_argument("--crop-bottom", type=int, default=35, help="Pixels to remove from bottom.")
    parser.add_argument(
        "--out-dir",
        default="",
        help="Output directory. Required unless --in-place is used.",
    )
    parser.add_argument(
        "--in-place",
        action="store_true",
        help="Overwrite input files instead of writing to out-dir.",
    )
    parser.add_argument(
        "--suffix",
        default="_cropped",
        help="Suffix for output filenames when not in-place.",
    )
    return parser.parse_args()


def crop_one(
    path: Path,
    crop_top: int,
    crop_right: int,
    crop_left: int,
    crop_bottom: int,
    out_path: Path,
) -> None:
    with Image.open(path) as img:
        w, h = img.size
        for name, value in (
            ("crop_top", crop_top),
            ("crop_right", crop_right),
            ("crop_left", crop_left),
            ("crop_bottom", crop_bottom),
        ):
            if value < 0:
                raise ValueError(f"--{name.replace('_', '-')} must be >= 0, got {value}")

        left = crop_left
        top = crop_top
        right = w - crop_right
        bottom = h - crop_bottom

        if right <= left or bottom <= top:
            raise ValueError(
                f"Invalid crop for '{path}': original=({w}x{h}), "
                f"crop=(top={crop_top}, right={crop_right}, left={crop_left}, bottom={crop_bottom})."
            )

        cropped = img.crop((left, top, right, bottom))
        out_path.parent.mkdir(parents=True, exist_ok=True)
        cropped.save(out_path)


def main() -> int:
    args = parse_args()

    if not args.in_place and not args.out_dir:
        print("Error: provide --out-dir or use --in-place.", file=sys.stderr)
        return 2

    src_paths = sorted(Path().glob(args.input_glob))
    if not src_paths:
        print(f"No files matched: {args.input_glob}", file=sys.stderr)
        return 1

    out_dir = Path(args.out_dir) if args.out_dir else None
    count = 0

    for src in src_paths:
        if args.in_place:
            dst = src
        else:
            dst_name = f"{src.stem}{args.suffix}{src.suffix}"
            dst = out_dir / dst_name  # type: ignore[operator]
        crop_one(
            src,
            args.crop_top,
            args.crop_right,
            args.crop_left,
            args.crop_bottom,
            dst,
        )
        count += 1
        print(f"Cropped: {src} -> {dst}")

    print(f"Done. Cropped {count} file(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
