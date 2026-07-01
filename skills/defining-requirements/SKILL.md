---
name: defining-requirements
description: "Use when starting a new Issue to explore the problem space, define the PRD, and produce a structured requirements document."
---

# Defining Requirements

Step 1 of the atdd-kit v1.0 flow. Take an Issue number, walk the author through the 4-element PRD structure (基礎項目 / 問題定義と背景 / ゴールと成功指標 / 機能要件, plus Open Questions) one question at a time, and write `docs/issues/<NNN>/prd.md` based on `templates/docs/issues/prd.md`.

**Scope ends at the PRD.** User Story extraction (incl. persona-less Connextra form and constraint stories) is owned by `extracting-user-stories` (Step 2, #189). This skill does not write User Stories.

## Trigger

- **Explicit:** `/atdd-kit:defining-requirements <issue-number>`
- **Keyword-detected (confirm before invoking):** When user messages mention PRD authoring intent (e.g. "PRD", "要件定義", "Issue NNN を整理して"), ask `Run defining-requirements skill on <issue>? Y/n` before starting. Auto-invocation without confirmation is forbidden by the v1.0 Step B progression rule (#179).

## Input

- Issue number (command-line argument or recognized in a user message)
- Issue body / title / labels read via `gh issue view <NNN> --json title,body,labels`

No other inputs. No Context Block. No resume of existing `docs/issues/<NNN>/prd.md`.

## Output

| Artifact | Path |
|----------|------|
| PRD file | `docs/issues/<NNN>/prd.md` (copied from `templates/docs/issues/prd.md`, filled in) |

No Issue comment, no `skill-status` fenced block. The PRD draft is committed and pushed **before** approval and presented as the Draft PR diff (mode-independent — the same order regardless of the caller).

## Flow

Each Section step maps to one of the 4 quality-discipline principles carried in `templates/docs/issues/prd.md` (facts/issue separation, one-essential-problem-per-PRD, observable goals, downstream feedback) so the dialogue stays consistent with the template's own guidance.

1. Read the Issue (`gh issue view`).
2. **Section 1 — 基礎項目** (one question): "What is the product/component, the target user or caller, and the constraints to assume?"
3. **Section 2 — 問題定義と背景** (one question at a time, in order):
   a. Facts: "Describe the observed current state — facts only, no evaluation."
   b. Issue: "What consequence or pain does that fact cause?" (kept separate from the fact — anti-pattern: mixing fact and issue)
   c. Why now (今やる背景): "Why does this need to happen now? Deadlines, triggers, opportunity cost?"
4. **Section 3 — ゴールと成功指標** (one question): "What externally observable state is reached when done? Avoid internal completion conditions (e.g. 'implement X', 'rewrite file Y') — state the change from the user's vantage point instead."
5. **Section 4 — 機能要件** (one question, then a follow-up): "List in-scope features or changes." Prioritize each in-scope feature using the 5-stage / 2-axis frame in [`docs/methodology/prioritization.md`](../../docs/methodology/prioritization.md) (MUST/SHOULD/WANT/次回以降/破棄, judged separately on impact vs. effort). Then "List intentionally out-of-scope items (スコープ外) with one-line rationale each."
6. **Open Questions** (one question): "List unresolved decisions (Unresolved only), or state 'none remain'. Resolved items are answered and closed, not left listed."
7. **Write draft.** `cp templates/docs/issues/prd.md docs/issues/<NNN>/prd.md`, then fill in each section in place.
8. **Commit / push / Draft PR.** Commit the draft to the Issue's work branch (Conventional Commits), push, and if no Draft PR exists open one with `gh pr create --draft`.
9. **Approval gate (on the PR).** In the terminal present only the PR link + the points needing a human decision — never the full PRD body — then ask via **AskUserQuestion** (header `Approve PRD?`; first option `(Recommended) 承認 (ok)` for one-tap approval, then the context-specific section send-backs `問題定義を修正`（旧 Problem） / `ゴールを修正`（旧 Outcome） / `スコープを変更`; `multiSelect: false`):
    > `Approve PRD? Reply 'ok' to approve, or name a section to revise.`
    ```
    Recommended: 承認 (ok) — reply 'ok' to accept, or name a section to revise
    ```
    The `Other` option is harness-auto — never list it manually; an `Other` free-text comment flows into the existing natural-language revision route unchanged. On non-selection-UI channels (headless / cron), the `Recommended: ... — reply 'ok'` line is the fallback: approve with the legacy `ok` text input. Revisions loop back to that section; commit and push each revision so the Draft PR diff stays current. Do not proceed without explicit `ok`.

Each section step is one question at a time. Do not bundle multiple sections into a single prompt.

## Iron Law: 対話ディシプリン

Section の問い文（上記 Flow）は現行維持のまま、以下 6 ディシプリンを対話全体に一括で適用する。

1. **1 ターン 1 問。** 1 ターンに複数の問いを並べない。一次情報: Steve Krug, *Rocket Surgery Made Easy* (2010)。
2. **引き出し型 HARD-GATE — 提案完成型禁止。** 課題・ゴール・機能の本質（何を解くか / 何を達成するか / 何を作るか）について、AI が候補を完成形で列挙して作者に選ばせる出力は禁止（HARD-GATE）。例外として手法領域（どう計測するか / どう実装するか）に限り AI が選択肢を提示してよい。本質は引き出す、手法は AI 提示可、という境界線を厳守する。
3. **対話の語彙制約。** 内部 ID・フレームワーク用語・出典名（本ドキュメントの識別子や理論名）を対話に使わない。作者自身の過去回答はその語をそのまま引用する。原則を説明するときは平易な言葉に言い換える。産婆術（Socratic elicitation）の系譜に連なる態度。
4. **経緯記録の自動駆動。** 対話中に機能の増減・優先度変更・分類変更を検知したら、変更内容・理由・日付を git commit message ではなく PRD 本体に追記する。commit message には経緯を委ねない。
5. **Wall 検知と差し戻し。** 次の 3 シグナルのいずれかを検知したら Wall とみなす（[独自] 整理）: (a) 層化要素の欠如、(b) 情報量の極端な低下（具体が 1 件未満）、(c) 症状の別語再陳述。1 回深掘りしてなお情報量が上がらなければ、上流の壁打ちへ戻す提案を発動する。共通の差し戻し文言テンプレート:
   > 「ここで一度立ち止めて、課題をもう少し具体化するところから始めてみましょうか？」
   このテンプレートを使うときは、どのシグナルが発動したかを本文中で補足する。
6. **ターゲット層化追問。** 「全員」型の層化されない回答には「強いて言うと誰？」を 1 回だけ追問して層化を試みる。

## Elicitation Technique Mapping

Per-section technique reference — details, primary sources, and examples live in [`docs/methodology/elicitation-techniques/`](../../docs/methodology/elicitation-techniques/README.md):

| Section | Technique |
|---------|-----------|
| Problem / Outcome | [job-story.md](../../docs/methodology/elicitation-techniques/job-story.md) |
| Constraints / Open Questions | [pre-mortem.md](../../docs/methodology/elicitation-techniques/pre-mortem.md) |
| Non-Goals | [out-of-scope-question.md](../../docs/methodology/elicitation-techniques/out-of-scope-question.md) |
| All sections (dialogue rule) | [one-question-at-a-time.md](../../docs/methodology/elicitation-techniques/one-question-at-a-time.md) |

## Responsibility Boundary

| Concern | Owner |
|---------|-------|
| Issue → PRD | **defining-requirements** (this skill) |
| PRD → User Stories (persona-less Connextra, constraint stories) | extracting-user-stories (Step 2, #189) |
| Plan + Acceptance Tests | writing-plan-and-tests (Step 3, #190) |
| ATDD double-loop implementation | running-atdd-cycle (Step 4, #191) |
| PRD / US / Plan / Code / AT review | reviewing-deliverables (Step 5, #192) |
| Parallel-session conflict, `in-progress` label management | skill-gate (#197) |

This skill **does not** spawn reviewer subagents — PRD review happens at Step 5. This skill **does not** add or remove the `in-progress` label — that is skill-gate's responsibility.

## Integration

- **Upstream:** `session-start` (may suggest this skill in Recommended Tasks)
- **Downstream:** `extracting-user-stories` (consumes `docs/issues/<NNN>/prd.md`)
