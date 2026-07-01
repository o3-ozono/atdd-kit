#!/usr/bin/env bats
# @covers: docs/methodology/testing/ui-e2e-foundations.md
# #371 UI/E2E test foundations doc -- structural pins (US-1..US-6, CS-1, CS-2)
# red->green: red before impl because the doc/addon references are absent

bats_require_minimum_version 1.5.0

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
DOC="${REPO_ROOT}/docs/methodology/testing/ui-e2e-foundations.md"
WEB_ADDON_YML="${REPO_ROOT}/addons/web/addon.yml"
IOS_README="${REPO_ROOT}/addons/ios/README.md"
DISCORD_README="${REPO_ROOT}/addons/discord/README.md"
METHODOLOGY_README="${REPO_ROOT}/docs/methodology/README.md"

# AT-371-1 (US-1): doc exists with the 3 required top-level sections
@test "AT-371-1: ui-e2e-foundations.md exists with 3 required sections" {
  [ -f "$DOC" ] || {
    echo "FAIL: $DOC が存在しない"
    return 1
  }
  grep -q '^## 4 Principles' "$DOC" || {
    echo "FAIL: '## 4 Principles' 節見出しが無い"
    return 1
  }
  grep -q '^## LLM Rule Set' "$DOC" || {
    echo "FAIL: '## LLM Rule Set' 節見出しが無い"
    return 1
  }
  grep -q '^## Footnotes' "$DOC" || {
    echo "FAIL: '## Footnotes' 節見出しが無い"
    return 1
  }
}

# AT-371-2 (US-1): all 4 principle headings present, each non-empty
@test "AT-371-2: all 4 principle headings present and non-empty" {
  for n in 1 2 3 4; do
    grep -q "^### Principle ${n}" "$DOC" || {
      echo "FAIL: '### Principle ${n}' 見出しが無い"
      return 1
    }
  done
  # non-empty check: at least 3 non-blank lines between each heading and the next
  awk '/^### Principle/{c++; if(c>1) exit(body<3); body=0; next} /^### /{next} /^## /{if(c>0) exit(body<3)} {if(c>0 && NF>0) body++} END{exit(c>0 && body<3)}' "$DOC" || {
    echo "FAIL: いずれかの原則本文が空/極端に短い"
    return 1
  }
}

# AT-371-3 (US-2): all 9 primary-source identifiers present in the footnotes block
@test "AT-371-3: footnotes block contains all 9 source identifiers" {
  footnotes="$(awk '/^## Footnotes/{f=1; next} /^## /{f=0} f' "$DOC")"
  [ -n "$footnotes" ] || {
    echo "FAIL: Footnotes 節本文が空"
    return 1
  }
  for id in "Playwright" "Cypress" "Testing Library" "Fowler" "Selenium" "Serenity" "van Deursen" "Vocke" "Kent C. Dodds"; do
    echo "$footnotes" | grep -qF "$id" || {
      echo "FAIL: 出典識別語 '$id' が Footnotes 節に無い"
      return 1
    }
  done
}

# AT-371-4 (US-2): [独自] marker present at least once
@test "AT-371-4: dokuji marker present in the doc" {
  grep -qF '[独自]' "$DOC" || {
    echo "FAIL: [独自] マーカーが doc 内に無い"
    return 1
  }
}

# AT-371-5 (US-3): Principle 2 documents both locator schools with rationale/trade-off
@test "AT-371-5: Principle 2 documents role / data-testid / data-cy with both schools" {
  p2="$(awk '/^### Principle 2/{f=1} /^### Principle 3/{f=0} f' "$DOC")"
  [ -n "$p2" ] || {
    echo "FAIL: Principle 2 節本文が空"
    return 1
  }
  for token in "role" "data-testid" "data-cy"; do
    echo "$p2" | grep -qF "$token" || {
      echo "FAIL: Principle 2 に '$token' が無い"
      return 1
    }
  done
  echo "$p2" | grep -qi "trade-off" || {
    echo "FAIL: Principle 2 に trade-off の記述が無い"
    return 1
  }
}

# AT-371-6 (US-3): mixing selector schools within one addon is a hard rule
@test "AT-371-6: mixing-schools-within-one-addon prohibition is a hard rule" {
  p2="$(awk '/^### Principle 2/{f=1} /^### Principle 3/{f=0} f' "$DOC")"
  echo "$p2" | grep -qi "mixing" || {
    echo "FAIL: Principle 2 に混在禁止（mixing）の記述が無い"
    return 1
  }
  echo "$p2" | grep -qF '[hard rule]' || {
    echo "FAIL: Principle 2 に [hard rule] マーカーが無い"
    return 1
  }
}

# AT-371-7 (US-4): LLM Rule Set has >=4 imperative [hard rule]-marked rules
@test "AT-371-7: LLM Rule Set has at least 4 [hard rule] entries" {
  rules="$(awk '/^## LLM Rule Set/{f=1; next} /^## /{f=0} f' "$DOC")"
  [ -n "$rules" ] || {
    echo "FAIL: LLM Rule Set 節本文が空"
    return 1
  }
  count="$(echo "$rules" | grep -cF '[hard rule]')"
  [ "$count" -ge 4 ] || {
    echo "FAIL: [hard rule] 件数が4未満 (count=$count)"
    return 1
  }
}

# AT-371-8 (US-5): all 3 addons reference ui-e2e-foundations.md
@test "AT-371-8: web/ios/discord addons reference ui-e2e-foundations.md" {
  grep -q 'ui-e2e-foundations.md' "$WEB_ADDON_YML" || {
    echo "FAIL: addons/web/addon.yml に参照が無い"
    return 1
  }
  grep -q 'ui-e2e-foundations.md' "$IOS_README" || {
    echo "FAIL: addons/ios/README.md に参照が無い"
    return 1
  }
  grep -q 'ui-e2e-foundations.md' "$DISCORD_README" || {
    echo "FAIL: addons/discord/README.md に参照が無い"
    return 1
  }
}

# AT-371-9 (US-5 / CS-1): platform-independent principle body is not duplicated in addon docs
@test "AT-371-9: platform-independent principle body not duplicated in addon docs" {
  for f in "$WEB_ADDON_YML" "$IOS_README" "$DISCORD_README"; do
    ! grep -qi "fixed.time.wait" "$f" || {
      echo "FAIL: $f に原則本文相当（固定時間待ち禁止）が再掲されている"
      return 1
    }
  done
}

# AT-371-10 (US-6): methodology README indexes the new doc
@test "AT-371-10: methodology README indexes ui-e2e-foundations" {
  grep -q 'ui-e2e-foundations' "$METHODOLOGY_README" || {
    echo "FAIL: docs/methodology/README.md に ui-e2e-foundations の記載が無い"
    return 1
  }
}

# AT-371-11 (CS-2): each hard rule in the LLM rule set traces to one of the 4 principles
@test "AT-371-11: LLM rule set hard rules trace to all 4 principles" {
  rules="$(awk '/^## LLM Rule Set/{f=1; next} /^## /{f=0} f' "$DOC")"
  for n in 1 2 3 4; do
    echo "$rules" | grep -qF "(Principle ${n})" || {
      echo "FAIL: LLM Rule Set に Principle ${n} への対応付けが無い"
      return 1
    }
  done
}
