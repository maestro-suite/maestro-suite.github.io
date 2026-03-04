#!/usr/bin/env python3
"""Export the per-run dataset used by model boxplot plots to CSV/JSON."""

from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path
from typing import List, Dict, Any


def _resolve_config(source_repo: Path, config_arg: str) -> Path:
    config_path = Path(config_arg).expanduser()
    if config_path.is_absolute():
        return config_path
    return (source_repo / config_path).resolve()


def _union_headers(rows: List[Dict[str, Any]]) -> List[str]:
    header_set = set()
    for row in rows:
        header_set.update(row.keys())
    # Stable key order with commonly useful columns first.
    priority = [
        "run_id",
        "run_label",
        "group_label",
        "gen_ai_system",
        "gen_ai_model",
        "task_count",
        "failed_tasks",
        "failure_rate",
        "total_duration_seconds",
        "avg_duration_seconds",
        "total_tokens",
        "avg_total_tokens",
        "input_tokens",
        "output_tokens",
        "cost_total",
    ]
    ordered = [k for k in priority if k in header_set]
    ordered.extend(sorted(header_set - set(ordered)))
    return ordered


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Export per-run rows used by plot_telemetry_model_boxplots.py"
    )
    parser.add_argument(
        "--source-repo",
        default="/home/cheny0y/git/mas-benchmark",
        help="Path to source repo containing plot/lib/parquet_utils.py",
    )
    parser.add_argument(
        "--config",
        default="plot/configs/runs_wi_by_model_parquet.json",
        help="Config path (absolute, or relative to source repo)",
    )
    parser.add_argument(
        "--csv-output",
        required=True,
        help="CSV output path",
    )
    parser.add_argument(
        "--json-output",
        default="",
        help="Optional JSON output path",
    )
    args = parser.parse_args()

    source_repo = Path(args.source_repo).expanduser().resolve()
    if not source_repo.exists():
        raise SystemExit(f"source repo not found: {source_repo}")

    if str(source_repo) not in sys.path:
        sys.path.insert(0, str(source_repo))

    from plot.lib.parquet_utils import (  # pylint: disable=import-error
        DEFAULT_ALLOWED_OPS,
        load_runs_from_parquet,
    )

    config_path = _resolve_config(source_repo, args.config)
    if not config_path.exists():
        raise SystemExit(f"config not found: {config_path}")

    pricing_file = source_repo / "tools" / "pricing.json"
    rows, _colors, _groups, _labels = load_runs_from_parquet(
        config_path,
        operations=DEFAULT_ALLOWED_OPS,
        pricing_file=pricing_file if pricing_file.exists() else None,
        price_per_1m=None,
    )

    csv_path = Path(args.csv_output).expanduser().resolve()
    csv_path.parent.mkdir(parents=True, exist_ok=True)
    headers = _union_headers(rows)
    with csv_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=headers, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)

    if args.json_output:
        json_path = Path(args.json_output).expanduser().resolve()
        json_path.parent.mkdir(parents=True, exist_ok=True)
        payload = {
            "source_repo": str(source_repo),
            "config": str(config_path),
            "row_count": len(rows),
            "rows": rows,
        }
        json_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")

    print(f"Exported {len(rows)} rows to {csv_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
