#!/usr/bin/env bash
# circuit_breaker.sh — Three-state circuit breaker for autopilot infinite-loop prevention
#
# Usage:
#   bash lib/circuit_breaker.sh check
#   bash lib/circuit_breaker.sh record_progress
#   bash lib/circuit_breaker.sh record_no_progress
#   bash lib/circuit_breaker.sh record_error <fingerprint>
#   bash lib/circuit_breaker.sh reset
#
# State file: .claude/cb-state.json (cwd-relative, worktree-scoped)
# States: CLOSED (normal) → HALF_OPEN (warning) → OPEN (tripped, halt)
# Thresholds: no_progress=3 trips OPEN; error_count=5 same fingerprint trips OPEN
#
# Design:
#   - No external dependencies (pure bash + printf/grep/sed)
#   - set -euo pipefail + dispatcher uses "check; exit $?" to propagate exit codes
#   - Inner functions use "return 0/1" to avoid set -e foot-guns
#   - Atomic JSON write: mktemp → mv

set -euo pipefail

STATE_FILE=".claude/cb-state.json"

# ---------------------------------------------------------------------------
# Internal: JSON read/write
# ---------------------------------------------------------------------------

# Read a single field from the state file via grep + sed (no jq dependency)
_get_field() {
  local field="$1"
  # Match "field":value or "field":"value" and extract the value
  grep -o "\"${field}\":[^,}]*" "$STATE_FILE" 2>/dev/null \
    | sed 's/"[^"]*"://; s/"//g; s/[[:space:]]//g' \
    | head -1
}

# Write the full state JSON atomically
_write_state() {
  local state="$1" no_progress="$2" error_count="$3" last_error_fingerprint="$4"
  local tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/cb-state-XXXXXX.json")"
  printf '{"state":"%s","no_progress":%s,"error_count":%s,"last_error_fingerprint":"%s"}\n' \
    "$state" "$no_progress" "$error_count" "$last_error_fingerprint" > "$tmp"
  mv "$tmp" "$STATE_FILE"
}

# ---------------------------------------------------------------------------
# Internal: State initialization
# ---------------------------------------------------------------------------

_init_state() {
  _write_state "CLOSED" "0" "0" ""
}

# Validate that the state file contains valid JSON fields.
# Returns 0 if valid, 1 if malformed.
_validate_state() {
  local s
  s="$(_get_field "state")"
  if [ -z "$s" ] || { [ "$s" != "CLOSED" ] && [ "$s" != "HALF_OPEN" ] && [ "$s" != "OPEN" ]; }; then
    return 1
  fi
  return 0
}

# Ensure state file exists and is valid; handle missing/malformed cases.
_ensure_state() {
  if [ ! -f "$STATE_FILE" ]; then
    _init_state
    return 0
  fi
  if ! _validate_state; then
    echo "ERROR: $STATE_FILE is malformed. Run: bash lib/circuit_breaker.sh reset" >&2
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Subcommand: check
# ---------------------------------------------------------------------------

_check() {
  _ensure_state || return 1
  local state
  state="$(_get_field "state")"
  if [ "$state" = "OPEN" ]; then
    local no_progress error_count last_fp
    no_progress="$(_get_field "no_progress")"
    error_count="$(_get_field "error_count")"
    last_fp="$(_get_field "last_error_fingerprint")"
    echo "Circuit breaker is OPEN — autopilot halted."
    if [ "$no_progress" -ge 3 ] 2>/dev/null; then
      echo "Trip reason: no_progress threshold reached (no_progress=${no_progress})"
    fi
    if [ -n "$last_fp" ] && [ "$error_count" -ge 5 ] 2>/dev/null; then
      echo "Trip reason: repeated error fingerprint (last_error_fingerprint=${last_fp}, error_count=${error_count})"
    fi
    echo "To reset: bash lib/circuit_breaker.sh reset"
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Subcommand: record_progress
# ---------------------------------------------------------------------------

_record_progress() {
  _ensure_state || return 1
  local state
  state="$(_get_field "state")"
  if [ "$state" = "OPEN" ]; then
    # OPEN is sticky — no change
    return 0
  fi
  _write_state "CLOSED" "0" "0" ""
  return 0
}

# ---------------------------------------------------------------------------
# Subcommand: record_no_progress
# ---------------------------------------------------------------------------

_record_no_progress() {
  _ensure_state || return 1
  local state no_progress
  state="$(_get_field "state")"
  no_progress="$(_get_field "no_progress")"

  if [ "$state" = "OPEN" ]; then
    # Already OPEN — idempotent, cap at 3
    return 0
  fi

  no_progress=$((no_progress + 1))
  if [ "$no_progress" -ge 3 ]; then
    no_progress=3
    _write_state "OPEN" "$no_progress" "0" ""
  elif [ "$no_progress" -eq 2 ]; then
    _write_state "HALF_OPEN" "$no_progress" "0" ""
  else
    _write_state "CLOSED" "$no_progress" "0" ""
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Subcommand: record_error
# ---------------------------------------------------------------------------

_record_error() {
  local fp="$1"
  # Validate fingerprint: only [a-zA-Z0-9_-] allowed
  if ! echo "$fp" | grep -qE '^[a-zA-Z0-9_-]+$'; then
    echo "ERROR: Invalid fingerprint '$fp'. Only [a-zA-Z0-9_-] characters are allowed." >&2
    return 1
  fi

  _ensure_state || return 1
  local state error_count last_fp
  state="$(_get_field "state")"
  error_count="$(_get_field "error_count")"
  last_fp="$(_get_field "last_error_fingerprint")"

  if [ "$state" = "OPEN" ]; then
    # Already OPEN — no-op
    return 0
  fi

  if [ "$fp" = "$last_fp" ]; then
    error_count=$((error_count + 1))
  else
    error_count=1
    last_fp="$fp"
  fi

  if [ "$error_count" -ge 5 ]; then
    error_count=5
    _write_state "OPEN" "0" "$error_count" "$last_fp"
  else
    _write_state "$state" "0" "$error_count" "$last_fp"
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Subcommand: reset
# ---------------------------------------------------------------------------

_reset() {
  _init_state
  return 0
}

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------

_usage() {
  echo "Usage: bash lib/circuit_breaker.sh <subcommand> [args]" >&2
  echo "" >&2
  echo "Valid subcommands:" >&2
  echo "  check                 — Exit 0 if CLOSED/HALF_OPEN, non-zero if OPEN" >&2
  echo "  record_progress       — Signal progress; resets counters (sticky in OPEN)" >&2
  echo "  record_no_progress    — Signal no progress; CLOSED→HALF_OPEN→OPEN at 3" >&2
  echo "  record_error <fp>     — Signal error with fingerprint; OPEN at 5 consecutive" >&2
  echo "  reset                 — Manually reset state to CLOSED" >&2
}

# ---------------------------------------------------------------------------
# Dispatcher
# ---------------------------------------------------------------------------

SUBCOMMAND="${1:-}"

case "$SUBCOMMAND" in
  check)
    _check; exit $?
    ;;
  record_progress)
    _record_progress; exit $?
    ;;
  record_no_progress)
    _record_no_progress; exit $?
    ;;
  record_error)
    if [ $# -lt 2 ]; then
      echo "ERROR: record_error requires a fingerprint argument." >&2
      _usage
      exit 1
    fi
    _record_error "$2"; exit $?
    ;;
  reset)
    _reset; exit $?
    ;;
  *)
    _usage
    exit 1
    ;;
esac
