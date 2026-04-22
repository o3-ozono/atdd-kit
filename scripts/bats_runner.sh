#!/usr/bin/env bash
# bats_runner.sh — impact-scoped BATS runner
#
# Usage:
#   bats_runner.sh --all [--repo <path>]
#   bats_runner.sh --impact --base <ref> [--repo <path>]
#
# Options:
#   --all             run all BATS files
#   --impact          run only BATS affected by changes vs --base
#   --base <ref>      git ref to diff against (required with --impact)
#   --repo <path>     path to repo root (default: directory of this script's parent)
#
# Environment (testing only):
#   _BATS_RUNNER_IMPACT_MAP_OVERRIDE  path to a script that replaces impact_map.sh
#
# Exit codes:
#   0 — success (all run BATS pass, or no affected BATS)
#   non-zero — bats failure, usage error, or git error
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

OPT_ALL=0
OPT_IMPACT=0
OPT_BASE=""
OPT_REPO="$DEFAULT_REPO_ROOT"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)    OPT_ALL=1;       shift   ;;
    --impact) OPT_IMPACT=1;    shift   ;;
    --base)   OPT_BASE="$2";   shift 2 ;;
    --repo)   OPT_REPO="$2";   shift 2 ;;
    *) echo "ERROR: unknown option '$1'" >&2; exit 1 ;;
  esac
done

if [[ $OPT_ALL -eq 0 && $OPT_IMPACT -eq 0 ]]; then
  echo "ERROR: either --all or --impact is required" >&2
  exit 1
fi

if [[ $OPT_IMPACT -eq 1 && -z "$OPT_BASE" ]]; then
  echo "ERROR: --impact requires --base <ref>" >&2
  exit 1
fi

# impact_map.sh: use override if set (for testing), else script-local
IMPACT_MAP="${_BATS_RUNNER_IMPACT_MAP_OVERRIDE:-${SCRIPT_DIR}/impact_map.sh}"
CONFIG="${OPT_REPO}/config/impact_rules.yml"

collect_all_bats() {
  find "${OPT_REPO}/tests" -maxdepth 1 -name "*.bats" 2>/dev/null | sort
  find "${OPT_REPO}/addons" -path "*/tests/*.bats" 2>/dev/null | sort
}

run_bats_files() {
  local -a bats_files=("$@")
  if [[ ${#bats_files[@]} -eq 0 ]]; then
    echo "no affected BATS"
    exit 0
  fi
  echo "Running ${#bats_files[@]} BATS file(s):"
  local f
  for f in "${bats_files[@]}"; do
    echo "  $(basename "$f")"
  done
  bats "${bats_files[@]}"
}

if [[ $OPT_ALL -eq 1 ]]; then
  all_files=()
  while IFS= read -r f; do
    [[ -n "$f" ]] && all_files+=("$f")
  done < <(collect_all_bats)
  run_bats_files "${all_files[@]}"
  exit $?
fi

# --impact mode: delegate to impact_map.sh
impact_stderr_file=$(mktemp)
trap 'rm -f "$impact_stderr_file"' EXIT

impact_output=""
set +e
impact_output=$(
  bash "$IMPACT_MAP" \
    --layer BATS \
    --base "$OPT_BASE" \
    --config "$CONFIG" \
    2>"$impact_stderr_file"
)
impact_exit=$?
set -e

impact_stderr=$(cat "$impact_stderr_file")

if [[ $impact_exit -ne 0 ]]; then
  echo "ERROR: impact_map.sh failed (exit $impact_exit)" >&2
  if [[ -n "$impact_stderr" ]]; then
    echo "$impact_stderr" >&2
  fi
  exit $impact_exit
fi

# Check for FALLBACK in stderr
if grep -q "^FALLBACK:" "$impact_stderr_file"; then
  echo "FALLBACK: unmatched changed files — running full BATS suite" >&2
  all_files=()
  while IFS= read -r f; do
    [[ -n "$f" ]] && all_files+=("$f")
  done < <(collect_all_bats)
  run_bats_files "${all_files[@]}"
  exit $?
fi

# Empty output = no changed files (AC5)
if [[ -z "$impact_output" ]]; then
  echo "no affected BATS"
  exit 0
fi

# Collect affected BATS files (deduplicated, sorted)
affected_files=()
while IFS= read -r f; do
  [[ -n "$f" ]] && affected_files+=("$f")
done < <(printf '%s\n' "$impact_output" | sort -u)

run_bats_files "${affected_files[@]}"
