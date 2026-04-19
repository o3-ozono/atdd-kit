#!/usr/bin/env bash
# scenario_loader.sh -- Validate and echo a headless skill-chain scenario spec (JSON)
# Issue #72 / AC4 (schema), AC5 (infra exit on schema violation)
#
# Usage:
#   bash lib/scenario_loader.sh <scenario.json>
#
# Behavior:
#   - Parses the scenario JSON and validates its schema.
#   - On success: exit 0, echoes the pretty-printed JSON to stdout (normalized).
#   - On schema violation or malformed JSON: exit 3 (infra) with a diagnostic.
#
# Schema:
#   {
#     "version": 1,
#     "name": "<string>",
#     "prompt": "<string>",
#     "expected_skills": ["<skill-id>", ...],
#     "forbidden_skills": ["<skill-id>", ...] (optional, default []),
#     "match_mode": "subsequence" | "strict",
#     "timeout": <number seconds> (optional, default 1800),
#     "model": "<string>" (optional),
#     "fixture": "<path>" (optional — present when the scenario has a committed replay fixture)
#   }

set -euo pipefail

usage() {
  echo "Usage: bash lib/scenario_loader.sh <scenario.json>" >&2
}

if [ $# -lt 1 ]; then
  usage
  exit 3
fi

SPEC="$1"

if [ ! -f "$SPEC" ]; then
  echo "ERROR: infra — scenario file not found: $SPEC" >&2
  exit 3
fi

if ! jq -e . "$SPEC" > /dev/null 2>&1; then
  echo "ERROR: infra — scenario JSON is malformed: $SPEC" >&2
  exit 3
fi

ERRORS=$(jq -r '
  def require($field; $type):
    if has($field) | not then "missing field: \($field)"
    elif (.[$field] | type) != $type then "field \($field) must be \($type), got \(.[$field] | type)"
    else empty end;

  def check_array_of_strings($field):
    if has($field) and (.[$field] | type) == "array"
    then
      .[$field]
      | to_entries[]
      | select(.value | type != "string")
      | "\($field)[\(.key)] must be string, got \(.value | type)"
    else empty end;

  require("version"; "number"),
  require("name"; "string"),
  require("prompt"; "string"),
  require("expected_skills"; "array"),
  require("match_mode"; "string"),

  check_array_of_strings("expected_skills"),
  (if has("forbidden_skills") then require("forbidden_skills"; "array") else empty end),
  check_array_of_strings("forbidden_skills"),

  (if has("match_mode") and (.match_mode | type) == "string"
     and (.match_mode != "subsequence" and .match_mode != "strict")
   then "match_mode must be one of: subsequence, strict (got: \(.match_mode))"
   else empty end),

  (if has("timeout") and (.timeout | type) != "number"
   then "timeout must be a number"
   else empty end),

  (if has("fixture") and (.fixture | type) != "string"
   then "fixture must be a string path"
   else empty end)
' "$SPEC")

if [ -n "$ERRORS" ]; then
  echo "ERROR: infra — scenario schema violation in $SPEC:" >&2
  echo "$ERRORS" | sed 's/^/  - /' >&2
  exit 3
fi

# Emit the normalized (with defaults filled in) scenario to stdout.
jq '{
  version: .version,
  name: .name,
  prompt: .prompt,
  expected_skills: .expected_skills,
  forbidden_skills: (.forbidden_skills // []),
  match_mode: .match_mode,
  timeout: (.timeout // 1800),
  model: (.model // null),
  fixture: (.fixture // null)
}' "$SPEC"
