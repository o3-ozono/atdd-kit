#!/usr/bin/env bats
# @covers: agents/**
# Structural smoke test for 6 reviewer subagent definitions (Issue #186).
# Covers AC1-AC6 of #186.

# --- helpers ---

# Extract YAML frontmatter (between leading '---' delimiters).
_frontmatter() {
  awk '
    /^---[[:space:]]*$/ {
      n++
      if (n == 1) { in_fm = 1; next }
      if (n == 2) { exit }
    }
    in_fm { print }
  ' "$1"
}

# Read the value of a top-level YAML scalar field from frontmatter.
# Only handles simple "key: value" (quoted or unquoted), no nesting.
_yaml_field() {
  local file="$1" key="$2"
  _frontmatter "$file" | awk -v k="$key" '
    $0 ~ "^"k":[[:space:]]" {
      sub("^"k":[[:space:]]+", "")
      gsub(/^"|"$/, "")
      print
      exit
    }
  '
}

# List top-level keys in frontmatter (one per line).
_yaml_keys() {
  _frontmatter "$1" | awk '
    /^[a-zA-Z_][a-zA-Z0-9_-]*:/ {
      sub(":.*", "")
      print
    }
  '
}

# List entries of a top-level YAML list field (one per line, leading "- " stripped).
_yaml_list() {
  local file="$1" key="$2"
  _frontmatter "$file" | awk -v k="$key" '
    $0 ~ "^"k":[[:space:]]*$" { in_list = 1; next }
    in_list && /^[[:space:]]+-[[:space:]]/ {
      sub(/^[[:space:]]+-[[:space:]]+/, "")
      gsub(/^"|"$/, "")
      print
      next
    }
    in_list && /^[^[:space:]]/ { exit }
  ' "$file"
  # Note: the second arg to awk above is unused; kept for symmetry.
}

# Count top-level numbered list items (unindented "1." .. "N.") in body.
_count_numbered_criteria() {
  local file="$1"
  awk '
    /^---[[:space:]]*$/ { fm++; next }
    fm < 2 { next }
    /^[0-9]+\./ { c++ }
    END { print c+0 }
  ' "$file"
}

# Print numbered criteria lines (body only).
_numbered_criteria_lines() {
  local file="$1"
  awk '
    /^---[[:space:]]*$/ { fm++; next }
    fm < 2 { next }
    /^[0-9]+\./ { print }
  ' "$file"
}

# First non-empty body line after frontmatter.
_first_body_line() {
  local file="$1"
  awk '
    /^---[[:space:]]*$/ { fm++; next }
    fm < 2 { next }
    /[^[:space:]]/ { print; exit }
  ' "$file"
}

# Specialist reviewer file paths
SPECIALISTS=(
  agents/prd-reviewer.md
  agents/us-reviewer.md
  agents/plan-reviewer.md
  agents/code-reviewer.md
  agents/at-reviewer.md
)

ALL_REVIEWERS=(
  agents/prd-reviewer.md
  agents/us-reviewer.md
  agents/plan-reviewer.md
  agents/code-reviewer.md
  agents/at-reviewer.md
  agents/final-reviewer.md
)

# ============================================================
# AC1: 6 reviewer subagent files exist with valid frontmatter
# ============================================================

@test "AC1: all 6 reviewer subagent files exist and are non-empty" {
  for f in "${ALL_REVIEWERS[@]}"; do
    [[ -f "$f" ]] || { echo "missing: $f"; return 1; }
    [[ -s "$f" ]] || { echo "empty: $f"; return 1; }
  done
}

@test "AC1: each reviewer frontmatter contains exactly {name, description, tools}" {
  for f in "${ALL_REVIEWERS[@]}"; do
    keys=$(_yaml_keys "$f" | sort | tr '\n' ',' | sed 's/,$//')
    [[ "$keys" == "description,name,tools" ]] || {
      echo "FAIL $f: keys=[$keys] (expected description,name,tools)"
      return 1
    }
  done
}

@test "AC1: each reviewer tools list excludes Write, Edit, NotebookEdit" {
  for f in "${ALL_REVIEWERS[@]}"; do
    [[ -f "$f" ]] || { echo "missing: $f"; return 1; }
    fm=$(_frontmatter "$f")
    for forbidden in Write Edit NotebookEdit; do
      echo "$fm" | grep -Eq "^[[:space:]]+-[[:space:]]+${forbidden}[[:space:]]*\$" && {
        echo "FAIL $f: tools contains forbidden $forbidden"
        return 1
      }
    done
  done
  true
}

@test "AC1: each reviewer name field is non-empty" {
  for f in "${ALL_REVIEWERS[@]}"; do
    name=$(_yaml_field "$f" name)
    [[ -n "$name" ]] || { echo "FAIL $f: empty name"; return 1; }
  done
}

# ============================================================
# AC2: 5 specialist reviewers cover Issue-specified categories
# ============================================================

@test "AC2: prd-reviewer covers required categories" {
  [[ -f agents/prd-reviewer.md ]] || { echo "missing agents/prd-reviewer.md"; return 1; }
  for cat in "問題定義の明確性" "Audience" "Outcome 測定可能性" "Non-Goals" "Open Questions"; do
    grep -qi -- "$cat" agents/prd-reviewer.md || {
      echo "prd-reviewer missing category: $cat"
      return 1
    }
  done
}

@test "AC2: us-reviewer covers required categories" {
  [[ -f agents/us-reviewer.md ]] || { echo "missing agents/us-reviewer.md"; return 1; }
  for cat in "Connextra" "INVEST" "制約 Story" "persona traceability"; do
    grep -qi -- "$cat" agents/us-reviewer.md || {
      echo "us-reviewer missing category: $cat"
      return 1
    }
  done
}

@test "AC2: plan-reviewer covers required categories" {
  [[ -f agents/plan-reviewer.md ]] || { echo "missing agents/plan-reviewer.md"; return 1; }
  for cat in "2-5 分粒度" "verification" "依存関係"; do
    grep -qi -- "$cat" agents/plan-reviewer.md || {
      echo "plan-reviewer missing category: $cat"
      return 1
    }
  done
}

@test "AC2: code-reviewer covers required categories" {
  [[ -f agents/code-reviewer.md ]] || { echo "missing agents/code-reviewer.md"; return 1; }
  for cat in "Robot Pattern" "testplan 分離" "AT 対応"; do
    grep -qi -- "$cat" agents/code-reviewer.md || {
      echo "code-reviewer missing category: $cat"
      return 1
    }
  done
}

@test "AC2: at-reviewer covers required categories" {
  [[ -f agents/at-reviewer.md ]] || { echo "missing agents/at-reviewer.md"; return 1; }
  for cat in "domain language" "AT lifecycle (planned→draft→green→regression)" "coverage"; do
    grep -qi -- "$cat" agents/at-reviewer.md || {
      echo "at-reviewer missing category: $cat"
      return 1
    }
  done
}

# ============================================================
# AC3: each specialist reviewer enumerates exactly 10 criteria
# ============================================================

@test "AC3: each specialist reviewer has exactly 10 top-level numbered criteria" {
  for f in "${SPECIALISTS[@]}"; do
    count=$(_count_numbered_criteria "$f")
    [[ "$count" -eq 10 ]] || {
      echo "FAIL $f: numbered-criteria count=$count (expected 10)"
      return 1
    }
  done
}

@test "AC3: each criterion line ends with '?' or contains a verification verb" {
  for f in "${SPECIALISTS[@]}"; do
    [[ -f "$f" ]] || { echo "missing: $f"; return 1; }
    lines=$(_numbered_criteria_lines "$f")
    [[ -n "$lines" ]] || { echo "FAIL $f: no numbered criteria found"; return 1; }
    while IFS= read -r line; do
      echo "$line" | grep -Eiq '(\?[[:space:]]*$)|\b(check|verify|ensure|confirm|validate|must|should)\b' || {
        echo "FAIL $f line: $line"
        return 1
      }
    done <<< "$lines"
  done
  true
}

@test "AC3: numbered criteria are contiguous 1..10 in document order" {
  for f in "${SPECIALISTS[@]}"; do
    nums=$(_numbered_criteria_lines "$f" | awk '{ sub(/\..*/, ""); print }' | tr '\n' ' ')
    [[ "$nums" == "1 2 3 4 5 6 7 8 9 10 " ]] || {
      echo "FAIL $f: criteria numbering=[$nums] (expected 1 2 ... 10)"
      return 1
    }
  done
}

# ============================================================
# AC4: final-reviewer aggregates 50 criteria with traceability
# ============================================================

@test "AC4: final-reviewer names all 5 upstream specialist files by basename" {
  for basename in prd-reviewer.md us-reviewer.md plan-reviewer.md code-reviewer.md at-reviewer.md; do
    grep -q -- "$basename" agents/final-reviewer.md || {
      echo "final-reviewer missing basename: $basename"
      return 1
    }
  done
}

@test "AC4: final-reviewer contains exactly 50 distinct traceability references" {
  count=$(grep -oE '(prd|us|plan|code|at)-reviewer#[0-9]+' agents/final-reviewer.md | sort -u | wc -l | tr -d ' ')
  [[ "$count" -eq 50 ]] || {
    echo "FAIL: distinct refs=$count (expected 50)"
    return 1
  }
}

@test "AC4: traceability references use exactly the 5 role prefixes with N in 1..10" {
  [[ -f agents/final-reviewer.md ]] || { echo "missing agents/final-reviewer.md"; return 1; }
  bad=$(grep -oE '(prd|us|plan|code|at)-reviewer#[0-9]+' agents/final-reviewer.md \
        | awk -F'#' '{ if ($2+0 < 1 || $2+0 > 10) print }')
  [[ -z "$bad" ]] || { echo "FAIL: out-of-range refs: $bad"; return 1; }
}

@test "AC4: Final Verdict section contains 'all 5' and 'PASS' substrings" {
  grep -q "Final Verdict" agents/final-reviewer.md || { echo "missing Final Verdict heading"; return 1; }
  # Extract the Final Verdict section (until next "## " heading or EOF)
  section=$(awk '/^##[[:space:]]+Final Verdict/{flag=1; next} flag && /^##[[:space:]]/{flag=0} flag' agents/final-reviewer.md)
  echo "$section" | grep -q "all 5" || { echo "Final Verdict section missing 'all 5'"; return 1; }
  echo "$section" | grep -q "PASS" || { echo "Final Verdict section missing 'PASS'"; return 1; }
}

# ============================================================
# AC5: each reviewer file conforms to existing agent convention
# ============================================================

@test "AC5: each reviewer has no 'skills' or other extra top-level frontmatter keys" {
  for f in "${ALL_REVIEWERS[@]}"; do
    [[ -f "$f" ]] || { echo "missing: $f"; return 1; }
    extra=$(_yaml_keys "$f" | grep -vE '^(name|description|tools)$' | tr '\n' ',' | sed 's/,$//')
    [[ -z "$extra" ]] || { echo "FAIL $f: extra keys=[$extra]"; return 1; }
  done
}

@test "AC5: each reviewer body opens with 'You are the <Role>.'" {
  for f in "${ALL_REVIEWERS[@]}"; do
    line=$(_first_body_line "$f")
    echo "$line" | grep -Eq '^You are the [^.]+\.' || {
      echo "FAIL $f: first body line does not match opener regex: $line"
      return 1
    }
  done
}

# ============================================================
# AC6: each subagent's name field equals its filename basename
# ============================================================

@test "AC6: each reviewer name field equals filename basename" {
  for f in "${ALL_REVIEWERS[@]}"; do
    base=$(basename "$f" .md)
    name=$(_yaml_field "$f" name)
    [[ "$name" == "$base" ]] || {
      echo "FAIL $f: name=[$name] basename=[$base]"
      return 1
    }
  done
}
