#!/usr/bin/env bash
# lint_skill_descriptions.sh -- Scan skills/*/SKILL.md for description anti-patterns
#
# Detection rules (WARN-only, exit 0 always):
#   (a) step-chain keyword: description contains ", then X" or "creates X, then Y"
#       indicating workflow steps rather than trigger conditions
#   (b) length > 200 chars: prose indicator; trigger-only descriptions are short
#   (c) dash-separator + noun/verb list: "summary -- item, item, item" pattern
#       indicates a summary rather than a trigger condition
#
# update when detection rule changes
#
# Usage:
#   scripts/lint_skill_descriptions.sh               # scan skills/*/SKILL.md
#   scripts/lint_skill_descriptions.sh --dir <path>  # scan <path>/**/SKILL.md

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/lint_skill_descriptions.sh               # scan skills/*/SKILL.md
  scripts/lint_skill_descriptions.sh --dir <path>  # scan custom dir for SKILL.md files

Exit code: always 0 (WARN-only mode; FAIL mode deferred to follow-up Issue)
Output format: "OK <path>" or "VIOLATION <path>: <reason>"
EOF
}

SCAN_DIR=""

while [ $# -gt 0 ]; do
  case "$1" in
    --dir)
      [ $# -ge 2 ] || { echo "Error: --dir requires a path argument" >&2; usage; exit 3; }
      SCAN_DIR="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: unknown argument: $1" >&2
      usage
      exit 3
      ;;
  esac
done

if [ -z "$SCAN_DIR" ]; then
  SCAN_DIR="${REPO_ROOT}/skills"
fi

# Collect all SKILL.md files under the target dir
skill_files_raw=$(find "$SCAN_DIR" -name "SKILL.md" 2>/dev/null | sort)

if [ -z "$skill_files_raw" ]; then
  echo "No SKILL.md files found under: $SCAN_DIR"
  exit 0
fi

check_description() {
  local file="$1"
  local desc

  # Extract the description field value from YAML frontmatter
  desc=$(sed -n '/^---$/,/^---$/p' "$file" | grep '^description:' | head -1 | sed 's/^description:[[:space:]]*//' | sed "s/^[\"']//" | sed "s/[\"']$//")

  if [ -z "$desc" ]; then
    echo "OK $file"
    return
  fi

  violation_a=""
  violation_b=""
  violation_c=""

  # Rule (a): step-chain keyword — ", then X" pattern
  if echo "$desc" | grep -qiE ', then [a-z]'; then
    violation_a="step-chain keyword detected (', then X' pattern)"
  fi

  # Rule (b): length > 200 chars
  len=${#desc}
  if [ "$len" -gt 200 ]; then
    violation_b="description too long (${len} chars > 200; prose indicator)"
  fi

  # Rule (c): dash-separator + list pattern — "summary -- item, item, item"
  # Match: "word(s) -- word, word" where right side has 2+ comma-separated items
  if echo "$desc" | grep -qE ' -- [^,]+(, [^,]+){1,}'; then
    violation_c="dash-separator with item list (summary pattern, not trigger condition)"
  fi

  if [ -n "$violation_a" ] || [ -n "$violation_b" ] || [ -n "$violation_c" ]; then
    reason=""
    for v in "$violation_a" "$violation_b" "$violation_c"; do
      [ -z "$v" ] && continue
      [ -n "$reason" ] && reason="${reason}; "
      reason="${reason}${v}"
    done
    echo "VIOLATION $file: $reason"
  else
    echo "OK $file"
  fi
}

while IFS= read -r skill_file; do
  check_description "$skill_file"
done <<< "$skill_files_raw"

exit 0
