#!/usr/bin/env bash
set -euo pipefail

# Reproduce paper RQ3 Tavily on/off latency-cost shift plot from parquet configs.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_REPO="${SOURCE_REPO:-${MAS_BENCHMARK_REPO:-}}"

WITH_CONFIG_ARG="${WITH_CONFIG_ARG:-plot/configs/runs_wi_by_arch_parquet.json}"
WITHOUT_CONFIG_ARG="${WITHOUT_CONFIG_ARG:-plot/configs/runs_wo_by_arch_parquet.json}"

SCATTER_OUTPUT="${SCATTER_OUTPUT:-$ROOT_DIR/data/raw/reference/tavily_shift_latency_cost.pdf}"

if [[ ! -d "$SOURCE_REPO" ]]; then
  if [[ -z "$SOURCE_REPO" ]]; then
    echo "Set SOURCE_REPO or MAS_BENCHMARK_REPO to your mas-benchmark path." >&2
    exit 1
  fi
  echo "Source repo not found: $SOURCE_REPO" >&2
  exit 1
fi

if [[ -x "$SOURCE_REPO/.venv/bin/python" ]]; then
  PYTHON_BIN="$SOURCE_REPO/.venv/bin/python"
elif [[ -x "$SOURCE_REPO/plot/.venv/bin/python" ]]; then
  PYTHON_BIN="$SOURCE_REPO/plot/.venv/bin/python"
elif [[ -x "$SOURCE_REPO/tools/.venv/bin/python" ]]; then
  PYTHON_BIN="$SOURCE_REPO/tools/.venv/bin/python"
else
  echo "No python venv found in source repo (.venv, plot/.venv, or tools/.venv)." >&2
  exit 1
fi

PLOT_SCRIPT="$SOURCE_REPO/plot/plot_telemetry_tavily_diff.py"
if [[ ! -f "$PLOT_SCRIPT" ]]; then
  echo "Missing plot script: $PLOT_SCRIPT" >&2
  exit 1
fi

if [[ "$WITH_CONFIG_ARG" = /* ]]; then
  WITH_CONFIG_PATH="$WITH_CONFIG_ARG"
else
  WITH_CONFIG_PATH="$SOURCE_REPO/$WITH_CONFIG_ARG"
fi
if [[ ! -f "$WITH_CONFIG_PATH" && "$(basename "$WITH_CONFIG_ARG")" == "runs_wi_by_arch.json" ]]; then
  WITH_CONFIG_PATH="$SOURCE_REPO/plot/configs/runs_wi_by_arch_parquet.json"
fi
if [[ ! -f "$WITH_CONFIG_PATH" ]]; then
  echo "With-config not found: $WITH_CONFIG_PATH" >&2
  exit 1
fi

if [[ "$WITHOUT_CONFIG_ARG" = /* ]]; then
  WITHOUT_CONFIG_PATH="$WITHOUT_CONFIG_ARG"
else
  WITHOUT_CONFIG_PATH="$SOURCE_REPO/$WITHOUT_CONFIG_ARG"
fi
if [[ ! -f "$WITHOUT_CONFIG_PATH" && "$(basename "$WITHOUT_CONFIG_ARG")" == "runs_wo_by_arch.json" ]]; then
  WITHOUT_CONFIG_PATH="$SOURCE_REPO/plot/configs/runs_wo_by_arch_parquet.json"
fi
if [[ ! -f "$WITHOUT_CONFIG_PATH" ]]; then
  echo "Without-config not found: $WITHOUT_CONFIG_PATH" >&2
  exit 1
fi

PARQUET_PATH="$SOURCE_REPO/data/parquet/traces.parquet"
if [[ ! -f "$PARQUET_PATH" ]]; then
  cat >&2 <<EOF
Missing parquet dataset: $PARQUET_PATH
Build it first, then rerun:
  cd $SOURCE_REPO
  $PYTHON_BIN tools/convert_dataset_to_parquet.py \\
    --dataset-root data/dataset \\
    --output-dir data/parquet \\
    --overwrite
EOF
  exit 2
fi

mkdir -p "$(dirname "$SCATTER_OUTPUT")"

"$PYTHON_BIN" "$PLOT_SCRIPT" \
  --with-config "$WITH_CONFIG_PATH" \
  --without-config "$WITHOUT_CONFIG_PATH" \
  --scatter-output "$SCATTER_OUTPUT" \
  --skip-crowded-labels \
  --label-distance-threshold 0.8 \
  --relative-percent \
  --color-mode model \
  --shade-arch-background \
  --arch-boundary-color '#607B8F' \
  --arch-background-alpha 0.27 \
  --no-arch-boundary \
  --no-title

echo "[saved] plot -> $SCATTER_OUTPUT"
stat "$SCATTER_OUTPUT" >/dev/null
echo "[ok] stat -> $SCATTER_OUTPUT"
