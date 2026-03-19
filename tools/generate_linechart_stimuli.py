#!/usr/bin/env python3
"""
Generate line-chart PNG stimuli for the experiment.

Output:
- 84 PNG files total:
  - 42 base charts (32 real + 10 practice)
  - each rendered with 2 legend variants (A/B)
"""

from __future__ import annotations

import random
from pathlib import Path
import csv
from itertools import combinations

import matplotlib.pyplot as plt
from matplotlib.lines import Line2D


# Reproducible stimuli generation.
RNG = random.Random(260309)

# Keep points comfortably below axis ceiling to avoid marker clipping at top.
MAX_POINT_VALUE = 960

# Pool sizes.
N_REAL_CHARTS = 32
N_PRACTICE_CHARTS = 10

# Output folder for generated line-chart stimuli.
OUT_DIR = Path("static/stimuli/linecharts")
QUESTIONS_CSV = OUT_DIR / "linechart_questions.csv"

# Marker pool requested by the study design.
MARKER_STYLES = [
    {"marker": "o", "filled": True},   # black-filled circle
    {"marker": "s", "filled": True},   # black-filled square
    {"marker": "^", "filled": True},   # black-filled triangle
    {"marker": "o", "filled": False},  # white-filled circle
    {"marker": "s", "filled": False},  # white-filled square
    {"marker": "^", "filled": False},  # white-filled triangle
]

# 10 preset themes used for real and practice chart pools.
THEMES = [
    {
        "name": "School Performance",
        "x_left": "Grade 9",
        "x_right": "Grade 10",
        "x_axis_label": "Grade level",
        "y_label": "Score",
        "categories": ["Math", "Science", "English", "History", "Art", "PE"],
    },
    {
        "name": "Music Popularity",
        "x_left": "Week 1",
        "x_right": "Week 2",
        "x_axis_label": "Week",
        "y_label": "Streams",
        "categories": ["Pop", "Hip-hop", "Rock", "R&B", "EDM", "Indie"],
    },
    {
        "name": "Fitness Activities",
        "x_left": "Last month",
        "x_right": "This month",
        "x_axis_label": "Month",
        "y_label": "Participants",
        "categories": ["Running", "Yoga", "Cycling", "Swimming", "Weights", "Dance"],
    },
    {
        "name": "Campus Clubs",
        "x_left": "2024",
        "x_right": "2025",
        "x_axis_label": "Year",
        "y_label": "Active members",
        "categories": ["Debate", "Robotics", "Drama", "Gaming", "Volunteering", "Photography"],
    },
    {
        "name": "Restaurant Orders",
        "x_left": "Lunch",
        "x_right": "Dinner",
        "x_axis_label": "Meal time",
        "y_label": "Orders",
        "categories": ["Burgers", "Pizza", "Salads", "Noodles", "Tacos", "Sushi"],
    },
    {
        "name": "Transport Mode Usage",
        "x_left": "Week 1",
        "x_right": "Week 2",
        "x_axis_label": "Week",
        "y_label": "Trips",
        "categories": ["Bus", "Train", "Car", "Bike", "Walk", "Scooter"],
    },
    {
        "name": "Movie Genre Views",
        "x_left": "Morning",
        "x_right": "Evening",
        "x_axis_label": "Time of day",
        "y_label": "Views",
        "categories": ["Action", "Comedy", "Drama", "Horror", "Sci-fi", "Romance"],
    },
    {
        "name": "Shopping Categories",
        "x_left": "Morning",
        "x_right": "Evening",
        "x_axis_label": "Time of day",
        "y_label": "Purchases",
        "categories": ["Clothing", "Groceries", "Electronics", "Beauty", "Home", "Sports"],
    }
]


def build_line_values(steep_idx: set[int]) -> list[tuple[int, int]]:
    """
    Build 6 line endpoints (early, late).
    - 3 lines share a steeper slope
    - 3 lines share a flatter slope
    - all lines slope in the same direction
    """
    # All charts in this version use increasing slopes (late > early).
    # The only varying factor is which 3 lines get the steeper slope.
    # Keep a minimum vertical gap so marker symbols do not overlap too much.
    min_gap = 28

    # Retry until we satisfy hard constraints:
    # - values in [0, MAX_POINT_VALUE]
    # - minimum separation at both early and late
    # Note: crossings are intentionally allowed.
    while True:
        # Make slope contrast more extreme.
        steep_delta = RNG.randint(250, 340)
        flat_delta = RNG.randint(10, 55)

        # Slightly tighter base spacing so steep-vs-flat differences pop more.
        step = RNG.randint(90, 125)

        # Keep early values low enough that increasing slopes stay within
        # MAX_POINT_VALUE, leaving top headroom for marker symbols.
        start = RNG.randint(20, 120)

        early_vals = [start + (i * step) for i in range(6)]

        deltas = [steep_delta if i in steep_idx else flat_delta for i in range(6)]

        values: list[tuple[int, int]] = []
        for early, delta in zip(early_vals, deltas):
            late = early + delta
            values.append((early, late))

        # Check hard bounds first.
        if any(early < 0 or early > MAX_POINT_VALUE or late < 0 or late > MAX_POINT_VALUE for early, late in values):
            continue

        # Check visible spacing at early and late positions.
        sorted_early = sorted(v[0] for v in values)
        sorted_late = sorted(v[1] for v in values)
        early_gaps = [sorted_early[i + 1] - sorted_early[i] for i in range(5)]
        late_gaps = [sorted_late[i + 1] - sorted_late[i] for i in range(5)]
        if min(early_gaps) < min_gap or min(late_gaps) < min_gap:
            continue

        return values


def split_patterns() -> list[tuple[int, int, int]]:
    """
    Return the 10 unique 3-vs-3 splits of 6 lines.
    We canonicalize each split by forcing index 0 to be in the chosen group.
    """
    patterns = []
    for combo in combinations(range(6), 3):
        if 0 not in combo:
            continue
        patterns.append(combo)
    return patterns


def derange_indices(n: int) -> list[int]:
    """Create a derangement so no position keeps its original item."""
    while True:
        idx = list(range(n))
        RNG.shuffle(idx)
        if all(i != idx[i] for i in range(n)):
            return idx


def marker_for_style(style: dict) -> dict:
    """Map abstract marker style to matplotlib kwargs."""
    if style["filled"]:
        return {
            "marker": style["marker"],
            "markerfacecolor": "black",
            "markeredgecolor": "black",
        }
    return {
        "marker": style["marker"],
        "markerfacecolor": "white",
        "markeredgecolor": "black",
    }


def draw_chart(
    chart_idx: int,
    legend_variant: str,
    theme: dict,
    categories: list[str],
    lines: list[tuple[int, int]],
    marker_styles: list[dict],
) -> None:
    """Render one chart + legend variant image."""
    # Make horizontal distance between early/late smaller so slope differences
    # are visually easier to compare.
    fig, ax = plt.subplots(figsize=(5.8, 5.6), dpi=140)
    # Pull early/late points toward the center so labels are not at extremes.
    x = [0.25, 0.75]

    legend_handles: list[Line2D] = []
    legend_labels: list[str] = []

    for cat, line_vals, marker_style in zip(categories, lines, marker_styles):
        mk = marker_for_style(marker_style)
        ax.plot(
            x,
            line_vals,
            color="black",
            linewidth=1.6,
            marker=mk["marker"],
            markersize=7,
            markerfacecolor=mk["markerfacecolor"],
            markeredgecolor=mk["markeredgecolor"],
            markeredgewidth=1.1,
        )

        # Build matching legend handle for each category marker.
        legend_handles.append(
            Line2D(
                [0],
                [0],
                color="black",
                linewidth=1.6,
                marker=mk["marker"],
                markersize=7,
                markerfacecolor=mk["markerfacecolor"],
                markeredgecolor=mk["markeredgecolor"],
                markeredgewidth=1.1,
            )
        )
        legend_labels.append(cat)

    # Keep full axis visible while placing points nearer the center.
    ax.set_xlim(0.0, 1.0)
    ax.set_ylim(0, 1000)
    ax.set_xticks([0.25, 0.75], labels=[theme["x_left"], theme["x_right"]], fontsize=10)
    # Keep axis line but remove numeric y tick labels for cleaner reading.
    ax.set_yticks([])
    ax.set_xlabel(theme["x_axis_label"], fontsize=12)
    ax.set_ylabel(theme["y_label"], fontsize=12)
    ax.grid(False)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)

    # Legend A: ordered by the right-most point (late), as requested.
    # If lines cross, this is the reference ordering.
    visual_order = sorted(range(6), key=lambda i: lines[i][1], reverse=True)
    ordered_handles = [legend_handles[i] for i in visual_order]
    ordered_labels = [legend_labels[i] for i in visual_order]

    # Legend B: shuffled order, with a full derangement (no item in same slot).
    deranged = derange_indices(6)
    shuffled_handles = [ordered_handles[i] for i in deranged]
    shuffled_labels = [ordered_labels[i] for i in deranged]

    # Two legend conditions: one ordered by chart, one fully shuffled.
    if legend_variant == "a":
        handles = ordered_handles
        labels = ordered_labels
    else:
        handles = shuffled_handles
        labels = shuffled_labels

    ax.legend(
        handles,
        labels,
        loc="center left",
        bbox_to_anchor=(1.02, 0.5),
        frameon=True,
        edgecolor="black",
        facecolor="white",
        framealpha=1.0,
        fontsize=12,
        labelspacing=0.95,
        borderaxespad=0.6,
    )

    fig.tight_layout()
    filename = f"linechart_{chart_idx:02d}_legend_{legend_variant}.png"
    out_path = OUT_DIR / filename
    fig.savefig(out_path, facecolor="white")
    plt.close(fig)


def build_questions_rows(
    chart_idx: int,
    pool: str,
    theme: dict,
    categories: list[str],
    lines: list[tuple[int, int]],
) -> list[dict]:
    """
    Create eight statements per base chart:
    - 4 main-effect statements (2 wording frames x true/false)
    - 4 interaction statements (2 wording frames x true/false)
    """
    # Per-category summary used for statement generation.
    per_cat = []
    for cat, (early, late) in zip(categories, lines):
        delta = late - early
        overall = (early + late) / 2.0
        per_cat.append({"cat": cat, "early": early, "late": late, "delta": delta, "overall": overall})

    # Main-effect restriction:
    # statement categories must not be topmost or bottommost at either endpoint.
    top_early = max(per_cat, key=lambda x: x["early"])["cat"]
    bottom_early = min(per_cat, key=lambda x: x["early"])["cat"]
    top_late = max(per_cat, key=lambda x: x["late"])["cat"]
    bottom_late = min(per_cat, key=lambda x: x["late"])["cat"]
    disallowed_main = {top_early, bottom_early, top_late, bottom_late}
    eligible_main = [row for row in per_cat if row["cat"] not in disallowed_main]
    # Interaction statements can use the broader set (no extra exclusion).
    eligible_interaction = list(per_cat)

    # If too few categories remain after exclusion, caller should regenerate.
    if len(eligible_main) < 2:
        raise ValueError("Not enough eligible categories for main-effect constraints.")

    # Main-effect pair comes from non-extrema categories only, and the two
    # lines must preserve their ordering at both endpoints (no crossing).
    dominant_pairs = []
    for a in eligible_main:
        for b in eligible_main:
            if a["cat"] == b["cat"]:
                continue
            if a["early"] > b["early"] and a["late"] > b["late"]:
                gap = a["overall"] - b["overall"]
                dominant_pairs.append((gap, a, b))

    if not dominant_pairs:
        raise ValueError("No non-crossing main-effect pair found among eligible categories.")

    dominant_pairs.sort(key=lambda item: item[0], reverse=True)
    _, high, low = dominant_pairs[0]

    # Choose one steep and one flat line for interaction statements.
    delta_sorted = sorted(eligible_interaction, key=lambda x: abs(x["delta"]))
    flat = delta_sorted[0]
    steep = delta_sorted[-1]

    trend_word = "increases"

    # Main-effect statements in two wording frames:
    # - comparison_frame = "more" => "greater than"
    # - comparison_frame = "less" => "less than"
    main_true_more = f"The overall value of {high['cat']} is greater than {low['cat']}."
    main_false_more = f"The overall value of {low['cat']} is greater than {high['cat']}."
    main_true_less = f"The overall value of {low['cat']} is less than {high['cat']}."
    main_false_less = f"The overall value of {high['cat']} is less than {low['cat']}."

    # Interaction true statements in two wording frames:
    # - comparison_frame = "more" => "more strongly than"
    # - comparison_frame = "less" => "more slowly than"
    inter_true_more = (
        f"The value of {steep['cat']} {trend_word} more strongly than {flat['cat']}."
    )
    inter_true_less = (
        f"The value of {flat['cat']} {trend_word} more slowly than {steep['cat']}."
    )

    # Interaction false statements use equal-slope pairs so both "more strongly"
    # and "more slowly" are false. Half of charts use steep category A, half flat A.
    abs_steep = abs(steep["delta"])
    abs_flat = abs(flat["delta"])
    other_steep_candidates = [
        row for row in eligible_interaction
        if row["cat"] != steep["cat"] and abs(row["delta"]) == abs_steep
    ]
    other_flat_candidates = [
        row for row in eligible_interaction
        if row["cat"] != flat["cat"] and abs(row["delta"]) == abs_flat
    ]
    if chart_idx % 2 == 0 and other_steep_candidates:
        inter_false_a = steep
        inter_false_b = other_steep_candidates[0]
    elif chart_idx % 2 == 1 and other_flat_candidates:
        inter_false_a = flat
        inter_false_b = other_flat_candidates[0]
    elif other_steep_candidates:
        inter_false_a = steep
        inter_false_b = other_steep_candidates[0]
    elif other_flat_candidates:
        inter_false_a = flat
        inter_false_b = other_flat_candidates[0]
    else:
        raise ValueError("No equal-slope pair available for false interaction statements.")

    inter_false_more = (
        f"The value of {inter_false_a['cat']} {trend_word} more strongly than {inter_false_b['cat']}."
    )
    inter_false_less = (
        f"The value of {inter_false_a['cat']} {trend_word} more slowly than {inter_false_b['cat']}."
    )

    # Safety check: main-effect categories must satisfy the endpoint-extrema rule.
    if {high["cat"], low["cat"]} & disallowed_main:
        raise ValueError("Main-effect categories include disallowed endpoint-extrema category.")

    # Include both stimulus files so UI can map either legend variant.
    left_file = f"linechart_{chart_idx:02d}_legend_a.png"
    right_file = f"linechart_{chart_idx:02d}_legend_b.png"

    rows = [
        {
            "chart_index": chart_idx,
            "pool": pool,
            "theme_name": theme["name"],
            "x_left": theme["x_left"],
            "x_right": theme["x_right"],
            "y_label": theme["y_label"],
            "slope_condition": "increasing",
            "legend_a_file": left_file,
            "legend_b_file": right_file,
            "statement_type": "main_effect",
            "truth_value": 1,
            "comparison_frame": "more",
            "statement_text": main_true_more,
            "category_a": high["cat"],
            "category_b": low["cat"],
        },
        {
            "chart_index": chart_idx,
            "pool": pool,
            "theme_name": theme["name"],
            "x_left": theme["x_left"],
            "x_right": theme["x_right"],
            "y_label": theme["y_label"],
            "slope_condition": "increasing",
            "legend_a_file": left_file,
            "legend_b_file": right_file,
            "statement_type": "main_effect",
            "truth_value": 0,
            "comparison_frame": "more",
            "statement_text": main_false_more,
            "category_a": low["cat"],
            "category_b": high["cat"],
        },
        {
            "chart_index": chart_idx,
            "pool": pool,
            "theme_name": theme["name"],
            "x_left": theme["x_left"],
            "x_right": theme["x_right"],
            "y_label": theme["y_label"],
            "slope_condition": "increasing",
            "legend_a_file": left_file,
            "legend_b_file": right_file,
            "statement_type": "interaction",
            "truth_value": 1,
            "comparison_frame": "more",
            "statement_text": inter_true_more,
            "category_a": steep["cat"],
            "category_b": flat["cat"],
        },
        {
            "chart_index": chart_idx,
            "pool": pool,
            "theme_name": theme["name"],
            "x_left": theme["x_left"],
            "x_right": theme["x_right"],
            "y_label": theme["y_label"],
            "slope_condition": "increasing",
            "legend_a_file": left_file,
            "legend_b_file": right_file,
            "statement_type": "interaction",
            "truth_value": 0,
            "comparison_frame": "more",
            "statement_text": inter_false_more,
            "category_a": inter_false_a["cat"],
            "category_b": inter_false_b["cat"],
        },
        {
            "chart_index": chart_idx,
            "pool": pool,
            "theme_name": theme["name"],
            "x_left": theme["x_left"],
            "x_right": theme["x_right"],
            "y_label": theme["y_label"],
            "slope_condition": "increasing",
            "legend_a_file": left_file,
            "legend_b_file": right_file,
            "statement_type": "main_effect",
            "truth_value": 1,
            "comparison_frame": "less",
            "statement_text": main_true_less,
            "category_a": low["cat"],
            "category_b": high["cat"],
        },
        {
            "chart_index": chart_idx,
            "pool": pool,
            "theme_name": theme["name"],
            "x_left": theme["x_left"],
            "x_right": theme["x_right"],
            "y_label": theme["y_label"],
            "slope_condition": "increasing",
            "legend_a_file": left_file,
            "legend_b_file": right_file,
            "statement_type": "main_effect",
            "truth_value": 0,
            "comparison_frame": "less",
            "statement_text": main_false_less,
            "category_a": high["cat"],
            "category_b": low["cat"],
        },
        {
            "chart_index": chart_idx,
            "pool": pool,
            "theme_name": theme["name"],
            "x_left": theme["x_left"],
            "x_right": theme["x_right"],
            "y_label": theme["y_label"],
            "slope_condition": "increasing",
            "legend_a_file": left_file,
            "legend_b_file": right_file,
            "statement_type": "interaction",
            "truth_value": 1,
            "comparison_frame": "less",
            "statement_text": inter_true_less,
            "category_a": flat["cat"],
            "category_b": steep["cat"],
        },
        {
            "chart_index": chart_idx,
            "pool": pool,
            "theme_name": theme["name"],
            "x_left": theme["x_left"],
            "x_right": theme["x_right"],
            "y_label": theme["y_label"],
            "slope_condition": "increasing",
            "legend_a_file": left_file,
            "legend_b_file": right_file,
            "statement_type": "interaction",
            "truth_value": 0,
            "comparison_frame": "less",
            "statement_text": inter_false_less,
            "category_a": inter_false_a["cat"],
            "category_b": inter_false_b["cat"],
        },
    ]

    return rows


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    # One split pattern produces no valid non-extrema, non-crossing main-effect
    # pair under the current geometry constraints, so we exclude it here.
    patterns = [pattern for pattern in split_patterns() if pattern != (0, 2, 4)]
    total_charts = N_REAL_CHARTS + N_PRACTICE_CHARTS

    question_rows: list[dict] = []

    for chart_idx in range(total_charts):
        pool = "real" if chart_idx < N_REAL_CHARTS else "practice"
        pattern = set(patterns[chart_idx % len(patterns)])
        # Cycle themes so large pools still use concrete semantic labels.
        theme = THEMES[chart_idx % len(THEMES)]
        categories = list(theme["categories"])

        # Regenerate line geometry until strict main-effect pair is available.
        # This enforces that "overall greater" statements use non-crossing pairs.
        while True:
            lines = build_line_values(pattern)
            marker_styles = RNG.sample(MARKER_STYLES, k=6)
            try:
                rows = build_questions_rows(chart_idx, pool, theme, categories, lines)
                break
            except ValueError:
                continue

        for legend_variant in ("a", "b"):
            draw_chart(
                chart_idx=chart_idx,
                legend_variant=legend_variant,
                theme=theme,
                categories=categories,
                lines=lines,
                marker_styles=marker_styles,
            )
        # Build 8 statement rows per base chart.
        question_rows.extend(rows)

    # Write question metadata so the frontend can load chart statements by condition.
    with QUESTIONS_CSV.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=[
                "chart_index",
                "pool",
                "theme_name",
                "x_left",
                "x_right",
                "y_label",
                "slope_condition",
                "legend_a_file",
                "legend_b_file",
                "statement_type",
                "truth_value",
                "comparison_frame",
                "statement_text",
                "category_a",
                "category_b",
            ],
        )
        writer.writeheader()
        writer.writerows(question_rows)

    print(f"Generated {total_charts * 2} line-chart stimuli in: {OUT_DIR}")
    print(f"Generated {len(question_rows)} question rows in: {QUESTIONS_CSV}")


if __name__ == "__main__":
    main()
