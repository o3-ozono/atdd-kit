#!/usr/bin/env bats
# @covers: skills/autopilot/SKILL.md
# Unit Test for the autopilot skill (autopilot orchestrator, #246).
# claude is NOT invoked; structural / wording invariants are checked via grep.
# LLM behavior is covered by tests/e2e/autopilot.bats.
#
# Scope (#246, gates re-placed in #249): autopilot is the autopilot MODE — a thin
# orchestrator that runs the EXISTING flow skills, narrows the User gates to three
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

@test "orchestration: User gates fixed to three points — requirements, design approval, merge (F1/AL-1, #249)" {
  grep -qiE 'user gate' "$SKILL_FILE"
  # the gate naming is unified to "User gate" (#281) — the old naming must be gone
  ! grep -qiE 'human gate|人間ゲート' "$SKILL_FILE"
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

@test "line budget (#254: Dialog economy section): SKILL.md is at most 280 lines" {
  # 240 → 260 (#254): the Dialog economy section adds ~10 lines of human-dialog
  # discipline that must live in the orchestrator (C1: flow skills stay unedited)
  # 260 → 280 (#275): #272 step-scoped rails + #275 diff-in-body left the file
  # at 260/260 with zero headroom; raised per the #276 review headroom finding
  local n
  n=$(wc -l < "$SKILL_FILE" | tr -d ' ')
  [ "$n" -le 280 ]
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
  # #272: payload が oracle 状態込みの新形式であること（blocking を含む）
  grep -qE 'JSON\.stringify\(\{ atGreen, coverageOk, uncovered, blocking \}\)' "$SKILL_FILE"
  # 旧 JSON.stringify(blocking) 単独 payload が残っていないこと
  ! grep -qF '${JSON.stringify(blocking)}' "$SKILL_FILE"
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
  # #292: optional chain added (verdict?.findings?.length) to prevent TypeError when verdict=null
  grep -qE 'prevFindings = verdict\??\.findings' "$SKILL_FILE"
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
  # so count the numbered items inside the User gates section itself
  local gates
  gates=$(sed -n '/^## User gates/,/^## Dialog economy/p' "$SKILL_FILE" | grep -cE '^[0-9]+\. ')
  [ "$gates" -eq 3 ]
}

@test "dialog economy (#254): defining-requirements stays autopilot-free (AT-005/C1)" {
  # the one-question-at-a-time override is declared ONLY on the orchestrator side;
  # the flow skill must carry no autopilot carve-out (regression guard for AT-005)
  ! grep -qi 'autopilot' skills/defining-requirements/SKILL.md
}

# --- Presentation channel (#267) ---------------------------------------------
# Deliverable bodies travel as the Draft PR diff at both User gates; the
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

@test "diff-in-body (#275): AT-000 sed boundaries for the section extractions exist" {
  # if a boundary heading is renamed, the sed ranges below silently expand to
  # EOF and AT-001..AT-005 would pass for the wrong reason — fail loudly here.
  # note: these are prefix matches (same regexes as the sed ranges), so an
  # INSERTED heading sharing an END prefix (e.g. '## Mechanism Details' inside
  # the Flow section) truncates the range without failing AT-000 — the
  # downstream AT-001..AT-004 greps then fail noisily, so no silent false-pass
  grep -q '^## Flow' "$SKILL_FILE"
  grep -q '^## Mechanism' "$SKILL_FILE"
  grep -q '^## Dialog economy' "$SKILL_FILE"
  grep -q '^## Output' "$SKILL_FILE"
}

@test "diff-in-body (#275): AT-001 re-presentation shows per-finding diff hunks with key lines, in both channels" {
  local flow
  flow=$(sed -n '/^## Flow/,/^## Mechanism/p' "$SKILL_FILE")
  echo "$flow" | grep -q 'Diff-in-body (mandatory, #275)'
  echo "$flow" | grep -qi 'diff blocks organized per finding'
  # AC-1's third element pinned independently: the key lines must be called out
  echo "$flow" | grep -qi 'with the key lines called out'
  echo "$flow" | grep -qi 'BOTH the in-session message and the GitHub gate comment'
  # the machine-checkable discriminator between the two presentation forms
  echo "$flow" | grep -qi 're-invoked with `rejectionFindings`'
  echo "$flow" | grep -qi 'anything else is a first presentation'
}

@test "diff-in-body (#275): AT-002 first presentation shows key decisions with file/line references; summary-only gates are banned" {
  local flow
  flow=$(sed -n '/^## Flow/,/^## Mechanism/p' "$SKILL_FILE")
  echo "$flow" | grep -qi 'key decisions with file/line references'
  # anchored: the ban's polarity is pinned, not just the phrase's existence
  echo "$flow" | grep -qi 'Never present a summary-only gate'
}

@test "diff-in-body (#275): AT-003 merge hand-off includes the implementation diff inline (per-file stat + key hunks)" {
  local flow
  flow=$(sed -n '/^## Flow/,/^## Mechanism/p' "$SKILL_FILE")
  # 'includes' pins the inclusion as required, not optional
  echo "$flow" | grep -qi 'the hand-off message includes the implementation diff inline'
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

@test "rejection (#261/#275): empty rejectionFindings array is refused fail-closed" {
  # [] is truthy in JS and .some() is vacuously false — without this guard an
  # empty array slips every check and reaches generate as a zero-finding
  # re-presentation (#276 round-4 review, error-handling lens)
  grep -q 'rejectionFindings.length === 0' "$SKILL_FILE"
  grep -qi 'must not be empty' "$SKILL_FILE"
  # containment invariant: the guard must sit INSIDE the undefined-check block,
  # right after Array.isArray — moved outside it, undefined.length is a TypeError
  grep -A 2 'if (A.rejectionFindings !== undefined)' "$SKILL_FILE" | grep -q 'length === 0'
}

@test "diff-in-body (#275): AT-005 #267/#275 reconciliation is pinned in BOTH sections" {
  # dropping either clause silently re-opens the #267-vs-#275 conflict: a model
  # reading #267 as dominant would suppress the mandatory inline hunks
  local flow dialog
  flow=$(sed -n '/^## Flow/,/^## Mechanism/p' "$SKILL_FILE")
  echo "$flow" | grep -qi 'not a replacement channel'
  dialog=$(sed -n '/^## Dialog economy/,/^## Output/p' "$SKILL_FILE")
  echo "$dialog" | grep -qi 'complements — does not override'
  echo "$dialog" | grep -qi 'decision evidence'
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
  # the null-fixed init is replaced by the unified seed (#288: SEED_FINDINGS =
  # design rejectionFindings | impl implSeedFindings); the JSON.stringify branch
  # then embeds the comments verbatim into iteration 1's generate
  grep -qE 'prevFindings = SEED_FINDINGS' "$SKILL_FILE"
  grep -qE "const SEED_FINDINGS = PHASE === 'design' \? REJECTION_FINDINGS : IMPL_SEED_FINDINGS" "$SKILL_FILE"
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
  grep -qE 'prevFindings = SEED_FINDINGS \? SEED_FINDINGS\.map\(\(f\) => \(\{ \.\.\.f, priority: priorityOf\(f\) \}\)\) : null' "$SKILL_FILE"
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

# --- #272: step スコープ化と oracle 状態込み fingerprint の構造 pin ----------

@test "AT-005 (#272): rails call passes current step to check_sameness and check_stuck" {
  # Given: SKILL.md の canonical Workflow script（rails ステップ）
  # When: 構造 pin（grep）を実行する
  # Then: check_sameness / check_stuck に step 引数 "${step}" が渡されており、
  #       step なし旧形式（check_sameness "<log>"; / check_stuck "<log>" 3;）が残っていない
  grep -qE 'check_sameness "<log>" "\$\{step\}"' "$SKILL_FILE"
  grep -qE 'check_stuck "<log>" 3 "\$\{step\}"' "$SKILL_FILE"
  # step なしの旧形式呼び出しが script 内に残っていないことを確認する
  # （rails プロンプト文字列の (c)/(d) 節に旧形式が使われていてはいけない）
  ! grep -qE '\(c\) check_sameness "<log>";' "$SKILL_FILE"
  ! grep -qE '\(d\) check_stuck "<log>" 3;' "$SKILL_FILE"
}

@test "AT-006 (#272): audit payload includes oracle state (atGreen, coverageOk, uncovered, blocking)" {
  # Given: SKILL.md の audit ステップ（label: audit:step）
  # When: 構造 pin（grep）を実行する
  # Then: payload が JSON.stringify({ atGreen, coverageOk, uncovered, blocking }) であり、
  #       旧 JSON.stringify(blocking) 単独 payload が残っていない
  grep -qF 'JSON.stringify({ atGreen, coverageOk, uncovered, blocking })' "$SKILL_FILE"
  # 旧 JSON.stringify(blocking) 単独（中括弧なし）が BEGIN-PAYLOAD 直後に残っていないこと
  ! grep -qF '${JSON.stringify(blocking)}' "$SKILL_FILE"
  # uncovered が payload より前にループスコープで宣言・代入されていること
  local uline pline
  uline=$(grep -n 'let uncovered' "$SKILL_FILE" | head -1 | cut -d: -f1)
  pline=$(grep -nF 'JSON.stringify({ atGreen' "$SKILL_FILE" | head -1 | cut -d: -f1)
  [ -n "$uline" ] && [ -n "$pline" ] && [ "$uline" -lt "$pline" ]
}

@test "AT-007 (#287): rails prompt resolves real paths and bans synthetic fixtures" {
  # Given: SKILL.md の rails ステップ（label: rails:step）のプロンプト文字列
  # When: rails 呼び出し行を抽出して構造 pin する
  # Then: freeze/audit と同じ実ディレクトリ解決指示を持ち、合成フィクスチャ・/tmp コピーを
  #       明示的に禁止している（プレースホルダのまま subagent に渡されて偽 halt を出さない）
  local rails
  rails=$(grep -F "run all five and report each one's integer exit code" "$SKILL_FILE")
  [ -n "$rails" ]
  # 実 issue ディレクトリ・実ログの解決指示（freeze/audit と同形）が rails プロンプトにある
  echo "$rails" | grep -qF 'Resolve the issue directory matching docs/issues/${NNN}-*'
  # 合成フィクスチャ・/tmp コピーの明示的禁止（#287）
  echo "$rails" | grep -qF 'NEVER fabricate synthetic fixtures'
  echo "$rails" | grep -qF '/tmp copies'
}

# --- #288: impl phase 再入の findings 配管 / audit trail 保護 ----------------

@test "AT-001 (#288): implSeedFindings validation is fail-closed, impl-only, before the freeze" {
  # Given: SKILL.md の args 解析（implSeedFindings ガード）
  # When: 構造 pin（grep）を実行する
  # Then: rejectionFindings と同型の fail-closed 検証（非配列・空・evidence_ref 欠落を拒否）かつ
  #       impl 限定（design では拒否）、すべて freeze:anchor より前に実行される
  grep -qE 'Array\.isArray\(A\.implSeedFindings\)' "$SKILL_FILE"
  grep -qE 'A\.implSeedFindings\.length === 0' "$SKILL_FILE"
  grep -qE 'every implSeedFindings item needs a non-empty evidence_ref' "$SKILL_FILE"
  # impl-phase-only — design は gate-rejection 用の rejectionFindings を使う
  grep -qE "PHASE !== 'impl'" "$SKILL_FILE"
  # ガードは freeze:anchor より前（不正 args で iteration を開始しない）
  local vline fline
  vline=$(grep -n 'Array\.isArray(A\.implSeedFindings)' "$SKILL_FILE" | head -1 | cut -d: -f1)
  fline=$(grep -n 'freeze:anchor' "$SKILL_FILE" | head -1 | cut -d: -f1)
  [ -n "$vline" ] && [ -n "$fline" ] && [ "$vline" -lt "$fline" ]
}

@test "AT-002 (#288): impl re-entry seeds iteration 1 via the unified SEED_FINDINGS" {
  # Given: SKILL.md の seed 配管
  # When: 構造 pin（grep）を実行する
  # Then: SEED_FINDINGS が phase で design rejectionFindings / impl implSeedFindings を選び、
  #       prevFindings の seed として priorityOf 正規化込みで使われる
  grep -qE 'const IMPL_SEED_FINDINGS = A\.implSeedFindings \|\| null' "$SKILL_FILE"
  grep -qE "const SEED_FINDINGS = PHASE === 'design' \? REJECTION_FINDINGS : IMPL_SEED_FINDINGS" "$SKILL_FILE"
  grep -qE 'prevFindings = SEED_FINDINGS \? SEED_FINDINGS\.map' "$SKILL_FILE"
}

@test "AT-003 (#288): audit agent commits ONLY the log after a successful record_iteration" {
  # Given: SKILL.md の audit ステップ（label: audit:step）プロンプト
  # When: audit 呼び出し行を抽出して構造 pin する
  # Then: record_iteration 成功後にログファイルのみを即コミットし、後続 gen の
  #       working-tree 巻き戻しから audit trail を保護する（#288 欠陥1a）
  # （audit プロンプトは複数行テンプレート — commit 指示は Steps 行に載るためファイル全体を grep）
  grep -qF 'if record_iteration succeeded, IMMEDIATELY commit ONLY the audit log' "$SKILL_FILE"
  grep -qF 'git add "<resolved-log-path>" && git commit' "$SKILL_FILE"
}

@test "AT-004 (#288): gen prompt forbids touching the orchestrator-owned audit log / pins" {
  # Given: SKILL.md の GEN_GUARD と gen 呼び出し
  # When: 構造 pin（grep）を実行する
  # Then: audit log / pin は orchestrator 所有で、追記・削除・コミット・巻き戻しを双方向に禁止し、
  #       その guard が両 gen 分岐プロンプトに挿入されている（#288 欠陥1a/1b）
  grep -qF 'const GEN_GUARD =' "$SKILL_FILE"
  grep -qF 'orchestrator-owned: never read, append to, edit, delete, commit, or roll back them' "$SKILL_FILE"
  grep -qF 'git restore / checkout -- / stash uncommitted work you did not create' "$SKILL_FILE"
  # 両分岐（prevFindings あり / なし）に GEN_GUARD が挿入されている
  local n
  n=$(grep -c "approved anchor\.\${GEN_GUARD}" "$SKILL_FILE")
  [ "$n" -eq 2 ]
}

# --- #292: agent() null フェイルセーフ ----------------------------------------
# 検証方式: SKILL.md の Workflow スクリプトに grep で構造アサーションをかける。
# 各 AT は AC で定めた null ガード文字列・reason・不変条件コメントを pin する。

@test "AT-001 (#292): at-gate atGreen calculation includes null guard (FS-1)" {
  # Given: SKILL.md no deterministic AT gate (label: at-gate:step) no atGreen sanshutu
  # When: grep structure pin wo jikko suru
  # Then: null guard tsuki keishiki wo fukumi, null guard nashi no sosaen ga tandokugyou to shite nokotte inai
  grep -qF 'atGreen = at != null && at.exitCode === 0 && at.green === true' "$SKILL_FILE"
  # null guard nashi no sosaen ga tankan de nokotte inai koto
  ! grep -qE '^\s*atGreen = at\.exitCode === 0 && at\.green === true' "$SKILL_FILE"
}

@test "AT-002 (#292): coverage cov null falls to uncovered=[] / coverageOk=false (FS-2)" {
  # Given: SKILL.md no AC-AT coverage gate (label: coverage:step) no sanshutu
  # When: grep structure pin wo jikko suru
  # Then: optional chain de uncovered wo anzen shutoku shi, cov != null check de coverageOk wo sanshutu suru
  grep -qF 'uncovered = cov?.uncovered || []' "$SKILL_FILE"
  grep -qF 'coverageOk = cov != null && cov.allCovered === true && uncovered.length === 0' "$SKILL_FILE"
  # null guard nashi no sosaen ga tankoku de nokotte inai koto
  ! grep -qE '^\s*coverageOk = cov\.allCovered === true' "$SKILL_FILE"
}

@test "AT-003 (#292): verdict null does not reach converged=true and does not crash prevFindings (fail-safe form, FS-3)" {
  # Given: SKILL.md no review kekka (verdict) wo sanshoo suru oracle sanshutu
  # When: grep structure pin wo jikko suru
  # Then: overall_correctness hikaku ga null guard tsuki keishiki ni natte ori, null verdict ga PASS ni taorenai
  grep -qE 'verdict != null && verdict\.overall_correctness === .correct.|verdict\?\.overall_correctness === .correct.' "$SKILL_FILE"
  # converged sanshutsu gyou ni null guard nashi no tandoku verdict.overall_correctness sosaen ga nokotte inai koto
  # (old form: converged = ... && verdict.overall_correctness === 'correct' without preceding verdict != null)
  ! grep -qE "converged = [^;]*[^&!] verdict\.overall_correctness === 'correct'" "$SKILL_FILE"
  # prevFindings dainyuu de null verdict ga crash shinai koto (AC3/FS-3: verdict?.findings?.length — optional chain hitsuyou)
  # verdict.findings?.length (optional chain nashi) no mama dewa verdict=null de TypeError crash suru
  grep -qF 'verdict?.findings?.length' "$SKILL_FILE"
}

@test "AT-004 (#292): freeze frozen null guard precedes anchor-pin-failed path (FS-4)" {
  # Given: SKILL.md no FREEZE step (label: freeze:anchor) no modorichigai guard
  # When: grep structure pin wo jikko suru
  # Then: frozen == null guard to reason: 'freeze-error' ga sonzai shi, frozen.logLines sanshoo yori mae ni aru
  grep -qF "frozen == null" "$SKILL_FILE"
  grep -qF "reason: 'freeze-error'" "$SKILL_FILE"
  # frozen == null guard ga frozen.pinned guard yori mae (gyoubangou hikaku)
  local null_line pin_line log_line
  null_line=$(grep -n 'frozen == null' "$SKILL_FILE" | head -1 | cut -d: -f1)
  pin_line=$(grep -n 'frozen\.pinned !== true' "$SKILL_FILE" | head -1 | cut -d: -f1)
  log_line=$(grep -n 'frozen\.logLines' "$SKILL_FILE" | head -1 | cut -d: -f1)
  [ -n "$null_line" ] && [ -n "$pin_line" ] && [ -n "$log_line" ]
  [ "$null_line" -lt "$pin_line" ]
  [ "$null_line" -lt "$log_line" ]
}

@test "AT-005 (#292): audit rec null merges into existing recordOk path (FS-5)" {
  # Given: SKILL.md no AUDIT step (label: audit:step) no henkyaku guard
  # When: grep structure pin wo jikko suru
  # Then: null merge keishiki no guard ga sonzai shi, reason: 'record-error' ga iji sareru
  grep -qF 'rec == null || rec.recordOk !== true' "$SKILL_FILE"
  grep -qF "reason: 'record-error'" "$SKILL_FILE"
}

@test "AT-006 (#292): rails r null guard precedes r.acDriftExit reference (FS-6)" {
  # Given: SKILL.md no safety rails step (label: rails:step) no halt sanshutu
  # When: grep structure pin wo jikko suru
  # Then: r == null guard to reason: 'rails-error' ga sonzai shi, r.acDriftExit sanshoo yori mae ni aru
  grep -qF "r == null" "$SKILL_FILE"
  grep -qF "reason: 'rails-error'" "$SKILL_FILE"
  local null_line drift_line
  null_line=$(grep -n 'r == null' "$SKILL_FILE" | head -1 | cut -d: -f1)
  drift_line=$(grep -n 'r\.acDriftExit' "$SKILL_FILE" | head -1 | cut -d: -f1)
  [ -n "$null_line" ] && [ -n "$drift_line" ]
  [ "$null_line" -lt "$drift_line" ]
}

@test "AT-007 (#292): fail-open prohibition comment exists in SKILL.md (CS-1)" {
  # Given: SKILL.md no null failsafe houshin comment
  # When: grep structure pin wo jikko suru
  # Then: never fail-open matawa dougi no hyougen wo fukumu comment ga sonzai suru
  grep -qiE 'never fail-open|fail-open.*forbidden' "$SKILL_FILE"
}
