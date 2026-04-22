---
name: skill-fix
description: "Use when a skill name (discover/plan/atdd/verify/ship/bug/issue/session-start/autopilot) and an intent verb (改善/修正/バグ/おかしい/直したい/fix/improve) both appear in the same message, indicating a skill defect should be reported. Also triggers on explicit /atdd-kit:skill-fix invocation."
---

## Session Start Check (required)

If `session-start` has not run in this session, run `/atdd-kit:session-start` first.

# skill-fix Skill — Background Skill Defect Reporting

<AUTOPILOT-GUARD>
If ARGUMENTS does not contain `--skill-fix` and is not invoked via `/atdd-kit:skill-fix` command:
- Display message: "skill-fix: direct invocation requires /atdd-kit:skill-fix."
- **STOP.** Do not proceed with execution.
If ARGUMENTS contains `--skill-fix` or command is `/atdd-kit:skill-fix`: skip this guard silently.
</AUTOPILOT-GUARD>

---

## Trigger Conditions

Two trigger paths:

**(a) Explicit invocation:** User runs `/atdd-kit:skill-fix` → proceed immediately to Interview.

**(b) Implicit trigger:** User message contains BOTH:
- **skill 名** (skill name): one of `discover / plan / atdd / verify / ship / bug / issue / session-start / autopilot`
- **意向動詞** (intent verb): 改善 / 修正 / バグ / おかしい / 直したい / fix / improve / broken / wrong

When BOTH conditions hold: ask ONE 確認質問 (confirmation question):
> "skill-fix フローに載せますか？ (YES → interview 開始 / NO → 通常会話に戻る)"

- YES → proceed to Interview
- NO → return to normal conversation immediately
- One condition only → normal conversation (no confirmation question)

---

## Phase 1: Interview (3 questions only)

Ask exactly **Q1, Q2, Q3** in sequence. 追加質問は出さない (no additional questions beyond Q3).

**Q1:** どの skill の、どの phase（step）で期待外れでしたか？
（例: discover の Step 3a-listing で、persona が自動選択されなかった）

**Q2:** 本来どう進むべきでしたか？（正しい動作を具体的に）

**Q3:** 再現情報を教えてください（skill 名・phase・観測した tool_use / 出力・期待との乖離を含む）

After Q3: proceed to Duplicate Check.

---

## Phase 2: Duplicate Check (main session, before subagent dispatch)

Search the following for 3-point match (同一 skill 名 + 同一 phase + 同一症状語):

- `skills/**/SKILL.md`, `commands/**/*.md`, `agents/**/*.md`
- `rules/**`, `docs/**`, `lib/**`
- `gh issue list --state all --search <keyword>`

**4 Classification (retrospective-codify):**

| 判定 | 基準 |
|------|------|
| 新規 | 3 点一致なし |
| 既存追記 | 2 点一致（skill + phase or skill + 症状） |
| 完全重複 | 3 点一致（skill 名 + phase + 症状語） |
| 判断保留 | 判定が分かれた場合 → conservative に倒す |

- **完全重複**: report `既存 #N が同じ趣旨` and STOP (no subagent dispatch)
- **それ以外**: proceed to subagent dispatch

---

## Phase 3: Parallel Activity Guard (AC7)

First, purge stale entries from inflight registry (AC9):
```bash
bash lib/skill_fix_dispatch.sh cleanup_stale
```
Stale criteria: issue has `ready-to-go`/`blocked-ac` label, issue is CLOSED, or `started_at` is >24h old.

Check inflight registry (`lib/skill_fix_dispatch.sh query_inflight`):
- If 1+ skill-fix subagent already running with same skill+phase → tell user `既存 skill-fix #N 実行中`, suppress new dispatch
- If same count but **different content** (duplicate check shows 新規/既存追記) → allow new dispatch
- Registry file: `~/.skill_fix_inflight.json` (or `$TMPDIR/skill_fix_inflight.json`)

---

## Phase 4: Subagent Dispatch (AC4 — β strategy)

Dispatch a single subagent using `isolation: worktree` + `run_in_background: true`.

**The subagent does NOT use Agent tool.** It uses Skill tool chain only:

```
1. /atdd-kit:issue   → creates new issue <new_n>
2. Append audit marker to <new_n> issue body:
   <!-- skill-fix-audit: invoked via --skill-fix bypass from parent-issue #<parent_n> at <ISO-8601 timestamp> -->
3. Run target skill via Skill tool (blank context) → RED baseline or GREEN fallback (AC5)
4. Post evidence as gh issue comment on <new_n>
5. /atdd-kit:discover <new_n> --skill-fix  → inline plan mode, quality gates retained
6. On MUST/UX/Interruption FAIL: add blocked-ac label + blocker comment, exit (no ready-to-go)
7. On all gates PASS: gh issue edit <new_n> --add-label ready-to-go
8. Observe <new_n> label (ready-to-go / blocked-ac / closed) → normal exit
```

Register in inflight registry before dispatch. Deregister on completion (AC7/AC9).

### Env Contract (AC8)

Subagent env:
- `ATDD_AUTOPILOT_WORKTREE`: **not inherited** (subagent uses its own isolated worktree path)
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`: inherited
- `GH_TOKEN`: inherited

### Return to Main Session

Main session resumes original work immediately (non-blocking). Do NOT wait for subagent completion.

---

## Phase 5: Completion Check (at next phase boundary)

At the next skill phase transition, run:
```bash
bash lib/skill_fix_dispatch.sh check_completion <new_n>
```

Report **1 行のみ** based on label:
- `ready-to-go`: `skill-fix #N: ready-to-go / link: <URL>`
- `blocked-ac`: `skill-fix #N: blocked-ac (phase=<last_phase>) / link: <URL>`
- FAILED: `skill-fix dispatch failed: #N (phase=<last_phase>) / link: <URL>`
- 未完了: (nothing)

No user judgment required (user can revert via `needs-plan-revision` later).

---

## Failure Path (AC9)

If subagent exits FAILED / BLOCKED / timeout:
1. Main session: 1-line report at next phase boundary: `skill-fix dispatch failed: #N (phase=<last_phase>) / link: <URL>`
2. Post `gh issue comment <new_n>` with `failed: <reason>` (distinct from `blocked-ac`)
3. Subagent handles worktree / team cleanup before exit

---

## Status Output (autopilot mode)

```skill-status
SKILL_STATUS: COMPLETE | PENDING | BLOCKED | FAILED
PHASE: skill-fix
RECOMMENDATION: <next action>
```
