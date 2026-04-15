#!/usr/bin/env bats

# Staleness detection tests for SKILL.md files
# These tests detect stale references that should be caught before they reach users.
#
# Maintenance: When adding new skills, tools, or files, update the allowlists in setup().

setup() {
  ALL_SKILLS=(atdd bug debugging discover ideate issue plan session-start ship sim-pool skill-gate ui-test-debugging verify)

  # Valid tool names that may appear in SKILL.md files.
  # Update this list when Claude Code adds or removes tools.
  TOOL_ALLOWLIST=(
    "Read" "Write" "Edit" "Grep" "Glob" "Bash"
    "Agent" "SendMessage" "TeamCreate"
    "Skill" "ToolSearch"
    "AskUserQuestion"
    "TaskCreate" "TaskUpdate" "TaskList" "TaskGet"
    "EnterWorktree" "ExitWorktree"
    "WebFetch" "WebSearch"
    "NotebookEdit"
  )
}

# --- (a) File reference existence check ---

@test "SKILL.md file references point to existing plugin files" {
  local fail=0
  for skill in "${ALL_SKILLS[@]}"; do
    local md="skills/${skill}/SKILL.md"
    [[ -f "$md" ]] || continue
    # Extract backtick-quoted paths that look like file references
    # Skip: template variables {{...}}, glob patterns *, output/project-side paths (.github/, .claude/)
    grep -oE '`[^`]+`' "$md" | tr -d '`' | while read -r ref; do
      # Skip non-path strings
      [[ "$ref" == *"/"* ]] || continue
      # Skip template variables
      [[ "$ref" == *"{{"* ]] && continue
      # Skip glob patterns
      [[ "$ref" == *"*"* ]] && continue
      # Skip project-side output paths (not in plugin)
      [[ "$ref" == .github/* ]] && continue
      [[ "$ref" == .claude/* ]] && continue
      # Skip command-like strings
      [[ "$ref" == git\ * ]] && continue
      [[ "$ref" == gh\ * ]] && continue
      # Skip relative paths starting with ./
      [[ "$ref" == ./* ]] && continue
      # Only check paths that look like plugin-internal references
      # (templates/, scripts/, skills/, docs/, addons/)
      case "$ref" in
        templates/*|scripts/*|skills/*|docs/*|addons/*)
          if [[ ! -e "$ref" ]]; then
            echo "STALE: $md references '$ref' but file does not exist" >&2
            fail=1
          fi
          ;;
      esac
    done
  done
  [[ "$fail" -eq 0 ]]
}

# --- (b) Tool name allowlist check ---

@test "SKILL.md tool references are in the allowlist" {
  local fail=0
  local allowlist_pattern
  allowlist_pattern=$(printf '%s\n' "${TOOL_ALLOWLIST[@]}" | sort -u | paste -sd '|' -)

  for skill in "${ALL_SKILLS[@]}"; do
    local md="skills/${skill}/SKILL.md"
    [[ -f "$md" ]] || continue
    # Find patterns like "Track ... with ToolName" or "Use ToolName" or "via the ToolName tool"
    # Also "ToolName tool"
    grep -oE '\b[A-Z][a-zA-Z]+ tool' "$md" | awk '{print $1}' | sort -u | while read -r tool; do
      if ! echo "$tool" | grep -qE "^(${allowlist_pattern})$"; then
        # Skip common false positives
        case "$tool" in
          "Skill"|"Bash"|"Read"|"Write"|"Edit"|"Template"|"Claude"|"Plugin"|"Merge"|"Setup"|"Auto") continue ;;
        esac
        echo "UNKNOWN TOOL: $md references tool '$tool' not in allowlist" >&2
        fail=1
      fi
    done
  done
  [[ "$fail" -eq 0 ]]
}

# --- (c) Skill cross-reference existence check ---

@test "atdd-kit skill references point to existing skill directories" {
  local fail=0
  for skill in "${ALL_SKILLS[@]}"; do
    local md="skills/${skill}/SKILL.md"
    [[ -f "$md" ]] || continue
    # Extract atdd-kit:skillname references
    grep -oE 'atdd-kit:[a-z][-a-z]*' "$md" | sort -u | while read -r ref; do
      local skill_name="${ref#atdd-kit:}"
      if [[ ! -d "skills/${skill_name}" ]]; then
        echo "STALE: $md references '${ref}' but skills/${skill_name}/ does not exist" >&2
        fail=1
      fi
    done
  done
  [[ "$fail" -eq 0 ]]
}

# --- (d) session-start sync table source file existence ---

@test "session-start sync table plugin source files exist" {
  local fail=0
  local md="skills/session-start/SKILL.md"
  [[ -f "$md" ]] || skip "SKILL.md not found"
  # Extract the Always-Sync table section and find plugin source paths
  sed -n '/Always-Sync\|Direct Copy/,/^####\|^---\|^##/p' "$md" | \
    grep -oE '`[^`]+`' | tr -d '`' | while read -r ref; do
      # Only check plugin-internal source paths (templates/, scripts/, addons/)
      case "$ref" in
        templates/*|scripts/*|addons/*)
          # Skip glob patterns
          [[ "$ref" == *"*"* ]] && continue
          if [[ ! -e "$ref" ]]; then
            echo "STALE: $md sync table references '$ref' but file does not exist" >&2
            fail=1
          fi
          ;;
      esac
    done
  [[ "$fail" -eq 0 ]]
}

# --- (e) No SKILL.ja.md files exist (English-only) ---

@test "no SKILL.ja.md files exist in any skill directory" {
  local fail=0
  for skill in "${ALL_SKILLS[@]}"; do
    if [[ -f "skills/${skill}/SKILL.ja.md" ]]; then
      echo "STALE: skills/${skill}/SKILL.ja.md should not exist (English-only)" >&2
      fail=1
    fi
  done
  [[ "$fail" -eq 0 ]]
}
