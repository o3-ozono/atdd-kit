#!/usr/bin/env bats

# AC4/AC7/AC8/AC10/AC15: Interaction reduction tests
# Unit (BATS) -- verifies SKILL.md structure for batch mode, fast track,
# default recommendations, and risk-based approval classification

# --- AC7: Complexity-based Fast Track ---

# (AC7 complexity classification and AC8 batch mode tests removed -- Step 0 was removed from discover in #104)

# --- AC10: Default Recommendations ---

@test "AC10: discover SKILL.md has default recommendation pattern" {
  grep -qi 'recommended.*ok\|recommend.*accept\|デフォルト推奨' skills/discover/SKILL.md
}

@test "AC10: plan SKILL.md has default recommendation pattern" {
  grep -qi 'recommended.*ok\|recommend.*accept\|デフォルト推奨' skills/plan/SKILL.md
}

@test "AC10: issue SKILL.md has default recommendation pattern" {
  grep -qi 'recommended.*ok\|recommend.*accept\|デフォルト推奨' skills/issue/SKILL.md
}

# --- AC15: Risk-based Approval Classification ---

@test "AC15: plan SKILL.md has risk classification section with color indicators" {
  grep -q '🔴\|🟡\|🟢' skills/plan/SKILL.md
}

@test "AC15: plan SKILL.md has risk classification criteria" {
  grep -qi 'risk.*classif\|リスク.*分類\|design.*policy\|設計ポリシー' skills/plan/SKILL.md
}
