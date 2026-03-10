#!/usr/bin/env python3
"""Build compact JSON for architecture tradeoff interactive plots."""

from __future__ import annotations

import argparse
import csv
import json
from collections import defaultdict
from pathlib import Path
from statistics import median


MODEL_ORDER = [
    "gemini-2.0-flash-lite",
    "gemini-2.5-flash-lite",
    "gemini-2.5-flash",
    "gpt-4o-mini",
    "gpt-5-nano",
    "gpt-5-mini",
]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--input-csv",
        default="data/raw/reference/scorecard_wi_by_model.csv",
        help="Input scorecard CSV from telemetry compare",
    )
    parser.add_argument(
        "--output-json",
        default="static/data/arch_tradeoff_v1.json",
        help="Output JSON for frontend charts",
    )
    args = parser.parse_args()

    input_csv = Path(args.input_csv).resolve()
    output_json = Path(args.output_json).resolve()
    if not input_csv.exists():
        raise SystemExit(f"missing input CSV: {input_csv}")

    rows = []
    with input_csv.open("r", encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            try:
                rows.append(
                    {
                        "model": row["model"].strip(),
                        "arch": row["arch"].strip(),
                        "latency": float(row["median_latency_s_per_task"]),
                        "cost": float(row["median_cost_per_task"]),
                        "accuracy": float(row["accuracy_pct"]),
                    }
                )
            except Exception:
                continue

    rank = {m: i for i, m in enumerate(MODEL_ORDER)}
    rows.sort(key=lambda r: (r["arch"], rank.get(r["model"], 999), r["model"]))

    by_arch = defaultdict(list)
    for r in rows:
        by_arch[r["arch"]].append(r)

    arch_summary = []
    for arch, vals in by_arch.items():
        acc_vals = [v["accuracy"] for v in vals]
        lat_vals = [v["latency"] for v in vals]
        cost_vals = [v["cost"] for v in vals]
        arch_summary.append(
            {
                "arch": arch,
                "accuracy": sum(acc_vals) / len(acc_vals) if acc_vals else 0.0,
                "accuracy_min": min(acc_vals) if acc_vals else 0.0,
                "accuracy_max": max(acc_vals) if acc_vals else 0.0,
                "latency_median": median(lat_vals) if lat_vals else 0.0,
                "cost_median": median(cost_vals) if cost_vals else 0.0,
            }
        )

    payload = {
        "model_order": MODEL_ORDER,
        "points": rows,
        "arch_summary": arch_summary,
        "arch_order": ["P&E", "crag", "lats"],
        "arch_labels": {"P&E": "Plan-and-Execute", "crag": "CRAG", "lats": "LATS"},
    }
    output_json.parent.mkdir(parents=True, exist_ok=True)
    output_json.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    print(f"[saved] interactive data -> {output_json}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
