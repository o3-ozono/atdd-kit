#!/usr/bin/env bash
# check-phase5-section.sh -- Output matching lines from commands/autopilot.md for a given grep pattern.
# Used by evals/footprint/autopilot.yml dynamic entries to verify Phase 5 research sections exist.
# Output byte count is used by measure-footprint.sh; non-zero means section is present.
#
# Usage: check-phase5-section.sh <grep-pattern>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
AUTOPILOT="${REPO_ROOT}/commands/autopilot.md"

pattern="${1:?Usage: check-phase5-section.sh <grep-pattern>}"

grep -i "$pattern" "$AUTOPILOT" || true
