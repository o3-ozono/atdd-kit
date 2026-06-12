#!/usr/bin/env bats
# @covers: agents/**
# Regression pin: fixed reviewer agents removal and #234 alignment (Issue #271)
# Replaces test_reviewer_subagents.bats (Issue #186 — fixed 6-agent structure smoke test).

# --- pin (a): 固定 reviewer agent 6 ファイルが存在しない ---

@test "pin(a): six fixed reviewer agent files do not exist under agents/" {
  for f in prd-reviewer.md us-reviewer.md plan-reviewer.md code-reviewer.md at-reviewer.md final-reviewer.md; do
    [[ ! -f "agents/${f}" ]] || {
      echo "FAIL: 削除済みであるべきファイルが存在する: agents/${f}"
      return 1
    }
  done
}

# --- pin (b): 対象範囲でレガシー参照 0 件 ---

@test "pin(b): no legacy reviewer references in agents/ docs/ skills/ commands/ rules/ README.md README.ja.md DEVELOPMENT.md DEVELOPMENT.ja.md" {
  # docs/ は issues/（歴史的記録）を除く全域。パターンはファイル名を含まない
  # レガシー表現（'specialist reviewer' / '47 criteria'）も検知する（#271 coverage gate）。
  local hits
  hits=$(grep -rE 'prd-reviewer|us-reviewer|plan-reviewer|code-reviewer|at-reviewer|final-reviewer|specialist reviewer|47 criteria' \
    --exclude-dir=issues \
    agents/ \
    docs/ \
    skills/ \
    commands/ \
    rules/ \
    README.md \
    README.ja.md \
    DEVELOPMENT.md \
    DEVELOPMENT.ja.md \
    2>/dev/null | \
    grep -v 'tests/test_agents_dynamic_panel\|tests/acceptance/AT-271' || true)

  [[ -z "$hits" ]] || {
    echo "FAIL: レガシー参照が残っている:"
    echo "$hits"
    return 1
  }
}

# --- pin (c): agents/README.md に動的パネル言及あり、レガシー Usage 文言なし ---

@test "pin(c): agents/README.md mentions dynamic panel and has no 'five specialist' legacy phrase" {
  # 動的パネルへの言及
  grep -qi 'dynamic' agents/README.md || {
    echo "FAIL: agents/README.md に dynamic への言及がない"
    return 1
  }

  # レガシー Usage 文言がない
  if grep -qE 'five specialist' agents/README.md 2>/dev/null; then
    echo "FAIL: agents/README.md に 'five specialist' レガシー文言が残っている"
    return 1
  fi
}
