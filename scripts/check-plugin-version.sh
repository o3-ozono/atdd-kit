#!/usr/bin/env bash
# Usage: check-plugin-version.sh <plugin_root> <cache_dir>
# Output protocol:
#   FIRST_RUN\n<current_version>        -- no cache exists
#   NO_UPDATE                           -- cache matches current
#   UPDATED\n<old>\n<current>\n<changelog_diff>  -- version changed
set -euo pipefail

PLUGIN_ROOT="${1:?Usage: check-plugin-version.sh <plugin_root> <cache_dir>}"
CACHE_DIR="${2:?Usage: check-plugin-version.sh <plugin_root> <cache_dir>}"

# Read current version from plugin.json (single source of truth)
CURRENT=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "${PLUGIN_ROOT}/.claude-plugin/plugin.json" | head -1)

if [[ -z "$CURRENT" ]]; then
  echo "ERROR: could not read version from ${PLUGIN_ROOT}/.claude-plugin/plugin.json" >&2
  exit 1
fi

CACHE_FILE="${CACHE_DIR}/atdd-kit.version"

# First run: no cache
if [[ ! -f "$CACHE_FILE" ]]; then
  echo "FIRST_RUN"
  echo "$CURRENT"
  mkdir -p "$CACHE_DIR"
  echo "$CURRENT" > "$CACHE_FILE"
  exit 0
fi

CACHED=$(cat "$CACHE_FILE")

# No update
if [[ "$CACHED" == "$CURRENT" ]]; then
  echo "NO_UPDATE"
  exit 0
fi

# Updated: extract CHANGELOG entries between cached and current version
echo "UPDATED"
echo "$CACHED"
echo "$CURRENT"

CHANGELOG="${PLUGIN_ROOT}/CHANGELOG.md"
if [[ -f "$CHANGELOG" ]]; then
  # Extract entries newer than cached version, stop at cached version header
  sed -n '/^## \[/,$ p' "$CHANGELOG" | while IFS= read -r line; do
    if [[ "$line" =~ ^##\ \[([0-9]+\.[0-9]+\.[0-9]+)\] ]]; then
      ver="${BASH_REMATCH[1]}"
      if [[ "$ver" == "$CACHED" ]]; then
        break
      fi
    fi
    echo "$line"
  done
fi

# Update cache
echo "$CURRENT" > "$CACHE_FILE"
