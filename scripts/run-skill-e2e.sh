#!/usr/bin/env bash
# scripts/run-skill-e2e.sh — Skill E2E Test runner with path-based impact mapping (#222)
#
# Computes the impacted skill set from a list of changed files using path-based
# mapping rules, then runs the corresponding Skill E2E Tests under
# tests/e2e/<skill>.bats and writes a log file under tests/e2e/.logs/.
#
# Mapping rules (path-based):
#   skills/<X>/...                          -> tests/e2e/<X>.bats
#   rules/ | templates/ | docs/methodology/ -> ALL tests/e2e/*.bats
#   lib/<file> | scripts/<file>             -> any skill whose SKILL.md cites
#                                              that file (grep)
#   other paths                             -> no impact
#
# Usage:
#   scripts/run-skill-e2e.sh --changed-files <f1>[,<f2>...] [--dry-run] [--log-dir <dir>]
#   scripts/run-skill-e2e.sh --all [--dry-run] [--log-dir <dir>]
#
# Exit codes:
#   0 PASS / dry-run success
#   1 at least one Skill E2E Test FAILED
#   3 usage / infra error

set -euo pipefail

if [ -n "${E2E_REPO_ROOT:-}" ]; then
  REPO_ROOT="$E2E_REPO_ROOT"
else
  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
E2E_DIR="${REPO_ROOT}/tests/e2e"
DEFAULT_LOG_DIR="${E2E_DIR}/.logs"

usage() {
  cat <<'EOF'
Usage:
  scripts/run-skill-e2e.sh --changed-files <f1>[,<f2>...] [--dry-run] [--log-dir <dir>]
  scripts/run-skill-e2e.sh --all [--dry-run] [--log-dir <dir>]

Options:
  --changed-files <list>  Comma-separated list of changed files (path-based mapping applied)
  --all                   Run every Skill E2E Test under tests/e2e/*.bats
  --dry-run               Resolve targets, print them, and write a log; do not execute bats
  --log-dir <dir>         Override log output directory (default: tests/e2e/.logs/)
  -h, --help              Show this help

Exit codes:
  0 PASS / dry-run success
  1 at least one E2E test FAILED
  3 usage / infra error
EOF
}

CHANGED_FILES=""
RUN_ALL=0
DRY_RUN=0
LOG_DIR="$DEFAULT_LOG_DIR"

if [ $# -eq 0 ]; then
  usage >&2
  exit 3
fi

while [ $# -gt 0 ]; do
  case "$1" in
    --changed-files)
      [ $# -ge 2 ] || { echo "Error: --changed-files requires a value" >&2; exit 3; }
      CHANGED_FILES="$2"
      shift 2
      ;;
    --all)
      RUN_ALL=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --log-dir)
      [ $# -ge 2 ] || { echo "Error: --log-dir requires a value" >&2; exit 3; }
      LOG_DIR="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: unknown argument: $1" >&2
      usage >&2
      exit 3
      ;;
  esac
done

if [ "$RUN_ALL" -eq 0 ] && [ -z "$CHANGED_FILES" ]; then
  echo "Error: one of --changed-files or --all is required" >&2
  exit 3
fi

TARGETS=()

resolve_all() {
  local f
  while IFS= read -r f; do
    TARGETS+=("tests/e2e/$(basename "$f")")
  done < <(find "$E2E_DIR" -maxdepth 1 -name '*.bats' -type f 2>/dev/null | sort)
}

resolve_lib_or_script() {
  local resource="$1"
  local skill_dir name target
  for skill_dir in "${REPO_ROOT}"/skills/*/; do
    [ -f "${skill_dir}SKILL.md" ] || continue
    if grep -qF "$resource" "${skill_dir}SKILL.md"; then
      name="$(basename "$skill_dir")"
      target="tests/e2e/${name}.bats"
      if [ -f "${REPO_ROOT}/${target}" ]; then
        TARGETS+=("$target")
      fi
    fi
  done
}

resolve_changed() {
  local files="$1"
  local IFS=','
  read -ra arr <<< "$files"
  local f trimmed name target full_resolve=0
  for f in "${arr[@]}"; do
    trimmed="$(echo "$f" | xargs)"
    [ -z "$trimmed" ] && continue
    case "$trimmed" in
      rules/*|templates/*|docs/methodology/*)
        full_resolve=1
        ;;
      skills/*/*)
        name="$(echo "$trimmed" | awk -F/ '{print $2}')"
        target="tests/e2e/${name}.bats"
        if [ -f "${REPO_ROOT}/${target}" ]; then
          TARGETS+=("$target")
        fi
        ;;
      lib/*|scripts/*)
        resolve_lib_or_script "$trimmed"
        ;;
      *)
        :
        ;;
    esac
  done
  if [ "$full_resolve" -eq 1 ]; then
    TARGETS=()
    resolve_all
  fi
}

if [ "$RUN_ALL" -eq 1 ]; then
  resolve_all
else
  resolve_changed "$CHANGED_FILES"
fi

# Deduplicate while preserving order (bash 3.2 compatible: no associative arrays)
if [ "${#TARGETS[@]}" -gt 0 ]; then
  UNIQ=()
  for t in "${TARGETS[@]}"; do
    found=0
    if [ "${#UNIQ[@]}" -gt 0 ]; then
      for u in "${UNIQ[@]}"; do
        if [ "$u" = "$t" ]; then
          found=1
          break
        fi
      done
    fi
    if [ "$found" -eq 0 ]; then
      UNIQ+=("$t")
    fi
  done
  TARGETS=("${UNIQ[@]}")
fi

mkdir -p "$LOG_DIR"
RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)-$$"
LOG_FILE="${LOG_DIR}/${RUN_ID}.log"
GIT_SHA="$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || echo 'unknown')"
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

{
  echo "run-id: ${RUN_ID}"
  echo "git_sha: ${GIT_SHA}"
  echo "timestamp: ${TIMESTAMP}"
  echo "mode: $([ "$DRY_RUN" -eq 1 ] && echo dry-run || echo execute)"
  echo "targets:"
  if [ "${#TARGETS[@]}" -eq 0 ]; then
    echo "  (none)"
  else
    for t in "${TARGETS[@]}"; do
      echo "  - ${t}"
    done
  fi
} > "$LOG_FILE"

echo "run-id: ${RUN_ID}"
echo "git_sha: ${GIT_SHA}"
echo "timestamp: ${TIMESTAMP}"
echo "log: ${LOG_FILE}"
echo "targets (${#TARGETS[@]}):"
if [ "${#TARGETS[@]}" -eq 0 ]; then
  echo "  (none)"
else
  for t in "${TARGETS[@]}"; do
    echo "  - ${t}"
  done
fi

if [ "${#TARGETS[@]}" -eq 0 ]; then
  {
    echo "results:"
    echo "  (none)"
    echo "summary: PASS (0/0) — no impacted skill"
  } >> "$LOG_FILE"
  echo "summary: PASS (0/0) — no impacted skill"
  exit 0
fi

if [ "$DRY_RUN" -eq 1 ]; then
  {
    echo "results:"
    echo "  (dry-run skipped)"
    echo "summary: DRY-RUN (resolved ${#TARGETS[@]} target(s))"
  } >> "$LOG_FILE"
  echo "summary: DRY-RUN (resolved ${#TARGETS[@]} target(s))"
  exit 0
fi

if ! command -v bats >/dev/null 2>&1; then
  echo "Error: bats not found in PATH" >&2
  exit 3
fi

PASS_COUNT=0
FAIL_COUNT=0
echo "results:" >> "$LOG_FILE"

for t in "${TARGETS[@]}"; do
  full="${REPO_ROOT}/${t}"
  if [ ! -f "$full" ]; then
    echo "  - ${t}: MISSING" >> "$LOG_FILE"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    continue
  fi
  if bats "$full" > /dev/null 2>&1; then
    echo "  - ${t}: PASS" >> "$LOG_FILE"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  - ${t}: FAIL" >> "$LOG_FILE"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
done

TOTAL=$((PASS_COUNT + FAIL_COUNT))
if [ "$FAIL_COUNT" -eq 0 ]; then
  echo "summary: PASS (${PASS_COUNT}/${TOTAL})" >> "$LOG_FILE"
  echo "summary: PASS (${PASS_COUNT}/${TOTAL})"
  exit 0
else
  echo "summary: FAIL (${PASS_COUNT}/${TOTAL})" >> "$LOG_FILE"
  echo "summary: FAIL (${PASS_COUNT}/${TOTAL})"
  exit 1
fi
