#!/usr/bin/env bash
# hooks/bash-output-normalizer.sh
#
# Bash PostToolUse hook: normalize Bash tool output to reduce token consumption.
#
# Processing pipeline (order matters):
#   1. JSON minify   -- if stdin is valid JSON, compact it (key order preserved)
#   2. Blank line collapse -- 3+ consecutive blank lines -> 2
#   3. Trailing whitespace -- remove trailing spaces/tabs from each line
#
# AC5 (fail-safe): any error exits 0 and passes original input through.
# This hook MUST NOT block tool output delivery to the agent.

# Read all of stdin
input=$(cat)

# Run full normalization pipeline via python3
# Using -c with escaped heredoc to avoid bash heredoc conflicts
normalized=$(printf '%s' "$input" | python3 -c "
import sys, json

# Read as bytes first, then decode with error replacement to handle non-UTF-8 input.
# Note: null bytes are stripped by bash variable semantics before we get here.
text = sys.stdin.buffer.read().decode('utf-8', errors='replace')

# Step 1: JSON minify (try-parse; fallback to original on failure)
try:
    obj = json.loads(text)
    # Minify: no indent, no extra spaces
    text = json.dumps(obj, separators=(',', ':'), ensure_ascii=False)
    # JSON is now on one line, steps 2+3 are vacuous but harmless
except (json.JSONDecodeError, ValueError):
    pass  # Not valid JSON, continue with original text

# Step 2: Collapse 3+ consecutive blank lines to 2
# Step 3: Remove trailing whitespace from each line
lines = text.split('\n')
result = []
blank_count = 0
for line in lines:
    stripped = line.rstrip()  # Step 3: trailing whitespace
    if stripped == '':
        blank_count += 1
        if blank_count <= 2:
            result.append(stripped)
    else:
        blank_count = 0
        result.append(stripped)

print('\n'.join(result), end='')
") || {
    # python3 failed entirely (not installed, crash, etc.) -- pass through original
    printf '%s' "$input"
    exit 0
}

printf '%s' "$normalized"
exit 0
