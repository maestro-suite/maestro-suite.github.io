#!/usr/bin/env python3
"""Build compact JSON for the v1 interactive model tradeoff section."""

from __future__ import annotations

import argparse
import csv
import json
from collections import defaultdict
from pathlib import Path
from statistics import median
from typing import Dict, List


def _pct_accuracy(task_count: float, failed_tasks: float) -> float:
    if task_count <= 0:
        return 0.0
    return (1.0 - failed_tasks / task_count) * 100.0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--input-csv",
        default="data/raw/reference/model_boxplots_wi_dataset.csv",
        help="Input CSV exported by export_model_boxplot_dataset.py",
    )
    parser.add_argument(
        "--output-json",
        default="static/data/model_tradeoff_v1.json",
        help="Output JSON for frontend charts",
    )
    args = parser.parse_args()

    input_csv = Path(args.input_csv).resolve()
    output_json = Path(args.output_json).resolve()

    if not input_csv.exists():
        raise SystemExit(f"missing input CSV: {input_csv}")

    rows_by_model_arch: Dict[str, Dict[str, List[dict]]] = defaultdict(lambda: defaultdict(list))

    with input_csv.open("r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            model = (row.get("group_label") or "").strip()
            arch = (row.get("run_label") or "").strip()
            if not model or not arch:
                continue
            if "embedding" in model.lower():
                continue

            try:
                task_count = float(row.get("task_count") or 0.0)
                failed_tasks = float(row.get("failed_tasks") or 0.0)
                total_duration = float(row.get("total_duration_seconds") or 0.0)
                total_cost = float(row.get("cost_total") or 0.0)
            except ValueError:
                continue

            if task_count <= 0:
                continue

            rows_by_model_arch[model][arch].append(
                {
                    "duration_per_task": total_duration / task_count,
                    "cost_per_task": total_cost / task_count,
                    "accuracy_pct": _pct_accuracy(task_count, failed_tasks),
                }
            )

    models_payload = []
    point_payload = []
    for model in sorted(rows_by_model_arch.keys()):
        arch_data = rows_by_model_arch[model]

        all_cost = []
        all_dur = []
        all_acc = []
        per_arch = []
        for arch in sorted(arch_data.keys()):
            samples = arch_data[arch]
            c_vals = [s["cost_per_task"] for s in samples]
            d_vals = [s["duration_per_task"] for s in samples]
            a_vals = [s["accuracy_pct"] for s in samples]

            c_med = median(c_vals)
            d_med = median(d_vals)
            # Use aggregated accuracy by (model, arch) rather than median of binary per-run values.
            # Per run here is mostly a single judged task, so median would collapse to 0/100.
            a_agg = sum(a_vals) / len(a_vals) if a_vals else 0.0

            per_arch.append(
                {
                    "arch": arch,
                    "cost_per_task_median": c_med,
                    "duration_per_task_median": d_med,
                    "accuracy_pct": a_agg,
                }
            )
            point_payload.append(
                {
                    "model": model,
                    "arch": arch,
                    "cost_per_task_median": c_med,
                    "duration_per_task_median": d_med,
                    "accuracy_pct": a_agg,
                }
            )

            all_cost.extend(c_vals)
            all_dur.extend(d_vals)
            all_acc.extend(a_vals)

        if not all_cost or not all_dur or not all_acc:
            continue

        per_arch_acc = [p["accuracy_pct"] for p in per_arch]
        model_acc = sum(per_arch_acc) / len(per_arch_acc) if per_arch_acc else 0.0

        models_payload.append(
            {
                "model": model,
                "cost_per_task_median": median(all_cost),
                "duration_per_task_median": median(all_dur),
                "accuracy_pct": model_acc,
                "accuracy_pct_min": min(per_arch_acc) if per_arch_acc else 0.0,
                "accuracy_pct_max": max(per_arch_acc) if per_arch_acc else 0.0,
                "accuracy_spread": (max(per_arch_acc) - min(per_arch_acc)) if per_arch_acc else 0.0,
                "per_arch": per_arch,
            }
        )

    output_json.parent.mkdir(parents=True, exist_ok=True)
    output_json.write_text(
        json.dumps(
            {
                "models": models_payload,
                "points": point_payload,
                "arch_order": ["lats", "crag", "P&E"],
                "arch_labels": {"lats": "LATS", "crag": "CRAG", "P&E": "Plan-and-Execute"},
            },
            indent=2,
        ),
        encoding="utf-8",
    )
    print(f"[saved] interactive data -> {output_json}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
