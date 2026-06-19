#!/usr/bin/env bats
# @covers: docs/methodology/acceptance-test-feasibility.md
# @covers: docs/methodology/README.md
# AT-312: AT 計画前 feasibility 実地探索の正典フロー確立
# Issue #312

bats_require_minimum_version 1.5.0

# repo_root helper
repo_root() {
  cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd
}

DOCTRINE="docs/methodology/acceptance-test-feasibility.md"
README="docs/methodology/README.md"

# ---------------------------------------------------------------------------
# AT-312-01: doctrine ファイルが存在し Loaded-by メタを持つ
# ---------------------------------------------------------------------------

@test "AT-312-01a: acceptance-test-feasibility.md exists at the correct path" {
  # Given: methodology 正典群の配置規約（docs/methodology/README.md Conventions）
  # When: docs/methodology/acceptance-test-feasibility.md を検査する
  # Then: ファイルが実在する
  local root
  root="$(repo_root)"
  [[ -f "${root}/${DOCTRINE}" ]] || {
    echo "FAIL: ${DOCTRINE} does not exist"
    return 1
  }
}

@test "AT-312-01b: acceptance-test-feasibility.md contains Loaded-by meta comment" {
  # Given: methodology 正典群の Conventions（各 doc は Loaded-by メタを持つ）
  # When: docs/methodology/acceptance-test-feasibility.md の本文を検査する
  # Then: "> **Loaded by:**" 行が含まれる
  local root
  root="$(repo_root)"
  [[ -f "${root}/${DOCTRINE}" ]] || skip "${DOCTRINE} does not exist yet"
  grep -q '> \*\*Loaded by:\*\*' "${root}/${DOCTRINE}" || {
    echo "FAIL: ${DOCTRINE} does not contain '> **Loaded by:**' meta comment"
    return 1
  }
}

# ---------------------------------------------------------------------------
# AT-312-02: 普遍ルール（GUI / 非 GUI 二分岐と判定基準）
# ---------------------------------------------------------------------------

@test "AT-312-02a: doctrine has a universal-rules section" {
  # Given: doctrine 本文を読む
  # When: 普遍ルール節（見出しレベル問わず "universal" / "Universal Rules" / "普遍ルール" 等）を検査する
  # Then: 節が存在する
  local root
  root="$(repo_root)"
  [[ -f "${root}/${DOCTRINE}" ]] || skip "${DOCTRINE} does not exist yet"
  grep -qiE '## (Universal Rules|Feasibility Probe Doctrine|Universal|Core Doctrine)' "${root}/${DOCTRINE}" || {
    echo "FAIL: ${DOCTRINE} has no universal-rules section heading"
    return 1
  }
}

@test "AT-312-02b: universal rules section documents GUI vs non-GUI bifurcation" {
  # Given: doctrine 本文を読む
  # When: 普遍ルール節を検査する
  # Then: GUI（実操作）と 非 GUI（実 API call）の二分岐が記述されている
  local root
  root="$(repo_root)"
  [[ -f "${root}/${DOCTRINE}" ]] || skip "${DOCTRINE} does not exist yet"
  grep -qiE 'GUI' "${root}/${DOCTRINE}" || {
    echo "FAIL: ${DOCTRINE} has no GUI mention"
    return 1
  }
  grep -qiE '(non-GUI|non GUI|API call|非 GUI|非GUI)' "${root}/${DOCTRINE}" || {
    echo "FAIL: ${DOCTRINE} has no non-GUI / API call mention"
    return 1
  }
}

@test "AT-312-02c: universal rules section documents decision criteria for GUI vs non-GUI" {
  # Given: doctrine 本文を読む
  # When: 普遍ルール節を検査する
  # Then: 両者を振り分ける判定基準が記述されている
  local root
  root="$(repo_root)"
  [[ -f "${root}/${DOCTRINE}" ]] || skip "${DOCTRINE} does not exist yet"
  grep -qiE '(criteria|criterion|判定|decision|determines|judge|render|real|actual)' "${root}/${DOCTRINE}" || {
    echo "FAIL: ${DOCTRINE} has no decision criteria for GUI/non-GUI bifurcation"
    return 1
  }
}

# ---------------------------------------------------------------------------
# AT-312-03: フロー統合点（[planned] 確定前のプローブ）
# ---------------------------------------------------------------------------

@test "AT-312-03a: doctrine has a flow-integration section" {
  # Given: doctrine 本文を読む
  # When: フロー統合点節を検査する
  # Then: 節が存在する
  local root
  root="$(repo_root)"
  [[ -f "${root}/${DOCTRINE}" ]] || skip "${DOCTRINE} does not exist yet"
  grep -qiE '## (Flow Integration|Integration Point|Where to Integrate|Flow)' "${root}/${DOCTRINE}" || {
    echo "FAIL: ${DOCTRINE} has no flow-integration section"
    return 1
  }
}

@test "AT-312-03b: flow integration section mentions writing-plan-and-tests" {
  # Given: doctrine 本文を読む
  # When: フロー統合点節を検査する
  # Then: writing-plan-and-tests への言及がある
  local root
  root="$(repo_root)"
  [[ -f "${root}/${DOCTRINE}" ]] || skip "${DOCTRINE} does not exist yet"
  grep -qF 'writing-plan-and-tests' "${root}/${DOCTRINE}" || {
    echo "FAIL: ${DOCTRINE} does not mention 'writing-plan-and-tests'"
    return 1
  }
}

@test "AT-312-03c: flow integration section mentions [planned] state and probe before confirmation" {
  # Given: doctrine 本文を読む
  # When: フロー統合点節を検査する
  # Then: [planned] と、プローブを [planned] 確定前に通す旨が記述されている
  local root
  root="$(repo_root)"
  [[ -f "${root}/${DOCTRINE}" ]] || skip "${DOCTRINE} does not exist yet"
  grep -qF '[planned]' "${root}/${DOCTRINE}" || {
    echo "FAIL: ${DOCTRINE} does not mention '[planned]' lifecycle state"
    return 1
  }
  grep -qiE '(before|prior|前に|before confirming|before marking)' "${root}/${DOCTRINE}" || {
    echo "FAIL: ${DOCTRINE} does not describe probe-before-[planned] constraint"
    return 1
  }
}

# ---------------------------------------------------------------------------
# AT-312-04: ユーザーゲート（ルート不在／不安定時）
# ---------------------------------------------------------------------------

@test "AT-312-04a: doctrine has a user-gate section" {
  # Given: doctrine 本文を読む
  # When: ユーザーゲート節を検査する
  # Then: 節が存在する
  local root
  root="$(repo_root)"
  [[ -f "${root}/${DOCTRINE}" ]] || skip "${DOCTRINE} does not exist yet"
  grep -qiE '## (User Gate|Escalation Gate|User Judgment|User Escalation)' "${root}/${DOCTRINE}" || {
    echo "FAIL: ${DOCTRINE} has no user-gate section"
    return 1
  }
}

@test "AT-312-04b: user-gate section describes route-missing or unstable scenario" {
  # Given: doctrine 本文を読む
  # When: ユーザーゲート節を検査する
  # Then: 「ルート不在／不安定 → 計画段階でユーザー判断を仰ぐ」というゲート条件が記述されている
  local root
  root="$(repo_root)"
  [[ -f "${root}/${DOCTRINE}" ]] || skip "${DOCTRINE} does not exist yet"
  grep -qiE '(no route|route.*absent|not found|unstable|unavailable|missing|ルート不在|不安定)' "${root}/${DOCTRINE}" || {
    echo "FAIL: ${DOCTRINE} does not describe route-absent/unstable scenario in user-gate section"
    return 1
  }
  grep -qiE '(user judgment|human decision|user.*gate|ask.*user|ユーザー判断|ユーザーゲート|escalate|計画段階)' "${root}/${DOCTRINE}" || {
    echo "FAIL: ${DOCTRINE} does not describe user-judgment escalation in user-gate section"
    return 1
  }
}

# ---------------------------------------------------------------------------
# AT-312-05: ツール抽象（プローブ抽象・非密結合）
# ---------------------------------------------------------------------------

@test "AT-312-05a: doctrine has a tool-abstraction section" {
  # Given: doctrine 本文を読む
  # When: ツール抽象節を検査する
  # Then: 節が存在する
  local root
  root="$(repo_root)"
  [[ -f "${root}/${DOCTRINE}" ]] || skip "${DOCTRINE} does not exist yet"
  grep -qiE '## (Tool Abstraction|Tooling Abstraction|Probe Abstraction|Addon)' "${root}/${DOCTRINE}" || {
    echo "FAIL: ${DOCTRINE} has no tool-abstraction section"
    return 1
  }
}

@test "AT-312-05b: tool-abstraction section mentions probe abstraction concept" {
  # Given: doctrine 本文を読む
  # When: ツール抽象節を検査する
  # Then: 「プローブ」抽象が記述されている
  local root
  root="$(repo_root)"
  [[ -f "${root}/${DOCTRINE}" ]] || skip "${DOCTRINE} does not exist yet"
  grep -qiE '(probe|プローブ)' "${root}/${DOCTRINE}" || {
    echo "FAIL: ${DOCTRINE} does not mention 'probe' abstraction in tool-abstraction section"
    return 1
  }
}

@test "AT-312-05c: tool-abstraction section describes addon-supplied concrete tools (non-tight-coupling)" {
  # Given: doctrine 本文を読む
  # When: ツール抽象節を検査する
  # Then: addon が具体手段を供給し特定ツールに密結合しない旨が記述されている
  local root
  root="$(repo_root)"
  [[ -f "${root}/${DOCTRINE}" ]] || skip "${DOCTRINE} does not exist yet"
  grep -qiE '(addon|add-on)' "${root}/${DOCTRINE}" || {
    echo "FAIL: ${DOCTRINE} does not mention 'addon' as concrete tool supplier"
    return 1
  }
  grep -qiE '(not.*tight|non-tight|decoupled|not.*coupled|loose|無関係|非密結合|密結合しない)' "${root}/${DOCTRINE}" || {
    echo "FAIL: ${DOCTRINE} does not describe non-tight-coupling from specific tools"
    return 1
  }
}

# ---------------------------------------------------------------------------
# AT-312-06: autopilot 整合（design phase / Gate ②）と相互参照健全性
# ---------------------------------------------------------------------------

@test "AT-312-06a: doctrine has an autopilot-alignment section" {
  # Given: doctrine 本文を読む
  # When: autopilot 整合節を検査する
  # Then: 節が存在する
  local root
  root="$(repo_root)"
  [[ -f "${root}/${DOCTRINE}" ]] || skip "${DOCTRINE} does not exist yet"
  grep -qiE '## (Autopilot|autopilot)' "${root}/${DOCTRINE}" || {
    echo "FAIL: ${DOCTRINE} has no autopilot-alignment section"
    return 1
  }
}

@test "AT-312-06b: autopilot-alignment section mentions design phase and Gate 2" {
  # Given: doctrine 本文を読む
  # When: autopilot 整合節を検査する
  # Then: design phase と Gate ②（設計承認）への反映が記述されている
  local root
  root="$(repo_root)"
  [[ -f "${root}/${DOCTRINE}" ]] || skip "${DOCTRINE} does not exist yet"
  grep -qiE '(design phase|design.*phase)' "${root}/${DOCTRINE}" || {
    echo "FAIL: ${DOCTRINE} does not mention 'design phase' in autopilot-alignment section"
    return 1
  }
  grep -qiE '(Gate.?[②2]|Gate 2|design.*approval|設計承認)' "${root}/${DOCTRINE}" || {
    echo "FAIL: ${DOCTRINE} does not mention Gate② (design approval) in autopilot-alignment section"
    return 1
  }
}

@test "AT-312-06c: doctrine cross-references atdd-guide, test-mapping, definition-of-ready, test-execution-policy" {
  # Given: doctrine 本文を読む
  # When: 相互参照リンクを検査する
  # Then: 4 つの既存 doc への相対リンクが存在する
  local root
  root="$(repo_root)"
  [[ -f "${root}/${DOCTRINE}" ]] || skip "${DOCTRINE} does not exist yet"

  for ref_doc in atdd-guide test-mapping definition-of-ready test-execution-policy; do
    grep -qF "${ref_doc}" "${root}/${DOCTRINE}" || {
      echo "FAIL: ${DOCTRINE} does not reference '${ref_doc}'"
      return 1
    }
  done
}

@test "AT-312-06d: cross-referenced docs all exist on disk" {
  # Given: doctrine が参照先ファイルを列挙している
  # When: 参照先の実在を確認する
  # Then: 全 4 ファイルが存在する
  local root
  root="$(repo_root)"
  for f in atdd-guide.md test-mapping.md definition-of-ready.md test-execution-policy.md; do
    [[ -f "${root}/docs/methodology/${f}" ]] || {
      echo "FAIL: docs/methodology/${f} does not exist"
      return 1
    }
  done
}

@test "AT-312-06e: README.md Documents table lists acceptance-test-feasibility.md" {
  # Given: docs/methodology/README.md の Documents 表
  # When: acceptance-test-feasibility.md 行の存在を検査する
  # Then: README 表に acceptance-test-feasibility.md 行がある
  local root
  root="$(repo_root)"
  grep -qF 'acceptance-test-feasibility.md' "${root}/${README}" || {
    echo "FAIL: ${README} does not list 'acceptance-test-feasibility.md' in its Documents table"
    return 1
  }
}

# ---------------------------------------------------------------------------
# AT-312-07: 外部調査根拠節（一次情報リンク付き 3 件以上の要約）
# PRD Outcome line 24: 外部調査（agentic E2E / self-verifying AC / browser・mobile UI agent /
# API 探索検証）の傾向・採用事例・落とし穴が doctrine の根拠として要約・引用されている
# ---------------------------------------------------------------------------

@test "AT-312-07a: doctrine has an external-research-basis section" {
  # Given: PRD Outcome line 24 — 外部調査根拠が doctrine に含まれることが必須
  # When: docs/methodology/acceptance-test-feasibility.md の見出しを検査する
  # Then: Research / Evidence / External / 根拠 等を含む ## 見出しが存在する
  local root
  root="$(repo_root)"
  [[ -f "${root}/${DOCTRINE}" ]] || skip "${DOCTRINE} does not exist yet"
  grep -qiE '^## .*(Research|Evidence|External|Empirical|Prior Art|Industry|Basis)' "${root}/${DOCTRINE}" || {
    echo "FAIL: ${DOCTRINE} has no external-research-basis section (## Research / Evidence / External / Basis etc.)"
    return 1
  }
}

@test "AT-312-07b: doctrine research section contains at least 3 primary-source URLs" {
  # Given: plan Story 2 verify — 「一次情報リンク付きで 3 件以上要約」
  # When: docs/methodology/acceptance-test-feasibility.md 内の https:// リンクを数える
  # Then: https:// URL が 3 件以上存在する
  local root url_count
  root="$(repo_root)"
  [[ -f "${root}/${DOCTRINE}" ]] || skip "${DOCTRINE} does not exist yet"
  url_count=$(grep -oE 'https?://[^ )>]+' "${root}/${DOCTRINE}" | wc -l | tr -d ' ')
  [[ "${url_count}" -ge 3 ]] || {
    echo "FAIL: ${DOCTRINE} has ${url_count} URL(s); need at least 3 primary-source links"
    return 1
  }
}

@test "AT-312-07c: doctrine research section covers agentic-E2E, browser-mobile-agent, and API-contract-verification domains" {
  # Given: PRD line 24 — agentic E2E / self-verifying AC / browser・mobile UI agent / API 探索検証
  # When: docs/methodology/acceptance-test-feasibility.md を検査する
  # Then: 3 領域（agentic E2E, browser/mobile agent, API contract verification）への言及がある
  local root
  root="$(repo_root)"
  [[ -f "${root}/${DOCTRINE}" ]] || skip "${DOCTRINE} does not exist yet"
  # Domain 1: agentic E2E
  grep -qiE '(agentic.*E2E|E2E.*agent|agentic.*test|autonomous.*test)' "${root}/${DOCTRINE}" || {
    echo "FAIL: ${DOCTRINE} does not mention agentic E2E testing in research section"
    return 1
  }
  # Domain 2: browser / mobile UI agent
  grep -qiE '(browser.*agent|mobile.*agent|Playwright.*agent|UI.*agent|agent.*browser|agent.*mobile)' "${root}/${DOCTRINE}" || {
    echo "FAIL: ${DOCTRINE} does not mention browser/mobile UI agent in research section"
    return 1
  }
  # Domain 3: API / contract verification
  grep -qiE '(API.*contract|contract.*test|OpenAPI|contract.*verif|API.*verif)' "${root}/${DOCTRINE}" || {
    echo "FAIL: ${DOCTRINE} does not mention API contract verification in research section"
    return 1
  }
}

# ---------------------------------------------------------------------------
# AT-312-08: back-references from existing 4 docs (bidirectional cross-references)
# PRD Outcome line 23: 「既存 methodology doc と矛盾せず、相互参照が張られている」
# — implies bidirectional: doctrine->4 docs + 4 docs->doctrine
# ---------------------------------------------------------------------------

@test "AT-312-08a: atdd-guide.md back-references acceptance-test-feasibility.md" {
  # Given: PRD line 23 — 双方向相互参照
  # When: docs/methodology/atdd-guide.md を検査する
  # Then: acceptance-test-feasibility への参照が存在する
  local root
  root="$(repo_root)"
  grep -qF 'acceptance-test-feasibility' "${root}/docs/methodology/atdd-guide.md" || {
    echo "FAIL: docs/methodology/atdd-guide.md does not reference acceptance-test-feasibility.md"
    return 1
  }
}

@test "AT-312-08b: test-mapping.md back-references acceptance-test-feasibility.md" {
  # Given: PRD line 23 — 双方向相互参照
  # When: docs/methodology/test-mapping.md を検査する
  # Then: acceptance-test-feasibility への参照が存在する
  local root
  root="$(repo_root)"
  grep -qF 'acceptance-test-feasibility' "${root}/docs/methodology/test-mapping.md" || {
    echo "FAIL: docs/methodology/test-mapping.md does not reference acceptance-test-feasibility.md"
    return 1
  }
}

@test "AT-312-08c: definition-of-ready.md back-references acceptance-test-feasibility.md" {
  # Given: PRD line 23 — 双方向相互参照
  # When: docs/methodology/definition-of-ready.md を検査する
  # Then: acceptance-test-feasibility への参照が存在する
  local root
  root="$(repo_root)"
  grep -qF 'acceptance-test-feasibility' "${root}/docs/methodology/definition-of-ready.md" || {
    echo "FAIL: docs/methodology/definition-of-ready.md does not reference acceptance-test-feasibility.md"
    return 1
  }
}

@test "AT-312-08d: test-execution-policy.md back-references acceptance-test-feasibility.md" {
  # Given: PRD line 23 — 双方向相互参照
  # When: docs/methodology/test-execution-policy.md を検査する
  # Then: acceptance-test-feasibility への参照が存在する
  local root
  root="$(repo_root)"
  grep -qF 'acceptance-test-feasibility' "${root}/docs/methodology/test-execution-policy.md" || {
    echo "FAIL: docs/methodology/test-execution-policy.md does not reference acceptance-test-feasibility.md"
    return 1
  }
}
