#!/usr/bin/env bash
# skill_transcript_parser.sh -- Extract Skill tool_use events from a stream-json transcript
# Issue #72 / AC3
#
# Usage:
#   bash lib/skill_transcript_parser.sh <transcript.jsonl>
#
# Behavior:
#   - Reads a Claude Code `--output-format stream-json` transcript (newline-delimited JSON)
#   - Emits a JSON array of { name, args, order } for each Skill tool_use
#   - order is 1-based, reflecting chronological appearance in the transcript
#   - Filters out tool_use entries spawned by sub-agents (parent_tool_use_id != null)
#   - Only considers tool_use entries where name == "Skill"
#
# Exit codes:
#   0 — success (valid transcript, array printed to stdout; empty array is still success)
#   1 — usage error (missing argument, unreadable file)
#   2 — parse_error (malformed JSON line, schema violation, non-UTF-8, missing required field)
#
# Error messages include a `line <N>:` reference when the offending line can be identified.
#
# Design: pure bash + jq (>= 1.6). No other runtime dependencies.

set -euo pipefail

usage() {
  echo "Usage: bash lib/skill_transcript_parser.sh <transcript.jsonl>" >&2
  echo "" >&2
  echo "Reads newline-delimited stream-json and emits Skill tool_use events as a JSON array." >&2
}

if [ $# -lt 1 ]; then
  usage
  exit 1
fi

INPUT="$1"

if [ ! -f "$INPUT" ]; then
  echo "ERROR: input file not found: $INPUT" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Step 1: UTF-8 validation
# ---------------------------------------------------------------------------
# `iconv` is POSIX/present on macOS + Ubuntu runners. Use it to detect non-UTF-8.
if ! iconv -f UTF-8 -t UTF-8 "$INPUT" > /dev/null 2>&1; then
  echo "ERROR: parse_error — input is not valid UTF-8: $INPUT" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Step 2: Per-line JSON well-formedness check
# ---------------------------------------------------------------------------
# `jq empty` fails the whole invocation on the first malformed line — but we
# want a line-numbered error, so walk line-by-line.
lineno=0
while IFS= read -r line || [ -n "$line" ]; do
  lineno=$((lineno + 1))
  # Skip empty lines (tolerate stream-json producers that emit them)
  if [ -z "$line" ]; then
    continue
  fi
  # Reject partial/truncated line: last line without trailing newline AND malformed
  if ! printf '%s' "$line" | jq -e . > /dev/null 2>&1; then
    echo "ERROR: parse_error — malformed JSON at line $lineno of $INPUT" >&2
    exit 2
  fi
done < "$INPUT"

# ---------------------------------------------------------------------------
# Step 3: Schema validation — every Skill tool_use must have input.skill (present and non-null)
# ---------------------------------------------------------------------------
# Distinction (AC1 / Issue #125):
#   - field ABSENT (key not in .input) → schema violation, exit 2
#   - field PRESENT but null           → schema violation, exit 2 (preserves existing behaviour)
#   - field PRESENT but "" / non-string → treat as non-skill entry (skip in Step 4), exit 0
# Using (.input.skill // null) == null catches both absent and null without requiring has().
schema_errors=$(jq -r -n --arg file "$INPUT" '
  [inputs
   | . as $line
   | (input_line_number) as $n
   | select(.type == "assistant")
   | select((.parent_tool_use_id // null) == null)
   | (.message.content // [])[]
   | select(.type == "tool_use" and .name == "Skill")
   | select((.input.skill // null) == null)
   | "line \($n): Skill tool_use missing input.skill"
  ] | .[]
' "$INPUT" 2>&1 || true)

if [ -n "$schema_errors" ]; then
  echo "ERROR: parse_error — schema violation in $INPUT:" >&2
  echo "$schema_errors" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Step 4: Extract Skill tool_use events
# ---------------------------------------------------------------------------
# Skip entries where input.skill is present but not a non-empty string
# (null, "", number, array, object → treated as non-skill, not emitted).
jq -c -n '
  [inputs
   | select(.type == "assistant")
   | select((.parent_tool_use_id // null) == null)
   | (.message.content // [])[]
   | select(.type == "tool_use" and .name == "Skill")
   | select((.input | has("skill")) and (.input.skill | type) == "string" and (.input.skill | length) > 0)
   | { name: .input.skill, args: (.input.args // null) }
  ]
  | to_entries
  | map({ name: .value.name, args: .value.args, order: (.key + 1) })
' "$INPUT"
