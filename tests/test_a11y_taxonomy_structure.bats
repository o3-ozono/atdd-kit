#!/usr/bin/env bats
# @covers: docs/methodology/a11y-test-taxonomy.md
# Issue #372: a11y テスト手段の3分割と「自動 green ≠ 達成」の明文化

# AT-372-1: テスト手段の3分割を参照できる（FS-1）

@test "AT-372-1: a11y-test-taxonomy.md exists" {
  [ -f "docs/methodology/a11y-test-taxonomy.md" ]
}

@test "AT-372-1: 3-way split section heading exists" {
  grep -qi '3-Way Split' docs/methodology/a11y-test-taxonomy.md
}

@test "AT-372-1: all 3 category names are present" {
  grep -q 'Automated / Static' docs/methodology/a11y-test-taxonomy.md
  grep -q 'Automated / Interactive' docs/methodology/a11y-test-taxonomy.md
  grep -q 'Manual' docs/methodology/a11y-test-taxonomy.md
}

@test "AT-372-1: all execution-timing terms are present" {
  grep -q 'unit' docs/methodology/a11y-test-taxonomy.md
  grep -qi 'CI' docs/methodology/a11y-test-taxonomy.md
  grep -q 'E2E' docs/methodology/a11y-test-taxonomy.md
  grep -q 'design review' docs/methodology/a11y-test-taxonomy.md
}

# AT-372-2: 「自動 green ≠ a11y 達成」を一次情報付きで確認できる（FS-2 / CS-1）

@test "AT-372-2: auto-green-not-equal section heading exists" {
  grep -qi 'Automated Green' docs/methodology/a11y-test-taxonomy.md
}

@test "AT-372-2: Playwright and Deque reference URLs are present" {
  grep -qi 'playwright' docs/methodology/a11y-test-taxonomy.md
  grep -qi 'deque' docs/methodology/a11y-test-taxonomy.md
  grep -qE 'https?://' docs/methodology/a11y-test-taxonomy.md
}

# AT-372-3: 適用基準（WCAG 2.2 AA / JIS 版差）を参照できる（FS-3）

@test "AT-372-3: applicability-criteria section has all required terms" {
  grep -qi 'Applicability Criteria' docs/methodology/a11y-test-taxonomy.md
  grep -q 'WCAG 2.2 AA' docs/methodology/a11y-test-taxonomy.md
  grep -q 'JIS X 8341-3:2016' docs/methodology/a11y-test-taxonomy.md
  grep -q 'WCAG 2.0' docs/methodology/a11y-test-taxonomy.md
}

# AT-372-4: 「テスト手段の分け方」と「WCAG SC トリアージ」が別軸だと確認できる（FS-4）

@test "AT-372-4: separate-axis section and triage term are present" {
  grep -qi 'Separate Axis' docs/methodology/a11y-test-taxonomy.md
  grep -qi 'triage' docs/methodology/a11y-test-taxonomy.md
}

# AT-372-5: ドキュメント構造を自動検証できる（FS-5）— 本ファイル自体が構造検証テストである
