#!/usr/bin/env bats
# @covers: docs/methodology/elicitation-techniques/**, skills/defining-requirements/SKILL.md, skills/batch-discovery/SKILL.md
# Issue #369: docs/methodology — 要件抽出の技法カタログ
# (Pre-mortem / Job Story / One question at a time / Out-of-scope question) を一次情報付きで新設

CATALOG_DIR="docs/methodology/elicitation-techniques"

# --- AT-369-1: 4 技法の一次情報付きカタログ (FS-1) ---

@test "AT-369-1: pre-mortem.md exists with primary source citing Klein 2007" {
  [ -f "${CATALOG_DIR}/pre-mortem.md" ]
  grep -A5 '^## 一次情報' "${CATALOG_DIR}/pre-mortem.md" | grep -q 'Klein'
  grep -A5 '^## 一次情報' "${CATALOG_DIR}/pre-mortem.md" | grep -q '2007'
}

@test "AT-369-1: job-story.md exists with primary source citing Klement 2013" {
  [ -f "${CATALOG_DIR}/job-story.md" ]
  grep -A5 '^## 一次情報' "${CATALOG_DIR}/job-story.md" | grep -q 'Klement'
  grep -A5 '^## 一次情報' "${CATALOG_DIR}/job-story.md" | grep -q '2013'
}

@test "AT-369-1: one-question-at-a-time.md exists with primary source citing Krug 2010" {
  [ -f "${CATALOG_DIR}/one-question-at-a-time.md" ]
  grep -A5 '^## 一次情報' "${CATALOG_DIR}/one-question-at-a-time.md" | grep -q 'Krug'
  grep -A5 '^## 一次情報' "${CATALOG_DIR}/one-question-at-a-time.md" | grep -q '2010'
}

@test "AT-369-1: out-of-scope-question.md exists with primary source citing Patton 2014" {
  [ -f "${CATALOG_DIR}/out-of-scope-question.md" ]
  grep -A5 '^## 一次情報' "${CATALOG_DIR}/out-of-scope-question.md" | grep -q 'Patton'
  grep -A5 '^## 一次情報' "${CATALOG_DIR}/out-of-scope-question.md" | grep -q '2014'
}

# --- AT-369-2: 各技法ドキュメントの統一フィールド (FS-2) ---

@test "AT-369-2: each technique doc has all 5 unified field headings" {
  for f in pre-mortem job-story one-question-at-a-time out-of-scope-question; do
    doc="${CATALOG_DIR}/${f}.md"
    grep -qF '## 目的' "$doc"
    grep -qF '## 問いの型' "$doc"
    grep -qF '## 適用先マッピング' "$doc"
    grep -qF '## 一次情報' "$doc"
    grep -qF '## 例' "$doc"
  done
}

# --- AT-369-3: 共通原則の独立ドキュメント (FS-3) ---

@test "AT-369-3: common-principles.md exists with 3 principles" {
  doc="${CATALOG_DIR}/common-principles.md"
  [ -f "$doc" ]
  grep -q 'キャッチボール' "$doc"
  grep -q '上位工程の責務' "$doc"
  grep -q '対話ログ' "$doc"
}

@test "AT-369-3: all 4 technique docs link to common-principles.md" {
  for f in pre-mortem job-story one-question-at-a-time out-of-scope-question; do
    doc="${CATALOG_DIR}/${f}.md"
    grep -q 'common-principles\.md' "$doc"
  done
}

# --- AT-369-4: SKILL.md からのマッピング参照 (FS-4) ---

@test "AT-369-4: defining-requirements/SKILL.md links to the catalog and stays within line budget" {
  skill="skills/defining-requirements/SKILL.md"
  grep -q 'docs/methodology/elicitation-techniques/' "$skill"
  n=$(wc -l < "$skill" | tr -d ' ')
  [ "$n" -le 200 ]
}

@test "AT-369-4: batch-discovery/SKILL.md links to the catalog" {
  grep -q 'docs/methodology/elicitation-techniques/' "skills/batch-discovery/SKILL.md"
}

@test "AT-369-4: SKILL.md files do not inline technique detail sections" {
  for skill in skills/defining-requirements/SKILL.md skills/batch-discovery/SKILL.md; do
    ! grep -q '^## 一次情報' "$skill"
  done
}

# --- AT-369-5: 一次情報への忠実性 (CS-1) ---

@test "AT-369-5: common-principles.md marks all 3 principles as original-organization" {
  doc="${CATALOG_DIR}/common-principles.md"
  count=$(grep -c '\[独自整理\]' "$doc")
  [ "$count" -ge 3 ]
}

# --- AT-369-6: 構造検証の自動ピン (CS-2) ---
# (this file itself, plus the README existence check, is AT-369-6's own subject)

@test "AT-369-6: README.md exists and links all 4 technique docs plus common-principles.md" {
  doc="${CATALOG_DIR}/README.md"
  [ -f "$doc" ]
  grep -q 'pre-mortem\.md' "$doc"
  grep -q 'job-story\.md' "$doc"
  grep -q 'one-question-at-a-time\.md' "$doc"
  grep -q 'out-of-scope-question\.md' "$doc"
  grep -q 'common-principles\.md' "$doc"
}

@test "AT-369-6: docs/methodology/README.md references the new catalog" {
  grep -q 'elicitation-techniques' "docs/methodology/README.md"
}
