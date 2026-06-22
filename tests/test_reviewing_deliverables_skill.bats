#!/usr/bin/env bats
# @covers: skills/reviewing-deliverables/SKILL.md
# Unit Test for the reviewing-deliverables skill (#234 / #179 Step B5).
# Per `docs/testing-skills.md` (#222), this is a Unit Test — `claude` is not
# invoked; structural / wording-level invariants are checked via grep. LLM
# behavior is covered by the companion Skill E2E Test at
# `tests/e2e/reviewing-deliverables.bats`.
#
# Scope (per #234): the skill replaces the former fixed 6-subagent SERIAL roster
# with a Workflow-tool review that (a) generates the reviewer panel DYNAMICALLY
# from the deliverable content, (b) reviews in PARALLEL, (c) verifies findings
# across multiple ADVERSARIAL rounds, and (d) covers functional + non-functional
# (security / performance / usability) + clean-code / testability + positive
# (advocate) / negative (skeptic) stances. Standard responsibility / language /
# budget gates are retained. The serial constraint is dissolved because the
# Workflow tool isolates each agent() context (#216 PRD OQ#1 was deferred here).

SKILL_FILE="skills/reviewing-deliverables/SKILL.md"

# --- Workflow-based mechanism ---------------------------------------------

@test "mechanism: SKILL.md drives the review through the Workflow tool" {
  grep -q 'Workflow' "$SKILL_FILE"
}

@test "mechanism: SKILL.md embeds a runnable workflow script (export const meta)" {
  grep -q 'export const meta' "$SKILL_FILE"
}

@test "mechanism: the workflow has the five phases Scout/Generate/Review/Verify/Aggregate" {
  grep -q 'Scout' "$SKILL_FILE"
  grep -q 'Generate' "$SKILL_FILE"
  grep -q 'Review' "$SKILL_FILE"
  grep -q 'Verify' "$SKILL_FILE"
  grep -q 'Aggregate' "$SKILL_FILE"
}

# --- Dynamic reviewer generation ------------------------------------------

@test "dynamic: reviewers are generated dynamically from the deliverable, not a fixed roster" {
  grep -qiE 'dynamic' "$SKILL_FILE"
  grep -qiE 'scout' "$SKILL_FILE"
  # the panel scales with the change rather than enumerating a fixed list
  grep -qiE 'scale|derive|generate the reviewer panel|panel' "$SKILL_FILE"
}

# --- Parallel execution (replaces serial) ---------------------------------

@test "execution: SKILL.md runs the reviewers in parallel" {
  grep -qiE 'parallel|pipeline' "$SKILL_FILE"
}

# --- Multi-round adversarial verification ---------------------------------

@test "verify: findings are challenged across multiple adversarial rounds" {
  grep -qiE 'adversarial' "$SKILL_FILE"
  grep -qiE 'round|majority|refute|challenge' "$SKILL_FILE"
}

# --- Multi-perspective coverage (functional + non-functional + stances) ----

@test "coverage: non-functional lenses (security / performance / usability)" {
  grep -qiE 'security' "$SKILL_FILE"
  grep -qiE 'performance' "$SKILL_FILE"
  grep -qiE 'usability' "$SKILL_FILE"
}

@test "coverage: clean-code and testability lenses" {
  grep -qiE 'clean-code|clean code|cleanliness' "$SKILL_FILE"
  grep -qiE 'testability' "$SKILL_FILE"
}

@test "coverage: documentation lens is an ALWAYS-include lens (#241)" {
  grep -qiE 'documentation' "$SKILL_FILE"
  # the ALWAYS-include list in the Generate prompt names documentation
  grep -qE 'ALWAYS include these lenses:.*documentation' "$SKILL_FILE"
}

@test "coverage: documentation lens checks accuracy, consistency, and follow-through/sync (#241)" {
  grep -qiE 'accuracy' "$SKILL_FILE"
  grep -qiE 'consistency' "$SKILL_FILE"
  grep -qiE 'follow-through|sync' "$SKILL_FILE"
  # the DEVELOPMENT.md README/CHANGELOG/version follow-through invariant
  grep -qE 'README' "$SKILL_FILE"
  grep -qiE 'CHANGELOG' "$SKILL_FILE"
  grep -qE 'plugin\.json' "$SKILL_FILE"
}

@test "coverage: positive (advocate) and negative (skeptic) stances" {
  grep -qiE 'advocate' "$SKILL_FILE"
  grep -qiE 'skeptic' "$SKILL_FILE"
}

# --- Verification via AT ---------------------------------------------------

@test "verification: SKILL.md states runtime behavior is verified by Acceptance Tests" {
  grep -qiE 'acceptance test' "$SKILL_FILE"
}

@test "verification: SKILL.md does not mandate manual / preview verification" {
  grep -qiE 'manual' "$SKILL_FILE"
  grep -qiE 'not (require|mandat|force)|no manual|without manual|not mandatory' "$SKILL_FILE"
}

# --- Single PASS/FAIL verdict ---------------------------------------------

@test "output: the Aggregate phase produces a single PASS / FAIL verdict" {
  grep -qE 'PASS' "$SKILL_FILE"
  grep -qE 'FAIL' "$SKILL_FILE"
}

# --- Line budget ----------------------------------------------------------

@test "line budget: SKILL.md is at most 240 lines (raised for the embedded workflow script)" {
  local n
  n=$(wc -l < "$SKILL_FILE" | tr -d ' ')
  [ "$n" -le 240 ]
}

# --- Responsibility boundary ----------------------------------------------

@test "responsibility: Upstream is running-atdd-cycle" {
  grep -qE '\*\*Upstream:\*\*[[:space:]]+`running-atdd-cycle`' "$SKILL_FILE"
}

@test "responsibility: Downstream is merging-and-deploying (Step 6 ownership)" {
  grep -qE '\*\*Downstream:\*\*[[:space:]]+`merging-and-deploying`' "$SKILL_FILE"
}

@test "responsibility: SKILL.md states in-progress label management is out of scope" {
  grep -qE '\*\*does not\*\* add or remove the `in-progress` label' "$SKILL_FILE"
}

# --- Output language ------------------------------------------------------

@test "output language: SKILL.md fixes output language to Japanese" {
  grep -qE 'Output language:[[:space:]]+Japanese' "$SKILL_FILE"
}

# --- Persona-less invariant (User Story form, unrelated to reviewer personas)

@test "no persona: SKILL.md does not introduce 'As a [persona]' line" {
  ! grep -qE '^As a ' "$SKILL_FILE"
}

# --- Structured verdict for autopilot loop control (#246) ------------------
# The Aggregate output is extended (backward-compatibly) so autopilot
# can drive its satisfaction-oracle loop from a machine-readable verdict.

@test "structured verdict: AGG_SCHEMA carries overall_correctness (#246)" {
  grep -qE 'overall_correctness' "$SKILL_FILE"
}

@test "structured verdict: findings carry priority, confidence and evidence_ref (#246)" {
  grep -qE 'evidence_ref' "$SKILL_FILE"
  grep -qE 'priority' "$SKILL_FILE"
  grep -qE 'confidence' "$SKILL_FILE"
}

@test "structured verdict: backward-compatible — verdict/summary/byLens retained (#246)" {
  grep -qE "verdict:" "$SKILL_FILE"
  grep -qE 'summary' "$SKILL_FILE"
  grep -qE 'byLens' "$SKILL_FILE"
}

@test "structured verdict: autopilot fields stay OPTIONAL — top-level required excludes them (#246)" {
  # the machine-readable additions must not enter AGG_SCHEMA's top-level required,
  # or non-autopilot callers that omit them would fail validation (backward break).
  grep -qE "required: \['verdict', 'summary', 'byLens'\]" "$SKILL_FILE"
  ! grep -qE "required: \[[^]]*overall_correctness" "$SKILL_FILE"
  ! grep -qE "required: \['verdict', 'summary', 'byLens'[^]]*findings" "$SKILL_FILE"
}

@test "structured verdict: findings items require priority + evidence_ref so the oracle can't read undefined as non-blocking (#246)" {
  grep -qE "required: \['priority', 'evidence_ref'\]" "$SKILL_FILE"
}

@test "fail-safe: aggregate never drops a confirmed P0/P1; the old fail-open drop is gone (#246)" {
  grep -qiE 'never drop a confirmed P0/P1|fail-safe, not fail-open' "$SKILL_FILE"
  ! grep -qE 'Drop any finding that has no evidence_ref' "$SKILL_FILE"
}

# --- Phase model assignment (#259) ------------------------------------------
# Scout〜Verify run on Sonnet (bench #259: equal functional quality, ~1/4 cost);
# Aggregate alone inherits the session model (final PASS/FAIL judgment stays
# on the strongest model).

@test "model (#259): Scout / Generate / Review / Verify agent() options pin model: 'sonnet' (AT-001)" {
  grep -qF "{ phase: 'Scout', model: 'sonnet', schema: SCOUT_SCHEMA }" "$SKILL_FILE"
  grep -qF "{ phase: 'Generate', model: 'sonnet', schema: PANEL_SCHEMA }" "$SKILL_FILE"
  grep -qF "phase: 'Review', model: 'sonnet', schema: FINDINGS_SCHEMA" "$SKILL_FILE"
  grep -qF "phase: 'Verify', model: 'sonnet', schema: VERDICT_SCHEMA" "$SKILL_FILE"
}

@test "model (#259): Aggregate agent() carries NO model — session inheritance with a reason comment (AT-002)" {
  # the Aggregate options stay exactly { phase: 'Aggregate', schema: AGG_SCHEMA }
  grep -qF "{ phase: 'Aggregate', schema: AGG_SCHEMA }" "$SKILL_FILE"
  ! grep -qE "phase: 'Aggregate'[^}]*model" "$SKILL_FILE"
  grep -qF "#259: Aggregate inherits the session model" "$SKILL_FILE"
}

@test "model (#259): prose note documents the assignment outside the script (AT-001/AT-002)" {
  # the Review mechanism section states Scout〜Verify = sonnet, Aggregate = session model
  grep -qE 'Model assignment' "$SKILL_FILE"
  grep -qiE 'session model' "$SKILL_FILE"
}

# --- #355 F3: 多視点合議制（N=3 panel + 2/3 majority）---------------------

@test "AT-355-F3-1: Aggregate rules specify N=3 panel (functional-correctness/safety/design-validity) and 2/3 majority adoption" {
  # N=3（機能正当性 / 安全性 / 設計妥当性）パネル構成が明記されていること
  grep -qiE 'functional.correctness|機能正当性' "$SKILL_FILE"
  # 2/3 majority ルールが Aggregate 規則に記述されていること
  grep -qiE '2/3|majority|過半数' "$SKILL_FILE"
  # blocker/major の majority 採用ルールが明記されていること
  grep -qiE 'majority.*blocker|majority.*major|blocker.*majority|major.*majority' "$SKILL_FILE"
}

@test "AT-355-F3-2: single-lens solo findings get severity downgraded one level" {
  # 単一レンズの単独所見は severity を一段下げる旨が明記されていること
  grep -qiE 'single.*lens.*sever|sever.*single.*lens|単一レンズ.*下げ|下げ.*単一レンズ|solo.*sever|sever.*downgrad' "$SKILL_FILE"
}

# --- #355 F4: ラウンド横断の収束／停止条件 -----------------------------------

@test "AT-355-F4-1: CONVERGED conditions are defined (zero new blocker/major OR only design/scope-out remaining)" {
  # CONVERGED の二条件が記述されていること
  grep -qiE 'CONVERGED' "$SKILL_FILE"
  # 条件 a: 新規 blocker/major ゼロ
  grep -qiE 'zero.*blocker|no.*blocker.*major|blocker.*ゼロ|新規.*blocker' "$SKILL_FILE"
  # 条件 b: 設計判断・スコープ外タグのみ残存で CONVERGED
  grep -qiE 'design.*judgment|out.of.scope|scope.out|設計判断|スコープ外' "$SKILL_FILE"
}

@test "AT-355-F4-2: maximum round limit is defined to prevent infinite FAIL loops" {
  # 最大ラウンド数上限が定義されていること
  grep -qiE 'max.*round|round.*max|最大ラウンド|ラウンド.*上限' "$SKILL_FILE"
}

# --- #355 F5: スコープガード（out-of-scope 分離）-----------------------------

@test "AT-355-F5-1: Scout has scope guard extracting boundary from PRD/US and tagging out-of-scope findings" {
  # Scout が PRD/US から境界を抽出し out-of-scope タグで分離することが記述されていること
  grep -qiE 'out.of.scope|スコープ外' "$SKILL_FILE"
  # out-of-scope は FAIL 要因にならず follow-up 候補へ回すことが記述されていること
  grep -qiE 'out.of.scope.*not.*fail|out.of.scope.*follow.up|not.*fail.*out.of.scope|スコープ外.*FAIL.*しない' "$SKILL_FILE"
}

# --- #355 F6: 設計判断のラウンド間記憶 ---------------------------------------

@test "AT-355-F6-1: deliberate trade-offs declared via docstring/ADR are not re-raised across rounds" {
  # 意図的トレードオフがラウンド間で再提出されないことが記述されていること
  grep -qiE 'deliberate.*trade.?off|trade.?off.*deliberate|意図的.*トレードオフ|トレードオフ.*意図的' "$SKILL_FILE"
  # docstring または ADR で宣言したものは合議で不当判定されない限り再提出しないルールが明記されていること
  grep -qiE 'docstring|ADR' "$SKILL_FILE"
  grep -qiE 'round.*memory|memory.*round|ラウンド.*記憶|記憶.*ラウンド|not.*re.submit|re.raised' "$SKILL_FILE"
}

# --- #355 F7: severity 較正の単一化 ------------------------------------------

@test "AT-355-F7-1: severity is assigned once after cross-lens merge (no duplicate assignment)" {
  # レンズ横断マージ後に 1 回だけ severity を付与する旨が記述されていること
  grep -qiE 'merge.*sever|sever.*merge|cross.lens.*merge|重複.*sever|severity.*once|once.*severity' "$SKILL_FILE"
  # 重複付与を排除するルールが明記されていること
  grep -qiE 'deduplic|dedup|重複.*排除|排除.*重複|no.*duplicate.*sever|duplicate.*severity.*eliminat' "$SKILL_FILE"
}
