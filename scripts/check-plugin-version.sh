#!/usr/bin/env bash
# Usage: check-plugin-version.sh <plugin_root> <cache_dir> [installed_plugins_json] [project_path]
# Output protocol:
#   FIRST_RUN\n<current_version>                       -- no cache exists
#   STALE_SESSION\n<loaded>\n<cached>                  -- loaded < cached (old session still running)
#   RESTART_REQUIRED\n<loaded>\n<installed>            -- installed > loaded (new version not yet active)
#   NO_UPDATE                                          -- cache matches current
#   UPDATED\n<old>\n<current>\n
#     VERSIONS: <count|UNKNOWN>\nBREAKING: <count>    -- version changed (5 lines total)
set -euo pipefail

PLUGIN_ROOT="${1:?Usage: check-plugin-version.sh <plugin_root> <cache_dir>}"
CACHE_DIR="${2:?Usage: check-plugin-version.sh <plugin_root> <cache_dir>}"
INSTALLED_PLUGINS_JSON="${3:-${HOME}/.claude/plugins/installed_plugins.json}"
PROJECT_PATH="${4:-${PWD}}"

# Read current version from plugin.json (single source of truth)
CURRENT=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "${PLUGIN_ROOT}/.claude-plugin/plugin.json" | head -1)

if [[ -z "$CURRENT" ]]; then
  echo "ERROR: could not read version from ${PLUGIN_ROOT}/.claude-plugin/plugin.json" >&2
  exit 1
fi

CACHE_FILE="${CACHE_DIR}/atdd-kit.version"

# Helper: compare versions using sort -V
# ver_gt A B → true if A > B
ver_gt() {
  local a="$1" b="$2"
  [[ "$a" != "$b" ]] && [[ "$(printf '%s\n%s\n' "$a" "$b" | sort -V | tail -1)" == "$a" ]]
}

# ver_lt A B → true if A < B
ver_lt() {
  ver_gt "$2" "$1"
}

# Helper: read installed version from installed_plugins.json for the given projectPath
# Returns empty string on any failure (file absent, parse error, no matching entry)
read_installed_version() {
  local json_file="$1" proj="$2"
  if [[ ! -f "$json_file" ]]; then
    echo ""
    return 0
  fi
  if ! command -v jq &>/dev/null; then
    # fallback: no jq available
    echo ""
    return 0
  fi
  local ver
  # Guard: if jq parse fails, return empty
  ver=$(jq -r --arg p "$proj" \
    '.plugins["atdd-kit@atdd-kit"][]? | select(.projectPath==$p) | .version' \
    "$json_file" 2>/dev/null | head -1) || ver=""
  echo "${ver:-}"
}

# First run: no cache
if [[ ! -f "$CACHE_FILE" ]]; then
  echo "FIRST_RUN"
  echo "$CURRENT"
  mkdir -p "$CACHE_DIR"
  echo "$CURRENT" > "$CACHE_FILE"
  exit 0
fi

CACHED=$(cat "$CACHE_FILE")

# STALE_SESSION: loaded version is older than cached (marker) version
# This means a newer session already ran and wrote the marker; current session is stale.
# Do NOT update marker — preserves the newer marker written by the newer session.
if ver_lt "$CURRENT" "$CACHED"; then
  echo "STALE_SESSION"
  echo "$CURRENT"
  echo "$CACHED"
  exit 0
fi

# RESTART_REQUIRED: an installed version newer than the loaded version exists locally
# Do NOT update marker — let the next session (with the new version loaded) do that.
INSTALLED=$(read_installed_version "$INSTALLED_PLUGINS_JSON" "$PROJECT_PATH")
if [[ -n "$INSTALLED" ]] && ver_gt "$INSTALLED" "$CURRENT"; then
  echo "RESTART_REQUIRED"
  echo "$CURRENT"
  echo "$INSTALLED"
  exit 0
fi

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
VERSIONS=0
BREAKING=0
FOUND_CACHED=0

if [[ -f "$CHANGELOG" ]]; then
  # Process substitution keeps variables in current shell (bash 3.2 compatible)
  while IFS= read -r line; do
    if [[ "$line" =~ ^##\ \[([0-9]+\.[0-9]+\.[0-9]+)\] ]]; then
      ver="${BASH_REMATCH[1]}"
      if [[ "$ver" == "$CACHED" ]]; then
        FOUND_CACHED=1
        break
      fi
      VERSIONS=$((VERSIONS + 1))
    fi
    if [[ "$line" == *"BREAKING CHANGE"* ]]; then
      BREAKING=$((BREAKING + 1))
    fi
  done < <(sed -n '/^## \[/,$ p' "$CHANGELOG")
fi

# CHANGELOG guard: if the CACHED version heading was never found, report UNKNOWN
if [[ "$FOUND_CACHED" -eq 0 && -f "$CHANGELOG" ]]; then
  echo "VERSIONS: UNKNOWN"
else
  echo "VERSIONS: ${VERSIONS}"
fi
echo "BREAKING: ${BREAKING}"

# Update cache
echo "$CURRENT" > "$CACHE_FILE"
