#!/usr/bin/env python3
"""Build an accuracy-by-architecture plot from telemetry compare scorecard CSV."""

from __future__ import annotations

import argparse
import csv
from collections import defaultdict
from pathlib import Path
from statistics import median

try:
    import matplotlib.pyplot as plt  # type: ignore
except Exception as exc:  # pragma: no cover
    raise SystemExit(f"matplotlib unavailable: {exc}")


ARCH_COLORS = {
    "lats": "#4e79a7",
    "crag": "#e15759",
    "P&E": "#76b041",
}

ARCH_LABELS = {
    "lats": "LATS",
    "crag": "CRAG",
    "P&E": "Plan-and-Execute",
}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--scorecard-csv", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--title", default="Accuracy by Architecture (with web search)")
    args = parser.parse_args()

    if not args.scorecard_csv.exists():
        raise SystemExit(f"missing scorecard CSV: {args.scorecard_csv}")

    by_arch = defaultdict(list)
    with args.scorecard_csv.open("r", encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            arch = row.get("arch", "").strip()
            acc_raw = row.get("accuracy_pct", "").strip()
            if not arch or not acc_raw:
                continue
            try:
                by_arch[arch].append(float(acc_raw))
            except ValueError:
                continue

    arch_order = [a for a in ("lats", "crag", "P&E") if a in by_arch]
    arch_order.extend(sorted(a for a in by_arch if a not in arch_order))
    if not arch_order:
        raise SystemExit("no architecture accuracy values found in scorecard CSV")

    data = [by_arch[a] for a in arch_order]
    labels = [ARCH_LABELS.get(a, a) for a in arch_order]
    colors = [ARCH_COLORS.get(a, "#888") for a in arch_order]
    medians = [median(vals) for vals in data]

    plt.style.use("default")
    fig, ax = plt.subplots(figsize=(6.4, 4.6), layout="constrained", facecolor="white")
    ax.set_facecolor("white")

    bp = ax.boxplot(data, patch_artist=True, tick_labels=labels)
    for box, color in zip(bp["boxes"], colors):
        box.set_facecolor(color)
        box.set_alpha(0.75)

    for idx, med in enumerate(medians, start=1):
        ax.text(idx + 0.08, med, f"{med:.1f}%", va="center", fontsize=9)

    ax.set_ylabel("Accuracy (%)")
    ax.set_ylim(0, 100)
    ax.grid(True, axis="y", alpha=0.3)
    ax.set_title(args.title)
    for spine in ax.spines.values():
        spine.set_visible(True)
        spine.set_linewidth(1.0)
        spine.set_color("#333")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(args.output, format=args.output.suffix.lstrip(".") or "pdf")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
