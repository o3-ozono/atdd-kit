#!/usr/bin/env bash
# check-required-labels.sh — pre-flight check: detect missing GitHub workflow
# labels and (optionally) create them.
#
# `commands/setup-github.md` is the canonical source of the required label set
# (16 labels). This script parses that file's `gh label create "<name>" ...`
# lines so the required set never drifts out of sync with setup-github.
#
# Standard pre-flight guard pattern (docs/design/setup-on-demand-policy.md):
#   - does NOT error-exit when labels are missing — it only notifies.
#   - skips gracefully (exit 0) when `gh label list` cannot be evaluated
#     (gh absent, unauthenticated, or any other failure) — never blocks the
#     calling workflow.
#   - remediation (gh label create --force) only runs when --create is passed
#     (confirm-after-notify), and is idempotent: creating an existing label
#     with --force is a no-op error-wise, so repeated runs never fail or
#     duplicate.
#
# Usage:
#   check-required-labels.sh [--create] [--setup-github-md <path>]
#
# Exit codes:
#   always 0 — this is a notify-only pre-flight guard, never a hard gate.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SETUP_GITHUB_MD="$REPO_ROOT/commands/setup-github.md"
DO_CREATE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --create)
      DO_CREATE=1; shift ;;
    --setup-github-md)
      [ $# -ge 2 ] || { echo "ERROR: --setup-github-md requires a value" >&2; exit 0; }
      SETUP_GITHUB_MD="$2"; shift 2 ;;
    -h|--help)
      cat <<'EOF'
check-required-labels.sh — pre-flight check for required GitHub workflow labels.

Usage:
  check-required-labels.sh [--create] [--setup-github-md <path>]

Options:
  --create              Additionally create missing labels via `gh label create --force`
                         (idempotent; safe to re-run).
  --setup-github-md <p> Path to setup-github.md used as the canonical label source
                         (default: commands/setup-github.md next to this script).

This is a notify-only pre-flight guard: it never error-exits. Missing labels are
reported; unavailable `gh` (absent or unauthenticated) results in a graceful skip.
EOF
      exit 0 ;;
    *) echo "ERROR: unknown argument: $1 (ignored — notify-only guard)" >&2; shift ;;
  esac
done

if [ ! -f "$SETUP_GITHUB_MD" ]; then
  echo "check-required-labels: skipped — canonical source not found: $SETUP_GITHUB_MD" >&2
  exit 0
fi

# --- Parse the canonical required label set from setup-github.md ---
required_labels="$(grep -oE '^gh label create "[^"]+"' "$SETUP_GITHUB_MD" | sed -E 's/^gh label create "//; s/"$//')"

if [ -z "$required_labels" ]; then
  echo "check-required-labels: skipped — no label definitions found in $SETUP_GITHUB_MD" >&2
  exit 0
fi

# --- Detect gh availability ---
if ! command -v gh >/dev/null 2>&1; then
  echo "check-required-labels: skipped — gh command not found (setup-github not run / gh not installed)" >&2
  exit 0
fi

# --- Query existing labels; skip gracefully on any failure (unauth, network, etc.) ---
existing_labels="$(gh label list --limit 200 2>/dev/null | awk -F'\t' '{print $1}')"
if [ -z "$existing_labels" ]; then
  echo "check-required-labels: skipped — could not retrieve label list (gh unauthenticated or repo unavailable)" >&2
  exit 0
fi

missing=""
while IFS= read -r label; do
  [ -n "$label" ] || continue
  if ! printf '%s\n' "$existing_labels" | grep -qxF "$label"; then
    missing="${missing}${label}"$'\n'
  fi
done <<< "$required_labels"

if [ -z "$missing" ]; then
  echo "check-required-labels: all required labels present"
  exit 0
fi

echo "check-required-labels: missing required labels:"
printf '%s' "$missing" | while IFS= read -r label; do
  [ -n "$label" ] || continue
  echo "  - $label"
done

if [ "$DO_CREATE" -eq 1 ]; then
  echo "check-required-labels: creating missing labels (gh label create --force, idempotent)..."
  while IFS= read -r label; do
    [ -n "$label" ] || continue
    gh label create "$label" --force >/dev/null 2>&1 \
      && echo "  created (or already existed): $label" \
      || echo "  WARNING: failed to create label: $label" >&2
  done <<< "$missing"
fi

exit 0
