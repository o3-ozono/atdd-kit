#!/usr/bin/env bash
# autopilot convergence safety rails (#246).
#
# Pure bash + coreutils (zero external dependencies). Sourced by the BATS
# suite and, conceptually, by the autopilot orchestrator to
# bound the autonomous loop. A NON-ZERO return from a check_* function means
# "halt and escalate to a human" (autopilot Iron Law AL-5).
#
# Functions:
#   fingerprint                              stdin -> normalized sha256 of a failure signature
#   record_iteration <jsonl> <it> <step> <verdict> <fp>   append one JSONL audit line (AL-4)
#   check_sameness <jsonl>                   non-zero if the last 2 iterations share a fingerprint
#   check_stuck <jsonl> <window>             non-zero if the last <window> iterations show no progress
#   check_max_iterations <current> <max>     non-zero if current >= max
#   pin_anchor <pinfile>                     pin the approved-AC fingerprint once at loop start (AL-2)
#   check_pin <pinfile> <current-fp>         non-zero if the AC anchor drifted from the pin (AL-2)
#   check_log_integrity <jsonl> <expected-lines>   non-zero if the audit log was deleted / rolled back mid-run (#262)
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
# message does not change the fingerprint. LC_ALL=C makes the byte pipeline
# locale-independent: under a UTF-8 locale `tr` aborts on invalid bytes and
# would silently emit the empty-string hash (false sameness / nondeterminism).
fingerprint() {
  LC_ALL=C tr '[:space:]' ' ' | LC_ALL=C tr -s ' ' | LC_ALL=C sed 's/^ *//; s/ *$//' | _sha256
}

# JSON-escape a string body (no surrounding quotes): escape backslash and
# double-quote, then collapse EVERY C0 control character (0x00-0x1f, incl.
# newline / CR / tab / form-feed / ESC / NUL) to a space. RFC 8259 forbids raw
# control characters inside a JSON string, so a hostile or accidental value
# cannot break out of the string, split the JSONL record, or write a line a
# strict parser rejects.
_json_escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | LC_ALL=C tr '[:cntrl:]' ' '
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
  # Normalize via base-10 so a leading-zero value ("007") becomes a valid JSON
  # number (7) rather than the invalid literal `007` a strict parser rejects.
  iteration=$((10#$iteration))
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
  # A non-numeric window would make the integer test / tail error out yet still
  # return 0 (fail-OPEN, silently disabling the rail). Validate → halt instead.
  case "$window" in
    '' | *[!0-9]*)
      echo "autopilot_convergence: invalid window: '$window'" >&2
      return 2
      ;;
  esac
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
# Both args are validated as integers: an empty `current` would otherwise be
# coerced to 0 by test(1) and continue forever (fail-OPEN on the budget rail).
check_max_iterations() {
  local current="$1" max="$2"
  case "$current" in '' | *[!0-9]*) echo "autopilot_convergence: invalid current: '$current'" >&2; return 2 ;; esac
  case "$max" in '' | *[!0-9]*) echo "autopilot_convergence: invalid max: '$max'" >&2; return 2 ;; esac
  [ "$current" -lt "$max" ]
}

# #262 audit-log continuity guard — the orchestrator tracks the EXPECTED line
# count in process memory (freeze baseline + one per successful record_iteration)
# and passes it here every rails check. check_sameness / check_stuck read their
# history from the JSONL, so a deleted / truncated log silently resets them
# (fail-OPEN); this guard demands an EXACT match (actual == expected) — the
# orchestrator is the only legitimate writer, so a shortfall (deletion /
# rollback) AND an excess (external append) both halt (fail-closed, #256).
check_log_integrity() {
  local jsonl="$1" expected="$2" actual
  # An empty / non-numeric expected would silently disable the rail (fail-OPEN)
  # or eval an injected string. Validate → halt, like check_stuck's window.
  case "$expected" in
    '' | *[!0-9]*)
      echo "autopilot_convergence: invalid expected-lines: '$expected'" >&2
      return 2
      ;;
  esac
  expected=$((10#$expected))
  if [ ! -f "$jsonl" ]; then
    # Missing log is legitimate ONLY before anything was recorded (first run).
    [ "$expected" -eq 0 ] && return 0
    echo "autopilot_convergence: audit log missing but $expected line(s) were recorded: '$jsonl'" >&2
    return 1
  fi
  actual=$(grep -c . "$jsonl")
  if [ "$actual" -ne "$expected" ]; then
    echo "autopilot_convergence: audit log has $actual line(s), expected $expected: '$jsonl'" >&2
    return 1
  fi
  return 0
}

# AL-2 immutable-AC anchor — pin the fingerprint of the human-approved AC
# (read from stdin) ONCE at loop start. Refuses to overwrite an existing pin so
# the anchor is frozen for the whole run; the loop can never re-baseline the AC
# it grades itself against.
pin_anchor() {
  local pinfile="$1" fp
  [ -n "$pinfile" ] || { echo "autopilot_convergence: pin_anchor needs a pinfile" >&2; return 2; }
  [ -f "$pinfile" ] && { echo "autopilot_convergence: AC pin already exists: '$pinfile'" >&2; return 2; }
  fp=$(fingerprint) || return $?
  case "$fp" in '' | *[!A-Za-z0-9._:-]*) echo "autopilot_convergence: invalid AC fingerprint" >&2; return 2 ;; esac
  printf '%s\n' "$fp" > "$pinfile"
}

# AL-2 drift check — compare the CURRENT approved-AC fingerprint against the pin.
# Non-zero (halt) when the anchor drifted, the pin is missing, or the current
# fingerprint is empty/unsafe — autopilot must never edit its own frozen AC.
check_pin() {
  local pinfile="$1" current="$2" pinned
  [ -f "$pinfile" ] || { echo "autopilot_convergence: missing AC pin: '$pinfile'" >&2; return 2; }
  case "$current" in '' | *[!A-Za-z0-9._:-]*) echo "autopilot_convergence: invalid current AC fp: '$current'" >&2; return 2 ;; esac
  pinned=$(cat "$pinfile")
  [ "$pinned" = "$current" ] || return 1
  return 0
}
