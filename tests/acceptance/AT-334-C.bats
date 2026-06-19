#!/usr/bin/env bats
# @covers: docs/methodology/autopilot-iron-law.md, docs/methodology/autopilot-overview.md
# AT-334-C: Gate③後フィードバックの正規ルート（F3）
#
# lifecycle: [regression]

IRON_LAW="docs/methodology/autopilot-iron-law.md"
OVERVIEW="docs/methodology/autopilot-overview.md"

# --- AT-334-C1: iron-law に規模分岐ルートが明文化されている ---

@test "AT-334-C1a: iron-law mentions Gate3 post-feedback new AC should not be directly implemented" {
  # Given: docs/methodology/autopilot-iron-law.md
  # When: Gate③後フィードバックの節を読む
  # Then: Gate③後の新ACは直接実装しない旨が記述されている
  run grep -qiE 'Gate.*3|Gate③|gate.*③|③.*gate|gate.*merge|merge.*gate' "$IRON_LAW"
  [ "$status" -eq 0 ]
}

@test "AT-334-C1b: iron-law specifies design-anchor-based routing for new AC after Gate3" {
  # Given: docs/methodology/autopilot-iron-law.md
  # When: Gate③後フィードバックの節を読む
  # Then: 設計アンカー変更の有無を一次基準とした分岐が記述されている
  run grep -qiE '設計アンカー|design.*anchor|anchor.*design' "$IRON_LAW"
  [ "$status" -eq 0 ]
}

@test "AT-334-C1c: iron-law specifies design-rollback route for small scope (anchor unchanged)" {
  # Given: docs/methodology/autopilot-iron-law.md
  # When: Gate③後の小規模ルートを読む
  # Then: 同一Issue内 design 差し戻しルートが記述されている
  run grep -qiE 'design.*差し戻し|差し戻し.*design|same.*issue|同一.*issue|design.*rollback|rollback.*design' "$IRON_LAW"
  [ "$status" -eq 0 ]
}

@test "AT-334-C1d: iron-law specifies new-Issue route for large scope (anchor change required)" {
  # Given: docs/methodology/autopilot-iron-law.md
  # When: Gate③後の大規模ルートを読む
  # Then: 新Issue ルートが記述されている
  run grep -qiE '新.*issue|new.*issue' "$IRON_LAW"
  [ "$status" -eq 0 ]
}

# --- AT-334-C2: overview が iron-law を正典参照する ---

@test "AT-334-C2a: overview mentions Gate3 post-feedback route" {
  # Given: docs/methodology/autopilot-overview.md
  # When: ライフサイクル節を読む
  # Then: Gate③後ルートの要約が存在する
  run grep -qiE 'Gate.*3|Gate③|gate.*③|③.*gate|gate.*merge|merge.*feedback|merge.*後' "$OVERVIEW"
  [ "$status" -eq 0 ]
}

@test "AT-334-C2b: overview references iron-law as canonical source" {
  # Given: docs/methodology/autopilot-overview.md
  # When: ライフサイクル節を読む
  # Then: iron-law を参照している（陳腐化防止の相互参照）
  run grep -qiE 'autopilot-iron-law|iron.*law|iron-law' "$OVERVIEW"
  [ "$status" -eq 0 ]
}
