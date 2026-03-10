#!/usr/bin/env bash
set -euo pipefail

# Reproduces model boxplot flow and exports the underlying per-run dataset.
# Defaults are aligned with current mas-benchmark parquet plot pipeline.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SOURCE_REPO="${SOURCE_REPO:-${MAS_BENCHMARK_REPO:-}}"
CONFIG_REL="${CONFIG_REL:-plot/configs/runs_wi_by_model_parquet.json}"
PLOT_OUTPUT="${PLOT_OUTPUT:-$ROOT_DIR/data/raw/reference/model_boxplots_wi.pdf}"
CSV_OUTPUT="${CSV_OUTPUT:-$ROOT_DIR/data/raw/reference/model_boxplots_wi_dataset.csv}"
JSON_OUTPUT="${JSON_OUTPUT:-$ROOT_DIR/data/raw/reference/model_boxplots_wi_dataset.json}"
TITLE="${TITLE:-Cost/Duration/Accuracy by Model (with web search)}"

if [[ ! -d "$SOURCE_REPO" ]]; then
  if [[ -z "$SOURCE_REPO" ]]; then
    echo "Set SOURCE_REPO or MAS_BENCHMARK_REPO to your mas-benchmark path." >&2
    exit 1
  fi
  echo "Source repo not found: $SOURCE_REPO" >&2
  exit 1
fi

if [[ "$CONFIG_REL" = /* ]]; then
  CONFIG_PATH="$CONFIG_REL"
else
  CONFIG_PATH="$SOURCE_REPO/$CONFIG_REL"
fi
if [[ ! -f "$CONFIG_PATH" ]]; then
  echo "Config not found: $CONFIG_PATH" >&2
  exit 1
fi

if [[ -x "$SOURCE_REPO/.venv/bin/python" ]]; then
  PYTHON_BIN="$SOURCE_REPO/.venv/bin/python"
elif [[ -x "$SOURCE_REPO/tools/.venv/bin/python" ]]; then
  PYTHON_BIN="$SOURCE_REPO/tools/.venv/bin/python"
else
  echo "No python venv found in source repo (.venv or tools/.venv)." >&2
  exit 1
fi

PLOT_SCRIPT_NEW="$SOURCE_REPO/plot/plot_telemetry_model_boxplots.py"
PLOT_SCRIPT_OLD="$SOURCE_REPO/tools/telemetry_model_boxplots.py"

mkdir -p "$(dirname "$PLOT_OUTPUT")" "$(dirname "$CSV_OUTPUT")" "$(dirname "$JSON_OUTPUT")"

echo "[1/2] Exporting boxplot dataset rows..."
"$PYTHON_BIN" "$ROOT_DIR/scripts/export_model_boxplot_dataset.py" \
  --source-repo "$SOURCE_REPO" \
  --config "$CONFIG_PATH" \
  --csv-output "$CSV_OUTPUT" \
  --json-output "$JSON_OUTPUT"

echo "[2/2] Rendering reference boxplot..."
if [[ -f "$PLOT_SCRIPT_NEW" ]]; then
  "$PYTHON_BIN" "$PLOT_SCRIPT_NEW" \
    --config "$CONFIG_PATH" \
    --output "$PLOT_OUTPUT" \
    --title "$TITLE" \
    --hide-accuracy-labels \
    --hide-subplot-titles
elif [[ -f "$PLOT_SCRIPT_OLD" ]]; then
  # Legacy path used in older instructions.
  "$PYTHON_BIN" "$PLOT_SCRIPT_OLD" \
    --config "$CONFIG_PATH" \
    --output "$PLOT_OUTPUT" \
    --title "$TITLE"
else
  echo "No model boxplot script found in source repo." >&2
  echo "Checked:" >&2
  echo "  - $PLOT_SCRIPT_NEW" >&2
  echo "  - $PLOT_SCRIPT_OLD" >&2
  exit 1
fi

echo "Done."
echo "  plot: $PLOT_OUTPUT"
echo "  csv:  $CSV_OUTPUT"
echo "  json: $JSON_OUTPUT"
