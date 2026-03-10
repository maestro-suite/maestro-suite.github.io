#!/usr/bin/env bash
set -euo pipefail

# Reproduce RQ1 artifacts:
# 1) tradeoff scorecard + accuracy-by-arch
# 2) consistency-by-arch

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_REPO="${SOURCE_REPO:-${MAS_BENCHMARK_REPO:-}}"

MODEL_CONFIG_ARG="${MODEL_CONFIG_ARG:-plot/configs/runs_wi_by_model_parquet.json}"
ARCH_CONFIG_ARG="${ARCH_CONFIG_ARG:-plot/configs/runs_wi_by_arch_parquet.json}"

PLOT_OUTPUT="${PLOT_OUTPUT:-$ROOT_DIR/data/raw/reference/tradeoff_scorecard_wi_by_model_overview.pdf}"
ACCURACY_ARCH_PLOT_OUTPUT="${ACCURACY_ARCH_PLOT_OUTPUT:-$ROOT_DIR/data/raw/reference/accuracy_by_arch_wi.pdf}"
CONSISTENCY_OUTPUT="${CONSISTENCY_OUTPUT:-$ROOT_DIR/data/raw/reference/consistency_by_arch_wi.pdf}"
OUT_CSV="${OUT_CSV:-$ROOT_DIR/data/raw/reference/scorecard_wi_by_model.csv}"

LABEL_DISTANCE_THRESHOLD="${LABEL_DISTANCE_THRESHOLD:-0.18}"
PLOT_MODE="${PLOT_MODE:-overview}"

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

if [[ "$MODEL_CONFIG_ARG" = /* ]]; then
  MODEL_CONFIG_PATH="$MODEL_CONFIG_ARG"
else
  MODEL_CONFIG_PATH="$SOURCE_REPO/$MODEL_CONFIG_ARG"
fi
if [[ ! -f "$MODEL_CONFIG_PATH" && "$(basename "$MODEL_CONFIG_ARG")" == "runs_wi_by_model.json" ]]; then
  MODEL_CONFIG_PATH="$SOURCE_REPO/plot/configs/runs_wi_by_model_parquet.json"
fi
if [[ ! -f "$MODEL_CONFIG_PATH" ]]; then
  echo "Model config not found: $MODEL_CONFIG_PATH" >&2
  exit 1
fi

if [[ "$ARCH_CONFIG_ARG" = /* ]]; then
  ARCH_CONFIG_PATH="$ARCH_CONFIG_ARG"
else
  ARCH_CONFIG_PATH="$SOURCE_REPO/$ARCH_CONFIG_ARG"
fi
if [[ ! -f "$ARCH_CONFIG_PATH" && "$(basename "$ARCH_CONFIG_ARG")" == "runs_wi_by_arch.json" ]]; then
  ARCH_CONFIG_PATH="$SOURCE_REPO/plot/configs/runs_wi_by_arch_parquet.json"
fi
if [[ ! -f "$ARCH_CONFIG_PATH" ]]; then
  echo "Arch config not found: $ARCH_CONFIG_PATH" >&2
  exit 1
fi

TELEMETRY_COMPARE_SCRIPT="$ROOT_DIR/scripts/run_reference_tradeoff_scorecard.sh"
ARCH_COMBO_SCRIPT="$SOURCE_REPO/plot/plot_telemetry_arch_combo.py"

if [[ ! -x "$TELEMETRY_COMPARE_SCRIPT" ]]; then
  echo "Missing runner script: $TELEMETRY_COMPARE_SCRIPT" >&2
  exit 1
fi
if [[ ! -f "$ARCH_COMBO_SCRIPT" ]]; then
  echo "Missing arch consistency script: $ARCH_COMBO_SCRIPT" >&2
  exit 1
fi

mkdir -p "$(dirname "$PLOT_OUTPUT")" "$(dirname "$ACCURACY_ARCH_PLOT_OUTPUT")" "$(dirname "$CONSISTENCY_OUTPUT")" "$(dirname "$OUT_CSV")"

# Step 1: compare + scorecard + accuracy-by-arch.
SOURCE_REPO="$SOURCE_REPO" \
CONFIG_ARG="$MODEL_CONFIG_PATH" \
PLOT_OUTPUT="$PLOT_OUTPUT" \
ACCURACY_ARCH_PLOT_OUTPUT="$ACCURACY_ARCH_PLOT_OUTPUT" \
OUT_CSV="$OUT_CSV" \
PLOT_MODE="$PLOT_MODE" \
LABEL_DISTANCE_THRESHOLD="$LABEL_DISTANCE_THRESHOLD" \
"$TELEMETRY_COMPARE_SCRIPT"

# Step 2: consistency by architecture.
"$PYTHON_BIN" "$ARCH_COMBO_SCRIPT" \
  --config "$ARCH_CONFIG_PATH" \
  --output "$CONSISTENCY_OUTPUT" \
  --title "Cost/Duration consistency by architecture (with web search)"

echo "[saved] plot -> $CONSISTENCY_OUTPUT"
