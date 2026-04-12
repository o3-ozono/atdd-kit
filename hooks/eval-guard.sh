#!/usr/bin/env bash
set -euo pipefail

# eval-guard.sh — PreToolUse hook that blocks git push when skills changed without eval
#
# Blocks git push if:
#   1. Any skills/*/SKILL.md was modified on this branch (vs origin/main)
#   2. No eval evidence marker exists for this branch
#
# Eval evidence is created by auto-eval command:
#   $XDG_CACHE_HOME/atdd-kit/eval-ran-<branch-name>

# --- Read hook input ---
INPUT=$(cat)

# Extract the command from Bash tool input
COMMAND=$(echo "$INPUT" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\(.*\)".*/\1/p' | head -1)

# Only intercept git push commands
if ! echo "$COMMAND" | grep -qE '(^|&&|;|\|\|)\s*git\s+push\b'; then
  echo '{}'
  exit 0
fi

# --- Check for skill changes ---
BRANCH=$(git branch --show-current 2>/dev/null || echo "")
if [ -z "$BRANCH" ] || [ "$BRANCH" = "main" ]; then
  # On main or detached HEAD — allow push
  echo '{}'
  exit 0
fi

# Get changed SKILL.md files compared to origin/main
CHANGED_SKILLS=$(git diff --name-only origin/main...HEAD -- 'skills/*/SKILL.md' 2>/dev/null || echo "")

if [ -z "$CHANGED_SKILLS" ]; then
  # No skill changes — allow push
  echo '{}'
  exit 0
fi

# --- Check for eval evidence ---
SAFE_BRANCH=$(echo "$BRANCH" | tr '/' '-')
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/atdd-kit"
MARKER="${CACHE_DIR}/eval-ran-${SAFE_BRANCH}"

if [ -f "$MARKER" ]; then
  # Eval was run — allow push
  echo '{}'
  exit 0
fi

# --- Block push ---
SKILL_LIST=$(echo "$CHANGED_SKILLS" | sed 's|skills/\(.*\)/SKILL.md|\1|' | tr '\n' ', ' | sed 's/,$//')

REASON="SKILL.md changes detected (${SKILL_LIST}) but no eval evidence found. Run /atdd-kit:auto-eval before pushing."

escape_for_json() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  printf '%s' "$s"
}

ESCAPED_REASON=$(escape_for_json "$REASON")

cat <<ENDJSON
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "${ESCAPED_REASON}"
  }
}
ENDJSON
