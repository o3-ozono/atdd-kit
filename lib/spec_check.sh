#!/usr/bin/env bash
# spec_check.sh — single source of truth for spec file detection and slug derivation.
#
# Usage:
#   bash lib/spec_check.sh derive_slug <issue-number>
#   bash lib/spec_check.sh spec_exists <slug> [<dir>]
#   bash lib/spec_check.sh read_acs <slug> [<dir>]
#   bash lib/spec_check.sh spec_status <slug> [<dir>]
#   bash lib/spec_check.sh spec_persona <slug> [<dir>]
#   bash lib/spec_check.sh get_spec_load_message <slug> <ac_count>
#   bash lib/spec_check.sh get_spec_warn_message <reason> [<slug>]
#
# Design:
#   - Mirror of lib/persona_check.sh: dispatcher with "fn; exit $?" propagation,
#     inner functions use "return 0/1" to avoid set -e foot-guns.
#   - Referenced by skills/{atdd,verify,bug}/SKILL.md spec-load / spec-authority /
#     spec-cite steps. SKILL.md prose is paired with these functions — do not
#     rely on prose alone.
#
# Environment:
#   GH_CMD_OVERRIDE       Overrides `gh issue view ... title` for testability.
#                         Value is a shell command that prints the Issue title.
#   SPEC_SLUG_OVERRIDE    Escape hatch for JA / non-ASCII titles: if set,
#                         derive_slug echoes its value verbatim.

set -euo pipefail

SPECS_DIR_DEFAULT="docs/specs"
US_AC_FORMAT_DOC="docs/methodology/us-ac-format.md"

# ---------------------------------------------------------------------------
# derive_slug <issue-number>
#
# Derives kebab-case slug from Issue title.
# EN-only path: strips conventional commit prefix, removes non-alphanumerics,
# kebab-cases remaining words. JA / non-ASCII titles must set SPEC_SLUG_OVERRIDE
# (see docs/methodology/us-ac-format.md § Slug Derivation Rule).
# ---------------------------------------------------------------------------

_derive_slug() {
  local issue="${1:-}"
  if [ -z "$issue" ]; then
    echo "ERROR: derive_slug requires an issue number." >&2
    return 1
  fi

  # Explicit override wins — used for JA titles and custom overrides.
  if [ -n "${SPEC_SLUG_OVERRIDE:-}" ]; then
    echo "$SPEC_SLUG_OVERRIDE"
    return 0
  fi

  local title
  if [ -n "${GH_CMD_OVERRIDE:-}" ]; then
    title=$(eval "$GH_CMD_OVERRIDE")
  else
    title=$(gh issue view "$issue" --json title --jq '.title' 2>/dev/null || true)
  fi

  if [ -z "$title" ]; then
    echo "ERROR: could not read Issue #${issue} title (set GH_CMD_OVERRIDE for tests)." >&2
    return 1
  fi

  # Strip conventional commit prefix: "type:" or "type(scope):" at start.
  local body
  body=$(printf '%s' "$title" | sed -E 's/^[a-zA-Z]+(\([^)]+\))?:[[:space:]]*//')

  # Detect JA / non-ASCII: if body contains any byte outside printable ASCII,
  # require SPEC_SLUG_OVERRIDE. Uses LC_ALL=C and a literal byte-range regex so
  # multi-byte UTF-8 sequences (e.g., JA) are detected regardless of locale.
  if LC_ALL=C printf '%s' "$body" | LC_ALL=C grep -q $'[^\x20-\x7E\t]'; then
    cat <<EOF >&2
ERROR: Issue #${issue} title contains non-ASCII characters.
Set SPEC_SLUG_OVERRIDE to an English kebab-case slug before continuing.
See ${US_AC_FORMAT_DOC} § Slug Derivation Rule for the 1 Issue = 1 spec policy.
EOF
    return 1
  fi

  # Lowercase, replace non-alphanumeric runs with hyphens, trim edges.
  local slug
  slug=$(printf '%s' "$body" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')

  if [ -z "$slug" ]; then
    echo "ERROR: derived slug is empty for Issue #${issue}." >&2
    return 1
  fi

  echo "$slug"
  return 0
}

# ---------------------------------------------------------------------------
# spec_exists <slug> [<dir>]
# ---------------------------------------------------------------------------

_spec_exists() {
  local slug="${1:-}"
  local dir="${2:-$SPECS_DIR_DEFAULT}"
  if [ -z "$slug" ]; then
    echo "ERROR: spec_exists requires a slug." >&2
    return 1
  fi
  [ -f "${dir}/${slug}.md" ]
}

# ---------------------------------------------------------------------------
# read_acs <slug> [<dir>]
#
# Prints the AC count (number of "### AC<N>" headings under "## Acceptance
# Criteria"). Missing spec → non-zero exit.
# ---------------------------------------------------------------------------

_read_acs() {
  local slug="${1:-}"
  local dir="${2:-$SPECS_DIR_DEFAULT}"
  if [ -z "$slug" ]; then
    echo "ERROR: read_acs requires a slug." >&2
    return 1
  fi
  local file="${dir}/${slug}.md"
  if [ ! -f "$file" ]; then
    echo "ERROR: spec not found: ${file}" >&2
    return 1
  fi
  # Count lines matching "### AC<digits>..." — case-sensitive, must start with "### AC".
  local count
  count=$(grep -cE '^### AC[0-9]+' "$file" || true)
  echo "${count:-0}"
  return 0
}

# ---------------------------------------------------------------------------
# spec_status <slug> [<dir>]
# ---------------------------------------------------------------------------

_spec_status() {
  local slug="${1:-}"
  local dir="${2:-$SPECS_DIR_DEFAULT}"
  if [ -z "$slug" ]; then
    echo "ERROR: spec_status requires a slug." >&2
    return 1
  fi
  local file="${dir}/${slug}.md"
  if [ ! -f "$file" ]; then
    echo "ERROR: spec not found: ${file}" >&2
    return 1
  fi
  local status
  status=$(awk -F': *' '/^status:/ { print $2; exit }' "$file" | tr -d '"' | tr -d "'" | tr -d ' ')
  if [ -z "$status" ]; then
    echo "ERROR: status field missing in ${file}" >&2
    return 1
  fi
  echo "$status"
  return 0
}

# ---------------------------------------------------------------------------
# spec_persona <slug> [<dir>]
# ---------------------------------------------------------------------------

_spec_persona() {
  local slug="${1:-}"
  local dir="${2:-$SPECS_DIR_DEFAULT}"
  if [ -z "$slug" ]; then
    echo "ERROR: spec_persona requires a slug." >&2
    return 1
  fi
  local file="${dir}/${slug}.md"
  if [ ! -f "$file" ]; then
    echo "ERROR: spec not found: ${file}" >&2
    return 1
  fi
  local persona
  persona=$(awk -F': *' '/^persona:/ { sub(/^persona: */, "", $0); print; exit }' "$file" \
    | sed -E 's/^"//; s/"$//')
  if [ -z "$persona" ]; then
    echo "ERROR: persona field missing in ${file}" >&2
    return 1
  fi
  echo "$persona"
  return 0
}

# ---------------------------------------------------------------------------
# get_spec_load_message <slug> <ac_count>
#
# Canonical "Loaded docs/specs/<slug>.md (AC count: N)" format used by atdd
# SKILL.md spec-load step. AC1 of Issue #70 mandates this exact phrasing.
# ---------------------------------------------------------------------------

_get_spec_load_message() {
  local slug="${1:-}"
  local count="${2:-}"
  if [ -z "$slug" ] || [ -z "$count" ]; then
    echo "ERROR: get_spec_load_message requires <slug> <ac_count>." >&2
    return 1
  fi
  printf 'Loaded docs/specs/%s.md (AC count: %s)\n' "$slug" "$count"
  return 0
}

# ---------------------------------------------------------------------------
# get_spec_warn_message <reason> [<slug>]
#
# Emits `[spec-warn]`-prefixed warning for fallback cases (AC6). Known reasons:
#   missing                    — (a) no spec at all (BLOCKED, used by non-continuation)
#   continuation-fallback      — (b) Continuation Path with no spec
#   tbd-persona                — (c) spec_persona == TBD...
# ---------------------------------------------------------------------------

_get_spec_warn_message() {
  local reason="${1:-}"
  local slug="${2:-<slug>}"
  if [ -z "$reason" ]; then
    echo "ERROR: get_spec_warn_message requires <reason>." >&2
    return 1
  fi
  case "$reason" in
    missing)
      echo "[spec-warn] missing: no spec found at docs/specs/${slug}.md — run discover to create it."
      ;;
    continuation-fallback)
      echo "[spec-warn] continuation-fallback: resuming branch without docs/specs/${slug}.md — falling back to Issue comment ACs."
      ;;
    tbd-persona)
      echo "[spec-warn] tbd-persona: docs/specs/${slug}.md has persona: TBD — continuing with spec ACs but persona resolution is pending."
      ;;
    *)
      echo "[spec-warn] ${reason}: docs/specs/${slug}.md"
      ;;
  esac
  return 0
}

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------

_usage() {
  cat >&2 <<EOF
Usage: bash lib/spec_check.sh <subcommand> [args]

Valid subcommands:
  derive_slug <issue-number>           — Echo kebab-case slug from Issue title (EN-only; set SPEC_SLUG_OVERRIDE for JA).
  spec_exists <slug> [<dir>]           — Exit 0 if docs/specs/<slug>.md exists.
  read_acs <slug> [<dir>]              — Print AC count (### AC<N> heading count).
  spec_status <slug> [<dir>]           — Print status frontmatter value.
  spec_persona <slug> [<dir>]          — Print persona frontmatter value.
  get_spec_load_message <slug> <n>     — Canonical "Loaded docs/specs/..." line for AC1.
  get_spec_warn_message <reason> [<slug>] — [spec-warn]-prefixed fallback line for AC6.
EOF
}

# ---------------------------------------------------------------------------
# Dispatcher
# ---------------------------------------------------------------------------

SUBCOMMAND="${1:-}"

case "$SUBCOMMAND" in
  derive_slug)        shift; _derive_slug "$@";        exit $? ;;
  spec_exists)        shift; _spec_exists "$@";        exit $? ;;
  read_acs)           shift; _read_acs "$@";           exit $? ;;
  spec_status)        shift; _spec_status "$@";        exit $? ;;
  spec_persona)       shift; _spec_persona "$@";       exit $? ;;
  get_spec_load_message)  shift; _get_spec_load_message "$@";  exit $? ;;
  get_spec_warn_message)  shift; _get_spec_warn_message "$@";  exit $? ;;
  *)
    _usage
    exit 1
    ;;
esac
