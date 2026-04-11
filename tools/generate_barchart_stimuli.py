#!/usr/bin/env python3
"""
Generate side-by-side bar-chart stimuli and trial metadata for bar-chart mode.

Design summary:
- Each dataset is a pair of charts (left/right), 10 bars each, y in [0, 100].
- Three color conditions:
  1) same-color
  2) double-encoding (smaller -> lighter, larger -> darker)
  3) random colors (lightest/darkest do not align with min/max bars)
- Task assignment (tallest vs shortest) is done in the frontend by block;
  this CSV stores only stimulus/image-level metadata.
"""

from __future__ import annotations

import csv
import random
from pathlib import Path

import matplotlib.pyplot as plt
from matplotlib.colors import to_rgb, to_hex

RNG = random.Random(20260311)

OUT_DIR = Path("static/stimuli/barcharts")
TRIALS_CSV = OUT_DIR / "barchart_trials.csv"

# Real pool: 96 underlying datasets. Each dataset is rendered in 3 colors so
# the frontend can assign exactly one color version per dataset at runtime.
# Practice pool uses 12 underlying datasets for the 12-practice-trial block.
N_REAL_DATASETS = 96
N_PRACTICE_DATASETS = 12

LIGHT_HEX = "#deebf7"
DARK_HEX = "#08306b"
SAME_HEX = "#6baed6"


def lerp_color(hex_a: str, hex_b: str, t: float) -> str:
    """Linear interpolation between two hex colors."""
    a = to_rgb(hex_a)
    b = to_rgb(hex_b)
    rgb = (
        a[0] + (b[0] - a[0]) * t,
        a[1] + (b[1] - a[1]) * t,
        a[2] + (b[2] - a[2]) * t,
    )
    return to_hex(rgb)


def rank_color_map(values: list[int]) -> list[str]:
    """Map values to gradient colors (small->light, large->dark)."""
    uniq = sorted(set(values))
    if len(uniq) == 1:
        return [SAME_HEX for _ in values]
    idx_by_val = {v: i for i, v in enumerate(uniq)}
    n = len(uniq) - 1
    colors = []
    for v in values:
        t = idx_by_val[v] / n
        colors.append(lerp_color(LIGHT_HEX, DARK_HEX, t))
    return colors


def generate_dataset(tallest_side: str, shortest_side: str) -> tuple[list[int], list[int]]:
    """
    Create one left/right dataset with constraints:
    - tallest and second-tallest differ by 5 and are on opposite sides
    - shortest and second-shortest differ by 5 and are on opposite sides
    - shortest >= 15
    """
    assert tallest_side in {"left", "right"}
    assert shortest_side in {"left", "right"}

    while True:
        left = [0] * 10
        right = [0] * 10

        tallest = RNG.randint(82, 96)
        second_tallest = tallest - 5
        shortest = RNG.randint(15, 32)
        second_shortest = shortest + 5

        # Ensure room for interior bars.
        if second_shortest + 2 >= second_tallest - 2:
            continue

        # Place extrema at unique positions on each side to avoid accidental overwrites.
        left_free = list(range(10))
        right_free = list(range(10))

        if tallest_side == "left":
            hi_idx = RNG.choice(left_free)
            left_free.remove(hi_idx)
            shi_idx = RNG.choice(right_free)
            right_free.remove(shi_idx)
            left[hi_idx] = tallest
            right[shi_idx] = second_tallest
        else:
            hi_idx = RNG.choice(right_free)
            right_free.remove(hi_idx)
            shi_idx = RNG.choice(left_free)
            left_free.remove(shi_idx)
            right[hi_idx] = tallest
            left[shi_idx] = second_tallest

        if shortest_side == "left":
            lo_idx = RNG.choice(left_free)
            left_free.remove(lo_idx)
            slo_idx = RNG.choice(right_free)
            right_free.remove(slo_idx)
            left[lo_idx] = shortest
            right[slo_idx] = second_shortest
        else:
            lo_idx = RNG.choice(right_free)
            right_free.remove(lo_idx)
            slo_idx = RNG.choice(left_free)
            left_free.remove(slo_idx)
            right[lo_idx] = shortest
            left[slo_idx] = second_shortest

        # Fill remaining bars with interior values.
        for arr in (left, right):
            for i in range(10):
                if arr[i] == 0:
                    arr[i] = RNG.randint(second_shortest + 1, second_tallest - 1)

        # Validate side constraints.
        all_vals = left + right
        max_val = max(all_vals)
        min_val = min(all_vals)

        max_side = "left" if max(left) == max_val else "right"
        min_side = "left" if min(left) == min_val else "right"
        if max_side != tallest_side or min_side != shortest_side:
            continue

        # Validate fixed gap constraints.
        sorted_desc = sorted(all_vals, reverse=True)
        sorted_asc = sorted(all_vals)
        if sorted_desc[0] - sorted_desc[1] != 5:
            continue
        if sorted_asc[1] - sorted_asc[0] != 5:
            continue
        if sorted_asc[0] < 15:
            continue

        return left, right


def make_random_colors(values: list[int]) -> list[str]:
    """
    Random color assignment where the tallest/shortest bars are not assigned
    either endpoint lightness. This avoids a misleading "darkest == tallest"
    or "lightest == shortest" cue in the random condition.
    """
    # Start from value-derived gradient, then permute assignments.
    base_colors = rank_color_map(values)
    min_idx = values.index(min(values))
    max_idx = values.index(max(values))

    # Identify visually lightest/darkest colors in base palette by their rank index.
    uniq_vals = sorted(set(values))
    color_by_val = {v: lerp_color(LIGHT_HEX, DARK_HEX, i / (len(uniq_vals) - 1 if len(uniq_vals) > 1 else 1))
                    for i, v in enumerate(uniq_vals)}
    lightest = color_by_val[min(uniq_vals)]
    darkest = color_by_val[max(uniq_vals)]

    for _ in range(200):
        perm = base_colors[:]
        RNG.shuffle(perm)
        if perm[min_idx] in {lightest, darkest}:
            continue
        if perm[max_idx] in {lightest, darkest}:
            continue
        return perm

    # Fallback: swap away violating endpoints.
    perm = base_colors[:]
    RNG.shuffle(perm)
    if perm[min_idx] in {lightest, darkest}:
        for i in range(len(perm)):
            if i != min_idx and perm[i] not in {lightest, darkest}:
                perm[min_idx], perm[i] = perm[i], perm[min_idx]
                break
    if perm[max_idx] in {lightest, darkest}:
        for i in range(len(perm)):
            if i != max_idx and perm[i] not in {lightest, darkest}:
                perm[max_idx], perm[i] = perm[i], perm[max_idx]
                break
    return perm


def draw_pair_image(out_path: Path, left_vals: list[int], right_vals: list[int], color_condition: str) -> None:
    """Render one side-by-side chart pair image."""
    fig, axes = plt.subplots(1, 2, figsize=(8.0, 4.6), dpi=140)
    x = list(range(10))

    if color_condition == "same":
        left_colors = [SAME_HEX] * 10
        right_colors = [SAME_HEX] * 10
    elif color_condition == "double":
        left_colors = rank_color_map(left_vals)
        right_colors = rank_color_map(right_vals)
    else:
        left_colors = make_random_colors(left_vals)
        right_colors = make_random_colors(right_vals)

    for ax, vals, colors in ((axes[0], left_vals, left_colors), (axes[1], right_vals, right_colors)):
        ax.bar(x, vals, color=colors, edgecolor="black", linewidth=0.6, width=0.72)
        ax.set_ylim(0, 100)
        ax.set_xticks([])
        ax.set_yticks([])
        ax.set_xlabel("")
        ax.set_ylabel("")
        ax.spines["top"].set_visible(False)
        ax.spines["right"].set_visible(False)
        ax.spines["left"].set_visible(False)

    plt.subplots_adjust(wspace=0.28, left=0.04, right=0.96, bottom=0.08, top=0.96)
    fig.savefig(out_path, facecolor="white")
    plt.close(fig)


def balanced_side_combos(n: int) -> list[tuple[str, str]]:
    """
    Return balanced side combos.

    We balance:
      - side of tallest bar (left/right)
      - side of shortest bar (left/right)
    In double-encoding condition, shortest side also corresponds to lightest side.
    """
    combos = [("left", "left"), ("left", "right"), ("right", "left"), ("right", "right")]
    reps = n // 4
    rest = n % 4
    result = combos * reps + combos[:rest]
    RNG.shuffle(result)
    return result


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    rows = []
    total_datasets = N_REAL_DATASETS + N_PRACTICE_DATASETS
    # Balance side combinations independently in real vs practice pools.
    real_combos = balanced_side_combos(N_REAL_DATASETS)
    practice_combos = balanced_side_combos(N_PRACTICE_DATASETS)

    for dataset_idx in range(total_datasets):
        pool = "real" if dataset_idx < N_REAL_DATASETS else "practice"
        if pool == "real":
            tallest_side, shortest_side = real_combos[dataset_idx]
        else:
            practice_idx = dataset_idx - N_REAL_DATASETS
            tallest_side, shortest_side = practice_combos[practice_idx]

        left_vals, right_vals = generate_dataset(tallest_side, shortest_side)

        for color_condition in ("same", "double", "random"):
            filename = f"barchart_{dataset_idx:02d}_{color_condition}.png"
            draw_pair_image(OUT_DIR / filename, left_vals, right_vals, color_condition)

            rows.append({
                "pool": pool,
                "dataset_index": dataset_idx,
                "image_file": filename,
                "color_condition": color_condition,
                "tallest_side": tallest_side,
                "shortest_side": shortest_side,
                "lightest_side": shortest_side,
            })

    with TRIALS_CSV.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=[
                "pool",
                "dataset_index",
                "image_file",
                "color_condition",
                "tallest_side",
                "shortest_side",
                "lightest_side",
            ],
        )
        writer.writeheader()
        writer.writerows(rows)

    print(f"Generated {total_datasets * 3} bar-chart images in: {OUT_DIR}")
    print(f"Generated {len(rows)} stimulus rows in: {TRIALS_CSV}")


if __name__ == "__main__":
    main()
