#!/usr/bin/env bash
# persona_check.sh — single source of truth for valid persona detection.
#
# Usage:
#   bash lib/persona_check.sh count_valid_personas <dir>
#   bash lib/persona_check.sh is_valid_persona <file>
#   bash lib/persona_check.sh get_persona_guidance_message
#
# Design:
#   - Shared by autopilot Phase 0.9 prerequisite check and discover Step 3a precheck.
#   - No external dependencies (pure bash + grep/sed/find).
#   - set -euo pipefail + dispatcher uses "fn; exit $?" to propagate exit codes.
#   - Inner functions use "return 0/1" to avoid set -e foot-guns.

set -euo pipefail

PERSONA_GUIDE_PATH="docs/methodology/persona-guide.md"

# ---------------------------------------------------------------------------
# Internal: per-file validation
#
# A valid persona file is:
#   1. A regular file (or symlink that resolves to one)
#   2. Located directly under <dir>/ (no subdirectories)
#   3. Not a hidden file (does not start with '.')
#   4. Not README.md or TEMPLATE.md (case-insensitive)
#   5. Extension is .md
#   6. Non-empty
#   7. Does not contain the TEMPLATE placeholder "[Persona Name]"
# ---------------------------------------------------------------------------

_is_valid_persona_file() {
  local file="$1"
  [ -f "$file" ] || return 1

  local base
  base="$(basename "$file")"

  case "$base" in
    .*) return 1 ;;
    README.md|README.MD|readme.md) return 1 ;;
    TEMPLATE.md|TEMPLATE.MD|template.md) return 1 ;;
    *.md) ;;
    *) return 1 ;;
  esac

  [ -s "$file" ] || return 1

  # Placeholder still present → TEMPLATE was copied without being filled in.
  if grep -q '\[Persona Name\]' "$file"; then
    return 1
  fi

  return 0
}

# ---------------------------------------------------------------------------
# Subcommand: is_valid_persona <file>
# ---------------------------------------------------------------------------

_is_valid_persona() {
  local file="${1:-}"
  if [ -z "$file" ]; then
    echo "ERROR: is_valid_persona requires a file argument." >&2
    return 1
  fi
  _is_valid_persona_file "$file"
}

# ---------------------------------------------------------------------------
# Subcommand: count_valid_personas <dir>
#
# Prints the count of valid personas to stdout. Missing directory → 0.
# Only regular files directly under <dir>/ are considered (no recursion).
# Symlinks are followed.
# ---------------------------------------------------------------------------

_count_valid_personas() {
  local dir="${1:-}"
  if [ -z "$dir" ]; then
    echo "ERROR: count_valid_personas requires a directory argument." >&2
    return 1
  fi

  if [ ! -d "$dir" ]; then
    echo "0"
    return 0
  fi

  local count=0 entry base
  # Use find with -maxdepth 1 so nested .md files never contribute.
  # -L follows symlinks when evaluating -f via _is_valid_persona_file.
  while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    base="$(basename "$entry")"
    # Skip hidden early for speed (find already skips via pattern below, but be defensive)
    case "$base" in .*) continue ;; esac
    if _is_valid_persona_file "$entry"; then
      count=$((count + 1))
    fi
  done < <(find -L "$dir" -maxdepth 1 -mindepth 1 \( -type f -o -type l \) -name '*.md' ! -name '.*' 2>/dev/null)

  echo "$count"
  return 0
}

# ---------------------------------------------------------------------------
# Subcommand: get_persona_guidance_message
#
# Emits the canonical BLOCKED guidance. Shared verbatim by autopilot Phase 0.9
# and discover Step 3a precheck so users get a consistent message.
# ---------------------------------------------------------------------------

_get_persona_guidance_message() {
  cat <<EOF
Autopilot requires at least one valid persona in docs/personas/ for development and bug flows.

Create at least one persona in docs/personas/ before running autopilot.

See ${PERSONA_GUIDE_PATH}:
- "Creation Process" section — do not create a persona for every Issue; personas represent *groups of users*
- Anti-Pattern 1 (Persona Without Research) — ground each field in evidence, not assumptions
- Anti-Pattern 2 (Persona Proliferation) — merge overlapping personas instead of adding new ones per feature

A valid persona file lives directly under docs/personas/, has a .md extension, is not README.md/TEMPLATE.md,
is non-empty, and has the TEMPLATE placeholder text replaced.
EOF
  return 0
}

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------

_usage() {
  echo "Usage: bash lib/persona_check.sh <subcommand> [args]" >&2
  echo "" >&2
  echo "Valid subcommands:" >&2
  echo "  count_valid_personas <dir>      — Print count of valid personas under <dir>" >&2
  echo "  is_valid_persona <file>         — Exit 0 if <file> is a valid persona, non-zero otherwise" >&2
  echo "  get_persona_guidance_message    — Emit canonical BLOCKED guidance" >&2
}

# ---------------------------------------------------------------------------
# Dispatcher
# ---------------------------------------------------------------------------

SUBCOMMAND="${1:-}"

case "$SUBCOMMAND" in
  count_valid_personas)
    shift
    _count_valid_personas "$@"; exit $?
    ;;
  is_valid_persona)
    shift
    _is_valid_persona "$@"; exit $?
    ;;
  get_persona_guidance_message)
    _get_persona_guidance_message; exit $?
    ;;
  *)
    _usage
    exit 1
    ;;
esac
