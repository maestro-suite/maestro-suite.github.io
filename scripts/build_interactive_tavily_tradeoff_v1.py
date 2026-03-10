#!/usr/bin/env python3
"""Build compact JSON for interactive Tavily on/off website charts."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
from statistics import median
from typing import Dict, Iterable, List, Optional, Sequence, Tuple


MODEL_ORDER = [
    "gemini-2.0-flash-lite",
    "gemini-2.5-flash-lite",
    "gemini-2.5-flash",
    "gpt-4o-mini",
    "gpt-5-nano",
    "gpt-5-mini",
]

ARCH_ORDER = ["P&E", "crag", "lats"]
ARCH_LABELS = {"P&E": "Plan-and-Execute", "crag": "CRAG", "lats": "LATS"}


def _median(values: Iterable[Optional[float]]) -> Optional[float]:
    vals = [v for v in values if isinstance(v, (int, float))]
    if not vals:
        return None
    return float(median(vals))


def _safe_div(numer: Optional[float], denom: Optional[float]) -> Optional[float]:
    if numer is None or denom is None or denom == 0:
        return None
    return numer / denom


def _pct_change(base: Optional[float], nxt: Optional[float]) -> Optional[float]:
    if base is None or nxt is None or base == 0:
        return None
    return (nxt - base) / base * 100.0


def _acc_from_counts(tasks: Optional[float], failed: Optional[float]) -> Optional[float]:
    if tasks is None or failed is None or tasks <= 0:
        return None
    return (1.0 - failed / tasks) * 100.0


def _resolve_path(root: Path, arg: str) -> Path:
    p = Path(arg)
    if p.is_absolute():
        return p
    if (root / p).exists():
        return (root / p).resolve()
    return p.resolve()


def _load_metrics(
    source_repo: Path,
    config_path: Path,
) -> Dict[Tuple[str, str], Dict[str, Optional[float]]]:
    import sys

    if str(source_repo) not in sys.path:
        sys.path.insert(0, str(source_repo))

    from plot.lib.parquet_utils import DEFAULT_ALLOWED_OPS, REPO_ROOT, load_runs_from_parquet  # type: ignore

    default_pricing = REPO_ROOT / "tools" / "pricing.json"
    pricing_file = default_pricing if default_pricing.exists() else None

    rows, _label_colors, _group_order, _label_order = load_runs_from_parquet(
        config_path,
        operations=list(DEFAULT_ALLOWED_OPS),
        pricing_file=pricing_file,
        price_per_1m=None,
    )

    buckets: Dict[Tuple[str, str], Dict[str, List[Optional[float]]]] = {}
    for row in rows:
        arch = str(row.get("group_label") or "unknown")
        model = str(row.get("run_label") or "unknown")
        key = (arch, model)
        bucket = buckets.setdefault(
            key,
            {"lat": [], "cost": [], "acc": [], "tasks": 0.0, "failed": 0.0},
        )

        tasks = float(row.get("task_count") or 0.0)
        duration = float(row.get("total_duration_seconds") or 0.0)
        failed = float(row.get("failed_tasks") or 0.0)
        cost_total = row.get("cost_total")
        cost_total_f = float(cost_total) if isinstance(cost_total, (int, float)) else None

        latency_per_task = _safe_div(duration, tasks)
        cost_per_task = _safe_div(cost_total_f, tasks)
        accuracy = (1.0 - failed / tasks) * 100.0 if tasks > 0 else None

        bucket["lat"].append(latency_per_task)
        bucket["cost"].append(cost_per_task)
        bucket["acc"].append(accuracy)
        bucket["tasks"] += tasks
        bucket["failed"] += failed

    out: Dict[Tuple[str, str], Dict[str, Optional[float]]] = {}
    for key, bucket in buckets.items():
        out[key] = {
            "lat": _median(bucket["lat"]),
            "cost": _median(bucket["cost"]),
            "acc": _median(bucket["acc"]),
            "tasks": float(bucket["tasks"]),
            "failed": float(bucket["failed"]),
        }
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--source-repo",
        default=os.environ.get("MAS_BENCHMARK_REPO", ""),
        help="Path to mas-benchmark repo (for parquet loader).",
    )
    parser.add_argument(
        "--with-config",
        default="plot/configs/runs_wi_by_arch_parquet.json",
        help="With-web-search config path (absolute or relative to source repo).",
    )
    parser.add_argument(
        "--without-config",
        default="plot/configs/runs_wo_by_arch_parquet.json",
        help="Without-web-search config path (absolute or relative to source repo).",
    )
    parser.add_argument(
        "--output-json",
        default="static/data/tavily_tradeoff_v1.json",
        help="Output JSON path for website charts.",
    )
    args = parser.parse_args()

    if not args.source_repo:
        raise SystemExit("set --source-repo or MAS_BENCHMARK_REPO")
    source_repo = Path(args.source_repo).resolve()
    if not source_repo.exists():
        raise SystemExit(f"missing source repo: {source_repo}")

    with_config = _resolve_path(source_repo, args.with_config)
    without_config = _resolve_path(source_repo, args.without_config)
    output_json = Path(args.output_json).resolve()

    if not with_config.exists():
        raise SystemExit(f"missing with-config: {with_config}")
    if not without_config.exists():
        raise SystemExit(f"missing without-config: {without_config}")

    with_metrics = _load_metrics(source_repo, with_config)
    without_metrics = _load_metrics(source_repo, without_config)

    keys = sorted(set(with_metrics.keys()) & set(without_metrics.keys()))
    rank = {m: i for i, m in enumerate(MODEL_ORDER)}

    scatter_points: List[Dict[str, float | str]] = []
    per_arch_acc: Dict[str, Dict[str, float]] = {}
    per_model_acc_points: List[Dict[str, float | str]] = []

    for arch, model in keys:
        with_row = with_metrics[(arch, model)]
        without_row = without_metrics[(arch, model)]
        d_lat = _pct_change(without_row.get("lat"), with_row.get("lat"))
        d_cost = _pct_change(without_row.get("cost"), with_row.get("cost"))
        base_acc_agg = _acc_from_counts(without_row.get("tasks"), without_row.get("failed"))
        with_acc_agg = _acc_from_counts(with_row.get("tasks"), with_row.get("failed"))
        d_acc = _pct_change(base_acc_agg, with_acc_agg)
        d_acc_abs = (with_acc_agg - base_acc_agg) if (base_acc_agg is not None and with_acc_agg is not None) else None

        if d_lat is not None and d_cost is not None:
            scatter_points.append(
                {
                    "arch": arch,
                    "model": model,
                    "duration_change_pct": float(d_lat),
                    "cost_change_pct": float(d_cost),
                    "accuracy_change_pct": float(d_acc) if d_acc is not None else 0.0,
                    "accuracy_change_abs": float(d_acc_abs) if d_acc_abs is not None else 0.0,
                }
            )

        if d_acc_abs is not None:
            per_model_acc_points.append(
                {
                    "arch": arch,
                    "model": model,
                    "accuracy_change_abs": float(d_acc_abs),
                }
            )

    for arch in ARCH_ORDER:
        base_tasks = sum(float(v.get("tasks") or 0.0) for (a, _m), v in without_metrics.items() if a == arch)
        base_failed = sum(float(v.get("failed") or 0.0) for (a, _m), v in without_metrics.items() if a == arch)
        with_tasks = sum(float(v.get("tasks") or 0.0) for (a, _m), v in with_metrics.items() if a == arch)
        with_failed = sum(float(v.get("failed") or 0.0) for (a, _m), v in with_metrics.items() if a == arch)
        base_acc = (1.0 - base_failed / base_tasks) * 100.0 if base_tasks > 0 else 0.0
        with_acc = (1.0 - with_failed / with_tasks) * 100.0 if with_tasks > 0 else 0.0
        per_arch_acc[arch] = {
            "accuracy_with": float(with_acc),
            "accuracy_without": float(base_acc),
            "accuracy_delta_abs": float(with_acc - base_acc),
        }

    scatter_points.sort(key=lambda r: (ARCH_ORDER.index(str(r["arch"])) if str(r["arch"]) in ARCH_ORDER else 999, rank.get(str(r["model"]), 999), str(r["model"])))
    per_model_acc_points.sort(key=lambda r: (ARCH_ORDER.index(str(r["arch"])) if str(r["arch"]) in ARCH_ORDER else 999, rank.get(str(r["model"]), 999), str(r["model"])))

    payload = {
        "model_order": MODEL_ORDER,
        "arch_order": ARCH_ORDER,
        "arch_labels": ARCH_LABELS,
        "scatter_points": scatter_points,
        "accuracy_arch": per_arch_acc,
        "accuracy_model_points": per_model_acc_points,
    }

    output_json.parent.mkdir(parents=True, exist_ok=True)
    output_json.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    print(f"[saved] interactive data -> {output_json}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
