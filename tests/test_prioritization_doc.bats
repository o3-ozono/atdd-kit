#!/usr/bin/env bats
# @covers: docs/methodology/prioritization.md, skills/defining-requirements/SKILL.md
# Issue #367: 機能優先度の方法論 doc（MUST/SHOULD/WANT + 次回以降/破棄・2軸=効き×工数）
#
# 回帰安全性 (AT-367-8): これらのピンはセクション見出し・キーワードの不変条件のみを
# assert し、バージョン番号・行数・日付の point-in-time 値は exact-pin しない。
# Test names are kept ASCII-only (bats 1.13 mangles non-ASCII @test names);
# the Japanese assertions themselves live in the grep patterns below.

DOC="docs/methodology/prioritization.md"

# AT-367-1: prioritization.md が新設され位置づけが明示される（US-1 / CS-1）

@test "AT-367-1: prioritization.md exists" {
  [ -f "$DOC" ]
}

@test "AT-367-1: doc states MoSCoW/DSDM origin with derivation marker" {
  grep -q 'MoSCoW' "$DOC"
  grep -q 'DSDM' "$DOC"
  grep -q '独自' "$DOC"
}

# AT-367-2: 5 段階の定義テーブルが完全である（US-1）

@test "AT-367-2: doc has a 5-stage section" {
  grep -qi '5 段階' "$DOC"
}

@test "AT-367-2: all 5 stage labels are present" {
  grep -q 'MUST' "$DOC"
  grep -q 'SHOULD' "$DOC"
  grep -q 'WANT' "$DOC"
  grep -q '次回以降' "$DOC"
  grep -q '破棄' "$DOC"
}

# AT-367-3: 効きと工数の 2 軸が分離定義される（US-2）

@test "AT-367-3: doc has a 2-axis section" {
  grep -qi '2 軸' "$DOC"
}

@test "AT-367-3: both axes are defined plus an integrated mapping table row" {
  grep -q '効き' "$DOC"
  grep -q '工数' "$DOC"
  grep -q '| 高 |' "$DOC"
}

# AT-367-4: anti-pattern セクションが工数混入誤用を明記する（US-2 / US-3）

@test "AT-367-4: doc has an anti-pattern section" {
  grep -qi 'anti-pattern' "$DOC"
}

@test "AT-367-4: anti-pattern names the effort-mixed-into-impact misuse" {
  grep -q '効くけど大変だから WANT' "$DOC"
}

# AT-367-5: 破棄の扱い（テーブル内保存・ゾンビ復活防止）が規定される（US-3）

@test "AT-367-5: doc has a discard-handling section" {
  grep -q '破棄' "$DOC"
}

@test "AT-367-5: discard section mentions zombie-revival prevention" {
  grep -q 'ゾンビ復活' "$DOC"
}

# AT-367-6: defining-requirements から prioritization.md への参照接続がある（US-4）

@test "AT-367-6: defining-requirements SKILL.md references prioritization.md" {
  grep -q 'docs/methodology/prioritization.md' skills/defining-requirements/SKILL.md
}
