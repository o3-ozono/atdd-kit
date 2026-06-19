> **Loaded by:** `autopilot` skill; referenced from `rules/atdd-kit.md` and `docs/issues/246-autopilot-revival/design-doc.md`.

# The autopilot Iron Law

The standard Iron Laws (`rules/atdd-kit.md`) govern **human-driven** work: one Issue, one PR, a human approving every Acceptance Criterion before code is written. **autopilot** — the autonomous convergence loop owned by the `autopilot` skill — is structurally different. It *generates → reviews → fixes* a deliverable on its own and iterates until a satisfaction oracle is met. A human does not approve each iteration, and one convergence cycle deliberately produces several deliverables at once.

So some standard Iron Laws cannot hold verbatim inside autopilot. Rather than treat every such case as a violation to suppress, autopilot **accepts** the conflict and is governed instead by the **autopilot Iron Law** below — a stricter, purpose-built law that replaces the conflicting standard clauses *only while autopilot is running*. Outside autopilot, the standard Iron Law is unchanged and supreme.

## Relationship to the standard Iron Law

| Standard Iron Law | Inside autopilot |
|-------------------|------------------|
| #1 No code edits without an Issue | **Unchanged.** autopilot always runs against one Issue. |
| #2 No implementation without approved ACs | **Replaced by AL-2.** Requirements are approved once at discover and the design deliverables once at the design-approval gate; iterations anchor to those immutable sets instead of re-approving each loop. Implementation (ATDD) never starts before the design-approval gate. |
| #3 No completion claims without fresh verification evidence | **Strengthened by AL-3 / AL-4.** Completion requires the satisfaction-oracle AND gate, not a self-assessment. |
| #4 bug loads `docs/specs/<slug>.md` before AC judgement | **Unchanged.** |
| "1 PR = 1 thing" (Commits/PRs) | **Relaxed by AL-6.** One convergence cycle = one Issue's deliverable set. |

## The law (AL-1 … AL-6)

### AL-1 — Three User gates, fixed
The only User approval gates are **discover (requirements approval)**, **design approval** (the converged design deliverables — user-stories / plan / acceptance-tests — reviewed and approved before any implementation), and **merge**. At these three points the standard Iron Law is fully in force. autopilot must not silently remove, automate, or route around any gate; ATDD never starts before the design-approval gate (#249: this is the user-expected flow — 壁打ち → design review → approval → ATDD).

**通常 autopilot（非 full-autopilot）では本 AL-1 は不変** — 三つの人間ゲートは常に発火する。`full-autopilot`（#318）の **hand-off モードでのみ** ①は queue 投入時の事前承認に、②は reviewer-oracle に、③は merge coordinator に委譲される（末尾の §AL-1 under full-autopilot を参照）。hand-off フラグの無い起動には一切影響しない。

On the **bugfix route** (`fixing-bugs`, #308) the middle gate is **specialized** from design-approval to a **cause-agreement** gate: the bugfix route writes no user-stories / plan / acceptance-tests spec, so its middle gate's approval target is `debugging` Step 5's **root-cause classification (Type A/B/C, evidence 付き) + the failing reproduction test (赤)** instead. **The gate count stays three** — this is a specialization, not a removal or an added gate. The approval target is non-empty (classification + failing repro test), so AL-1's "ATDD never starts before that gate" is preserved: the minimal fix never starts before the cause-agreement gate. This middle-gate specialization is described identically in `docs/methodology/autopilot-design-gate.md` (the presentation contract) — both docs name the bugfix middle gate the **cause-agreement** gate and the same approval target, so neither goes stale.

### AL-2 — Immutable per-phase anchor (replaces standard #2)
An iteration may write a deliverable without a fresh human approval **iff** it is traceable to the **immutable** artifacts a human approved **before the current phase**: the design phase anchors to the discover-approved PRD, and the impl phase anchors to the design-gate-approved set (prd.md + user-stories.md). A pin never covers an artifact the same phase's loop may edit (#249: pinning user-stories.md while looping `extracting-user-stories` guaranteed a false `ac-drift` halt); acceptance-tests.md is not pinned because `running-atdd-cycle` advances its lifecycle markers — its content is guarded by the **AC→AT coverage gate** instead, run in a context separate from the AT author, confirming the Acceptance Tests encode every approved AC (any uncovered AC is a P0 finding). Each anchor is frozen *after* it is approved; autopilot may never edit it. The freeze is **enforced**, not merely declared: a sha256 of the anchor is pinned at phase start (`pin_anchor` → `autopilot-prd.pin` / `autopilot-design.pin`) and re-checked every iteration (`check_pin`); any drift halts the loop (`ac-drift`), so autopilot cannot weaken the anchor it grades itself against.

### AL-3 — Satisfaction-oracle AND gate (strengthens standard #3)
A deliverable is "done" only when `AND(executable AT green, AC→AT coverage green [AL-2], reviewer verdict.overall_correctness = correct, confirmed P0/P1 findings = 0)` holds. Pass/fail of lint/test/AT is decided by the **deterministic gate** (CI / code), never by asking an LLM whether tests "would" pass. No completion claim without this evidence.

#### AL-3 bugfix specialization (#308) — coverage term + convergence oracle
On the bugfix route the standard AND oracle's `AC→AT coverage` term has **no approved AC set** to cover (no US/plan/AT spec). To keep the coverage guard — never degraded to a bare "tests pass" — the coverage term is **specialized** (not overridden; the standard route's `AC→AT coverage` is unchanged): its covered target becomes the **cause-agreement-gate-approved failing reproduction test**. The coverage gate verifies, in a context separate from the AT author, that **the reproduction test exists and went 赤→緑** (the oracle anchor is real and the fix turned it green). This preserves AL-2/AL-3's external-anchor coverage guard (the loop never grades its own AT). The standard AL-3 AND structure stays four-term: `AND(回帰テスト green [deterministic], 失敗再現テスト被覆 green — repro 赤→緑 confirmed externally, reviewer overall_correctness = correct, confirmed P0/P1 = 0)`.

The bugfix convergence oracle wiring is therefore: **回帰テスト green ＋ 既存テスト非破壊（既存回帰なし）＋ 失敗再現テスト 赤→緑（= specialized coverage anchor）**, with the **middle gate = cause-agreement** (the specialized design-approval gate — a specialization, not a removal) and the **terminal gate = the User merge gate (AL-1 maintained — never auto-merge)**.

### AL-4 — Mandatory evidence_ref + auto-demote false-green
Every finding carries an `evidence_ref`: a failing-AT name / log path, or a quoted line from the immutable AC/PRD, or a human-comment URL. A PASS with no backing reviewer evidence is **auto-demoted to FAIL and re-run**. Every iteration's verdict is appended to `docs/issues/<NNN>-<slug>/autopilot-log.jsonl` as the external source of truth and audit trail.

### AL-5 — Fail safe
autopilot halts and escalates to a human on non-convergence, budget overrun, or repeated identical failure. Mechanisms: `MAX_ITERATIONS` per step, a **sameness-detector** (normalized sha256 fingerprint identical twice in a row among **same-step FAIL rows only**), **stuck detection** (no progress across a window of 3 using **same-step FAIL rows only** — PASS rows are never part of the comparison population, #277), and `COMPLETED_WITH_DEBT` (record unresolved findings and hand to a human). Silent infinite loops and silent fake-green are structurally impossible.

### AL-5b — Gate③後フィードバックの正規ルート (#334)

Gate③（merge）後にユーザーの実機フィードバックで新たなACが生じた場合、**直接実装しない**。規模で次の分岐に従う:

- **小（設計アンカー変更不要・少数AC）**: 同一Issue内 design 差し戻し。設計アンカー（pin）が不変のまま吸収できる少数ACは、同一Issueの design phase に差し戻して既存 acceptance-tests に追加・収束させる。
- **大（設計アンカー変更を伴うまとまった新機能）**: 新Issue。アンカー変更を伴う場合は新Issueを立てて AL-1 の三ゲートを踏む。

**一次基準は「設計アンカー（pin）変更を伴うか」**。AC数の数値閾値は補助的目安にすぎない。AL-2（immutable anchor）の思想と整合し、既存 pin が変更不要なら同一Issue内で吸収できる。

### AL-6 — One convergence cycle may produce many deliverables (relaxes "1 PR = 1 thing")
Inside the loop, one cycle may produce a whole phase's deliverable set (design phase: US → plan → AT; impl phase: code + green AT), and one Issue still ships as one PR. The "one thing" discipline is preserved at the User **merge** gate, where a person reviews the near-green result as a whole.

## Skills are unchanged; only their role shifts under autopilot

autopilot does not fork or rewrite the flow skills. Each flow skill (`defining-requirements` … `reviewing-deliverables`) keeps its normal behavior. What changes **only while autopilot runs** is *where the User gate sits*: outside autopilot a human reviews each step; under autopilot the User gates collapse to requirements approval (start), design approval (before ATDD), and merge (end), and the steps between gates are looped autonomously. This is why autopilot is implemented as a **thin orchestrator** (`autopilot`) over the existing skills rather than as edits to them — the skills' role is mode-dependent, their code is not. (`reviewing-deliverables`'s machine-readable verdict is a backward-compatible addition: non-autopilot callers ignore it.)

## 効率は test-first 逸脱の理由にしない (#334)

**効率（session limit / トークン / 速さ）は test-first 逸脱（red 先行スキップを含む）の理由にしない。** これは AL-3 の deterministic gate と対をなす原則であり、理由の如何を問わず適用される。

- AT を書いた後に red を確認せず実装に進む（red skip）= test-first 逸脱
- 「今回は小さい変更だから」「セッション上限が近いから」「トークン節約のため」= いずれも逸脱の正当化に使えない
- test-first deviation の唯一の正当な根拠は「技術的に AT を先行させることが構造上不可能な変更（例: AT フレームワーク自体の入れ替え）」のみであり、それ以外は逸脱ではなく手順の問題として扱う

正典: 本節 (`docs/methodology/autopilot-iron-law.md`)。`rules/atdd-kit.md` から参照される。

## Why these overrides are legitimate (not rationalization)

The standard Iron Law exists to keep a human in control of *what gets built* and *whether it is correct*. autopilot keeps both: **what** is anchored to the human-approved immutable requirements and design (AL-1, AL-2), and **whether it is correct** is gated by an objective AND oracle plus auditable evidence (AL-3, AL-4), with a guaranteed human-escalation exit (AL-5). The overrides relax *how often a human signs off mid-loop*, not *whether a human owns the boundaries*. This is the same boundary the strongest field players keep (Anthropic: *"Claude does not approve or block PRs"*; OpenAI: *"a support tool, not a replacement"*) — see `docs/issues/246-autopilot-revival/research.md`.

## AL-1 under full-autopilot (hand-off mode)

`full-autopilot`（#318）は autopilot を **headless worker として多重起動する上位オーケストレータ**であり、autopilot 自身を書き換えない（疎結合）。worker を `--hand-off` 付きで起動したときのみ、AL-1 の三ゲートは次のように **担い手が移る**（人間がゲートの境界を所有し続ける点は不変）:

| ゲート | 通常 autopilot | full-autopilot hand-off |
|--------|----------------|--------------------------|
| ① 要件承認 | 起動時に人間が壁打ち承認 | **queue 投入時に事前承認済み**（`ready-to-go` の前提）。人間が queue をキュレーションすることで①を所有 |
| ② 設計承認 | 人間がサインオフ | **reviewer-oracle に委譲**（設計ループ generate→review→fix と near-green 収束は維持。AL-3 の AND オラクル＋AL-4 の evidence で担保）。人間は Draft PR の設計成果物を見て差し戻す **override 権を保持** |
| ③ merge | 人間が merge | **merge coordinator に委譲**（容量1直列・rebase 後フル再ゲート。autopilot は元々 merge しない） |

**正当性**: hand-off は「人間が境界を所有するか」を緩めない。①は queue キュレーション、②は AL-3/AL-4 の客観オラクル＋人間 override、③は coordinator の再ゲート＋AL-5 のエスカレーション（N 回失敗で human フラグ）で担保される。緩めるのは「人間がループ途中で何回サインオフするか」だけで、これは通常 autopilot が②を人間に残すのに対し full-autopilot がそれを reviewer-oracle に委ねる差にすぎない。**この上書きは hand-off フラグが立っている起動に厳密に閉じ、通常 autopilot の AL-1 を変更しない。**
