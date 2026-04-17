#!/usr/bin/env bash
# check-persona-check-order.sh -- Assert "Persona Prerequisite Check" appears
# before TeamCreate in commands/autopilot.md. Used by footprint eval AC4.
#
# Output layout (used only as proof-of-presence for measure-footprint.sh;
# non-zero bytes == assertion held):
#   persona-check-line: <line#>
#   teamcreate-line:    <line#>
#
# Exit non-zero (empty stdout) when order is violated or either marker missing.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TARGET="${REPO_ROOT}/${1:-commands/autopilot.md}"

[ -f "$TARGET" ] || { echo "ERROR: $TARGET not found" >&2; exit 1; }

persona_line=$(grep -n -m1 'Persona Prerequisite Check' "$TARGET" | cut -d: -f1 || true)
teamcreate_line=$(grep -n -m1 '^[[:space:]]*[0-9]*\.\?[[:space:]]*TeamCreate' "$TARGET" | cut -d: -f1 || true)

if [ -z "$persona_line" ] || [ -z "$teamcreate_line" ]; then
  echo "ERROR: missing marker — persona_line=$persona_line teamcreate_line=$teamcreate_line" >&2
  exit 1
fi

if [ "$persona_line" -ge "$teamcreate_line" ]; then
  echo "ERROR: persona check (line $persona_line) must come before TeamCreate (line $teamcreate_line)" >&2
  exit 1
fi

printf 'persona-check-line: %s\n' "$persona_line"
printf 'teamcreate-line:    %s\n' "$teamcreate_line"
