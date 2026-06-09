#!/usr/bin/env bash
# autopilot convergence safety rails (#246).
#
# Pure bash + coreutils (zero external dependencies). Sourced by the BATS
# suite and, conceptually, by the converging-deliverables orchestrator to
# bound the autonomous loop. A NON-ZERO return from a check_* function means
# "halt and escalate to a human" (autopilot Iron Law AL-5).
#
# Functions:
#   fingerprint                              stdin -> normalized sha256 of a failure signature
#   record_iteration <jsonl> <it> <step> <verdict> <fp>   append one JSONL audit line (AL-4)
#   check_sameness <jsonl>                   non-zero if the last 2 iterations share a fingerprint
#   check_stuck <jsonl> <window>             non-zero if the last <window> iterations show no progress
#   check_max_iterations <current> <max>     non-zero if current >= max
#
# Hardening (#246 review): record_iteration validates its inputs and refuses
# to write a corrupt or empty line. A missing hash tool, or a fingerprint that
# carries quotes / backslashes / newlines, would otherwise produce a malformed
# JSONL line (breaking the AL-4 audit log) or an empty fingerprint (silently
# disabling the sameness / stuck rails). record_iteration returns non-zero on
# any such input so the orchestrator escalates instead of looping blind.

# sha256 of stdin, portable across sha256sum (Linux) and shasum (macOS).
_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | cut -d' ' -f1
  else
    echo "autopilot_convergence: no sha256 tool found" >&2
    return 127
  fi
}

# Normalize whitespace, then hash: collapse every run of whitespace (incl.
# newlines) to a single space and trim, so cosmetic jitter in a failure
# message does not change the fingerprint.
fingerprint() {
  tr '[:space:]' ' ' | tr -s ' ' | sed 's/^ *//; s/ *$//' | _sha256
}

# JSON-escape a string body (no surrounding quotes): escape backslash and
# double-quote, and collapse control characters (newline / carriage-return /
# tab) to a space so a hostile or accidental value cannot break out of the
# JSON string or split the JSONL record across physical lines.
_json_escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | tr '\n\r\t' '   '
}

# Append one audit line to the JSONL log — the external source of truth for a
# fresh-context-per-iteration loop (AL-4). Validates inputs and refuses
# (non-zero) to write a malformed or rail-disabling line.
record_iteration() {
  local jsonl="$1" iteration="$2" step="$3" verdict="$4" fp="$5"
  # iteration must be a non-negative integer, else the JSON number is invalid.
  case "$iteration" in
    '' | *[!0-9]*)
      echo "autopilot_convergence: invalid iteration: '$iteration'" >&2
      return 2
      ;;
  esac
  # fingerprint must be non-empty and JSON-safe (no quotes / backslashes /
  # whitespace). fingerprint() always yields hex; an empty or unsafe value
  # here means a missing hash tool or a raw finding string leaked through —
  # refuse rather than write a line that disables the rails or forges keys.
  case "$fp" in
    '' | *[!A-Za-z0-9._:-]*)
      echo "autopilot_convergence: invalid fingerprint: '$fp'" >&2
      return 2
      ;;
  esac
  printf '{"iteration":%s,"step":"%s","verdict":"%s","fingerprint":"%s"}\n' \
    "$iteration" "$(_json_escape "$step")" "$(_json_escape "$verdict")" "$fp" >> "$jsonl"
}

# Echo the fingerprint column from the JSONL log, in order, one per line.
_fingerprints() {
  local jsonl="$1"
  [ -f "$jsonl" ] || return 0
  grep -o '"fingerprint":"[^"]*"' "$jsonl" | sed 's/"fingerprint":"//; s/"$//'
}

# sameness-detector: halt (non-zero) when the last two iterations carry the
# same fingerprint — the loop is repeating the identical failure.
check_sameness() {
  local jsonl="$1" fps n last prev
  fps=$(_fingerprints "$jsonl")
  [ -z "$fps" ] && return 0
  n=$(printf '%s\n' "$fps" | grep -c .)
  [ "$n" -lt 2 ] && return 0
  last=$(printf '%s\n' "$fps" | tail -n 1)
  prev=$(printf '%s\n' "$fps" | tail -n 2 | head -n 1)
  [ "$last" = "$prev" ] && return 1
  return 0
}

# stuck detection: halt (non-zero) when the last <window> iterations show no
# forward progress. "No progress" = the window revisits a prior state, i.e.
# any fingerprint repeats within the window (distinct < count). This catches
# both a flatline (A,A,A) AND an oscillation (A,B,A,B — fix-one / break-another),
# which the previous "collapse to a single distinct" rule missed and which
# check_sameness (last-two only) also misses.
check_stuck() {
  local jsonl="$1" window="${2:-3}" fps n tail_fps count distinct
  fps=$(_fingerprints "$jsonl")
  [ -z "$fps" ] && return 0
  n=$(printf '%s\n' "$fps" | grep -c .)
  [ "$n" -lt "$window" ] && return 0
  tail_fps=$(printf '%s\n' "$fps" | tail -n "$window")
  count=$(printf '%s\n' "$tail_fps" | grep -c .)
  distinct=$(printf '%s\n' "$tail_fps" | sort -u | grep -c .)
  [ "$distinct" -lt "$count" ] && return 1
  return 0
}

# max-iterations: halt (non-zero) when the current count reaches the ceiling.
check_max_iterations() {
  local current="$1" max="$2"
  [ "$current" -lt "$max" ]
}
