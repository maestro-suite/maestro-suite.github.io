#!/usr/bin/env bash
set -euo pipefail

SOURCE_REPO=""
SOURCES_FILE=""
MANIFEST=""
DEST=""

declare -A SOURCES

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

add_source_alias() {
  local alias="$1"
  local path="$2"

  if [[ -z "$alias" || -z "$path" ]]; then
    return 1
  fi
  if [[ ! -d "$path" ]]; then
    echo "Source repo does not exist for alias '$alias': $path" >&2
    return 1
  fi
  SOURCES["$alias"]="$path"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source)
      SOURCE_REPO="${2:-}"
      shift 2
      ;;
    --sources-file)
      SOURCES_FILE="${2:-}"
      shift 2
      ;;
    --manifest)
      MANIFEST="${2:-}"
      shift 2
      ;;
    --dest)
      DEST="${2:-}"
      shift 2
      ;;
    *)
      echo "Unknown arg: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$MANIFEST" || -z "$DEST" ]]; then
  echo "Usage: $0 [--source <default_source_repo>] [--sources-file <sources_map>] --manifest <manifest_path> --dest <dest_dir>" >&2
  exit 1
fi

if [[ -n "$SOURCE_REPO" ]]; then
  add_source_alias "default" "$SOURCE_REPO"
fi

if [[ -n "$SOURCES_FILE" ]]; then
  if [[ ! -f "$SOURCES_FILE" ]]; then
    echo "Sources file does not exist: $SOURCES_FILE" >&2
    exit 1
  fi

  while IFS= read -r raw || [[ -n "$raw" ]]; do
    line="$(trim "$raw")"
    if [[ -z "$line" || "${line:0:1}" == "#" ]]; then
      continue
    fi

    if [[ "$line" != *"="* ]]; then
      echo "Invalid sources entry (expected alias=path): $line" >&2
      exit 1
    fi

    alias="$(trim "${line%%=*}")"
    path="$(trim "${line#*=}")"
    add_source_alias "$alias" "$path"
  done < "$SOURCES_FILE"
fi

if [[ ${#SOURCES[@]} -eq 0 ]]; then
  echo "No source repos configured. Provide --source or --sources-file." >&2
  exit 1
fi

if [[ ! -f "$MANIFEST" ]]; then
  echo "Manifest does not exist: $MANIFEST" >&2
  exit 1
fi

mkdir -p "$DEST"

copied=0
missing=0

while IFS= read -r line || [[ -n "$line" ]]; do
  entry="$(trim "$line")"
  if [[ -z "$entry" || "${entry:0:1}" == "#" ]]; then
    continue
  fi

  # Supported formats:
  # 1) source/relative/path.ext
  # 2) source/relative/path.ext => repo/relative/destination.ext
  # 3) alias:source/relative/path.ext => repo/relative/destination.ext
  if [[ "$entry" == *"=>"* ]]; then
    src_ref="$(trim "${entry%%=>*}")"
    dst_rel="$(trim "${entry#*=>}")"
  else
    src_ref="$entry"
    dst_rel="$entry"
  fi

  if [[ -z "$src_ref" || -z "$dst_rel" ]]; then
    echo "Invalid manifest entry: $entry" >&2
    missing=$((missing + 1))
    continue
  fi

  if [[ "${dst_rel:0:1}" == "/" || "$dst_rel" == *".."* ]]; then
    echo "Unsafe destination path in manifest entry: $entry" >&2
    missing=$((missing + 1))
    continue
  fi

  alias="default"
  src_rel="$src_ref"
  if [[ "$src_ref" == *":"* ]]; then
    potential_alias="${src_ref%%:*}"
    potential_src="${src_ref#*:}"
    if [[ -n "${SOURCES[$potential_alias]+x}" ]]; then
      alias="$potential_alias"
      src_rel="$potential_src"
    fi
  fi

  if [[ -z "${SOURCES[$alias]+x}" ]]; then
    echo "Unknown source alias '$alias' in entry: $entry" >&2
    missing=$((missing + 1))
    continue
  fi

  source_root="${SOURCES[$alias]}"
  src_path="$source_root/$src_rel"
  dst_path="$DEST/$dst_rel"

  if [[ ! -f "$src_path" ]]; then
    echo "Missing asset: $alias:$src_rel" >&2
    missing=$((missing + 1))
    continue
  fi

  mkdir -p "$(dirname "$dst_path")"
  cp -f "$src_path" "$dst_path"
  echo "Synced: $alias:$src_rel -> $dst_rel"
  copied=$((copied + 1))
done < "$MANIFEST"

echo "Sync completed: copied=$copied missing=$missing"

if [[ "$missing" -gt 0 ]]; then
  exit 2
fi
