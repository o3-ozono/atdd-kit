#!/usr/bin/env bats
# @covers: skills/autopilot/SKILL.md
# Unit Test for the autopilot skill (autopilot orchestrator, #246).
# claude is NOT invoked; structural / wording invariants are checked via grep.
# LLM behavior is covered by tests/e2e/autopilot.bats.
#
# Scope (#246, gates re-placed in #249): autopilot is the autopilot MODE — a thin
# orchestrator that runs the EXISTING flow skills, narrows the human gates to three
# (requirements approval at the start, design approval before ATDD, merge at the
# end), and loops generate→review→fix until a satisfaction oracle (AND of green AT,
# reviewer verdict, zero P0/P1) holds, with safety rails.
# It does NOT permanently change the flow skills; their role changes only under autopilot.

SKILL_FILE="skills/autopilot/SKILL.md"

# --- Identity -------------------------------------------------------------

@test "identity: name field matches directory (kebab-case)" {
  local name
  name=$(grep '^name:' "$SKILL_FILE" | sed 's/^name:[[:space:]]*//')
  [ "$name" = "autopilot" ]
}

@test "identity: description starts with Use when (trigger-only)" {
  local desc
  desc=$(grep '^description:' "$SKILL_FILE" | sed 's/^description:[[:space:]]*//' | tr -d '"')
  [[ "$desc" == "Use when"* ]]
}

# --- Half-automated orchestration over EXISTING flow skills (F1) ----------

@test "orchestration: drives the existing flow skills in order (F1)" {
  grep -q 'extracting-user-stories' "$SKILL_FILE"
  grep -q 'writing-plan-and-tests' "$SKILL_FILE"
  grep -q 'running-atdd-cycle' "$SKILL_FILE"
  grep -q 'reviewing-deliverables' "$SKILL_FILE"
}

@test "orchestration: human gates fixed to three points — requirements, design approval, merge (F1/AL-1, #249)" {
  grep -qiE 'human gate|人間ゲート' "$SKILL_FILE"
  grep -qiE 'requirements approval|defining-requirements' "$SKILL_FILE"
  grep -qiE 'design approval|design-approval' "$SKILL_FILE"
  grep -qiE 'merge' "$SKILL_FILE"
  grep -qiE 'exactly three' "$SKILL_FILE"
  # the old two-gate contract must be gone
  ! grep -qiE 'exactly two|two gates only' "$SKILL_FILE"
}

@test "gates (#249): ATDD never starts before the design-approval gate" {
  # the user-expected flow: 壁打ち → design review → approval → ATDD
  grep -qiE 'ATDD never starts before (this|the design-approval) gate' "$SKILL_FILE"
  # design phase loops only the design steps; running-atdd-cycle is impl-only
  grep -qE "\['extracting-user-stories', 'writing-plan-and-tests'\]" "$SKILL_FILE"
  grep -qE "\['running-atdd-cycle'\]" "$SKILL_FILE"
  # fail-closed: looping the AT step inside the design phase must throw
  grep -qE "PHASE === 'design' && STEPS\.includes\(AT_STEP\)" "$SKILL_FILE"
}

@test "gates (#249): design-gate rejection comments re-enter the design loop as findings" {
  grep -qiE 'evidence_ref.*human comment|human comment.*evidence_ref' "$SKILL_FILE"
}

@test "non-goal: flow skills are not permanently changed (role changes only under autopilot, C1)" {
  grep -qiE 'only under autopilot|autopilot を使った場合のみ|恒久(的に)?変更しない|does not permanently change' "$SKILL_FILE"
}

# --- Satisfaction oracle (F2) ---------------------------------------------

@test "oracle: satisfaction oracle is AND of green AT, verdict, zero P0/P1 (F2)" {
  grep -qiE 'satisfaction oracle|満足オラクル' "$SKILL_FILE"
  grep -qE 'AND' "$SKILL_FILE"
  grep -qiE 'overall_correctness|verdict' "$SKILL_FILE"
  grep -qiE 'P0/P1|P0|P1' "$SKILL_FILE"
}

@test "oracle: loops generate -> review -> fix (F2)" {
  grep -qiE 'generate' "$SKILL_FILE"
  grep -qiE 'review' "$SKILL_FILE"
  grep -qiE 'fix' "$SKILL_FILE"
}

# --- Safety rails (F3) ----------------------------------------------------

@test "safety: MAX_ITERATIONS / sameness / stuck / COMPLETED_WITH_DEBT / escalation (F3/AL-5)" {
  grep -qE 'MAX_ITERATIONS' "$SKILL_FILE"
  grep -qiE 'sameness' "$SKILL_FILE"
  grep -qiE 'stuck' "$SKILL_FILE"
  grep -qE 'COMPLETED_WITH_DEBT' "$SKILL_FILE"
  grep -qiE 'escalat' "$SKILL_FILE"
}

@test "safety: reuses lib/autopilot_convergence.sh for the rails (F3)" {
  grep -q 'lib/autopilot_convergence.sh' "$SKILL_FILE"
}

@test "audit: each iteration verdict is persisted to autopilot-log.jsonl (F3/AL-4)" {
  grep -q 'autopilot-log.jsonl' "$SKILL_FILE"
}

# --- autopilot Iron Law (F4) ----------------------------------------------

@test "iron-law: references the autopilot Iron Law that overrides the standard one (F4)" {
  grep -q 'autopilot-iron-law' "$SKILL_FILE"
}

# --- Workflow mechanism ---------------------------------------------------

@test "mechanism: drives the loop through the Workflow tool (export const meta)" {
  grep -q 'Workflow' "$SKILL_FILE"
  grep -q 'export const meta' "$SKILL_FILE"
}

# --- Output language ------------------------------------------------------

@test "output language: SKILL.md fixes output language to Japanese" {
  grep -qE 'Output language:[[:space:]]+Japanese' "$SKILL_FILE"
}

# --- Responsibility / Integration -----------------------------------------

@test "integration: has Integration section with Upstream/Downstream" {
  grep -q '## Integration' "$SKILL_FILE"
  grep -q 'Upstream:' "$SKILL_FILE"
  grep -q 'Downstream:' "$SKILL_FILE"
}

# --- Line budget ----------------------------------------------------------

@test "line budget (#254: Dialog economy section): SKILL.md is at most 260 lines" {
  # 240 → 260 (#254): the Dialog economy section adds ~10 lines of human-dialog
  # discipline that must live in the orchestrator (C1: flow skills stay unedited)
  local n
  n=$(wc -l < "$SKILL_FILE" | tr -d ' ')
  [ "$n" -le 260 ]
}

# --- Code-deep oracle (#246 review: rails/oracle must be code, not just prose)

@test "oracle: AT-green is DETERMINISTIC (test exit code), not an LLM opinion (AL-3)" {
  grep -qiE 'deterministic AT gate' "$SKILL_FILE"
  grep -qiE 'exit code' "$SKILL_FILE"
  grep -qE 'AL-3' "$SKILL_FILE"
  # the inert "!verdict.atRequired || verdict.atGreen" leg (always-true) must be gone
  ! grep -qE '!verdict\.atRequired' "$SKILL_FILE"
}

@test "oracle: AC→AT coverage gate is wired and run in a separate context (AL-2)" {
  grep -qiE 'coverage gate' "$SKILL_FILE"
  grep -qiE 'separate from the AT author' "$SKILL_FILE"
  grep -qE 'AL-2' "$SKILL_FILE"
}

@test "oracle: fail-safe — confirmed P0/P1 blocks regardless of evidence_ref" {
  grep -qiE 'fail-safe' "$SKILL_FILE"
  grep -qE 'priorityOf' "$SKILL_FILE"
  # the old fail-OPEN filter (required evidence_ref to even count as blocking) must be gone
  ! grep -qE 'f\.evidence_ref && f\.priority' "$SKILL_FILE"
}

@test "oracle: consumer schema requires priority + evidence_ref in findings items" {
  grep -qE "required: \['priority', 'evidence_ref'\]" "$SKILL_FILE"
}

@test "rails: a non-zero record_iteration (corrupt/empty fingerprint) is itself a halt" {
  grep -qiE 'record-error' "$SKILL_FILE"
}

# --- round-2 hardening regression guards (#246 second review) -------------

@test "audit: the log path uses the slug-suffixed issue dir, not the bare number" {
  # regression guard for the round-2 blocker: docs/issues/<NNN>/ would write to a
  # phantom dir and break AL-4. It must resolve docs/issues/<NNN>-*/ like the gate.
  grep -qE 'docs/issues/\$\{NNN\}-\*' "$SKILL_FILE"
  ! grep -qE 'docs/issues/\$\{NNN\}/autopilot-log' "$SKILL_FILE"
}

@test "config: AT_STEP must be one of STEPS (fail-closed, gates can't silently vanish)" {
  grep -qE 'STEPS\.includes\(AT_STEP\)' "$SKILL_FILE"
}

@test "rails: the halt is computed in JS from raw exit codes, not summarized by the LLM" {
  grep -qE 'maxIterExit|samenessExit|stuckExit' "$SKILL_FILE"
  grep -qE "halt = .*MAX_ITERATIONS" "$SKILL_FILE"
}

@test "audit: record_iteration is invoked with its full 5-arg signature" {
  # the rails prompt must pass <jsonl> <it> <step> <verdict> <fp>, not 2 args
  grep -qE 'record_iteration "<resolved-log-path>" \$\{it\} \$\{step\}' "$SKILL_FILE"
}

@test "AL-2: the approved anchor is pinned at phase start and drift halts the loop (enforced freeze)" {
  grep -qE 'pin_anchor' "$SKILL_FILE"
  grep -qE 'check_pin' "$SKILL_FILE"
  grep -qiE 'ac-drift' "$SKILL_FILE"
  # the impl freeze pins the human-approved source (prd + user-stories), not the loop-mutable AT
  grep -qE 'prd\.md .*user-stories\.md' "$SKILL_FILE"
}

@test "AL-2 (#249): one pin per phase — design anchors to PRD, impl to the design-gate-approved set" {
  # design phase pin: prd.md only (the loop edits user-stories.md, so pinning it
  # there would guarantee a false ac-drift halt — the #249 contradiction)
  grep -qE 'autopilot-prd\.pin' "$SKILL_FILE"
  grep -qE 'autopilot-design\.pin' "$SKILL_FILE"
  # a pin must never cover an artifact the same phase's loop may edit
  grep -qiE 'never an artifact (this|the same) phase' "$SKILL_FILE"
  # acceptance-tests.md is NOT pinned (lifecycle markers move); coverage gate guards it
  grep -qiE 'acceptance-tests\.md is NOT pinned' "$SKILL_FILE"
  # the single-pin two-gate freeze must be gone
  ! grep -qE 'autopilot-ac\.pin' "$SKILL_FILE"
}

@test "AL-2 (#249): phase re-entry verifies the existing pin instead of bricking the freeze" {
  # a design-gate rejection re-runs the design phase; pin_anchor refuses overwrite,
  # so the freeze must fall back to check_pin against the existing pin
  grep -qiE 'already exists.*check_pin' "$SKILL_FILE"
}

# --- #252 prompt-defect regression guards ----------------------------------

@test "audit (#252): the placeholder fingerprint instruction is gone (AC1)" {
  # the literal placeholder used to be hashed as-is (constant 2aed7ea6… in the log)
  ! grep -qF '<the blocking findings text, verbatim>' "$SKILL_FILE"
  ! grep -q 'Run EXACTLY' "$SKILL_FILE"
}

@test "audit (#252): findings payload is embedded between markers and hashed via quoted heredoc (AC1)" {
  grep -q 'BEGIN-PAYLOAD' "$SKILL_FILE"
  grep -q 'END-PAYLOAD' "$SKILL_FILE"
  grep -qE 'JSON\.stringify\(blocking\)' "$SKILL_FILE"
  grep -qi 'quoted heredoc' "$SKILL_FILE"
}

@test "review (#252): scope is phase x step aware — design phase never demands production code (AC2)" {
  grep -qE 'reviewScope' "$SKILL_FILE"
  # design phase: absence of production code / executable AT is NOT a finding
  grep -qE 'their absence is NOT a finding' "$SKILL_FILE"
  # the review prompt concatenates the scope helper
  grep -qE '\$\{reviewScope\(step\)\}' "$SKILL_FILE"
}

@test "review (#252): US step scope excludes plan.md / acceptance-tests.md (AC3)" {
  grep -qE 'do NOT return findings on plan\.md / acceptance-tests\.md' "$SKILL_FILE"
}

@test "gen (#252): iteration 2+ embeds the previous findings text verbatim (AC4)" {
  # the gen call branches on prevFindings: iteration 1 keeps the legacy wording,
  # later iterations embed the findings JSON — never a body-less "fix them verbatim"
  grep -qE 'await agent\(prevFindings' "$SKILL_FILE"
  grep -qE 'JSON\.stringify\(prevFindings\)' "$SKILL_FILE"
  grep -qE 'prevFindings = verdict\.findings' "$SKILL_FILE"
}

@test "args (#252, refs #256): defensive parse + fail-closed integer guard are pinned" {
  # the harness may deliver Workflow args as a JSON string (#256 incident:
  # issue=undefined ran the loop against a phantom dir) — both guards must stay
  grep -qE "typeof args === 'string' \? JSON\.parse\(args\)" "$SKILL_FILE"
  grep -qE 'Number\.isInteger\(NNN\)' "$SKILL_FILE"
  grep -qE 'refusing to run with an unresolvable issue dir' "$SKILL_FILE"
}

@test "args (#256): phase guard is fail-closed — no impl→design fallback, JSON-object note on both invokes" {
  # (a) the old ternary (A.phase === 'impl' ? 'impl' : 'design') silently ran an
  # impl invocation as design when args arrived stringified — explicit guard only
  grep -qE "A\.phase !== 'design' && A\.phase !== 'impl'" "$SKILL_FILE"
  grep -qE 'refusing to default to design' "$SKILL_FILE"
  # (b) the silent fallback must be gone, and PHASE must be the bare post-guard
  # assignment — a re-regression like `A.phase ?? 'design'` must not pass (AT-002)
  ! grep -qE "A\.phase === 'impl' \? 'impl' : 'design'" "$SKILL_FILE"
  grep -qE "const PHASE = A\.phase$" "$SKILL_FILE"
  # (c) Flow steps 2 and 4 both instruct passing args as a JSON object
  [ "$(grep -c '文字列化した JSON を渡さない' "$SKILL_FILE")" -eq 2 ]
}

# --- #262: 監査ログ fail-closed ガードの配管 --------------------------------
# check_sameness / check_stuck はログ前提のため、ログ削除・巻き戻しで黙って
# 無効化される（fail-open）。orchestrator がメモリ上で期待行数を追跡し、
# rails の check_log_integrity に渡す配管を pin する。

# AT-006: rails が新ガードを呼び、halt 理由 'log-integrity' を持つ
@test "rails (#262): check_log_integrity is wired into the rails call (AT-006)" {
  # rails prompt は orchestrator 追跡の期待行数 ${recorded} を渡す
  grep -qE 'check_log_integrity "<log>" \$\{recorded\}' "$SKILL_FILE"
  # schema は生の exit code を返す（LLM 要約ではなく JS 側で halt 判定）
  grep -qE 'logIntegrityExit' "$SKILL_FILE"
  # halt 理由 'log-integrity' が存在し、acDriftExit 判定の直後に来る
  # （sameness / stuck はログを前提とするため、それらより先に理由判定する）
  grep -qE "acDriftExit !== 0 \? 'ac-drift' : r\.logIntegrityExit !== 0 \? 'log-integrity'" "$SKILL_FILE"
}

# AT-007: 期待行数の真実が freeze（baseline）→ audit（increment）で一貫維持される
@test "freeze/audit (#262): logLines baseline + recorded counter survive freeze to audit (AT-007)" {
  # freeze agent はログの現在行数を logLines として報告する（再入・phase 跨ぎ吸収）
  grep -qE 'logLines' "$SKILL_FILE"
  # baseline 吸収: recorded は frozen.logLines で初期化される
  grep -qE 'let recorded = frozen\.logLines' "$SKILL_FILE"
  # record_iteration 成功 = ログ +1 行をメモリ側の真実に反映する
  grep -qE 'recorded\+\+' "$SKILL_FILE"
}

# --- Dialog economy (#254) -------------------------------------------------

@test "dialog economy (#254): asks only human-only decisions (US-1)" {
  # questions are limited to what a human alone can decide:
  # trade-offs / 割り切り, scope changes, Outcome pass/fail criteria
  # ('scope changes', not bare 'scope' — the bare word also matches reviewScope code)
  grep -qi 'ask ONLY' "$SKILL_FILE"
  grep -qi 'trade-off' "$SKILL_FILE"
  grep -qi 'scope changes' "$SKILL_FILE"
  grep -q 'Outcome pass/fail criteria' "$SKILL_FILE"
  # derivability must be operationally defined, not left to LLM judgment (P0)
  grep -qi 'mechanically reconstructable' "$SKILL_FILE"
}

@test "dialog economy (#254): drafts are batch-presented, approved once per fixed gate (US-2)" {
  # no section-by-section ok-loops: draft everything derivable, present in bulk,
  # approve / send back once at each fixed gate (PRD approval / design approval / merge)
  grep -qi 'batch-present' "$SKILL_FILE"
  grep -qi 'never ask section-by-section' "$SKILL_FILE"
}

@test "dialog economy (#254): directive lives in the orchestrator and covers all gate dialogs (US-3/CS-2)" {
  # the directive is the orchestrator's (C1: flow skills are never edited for autopilot)
  # and applies to every human-facing dialog, not just Gate ①
  grep -q '## Dialog economy' "$SKILL_FILE"
  grep -qi 'all human-facing dialog under autopilot' "$SKILL_FILE"
  grep -qF 'one question at a time' "$SKILL_FILE"
  grep -qi 'overrid' "$SKILL_FILE"
  [ "$(grep -c 'Dialog economy' "$SKILL_FILE")" -ge 3 ]
}

@test "dialog economy (#254): gates stay exactly three (CS-1)" {
  # the section removes micro-confirmations only — never a gate (AL-1 invariant)
  grep -q 'exactly three' "$SKILL_FILE"
  grep -qi 'never a gate' "$SKILL_FILE"
  # count-based pin: a 4th numbered gate item would keep the strings above intact,
  # so count the numbered items inside the Human gates section itself
  local gates
  gates=$(sed -n '/^## Human gates/,/^## Dialog economy/p' "$SKILL_FILE" | grep -cE '^[0-9]+\. ')
  [ "$gates" -eq 3 ]
}

@test "dialog economy (#254): defining-requirements stays autopilot-free (AT-005/C1)" {
  # the one-question-at-a-time override is declared ONLY on the orchestrator side;
  # the flow skill must carry no autopilot carve-out (regression guard for AT-005)
  ! grep -qi 'autopilot' skills/defining-requirements/SKILL.md
}

# --- Presentation channel (#267) ---------------------------------------------
# Deliverable bodies travel as the Draft PR diff at both human gates; the
# terminal / comments carry the PR link + decision points only.

@test "presentation channel (#267): AT-003 both gates present deliverable bodies as the Draft PR diff" {
  local section
  section=$(sed -n '/^## Dialog economy/,/^## Output/p' "$SKILL_FILE")
  echo "$section" | grep -q 'Draft PR diff'
  echo "$section" | grep -q 'Gate ①'
  echo "$section" | grep -q 'Gate ②'
}

@test "presentation channel (#267): AT-004 terminal carries the PR link + decision points only" {
  local section
  section=$(sed -n '/^## Dialog economy/,/^## Output/p' "$SKILL_FILE")
  echo "$section" | grep -qi 'PR link'
  echo "$section" | grep -qi 'never the full deliverable body'
}

@test "presentation channel (#267): full-channel sync of approval requests / state notifications is kept" {
  local section
  section=$(sed -n '/^## Dialog economy/,/^## Output/p' "$SKILL_FILE")
  echo "$section" | grep -qi 'full-channel sync'
}

# --- Diff-in-body (#275) ------------------------------------------------------
# The gate message itself carries the decision evidence inline at the
# design-approval gate (Flow step 3) and the merge hand-off (step 5).

@test "diff-in-body (#275): AT-001 re-presentation shows per-finding diff hunks with key lines, in both channels" {
  local flow
  flow=$(sed -n '/^## Flow/,/^## Mechanism/p' "$SKILL_FILE")
  echo "$flow" | grep -q 'Diff-in-body (mandatory, #275)'
  echo "$flow" | grep -qi 'diff blocks organized per finding'
  echo "$flow" | grep -qi 'BOTH the in-session message and the GitHub gate comment'
}

@test "diff-in-body (#275): AT-002 first presentation shows key decisions with file/line references; summary-only gates are banned" {
  local flow
  flow=$(sed -n '/^## Flow/,/^## Mechanism/p' "$SKILL_FILE")
  echo "$flow" | grep -qi 'key decisions with file/line references'
  echo "$flow" | grep -qi 'summary-only gate'
}

@test "diff-in-body (#275): AT-003 merge hand-off includes the implementation diff inline (per-file stat + key hunks)" {
  local flow
  flow=$(sed -n '/^## Flow/,/^## Mechanism/p' "$SKILL_FILE")
  echo "$flow" | grep -qi 'per-file stat'
  echo "$flow" | grep -qi 'not just a green-status summary'
}

@test "diff-in-body (#275): AT-004 key lines / key decision carry operational definitions" {
  # without these definitions a formally-compliant but content-free gate
  # message satisfies the rule (review finding on #276)
  local flow
  flow=$(sed -n '/^## Flow/,/^## Mechanism/p' "$SKILL_FILE")
  echo "$flow" | grep -qi 'key lines.* = lines that directly implement an AC'
  echo "$flow" | grep -qi 'key decision.* = a choice that, if reversed'
}

# --- Model assignment (#259) -------------------------------------------------
# impl / review subagents default to Sonnet (bench-verified); design phase and
# the orchestrator stay on the session model; escalation is one-way per Issue.

@test "model (#259): Model assignment section — impl subagents Sonnet by default, design-heavy Issues on the session model (AT-003)" {
  grep -q '## Model assignment' "$SKILL_FILE"
  local section
  section=$(sed -n '/^## Model assignment/,/^## [^M]/p' "$SKILL_FILE")
  echo "$section" | grep -qi 'sonnet'
  echo "$section" | grep -qi 'session model'
  # design-heavy Issues (architecture judgment / trade-offs) start escalated
  echo "$section" | grep -qiE 'design-heavy|architecture'
}

@test "model (#259): escalation trigger is the convergence-failure halt set, one-way per Issue (AT-005)" {
  local section
  section=$(sed -n '/^## Model assignment/,/^## [^M]/p' "$SKILL_FILE")
  # the canonical trigger phrase (must stay literally identical to agents/README.md)
  echo "$section" | grep -qF 'convergence-failure halt (`MAX_ITERATIONS` / `sameness-detector` / `stuck`)'
  echo "$section" | grep -qF 'COMPLETED_WITH_DEBT'
  echo "$section" | grep -qiE 'one-way per Issue'
  # ac-drift / record-error are integrity halts, not model-quality signals
  echo "$section" | grep -qE 'ac-drift'
}

@test "model (#259): design phase and the orchestrator are explicitly out of scope (AT-003/CS-3)" {
  local section
  section=$(sed -n '/^## Model assignment/,/^## [^M]/p' "$SKILL_FILE")
  echo "$section" | grep -qE 'extracting-user-stories'
  echo "$section" | grep -qE 'writing-plan-and-tests'
  echo "$section" | grep -qiE 'orchestrator'
}

# --- #261 design-gate rejection plumbing pins -------------------------------

@test "rejection (#261): rejectionFindings args reach iteration 1 via the prevFindings seed (AT-001)" {
  # a gate rejection re-runs the phase as a NEW Workflow call where prevFindings
  # starts null — without this plumbing the human comments are silently dropped
  grep -qE 'const REJECTION_FINDINGS' "$SKILL_FILE"
  # the null-fixed init is replaced by the seed; the existing JSON.stringify
  # branch then embeds the human comments verbatim into iteration 1's generate
  grep -qE 'prevFindings = REJECTION_FINDINGS' "$SKILL_FILE"
  ! grep -qE 'let prevFindings = null$' "$SKILL_FILE"
}

@test "rejection (#261): rejectionFindings validation is fail-closed and sits before the freeze (AT-002)" {
  # (a) non-array throws
  grep -qE 'Array\.isArray\(A\.rejectionFindings\)' "$SKILL_FILE"
  # (b) every item needs a non-empty string evidence_ref (AL-4)
  grep -qE 'non-empty evidence_ref' "$SKILL_FILE"
  # (c) design-phase-only — impl must never receive gate-rejection plumbing
  grep -qE "PHASE !== 'design'" "$SKILL_FILE"
  # all three guards run before freeze:anchor — bad args never start an iteration
  local vline fline
  vline=$(grep -n 'Array\.isArray(A\.rejectionFindings)' "$SKILL_FILE" | head -1 | cut -d: -f1)
  fline=$(grep -n 'freeze:anchor' "$SKILL_FILE" | head -1 | cut -d: -f1)
  [ -n "$vline" ] && [ -n "$fline" ] && [ "$vline" -lt "$fline" ]
}

@test "rejection (#261): seeded findings get priorityOf normalization — absent priority = blocker (AT-003)" {
  # fail-safe: a human comment without an explicit severity is priority 0
  grep -qE 'prevFindings = REJECTION_FINDINGS \? REJECTION_FINDINGS\.map\(\(f\) => \(\{ \.\.\.f, priority: priorityOf\(f\) \}\)\) : null' "$SKILL_FILE"
}

@test "rejection (#261): partial approval is rejection of the whole set, split per section (AT-004/AT-005)" {
  # AT-004: non-'ok' (incl. partial approval) = whole-set rejection; never enter impl
  grep -q '部分承認は承認ではない' "$SKILL_FILE"
  grep -qiE 'whole deliverable set' "$SKILL_FILE"
  # AT-004: re-invocation args carry the findings
  grep -qE "phase: 'design', rejectionFindings: \[\.\.\.\]" "$SKILL_FILE"
  # AT-005: split the comment per section — 1 section's point = 1 finding,
  # evidence_ref = that section's human comment verbatim
  grep -q 'セクション単位' "$SKILL_FILE"
  grep -q '1 セクションの指摘 = 1 finding' "$SKILL_FILE"
  grep -qiE "evidence_ref.*(human comment|verbatim)" "$SKILL_FILE"
}
