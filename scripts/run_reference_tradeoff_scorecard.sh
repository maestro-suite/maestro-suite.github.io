#!/usr/bin/env bash
set -euo pipefail

# Reproduce telemetry tradeoff overview + accuracy-by-arch plot and scorecard CSV.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_REPO="${SOURCE_REPO:-${MAS_BENCHMARK_REPO:-}}"
CONFIG_ARG="${CONFIG_ARG:-plot/configs/runs_wi_by_model_parquet.json}"
PLOT_OUTPUT="${PLOT_OUTPUT:-$ROOT_DIR/data/raw/reference/tradeoff_scorecard_wi_by_model_overview.pdf}"
ACCURACY_ARCH_PLOT_OUTPUT="${ACCURACY_ARCH_PLOT_OUTPUT:-$ROOT_DIR/data/raw/reference/accuracy_by_arch_wi.pdf}"
OUT_CSV="${OUT_CSV:-$ROOT_DIR/data/raw/reference/scorecard_wi_by_model.csv}"
PLOT_MODE="${PLOT_MODE:-overview}"
LABEL_DISTANCE_THRESHOLD="${LABEL_DISTANCE_THRESHOLD:-0.18}"
TITLE="${TITLE:-Latency vs Cost per Task, by Arch.}"

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

PLOT_SCRIPT="$SOURCE_REPO/plot/plot_telemetry_compare.py"
if [[ ! -f "$PLOT_SCRIPT" ]]; then
  echo "Missing plot script: $PLOT_SCRIPT" >&2
  exit 1
fi

# Backward-compatible config fallback for legacy command snippets.
if [[ "$CONFIG_ARG" = /* ]]; then
  CONFIG_PATH="$CONFIG_ARG"
else
  CONFIG_PATH="$SOURCE_REPO/$CONFIG_ARG"
fi
if [[ ! -f "$CONFIG_PATH" && "$(basename "$CONFIG_ARG")" == "runs_wi_by_model.json" ]]; then
  CONFIG_PATH="$SOURCE_REPO/plot/configs/runs_wi_by_model_parquet.json"
fi
if [[ ! -f "$CONFIG_PATH" ]]; then
  echo "Config not found: $CONFIG_PATH" >&2
  exit 1
fi

mkdir -p "$(dirname "$PLOT_OUTPUT")" "$(dirname "$ACCURACY_ARCH_PLOT_OUTPUT")" "$(dirname "$OUT_CSV")"

"$PYTHON_BIN" "$PLOT_SCRIPT" \
  --config "$CONFIG_PATH" \
  --plot-output "$PLOT_OUTPUT" \
  --csv-output "$OUT_CSV" \
  --plot-mode "$PLOT_MODE" \
  --skip-crowded-labels \
  --label-distance-threshold "$LABEL_DISTANCE_THRESHOLD" \
  --title "$TITLE"

echo "[saved] scorecard -> $OUT_CSV"
echo "[saved] plot -> $PLOT_OUTPUT"

"$PYTHON_BIN" "$ROOT_DIR/scripts/plot_accuracy_by_arch.py" \
  --scorecard-csv "$OUT_CSV" \
  --output "$ACCURACY_ARCH_PLOT_OUTPUT" \
  --title "Accuracy by Architecture (with web search)"

echo "[saved] accuracy-by-arch plot -> $ACCURACY_ARCH_PLOT_OUTPUT"
