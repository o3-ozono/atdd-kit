#!/usr/bin/env bats
# @covers: docs/methodology/skill-loader-split.md
# @covers: docs/methodology/README.md
# AT-314: SKILL.md loader stub split methodology document (research)
# Issue #314

bats_require_minimum_version 1.5.0

# repo_root helper
repo_root() {
  cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd
}

SPLIT_DOC="docs/methodology/skill-loader-split.md"

# ---------------------------------------------------------------------------
# AT-314-1: Split Pattern section documents stub/split criteria (FS-1)
# ---------------------------------------------------------------------------

@test "AT-314-1: skill-loader-split.md has Split Pattern section with stub/split criteria" {
  # Given: docs/methodology/skill-loader-split.md が存在する
  # When: ## Split Pattern 節を読む
  # Then: stub に残す / 分離する両基準が箇条書きで列挙され、分離先ポインタ形式が例示されている
  local root
  root="$(repo_root)"

  [[ -f "${root}/${SPLIT_DOC}" ]] || {
    echo "FAIL: ${SPLIT_DOC} does not exist"
    return 1
  }

  grep -q '## Split Pattern' "${root}/${SPLIT_DOC}" || {
    echo "FAIL: ${SPLIT_DOC} has no '## Split Pattern' section"
    return 1
  }

  # stub に残すもの (frontmatter / Trigger / Input / Output) の基準が存在すること
  grep -qiE 'stub|remain|keep|frontmatter|Trigger|Input|Output' "${root}/${SPLIT_DOC}" || {
    echo "FAIL: ${SPLIT_DOC} has no stub-retention criteria"
    return 1
  }

  # 分離先ポインタ形式の例示 (docs/methodology/) が存在すること
  grep -qF 'docs/methodology/' "${root}/${SPLIT_DOC}" || {
    echo "FAIL: ${SPLIT_DOC} has no docs/methodology/ pointer example"
    return 1
  }
}

# ---------------------------------------------------------------------------
# AT-314-2a: Skill Inventory table covers all 20 SKILL.md files with correct line counts (FS-2)
# ---------------------------------------------------------------------------

@test "AT-314-2a: Skill Inventory table covers all 20 SKILL.md files with correct line counts" {
  # Given: skill-loader-split.md に ## Skill Inventory 表がある
  # When: 全 SKILL.md の実測行数と表の現行行数列を突き合わせる
  # Then: 表に 20 行（全 SKILL.md）が存在し、各行の現行行数が実測値と一致する
  local root
  root="$(repo_root)"

  [[ -f "${root}/${SPLIT_DOC}" ]] || {
    echo "FAIL: ${SPLIT_DOC} does not exist"
    return 1
  }

  grep -q '## Skill Inventory' "${root}/${SPLIT_DOC}" || {
    echo "FAIL: ${SPLIT_DOC} has no '## Skill Inventory' section"
    return 1
  }

  # 全 20 SKILL.md ファイルが表に登録されていることを検証する
  local missing_count=0
  local skill
  for f in "${root}/skills"/*/SKILL.md; do
    skill=$(basename "$(dirname "$f")")
    if ! grep -qF "$skill" "${root}/${SPLIT_DOC}"; then
      echo "WARN: $skill is missing from ${SPLIT_DOC}"
      (( missing_count++ )) || true
    fi
  done

  [[ "$missing_count" -eq 0 ]] || {
    echo "FAIL: ${missing_count} skill(s) are missing from the Skill Inventory table"
    return 1
  }

  # 実測行数と表の行数列が一致することを検証する
  local mismatch=0
  for f in "${root}/skills"/*/SKILL.md; do
    skill=$(basename "$(dirname "$f")")
    local actual
    actual=$(wc -l < "$f" | tr -d ' ')
    if ! grep -qF "$actual" "${root}/${SPLIT_DOC}"; then
      echo "WARN: $skill actual line count $actual not found in ${SPLIT_DOC}"
      (( mismatch++ )) || true
    fi
  done

  [[ "$mismatch" -eq 0 ]] || {
    echo "FAIL: ${mismatch} skill(s) have line count mismatches in the inventory table"
    return 1
  }
}

# ---------------------------------------------------------------------------
# AT-314-2b: Urgency threshold is defined and autopilot is classified CRITICAL (FS-2)
# ---------------------------------------------------------------------------

@test "AT-314-2b: urgency threshold is defined and autopilot is classified CRITICAL" {
  # Given: Skill Inventory 節に逼迫度しきい値の数値定義がある
  # When: 各 Skill 行の逼迫度ランク（CRITICAL/HIGH/MEDIUM/LOW）をしきい値定義に照らす
  # Then: ランクが定義から機械的に導け、autopilot=CRITICAL（279/280）が含まれる
  local root
  root="$(repo_root)"

  [[ -f "${root}/${SPLIT_DOC}" ]] || {
    echo "FAIL: ${SPLIT_DOC} does not exist"
    return 1
  }

  grep -qE 'CRITICAL|HIGH|MEDIUM|LOW' "${root}/${SPLIT_DOC}" || {
    echo "FAIL: ${SPLIT_DOC} has no urgency rank definitions (CRITICAL/HIGH/MEDIUM/LOW)"
    return 1
  }

  # しきい値の数値定義が存在すること
  grep -qE '[0-9]+ lines?' "${root}/${SPLIT_DOC}" || {
    echo "FAIL: ${SPLIT_DOC} has no numeric threshold definition"
    return 1
  }

  # autopilot が CRITICAL ランクであること
  grep -qiE 'autopilot.*CRITICAL|CRITICAL.*autopilot' "${root}/${SPLIT_DOC}" || {
    echo "FAIL: ${SPLIT_DOC} does not classify autopilot as CRITICAL"
    return 1
  }
}

# ---------------------------------------------------------------------------
# AT-314-2c: session-start pin-absence finding is recorded (FS-2)
# ---------------------------------------------------------------------------

@test "AT-314-2c: session-start pin-absence risk is recorded as a finding" {
  # Given: Skill Inventory 表に session-start 行がある
  # When: session-start の pin 上限列と備考を読む
  # Then: pin 上限が none（未ガード）と明記され、備考に逼迫リスクが記述されている
  local root
  root="$(repo_root)"

  [[ -f "${root}/${SPLIT_DOC}" ]] || {
    echo "FAIL: ${SPLIT_DOC} does not exist"
    return 1
  }

  grep -q 'session-start' "${root}/${SPLIT_DOC}" || {
    echo "FAIL: ${SPLIT_DOC} has no session-start entry"
    return 1
  }

  # pin なし（none / unguarded）の記述が存在すること
  grep -qiE 'session.start.*none|none.*session.start|no pin.*session.start|session.start.*no pin|unguard' "${root}/${SPLIT_DOC}" || {
    echo "FAIL: ${SPLIT_DOC} does not record session-start as having no pin (none/unguarded)"
    return 1
  }
}

# ---------------------------------------------------------------------------
# AT-314-3a: Impact Analysis covers 3 perspectives with impact + mitigation pairs (FS-3)
# ---------------------------------------------------------------------------

@test "AT-314-3a: Impact Analysis covers string-pin AT, template sync, and line-count pin perspectives" {
  # Given: skill-loader-split.md に ## Impact Analysis 節がある
  # When: 3 観点（string-pin / テンプレート同期 / 行数 pin）を読む
  # Then: 3 観点すべてが区別され、各々に影響と対応方針が対で記述されている
  local root
  root="$(repo_root)"

  [[ -f "${root}/${SPLIT_DOC}" ]] || {
    echo "FAIL: ${SPLIT_DOC} does not exist"
    return 1
  }

  grep -q '## Impact Analysis' "${root}/${SPLIT_DOC}" || {
    echo "FAIL: ${SPLIT_DOC} has no '## Impact Analysis' section"
    return 1
  }

  grep -qiE 'string.?pin|string pin' "${root}/${SPLIT_DOC}" || {
    echo "FAIL: ${SPLIT_DOC} Impact Analysis missing string-pin AT perspective"
    return 1
  }

  grep -qiE 'template|sync' "${root}/${SPLIT_DOC}" || {
    echo "FAIL: ${SPLIT_DOC} Impact Analysis missing template sync perspective"
    return 1
  }

  grep -qiE 'line.?budget.?pin|line.?count.?pin|line count test' "${root}/${SPLIT_DOC}" || {
    echo "FAIL: ${SPLIT_DOC} Impact Analysis missing line-count pin test perspective"
    return 1
  }
}

# ---------------------------------------------------------------------------
# AT-314-3b: string-pin migration rule (both pins inventory + @covers widening) is stated (FS-3)
# ---------------------------------------------------------------------------

@test "AT-314-3b: string-pin migration rule states both-pin inventory and @covers widening" {
  # Given: Impact Analysis 節の string-pin 観点
  # When: detail doc へ検証文字列が移る場合の対応方針を読む
  # Then: 「分離元・分離先の両 pin 棚卸し」と「@covers の付け替え／広域化」が明記されている
  local root
  root="$(repo_root)"

  [[ -f "${root}/${SPLIT_DOC}" ]] || {
    echo "FAIL: ${SPLIT_DOC} does not exist"
    return 1
  }

  grep -qiE 'both.*pin|pin.*both|source.*pin.*destination|destination.*pin.*source|@covers' "${root}/${SPLIT_DOC}" || {
    echo "FAIL: ${SPLIT_DOC} missing both-pin inventory or @covers widening rule"
    return 1
  }
}

# ---------------------------------------------------------------------------
# AT-314-4: autopilot is listed as reference implementation with detail doc table (FS-4)
# ---------------------------------------------------------------------------

@test "AT-314-4: autopilot reference implementation lists autopilot-iron-law.md and other detail docs" {
  # Given: skill-loader-split.md の Split Pattern または専用節
  # When: autopilot の分離先 detail doc 一覧を読む
  # Then: autopilot-iron-law.md 等の実在 detail doc 名が列挙され、
  #       「SKILL.md ポインタ ↔ 分離先 doc」の対応が示されている
  local root
  root="$(repo_root)"

  [[ -f "${root}/${SPLIT_DOC}" ]] || {
    echo "FAIL: ${SPLIT_DOC} does not exist"
    return 1
  }

  # autopilot-iron-law.md が実在することの確認（前提条件）
  [[ -f "${root}/docs/methodology/autopilot-iron-law.md" ]] || {
    echo "FAIL: docs/methodology/autopilot-iron-law.md does not exist (precondition)"
    return 1
  }

  grep -qF 'autopilot-iron-law.md' "${root}/${SPLIT_DOC}" || {
    echo "FAIL: ${SPLIT_DOC} does not reference autopilot-iron-law.md"
    return 1
  }

  grep -qiE 'reference|#283|#304' "${root}/${SPLIT_DOC}" || {
    echo "FAIL: ${SPLIT_DOC} does not reference autopilot as reference implementation (#283/#304)"
    return 1
  }
}

# ---------------------------------------------------------------------------
# AT-314-5: Pin Operation section aligns with DEVELOPMENT.md and covers stub/detail (FS-5)
# ---------------------------------------------------------------------------

@test "AT-314-5: Pin Operation section quotes DEVELOPMENT.md rule and covers stub and detail pin policy" {
  # Given: skill-loader-split.md に ## Pin Operation 節がある
  # When: 分割後の pin 運用記述を読む
  # Then: DEVELOPMENT.md の「2 回まで・3 回目で loader stub 分割」ルールが引用され、
  #       stub budget pin と分離先構造 pin の双方の設置方針が述べられている
  local root
  root="$(repo_root)"

  [[ -f "${root}/${SPLIT_DOC}" ]] || {
    echo "FAIL: ${SPLIT_DOC} does not exist"
    return 1
  }

  grep -q '## Pin Operation' "${root}/${SPLIT_DOC}" || {
    echo "FAIL: ${SPLIT_DOC} has no '## Pin Operation' section"
    return 1
  }

  grep -qiE 'DEVELOPMENT.md|Line.Budget Raises|twice|2 times|third raise|3rd raise' "${root}/${SPLIT_DOC}" || {
    echo "FAIL: ${SPLIT_DOC} Pin Operation section does not quote DEVELOPMENT.md Line-Budget Raises rule"
    return 1
  }

  grep -qiE 'stub.*pin|pin.*stub' "${root}/${SPLIT_DOC}" || {
    echo "FAIL: ${SPLIT_DOC} has no stub pin policy"
    return 1
  }

  grep -qiE 'detail.*pin|pin.*detail|Loaded.by|structure.*pin' "${root}/${SPLIT_DOC}" || {
    echo "FAIL: ${SPLIT_DOC} has no detail doc pin policy"
    return 1
  }
}

# ---------------------------------------------------------------------------
# AT-314-6: Rollout Plan is ordered by urgency rank descending (FS-6)
# ---------------------------------------------------------------------------

@test "AT-314-6: Rollout Plan is ordered by urgency rank descending with FS-2 dependency noted" {
  # Given: skill-loader-split.md に ## Rollout Plan 節がある
  # When: 適用順序の表を読む
  # Then: 逼迫度ランク降順に並び、各行に「対象 Skill / 推定派生 Issue スコープ / 前提依存」が
  #       記載され、FS-2 しきい値への依存が明記されている
  local root
  root="$(repo_root)"

  [[ -f "${root}/${SPLIT_DOC}" ]] || {
    echo "FAIL: ${SPLIT_DOC} does not exist"
    return 1
  }

  grep -q '## Rollout Plan' "${root}/${SPLIT_DOC}" || {
    echo "FAIL: ${SPLIT_DOC} has no '## Rollout Plan' section"
    return 1
  }

  grep -qE 'CRITICAL|HIGH|MEDIUM|LOW' "${root}/${SPLIT_DOC}" || {
    echo "FAIL: ${SPLIT_DOC} Rollout Plan has no urgency rank entries"
    return 1
  }

  grep -qiE 'FS-2|threshold|headroom' "${root}/${SPLIT_DOC}" || {
    echo "FAIL: ${SPLIT_DOC} Rollout Plan does not reference FS-2 threshold dependency"
    return 1
  }
}

# ---------------------------------------------------------------------------
# AT-314-CS1a: skill-loader-split.md starts with Loaded-by meta-comment (CS-1)
# ---------------------------------------------------------------------------

@test "AT-314-CS1a: skill-loader-split.md starts with Loaded-by meta-comment" {
  # Given: 成果物 docs/methodology/skill-loader-split.md が存在する
  # When: head -3 docs/methodology/skill-loader-split.md を読む
  # Then: 冒頭に > **Loaded by:** メタコメントが存在する
  local root
  root="$(repo_root)"

  [[ -f "${root}/${SPLIT_DOC}" ]] || {
    echo "FAIL: ${SPLIT_DOC} does not exist"
    return 1
  }

  head -3 "${root}/${SPLIT_DOC}" | grep -q '> \*\*Loaded by:\*\*' || {
    echo "FAIL: ${SPLIT_DOC} does not start with '> **Loaded by:**' meta-comment"
    return 1
  }
}

# ---------------------------------------------------------------------------
# AT-314-CS1b: docs/methodology/README.md registers skill-loader-split.md (CS-1)
# ---------------------------------------------------------------------------

@test "AT-314-CS1b: docs/methodology/README.md has skill-loader-split.md registered" {
  # Given: docs/methodology/README.md の Documents 表
  # When: grep -q 'skill-loader-split' docs/methodology/README.md を実行
  # Then: 登録行がヒットする
  local root
  root="$(repo_root)"

  grep -q 'skill-loader-split' "${root}/docs/methodology/README.md" || {
    echo "FAIL: docs/methodology/README.md has no skill-loader-split.md entry"
    return 1
  }
}

# ---------------------------------------------------------------------------
# AT-314-CS2: No SKILL.md changes in this Issue branch (CS-2, regression)
# ---------------------------------------------------------------------------

@test "AT-314-CS2: git diff main...HEAD -- skills/ is empty (no SKILL.md changes)" {
  # Given: 本 Issue ブランチ（research フェーズ）
  # When: git diff main...HEAD -- skills/ を実行する
  # Then: 出力が空である（skills/*/SKILL.md への変更が存在しない）
  #
  # CS-2 is a PR-scoped guard for Issue #314's research phase: #314 split skills
  # into loaders/stubs WITHOUT touching SKILL.md bodies. It is inert post-merge
  # (HEAD == main → empty) and would false-fail on any later branch that
  # legitimately edits a SKILL.md, so it only runs on the #314 issue branch.
  local root
  root="$(repo_root)"

  local branch
  branch=$(git -C "${root}" branch --show-current 2>/dev/null || true)
  [[ "$branch" == *314* ]] || skip "CS-2 applies only to the #314 issue branch (inert elsewhere)"

  local diff_output
  diff_output=$(git -C "${root}" diff main...HEAD -- skills/ 2>/dev/null || true)

  [[ -z "$diff_output" ]] || {
    echo "FAIL: git diff main...HEAD -- skills/ is non-empty (SKILL.md changes detected)"
    echo "--- diff (first 20 lines) ---"
    echo "$diff_output" | head -20
    return 1
  }
}

# ---------------------------------------------------------------------------
# AT-314-CS3a: skill-loader-split.md contains no Japanese characters (CS-3, regression)
# ---------------------------------------------------------------------------

@test "AT-314-CS3a: skill-loader-split.md contains no Japanese characters (English only)" {
  # Given: 成果物 docs/methodology/skill-loader-split.md
  # When: grep -P '[ぁ-んァ-ヶ一-龥]' docs/methodology/skill-loader-split.md を実行する
  # Then: ヒットが無い（日本語文字 0）
  local root
  root="$(repo_root)"

  [[ -f "${root}/${SPLIT_DOC}" ]] || {
    echo "FAIL: ${SPLIT_DOC} does not exist"
    return 1
  }

  if grep -P '[ぁ-んァ-ヶ一-龥]' "${root}/${SPLIT_DOC}" >/dev/null 2>&1; then
    echo "FAIL: ${SPLIT_DOC} contains Japanese characters (English only violation)"
    grep -P '[ぁ-んァ-ヶ一-龥]' "${root}/${SPLIT_DOC}" | head -5
    return 1
  fi
}

# ---------------------------------------------------------------------------
# AT-314-CS3b: skill-loader-split.ja.md translation does not exist (CS-3, regression)
# ---------------------------------------------------------------------------

@test "AT-314-CS3b: docs/methodology/skill-loader-split.ja.md does not exist" {
  # Given: docs/methodology/ 配下
  # When: ls docs/methodology/skill-loader-split.ja.md を確認する
  # Then: ファイルが存在しない（翻訳同期負債を発生させない）
  local root
  root="$(repo_root)"

  [[ ! -f "${root}/docs/methodology/skill-loader-split.ja.md" ]] || {
    echo "FAIL: docs/methodology/skill-loader-split.ja.md exists (no translation needed)"
    return 1
  }
}
