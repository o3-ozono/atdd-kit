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
#   record_iteration <jsonl> <it> <step> <verdict> <fp>   append one JSONL audit line (AL-4) with timestamp
#   record_halt <jsonl> <step> <reason> <findings_digest>  append one terminating HALT record to JSONL (convergence-failure halts only — #299)
#   check_sameness <jsonl> [step]            non-zero if the last 2 FAIL iterations share a fingerprint (step-scoped when step given; FAIL rows only — #277)
#   check_stuck <jsonl> <window> [step]      non-zero if the last <window> FAIL iterations show no progress (step-scoped when step given; FAIL rows only — #277)
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
  local ts; ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '{"iteration":%s,"step":"%s","verdict":"%s","fingerprint":"%s","timestamp":"%s"}\n' \
    "$iteration" "$(_json_escape "$step")" "$(_json_escape "$verdict")" "$fp" "$ts" >> "$jsonl"
}

# Append one terminating HALT record to the JSONL audit log (#299).
# Convergence-failure halts only — record-error / rails-error / freeze-error /
# anchor-pin-failed return without a HALT record (they are not convergence failures).
# Invariant: this HALT line is the last write of the current run, appended AFTER the
# rails check (check_log_integrity included) and BEFORE return. The orchestrator MUST
# NOT increment `recorded` for this line and MUST NOT re-run check_log_integrity
# afterwards — the integrity check was already satisfied before this append, and the
# next freeze re-entry will absorb the HALT line as a baseline (#262 baseline absorption).
#
# findings_digest must be a pre-formatted JSON array value (e.g. '[{"priority":1,"evidence_ref":"..."}]');
# record_halt embeds it verbatim (%s, no _json_escape) so it becomes a nested JSON array,
# not an escaped JSON string scalar. step / reason are scalar strings and ARE _json_escape'd.
record_halt() {
  local jsonl="$1" step="$2" reason="$3" findings_digest="${4:-[]}"
  [ -n "$jsonl" ] || { echo "autopilot_convergence: record_halt: jsonl path required" >&2; return 2; }
  # reason is restricted to the convergence-failure enum; out-of-range values are refused
  # so an incorrect HALT record is never written (invariant enforcement).
  # #355 (F2): gate-unverifiable added for early escalation when the gate mechanism itself
  # cannot self-verify (demonstrably-done but mechanism unconfirmable), distinct from
  # MAX_ITERATIONS (exhausted budget) or stuck (no progress).
  case "$reason" in
    MAX_ITERATIONS|sameness-detector|stuck|ac-drift|log-integrity|gate-unverifiable) ;;
    *)
      echo "autopilot_convergence: record_halt: invalid reason '$reason' (must be one of MAX_ITERATIONS / sameness-detector / stuck / ac-drift / log-integrity / gate-unverifiable)" >&2
      return 2
      ;;
  esac
  local ts; ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '{"outcome":"HALT","step":"%s","reason":"%s","findings_digest":%s,"timestamp":"%s"}\n' \
    "$(_json_escape "$step")" "$(_json_escape "$reason")" "$findings_digest" "$ts" >> "$jsonl"
}

# Echo the fingerprint column from the JSONL log, in order, one per line.
# Optional second argument `step`: when non-empty, restrict to rows whose
# "step" field matches that value exactly (fixed-string match on the escaped
# JSON representation). This prevents cross-step fingerprint leakage that
# causes false sameness halts (#272, #269 incident).
# Step is already _json_escape'd by record_iteration, so a fixed-string match
# on the literal value is correct for all well-formed step names.
#
# FAIL-only filter (#277): 比較母集団は同一 step かつ verdict=FAIL の行のみ。
# PASS 行は「失敗の繰り返し」の証拠にならないため除外する。空 blocking findings の
# イテレーションはすべて同一 fingerprint になるため、PASS 行を含めると設計ゲート
# 差し戻し再入などのシナリオで check_sameness / check_stuck が偽停止する（#277）。
# この FAIL-only フィルタは step 引数の有無にかかわらず全モードで適用する（Gate ①）。
#
# Corruption guard (#248, AL-4 completeness): every candidate FAIL row MUST yield
# exactly one well-formed fingerprint (non-empty, restricted to record_iteration's
# charset [A-Za-z0-9._:-]). The old `grep -o` SILENTLY DROPPED a row whose
# fingerprint was partial-written / externally corrupted, erasing a data point
# from the stuck/sameness population — a fail-OPEN memory loss. Now the candidate
# rows are counted first; if line-count != well-formed-fingerprint-count the log
# is corrupt and the function returns non-zero (3) so the rails escalate (halt)
# instead of going dark. check_sameness / check_stuck propagate that code.
_fingerprints() {
  local jsonl="$1" step="${2:-}" lines nlines fps nfps
  [ -f "$jsonl" ] || return 0
  # Collect the candidate population: verdict=FAIL rows (#277), optionally scoped
  # to a single step (#272). step is _json_escape'd by record_iteration, so a
  # fixed-string match (grep -F) on the escaped literal is correct.
  if [ -n "$step" ]; then
    local escaped_step
    escaped_step=$(_json_escape "$step")
    lines=$(grep -F "\"step\":\"${escaped_step}\"" "$jsonl" | grep -F '"verdict":"FAIL"')
  else
    lines=$(grep -F '"verdict":"FAIL"' "$jsonl")
  fi
  [ -z "$lines" ] && return 0
  nlines=$(printf '%s\n' "$lines" | grep -c .)
  # A non-empty, charset-restricted fingerprint value only — an empty
  # ("fingerprint":"") or out-of-charset value is corruption, not a data point.
  fps=$(printf '%s\n' "$lines" | grep -o '"fingerprint":"[A-Za-z0-9._:-][A-Za-z0-9._:-]*"' | sed 's/"fingerprint":"//; s/"$//')
  nfps=$(printf '%s\n' "$fps" | grep -c .)
  if [ "$nlines" -ne "$nfps" ]; then
    echo "autopilot_convergence: audit log corruption — $nlines FAIL row(s) but $nfps well-formed fingerprint(s): '$jsonl'" >&2
    return 3
  fi
  printf '%s\n' "$fps"
}

# sameness-detector: halt (non-zero) when the last two iterations carry the
# same fingerprint — the loop is repeating the identical failure.
# 比較母集団は FAIL 行のみ。PASS 行は失敗反復の証拠にならないため除外する (#277)。
# PASS を挟んだ同一 fingerprint の FAIL 再発（FAIL→PASS→FAIL）は「同じ失敗の繰り返し」
# として halt する — これは意図された挙動（#277 AT-006 意味論 pin）。
# Optional second argument `step`: when non-empty, only the rows for that step
# are compared, preventing cross-phase fingerprint coincidence from halting the
# loop (#272 / #269 incident). Omitting step preserves the legacy whole-log
# behavior (backward-compatible); FAIL-only applies to both modes (#277 Gate ①).
check_sameness() {
  local jsonl="$1" step="${2:-}" fps n last prev rc
  fps=$(_fingerprints "$jsonl" "$step"); rc=$?
  # #248: a corrupt log (non-zero from _fingerprints) is a halt, not a continue.
  [ "$rc" -ne 0 ] && return "$rc"
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
# window 母集団は同一 step の FAIL 行のみ。PASS 行は進捗の証拠にならないため除外する (#277)。
# Optional third argument `step`: when non-empty, only the rows for that step
# are included in the window population (#272 / #269 incident fix). Omitting
# step preserves the legacy whole-log behavior (backward-compatible);
# FAIL-only applies to both modes (#277 Gate ①).
check_stuck() {
  local jsonl="$1" window="${2:-3}" step="${3:-}" fps n tail_fps count distinct rc
  # A non-numeric window would make the integer test / tail error out yet still
  # return 0 (fail-OPEN, silently disabling the rail). Validate → halt instead.
  case "$window" in
    '' | *[!0-9]*)
      echo "autopilot_convergence: invalid window: '$window'" >&2
      return 2
      ;;
  esac
  fps=$(_fingerprints "$jsonl" "$step"); rc=$?
  # #248: a corrupt log (non-zero from _fingerprints) is a halt, not a continue.
  [ "$rc" -ne 0 ] && return "$rc"
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

# #334 red evidence — record that a test commit was observed RED (non-zero exit) before
# implementation. This is the symmetric counterpart to AL-3's green gate: the green gate
# verifies the AT passes after implementation; the red gate verifies the AT failed before it.
#
# record_red_evidence <red-jsonl> <test-commit-sha> <at-file> [impl-baseline-sha]
#   Append one JSONL line recording that <at-file> was observed RED at <test-commit-sha>.
#   #355 (F8): the optional 4th argument <impl-baseline-sha> records the impl baseline SHA
#   (the HEAD at red-observation time, before any impl commits) directly in the JSONL line,
#   so check_red_evidence can read it from the record instead of reconstructing via git log.
#   Validates inputs with the same fail-closed rules as record_iteration:
#   - commit sha must be non-empty and JSON-safe (no quotes / backslashes / newlines)
#   - impl_sha (when supplied) undergoes the same charset validation
#   - at-file is _json_escape'd to allow path separators and dots
#   Returns non-zero on any invalid input and writes nothing.
record_red_evidence() {
  local red_jsonl="$1" commit_sha="$2" at_file="$3" impl_sha="${4:-}"
  [ -n "$red_jsonl" ] || { echo "autopilot_convergence: record_red_evidence: jsonl path required" >&2; return 2; }
  # commit sha must be non-empty and safe (git SHAs are hex, but allow the same charset as fingerprint)
  case "$commit_sha" in
    '' | *[!A-Za-z0-9._:-]*)
      echo "autopilot_convergence: record_red_evidence: invalid commit sha: '$commit_sha'" >&2
      return 2
      ;;
  esac
  [ -n "$at_file" ] || { echo "autopilot_convergence: record_red_evidence: at-file required" >&2; return 2; }
  # validate impl_sha when supplied (same charset as commit_sha)
  if [ -n "$impl_sha" ]; then
    case "$impl_sha" in
      *[!A-Za-z0-9._:-]*)
        echo "autopilot_convergence: record_red_evidence: invalid impl sha: '$impl_sha'" >&2
        return 2
        ;;
    esac
  fi
  local ts; ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  if [ -n "$impl_sha" ]; then
    printf '{"step":"red","commit":"%s","impl_sha":"%s","at_file":"%s","timestamp":"%s"}\n' \
      "$(_json_escape "$commit_sha")" "$(_json_escape "$impl_sha")" "$(_json_escape "$at_file")" "$ts" >> "$red_jsonl"
  else
    printf '{"step":"red","commit":"%s","at_file":"%s","timestamp":"%s"}\n' \
      "$(_json_escape "$commit_sha")" "$(_json_escape "$at_file")" "$ts" >> "$red_jsonl"
  fi
}

# #334 red evidence check — verify that red evidence exists for the given test commit.
# This is a deterministic gate (exit code only, no LLM opinion) symmetric to AL-3 green gate.
# Implements design-doc Decision 1 Case C: commit separation AND red-exit record (both required).
#
# check_red_evidence <test-commit-sha> <impl-commit-sha> <red-jsonl> [git-dir]
#   Returns 0 (redObserved=true) iff ALL of:
#     1. both test-commit and impl-commit are non-empty
#     2. red-jsonl exists and has at least one record for test-commit-sha (red-exit record)
#     3. test-commit is a strict ancestor of impl-commit in git history
#        (git merge-base --is-ancestor test_sha impl_sha) — commit separation anchor
#   Returns non-zero (fail-closed) on:
#     - empty test-commit or impl-commit
#     - no red evidence for test-commit-sha (AT was never observed failing)
#     - missing red-jsonl (no evidence file)
#     - test-commit is NOT an ancestor of impl-commit (impl preceded test in history)
#     - git ancestry check fails (e.g. unknown SHAs, not a git repo)
#   [git-dir] defaults to "." (current working directory); pass an explicit path in tests.
check_red_evidence() {
  local test_sha="$1" impl_sha="$2" red_jsonl="$3" git_dir="${4:-.}"
  # Both SHAs must be non-empty and JSON-safe (symmetric with record_red_evidence case validation)
  case "$test_sha" in
    '' | *[!A-Za-z0-9._:-]*)
      echo "autopilot_convergence: check_red_evidence: invalid commit sha: '$test_sha'" >&2
      return 2
      ;;
  esac
  case "$impl_sha" in
    '' | *[!A-Za-z0-9._:-]*)
      echo "autopilot_convergence: check_red_evidence: invalid commit sha: '$impl_sha'" >&2
      return 2
      ;;
  esac
  # The red-jsonl must exist (evidence must have been recorded before this check)
  [ -f "$red_jsonl" ] || { echo "autopilot_convergence: check_red_evidence: red evidence file not found: '$red_jsonl'" >&2; return 1; }
  # There must be at least one record for the test commit sha (red-exit evidence)
  if ! grep -qF "\"commit\":\"${test_sha}\"" "$red_jsonl"; then
    echo "autopilot_convergence: check_red_evidence: no red evidence found for commit '$test_sha'" >&2
    return 1
  fi
  # Commit separation: test_sha must be a strict ancestor of impl_sha (test preceded impl in history).
  # This is the hard-to-forge temporal anchor (design-doc Decision 1 Case C) that prevents
  # post-hoc log injection — git history is an immutable, external record that the LLM cannot alter.
  if ! git -C "$git_dir" merge-base --is-ancestor "$test_sha" "$impl_sha" 2>/dev/null; then
    echo "autopilot_convergence: check_red_evidence: test commit '$test_sha' is not an ancestor of impl commit '$impl_sha' (commit order violation or unknown sha)" >&2
    return 1
  fi
  return 0
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
