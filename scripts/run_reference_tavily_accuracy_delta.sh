#!/usr/bin/env bash
set -euo pipefail

# Reproduce Tavily on/off accuracy delta plot.
# Preferred source: agent-observability (tools/telemetry_tavily_diff.py)
# Fallback source: mas-benchmark (plot/plot_telemetry_tavily_diff.py)

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_REPO="${SOURCE_REPO:-${AGENT_OBSERVABILITY_REPO:-}}"
FALLBACK_PLOT_REPO="${FALLBACK_PLOT_REPO:-${MAS_BENCHMARK_REPO:-}}"
ACCURACY_OUTPUT="${ACCURACY_OUTPUT:-$ROOT_DIR/static/pdfs/figures/tavily_accuracy_delta.pdf}"

if [[ -z "$SOURCE_REPO" ]]; then
  echo "Set SOURCE_REPO or AGENT_OBSERVABILITY_REPO to your agent-observability path." >&2
  exit 1
fi

if [[ ! -d "$SOURCE_REPO" ]]; then
  echo "Source repo not found: $SOURCE_REPO" >&2
  exit 1
fi

TOOL_SCRIPT=""
SCRIPT_REPO=""
MODE=""
if [[ -f "$SOURCE_REPO/tools/telemetry_tavily_diff.py" ]]; then
  TOOL_SCRIPT="$SOURCE_REPO/tools/telemetry_tavily_diff.py"
  SCRIPT_REPO="$SOURCE_REPO"
  MODE="obs"
elif [[ -f "$SOURCE_REPO/plot/plot_telemetry_tavily_diff.py" ]]; then
  TOOL_SCRIPT="$SOURCE_REPO/plot/plot_telemetry_tavily_diff.py"
  SCRIPT_REPO="$SOURCE_REPO"
  MODE="plot"
elif [[ -f "$FALLBACK_PLOT_REPO/plot/plot_telemetry_tavily_diff.py" ]]; then
  TOOL_SCRIPT="$FALLBACK_PLOT_REPO/plot/plot_telemetry_tavily_diff.py"
  SCRIPT_REPO="$FALLBACK_PLOT_REPO"
  MODE="plot"
  echo "[warn] $SOURCE_REPO does not contain telemetry_tavily_diff.py; falling back to $FALLBACK_PLOT_REPO" >&2
else
  cat >&2 <<ERR
Missing Tavily diff script.
Checked:
  $SOURCE_REPO/tools/telemetry_tavily_diff.py
  $SOURCE_REPO/plot/plot_telemetry_tavily_diff.py
  $FALLBACK_PLOT_REPO/plot/plot_telemetry_tavily_diff.py
ERR
  exit 1
fi

if [[ "$MODE" == "obs" ]]; then
  WITH_CONFIG_ARG="${WITH_CONFIG_ARG:-tools/runs_wi_by_arch.json}"
  WITHOUT_CONFIG_ARG="${WITHOUT_CONFIG_ARG:-tools/runs_wo_by_arch.json}"
else
  WITH_CONFIG_ARG="${WITH_CONFIG_ARG:-plot/configs/runs_wi_by_arch_parquet.json}"
  WITHOUT_CONFIG_ARG="${WITHOUT_CONFIG_ARG:-plot/configs/runs_wo_by_arch_parquet.json}"
fi

if [[ -x "$SCRIPT_REPO/.venv/bin/python" ]]; then
  PYTHON_BIN="$SCRIPT_REPO/.venv/bin/python"
elif [[ -x "$SCRIPT_REPO/tools/.venv/bin/python" ]]; then
  PYTHON_BIN="$SCRIPT_REPO/tools/.venv/bin/python"
elif [[ -x "$SCRIPT_REPO/plot/.venv/bin/python" ]]; then
  PYTHON_BIN="$SCRIPT_REPO/plot/.venv/bin/python"
elif [[ -n "${VIRTUAL_ENV:-}" ]] && command -v python >/dev/null 2>&1; then
  PYTHON_BIN="$(command -v python)"
elif command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN="$(command -v python3)"
else
  echo "No python interpreter found (checked repo venv and active shell)." >&2
  exit 1
fi

resolve_config() {
  local arg="$1"
  shift
  local candidates=("$@")

  if [[ "$arg" = /* ]]; then
    printf '%s' "$arg"
    return 0
  fi

  if [[ -f "$SOURCE_REPO/$arg" ]]; then
    printf '%s' "$SOURCE_REPO/$arg"
    return 0
  fi
  if [[ -f "$SCRIPT_REPO/$arg" ]]; then
    printf '%s' "$SCRIPT_REPO/$arg"
    return 0
  fi

  for c in "${candidates[@]}"; do
    if [[ -f "$SOURCE_REPO/$c" ]]; then
      printf '%s' "$SOURCE_REPO/$c"
      return 0
    fi
    if [[ -f "$SCRIPT_REPO/$c" ]]; then
      printf '%s' "$SCRIPT_REPO/$c"
      return 0
    fi
  done

  printf '%s' "$SCRIPT_REPO/$arg"
}

if [[ "$MODE" == "obs" ]]; then
  WITH_CONFIG_PATH="$(resolve_config "$WITH_CONFIG_ARG" "tools/runs_wi_by_arch.json")"
  WITHOUT_CONFIG_PATH="$(resolve_config "$WITHOUT_CONFIG_ARG" "tools/runs_wo_by_arch.json")"
else
  WITH_CONFIG_PATH="$(resolve_config "$WITH_CONFIG_ARG" "plot/configs/runs_wi_by_arch_parquet.json" "plot/configs/runs_wi_by_arch.json")"
  WITHOUT_CONFIG_PATH="$(resolve_config "$WITHOUT_CONFIG_ARG" "plot/configs/runs_wo_by_arch_parquet.json" "plot/configs/runs_wo_by_arch.json")"
fi

if [[ ! -f "$WITH_CONFIG_PATH" ]]; then
  echo "With-config not found: $WITH_CONFIG_PATH" >&2
  exit 1
fi
if [[ ! -f "$WITHOUT_CONFIG_PATH" ]]; then
  echo "Without-config not found: $WITHOUT_CONFIG_PATH" >&2
  exit 1
fi

mkdir -p "$(dirname "$ACCURACY_OUTPUT")"

"$PYTHON_BIN" "$TOOL_SCRIPT" \
  --with-config "$WITH_CONFIG_PATH" \
  --without-config "$WITHOUT_CONFIG_PATH" \
  --accuracy-output "$ACCURACY_OUTPUT"

echo "[saved] accuracy delta -> $ACCURACY_OUTPUT"
stat "$ACCURACY_OUTPUT" >/dev/null
echo "[ok] stat -> $ACCURACY_OUTPUT"
