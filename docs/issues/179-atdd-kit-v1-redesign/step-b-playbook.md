# Step B Playbook — 新 capability-name skill 実装の進め方

**目的**: #179 Step B (B1-B8) を 1 セッション内で再現可能な手順で進める。Claude のセッション間挙動ブレを抑え、ユーザーは reviewer 役に専念できる状態にする。

**スコープ**: B1 (#188 / merged #221) と B2 (#189 / merged #226) で確立した進め方を統合し、B3-B8 (#190-#195) に適用する規準。

---

## 0. 大前提（4 行で）

- **1 Step B Issue = 1 worktree = 1 Draft PR**。最初の commit 時に Draft PR を開く（commit moment = Draft PR moment）。
- **AI が draft 役、ユーザーが reviewer 役**。AI からユーザーに白紙質問を投げない。
- **skill 実装と Skill Acceptance Test を同一 PR で完成**させる。SAT なしで merge しない。
- **ATDD outer→inner→outer サイクル必須**: Acceptance Test (outer) を **先に** 書いて RED → Unit Test (inner) を書いて RED → 実装 → Unit Test GREEN → Acceptance Test GREEN の順を守る。outer GREEN まで終わらないと当該 commit を merge 不可。

---

## 1. 標準フロー（コミット単位）

B2 (#226) で確立した 4 コミット構成を踏襲。**コミット 1 つ＝ 1 単位 = AI が draft → ユーザー review → ok → 次の単位**。

| 順 | 単位 | 成果物 | 提示方法 | 参考 commit |
|---|---|---|---|---|
| 1 | PRD | `docs/issues/<NNN>/prd.md` | **セクション逐次** (Problem → Why now → Outcome → What → Non-Goals → Open Questions) | `9226ec70` |
| 2 | User Stories | `docs/issues/<NNN>/user-stories.md` | **batch 1 メッセージ**で Functional + Constraint Story 全候補を提示 | `c0f02271` |
| 3 | Plan + AT (draft) | `docs/issues/<NNN>/plan.md`, `acceptance-tests.md` | **batch 1 メッセージ**で Plan 全体 + AT 全件 (`[planned]`) | `b3ca4fa1` |
| 4 | 本実装 + テスト | `skills/<name>/SKILL.md`, `tests/test_<name>_skill.bats`, `tests/e2e/<name>.bats`, `CHANGELOG.md`, AT を `[planned]→[green]`, `tests/test_v1_skill_skeletons.bats` から該当行削除 | **outer→inner→outer サイクル** (§1.1) を回し切ってから 1 コミット | `e441e787` |

「進めて」は **次の 1 単位の draft 生成許可**であり、複数単位 skip 許可ではない（`feedback_skill_dialog_strictly.md`）。

### 1.1 コミット 4 の outer→inner→outer サイクル（必須）

ATDD の二重ループ。**先に outer (AT) を RED で書いてから inner (Unit Test) に降りる**。順番を逆にしない。

| 順 | 層 | 動作 | 期待状態 |
|---|---|---|---|
| ① | outer | Skill E2E Test (AT) を `tests/e2e/<name>.bats` に書く（User Story 1 件 = 1 @test、user-stories.md の順序） | — |
| ② | outer | `scripts/run-skill-e2e.sh --changed-files skills/<name>/SKILL.md` 実行 | **RED**（SKILL.md skeleton のため失敗） |
| ③ | inner | Unit Test を `tests/test_<name>_skill.bats` に書く（Responsibility / Line budget / 仕様固有 invariants） | — |
| ④ | inner | `bats tests/test_<name>_skill.bats` 実行 | **RED**（SKILL.md skeleton のため失敗） |
| ⑤ | impl | `skills/<name>/SKILL.md` を skeleton（HARD-GATE）から実装版（≤200 行）へ書き換え | — |
| ⑥ | inner | `bats tests/test_<name>_skill.bats` 実行 | **GREEN** |
| ⑦ | outer | `scripts/run-skill-e2e.sh --changed-files skills/<name>/SKILL.md` 実行 | **GREEN** |
| ⑧ | sweep | `tests/test_v1_skill_skeletons.bats` の `SKELETON_SKILLS` array から該当行を削除 → 実行 | **GREEN** |
| ⑨ | docs | `CHANGELOG.md` に追記、`docs/issues/<NNN>/acceptance-tests.md` の AT を `[planned]` → `[green]` | — |
| ⑩ | commit | 1 コミットにまとめて push（commit moment = ⑦ で GREEN 確認した時点以降） | — |

**鉄則**:
- ② / ④ で **必ず RED を目視確認**してから次のステップへ。RED を確認せずに実装に入ると AT/Unit Test の検証性能が担保されない。
- ⑦ で outer が GREEN にならない場合は SKILL.md / E2E テストの妥当性を再点検。**AT を緩めて通すのは禁止**。
- ⑩ で push したら CI で同じ outer→inner が再現される（CI 上の `skill-tests` job が両層走らせる）。

### コミット 4 で必ず触る 6 ファイル

1. `skills/<name>/SKILL.md` — skeleton（≤50 行 HARD-GATE）から実装版（≤200 行）へ置換
2. `tests/test_<name>_skill.bats` — Unit Test（claude 非呼出、構造検証）
3. `tests/e2e/<name>.bats` — Skill E2E Test（claude -p、User Story 1 件 = 1 @test）
4. `tests/test_v1_skill_skeletons.bats` — `SKELETON_SKILLS` array から該当行を削除
5. `CHANGELOG.md` — `[Unreleased]` の `### Added` / `### Changed` に追記
6. `docs/issues/<NNN>/acceptance-tests.md` — AT を `[planned]` → `[green]`

---

## 2. SKILL.md の標準構造（≤200 行）

B1/B2 の 64/63 行を上限の目安に、以下の順序で書く（順序とテーブル化は B1 で確立済み）。

```markdown
---
name: <kebab-case>
description: Use when ... so that ...
---

# <Title>

## Scope
<1 行で「ここまで完結」を宣言。Downstream skill 名を明記>

## Trigger
- Explicit: `/atdd-kit:<name> <args>`
- Keyword-detected: "…", "…" — confirm before proceeding

## Input
| Path / Source | Required | Notes |
|---|---|---|
| ... | yes | ... |

## Output
| Path | Format | Language |
|---|---|---|
| `docs/issues/<NNN>/<file>.md` | markdown | Japanese (fixed) |

## Flow
1. <Step 1>
2. <Step 2>
   ...
N. Approval gate: present draft → wait for user "ok" → write artifact

## Responsibility Boundary
| Concern | This skill | Other skill |
|---|---|---|
| <topic> | ✅ | — |
| Subagent spawn | ❌ | reviewing-deliverables |
| `in-progress` label | ❌ | skill-gate |

## Integration
- Upstream: <skill name>
- Downstream: <skill name>
```

**鉄則**:
- Output language は **日本語固定**（B2 で確立、`#223` i18n 廃止方針の先取り）
- Responsibility Boundary に **out-of-scope** を必ず明記（subagent spawn / label 管理）
- persona / Example Mapping / INVEST / Story Splitting は **採用しない**（`#218` で完全撤去済）
- User Story 形式は **persona 抜き Connextra** `I want to <goal>, so that <reason>` のみ

---

## 3. Unit Test の標準（`tests/test_<name>_skill.bats`）

claude を呼ばない構造検証。B2 の 13 @test を上限目安とする。

| カテゴリ | 検証内容 | 必須/任意 |
|---|---|---|
| Responsibility | 出力 path 言及 / template 言及 / Upstream / Downstream / subagent out-of-scope / label out-of-scope | **必須**（6 @test 程度） |
| Line budget | `wc -l <SKILL.md>` ≤ 200 | **必須** |
| Dialog protocol | "one question at a time" / "batch presentation" 等の mandate 文言の有無 | skill 仕様に応じて |
| Output language | "Japanese" 等の固定宣言 grep | 出力言語固定 skill のみ |
| Persona-less | `As a [persona]` パターンが SKILL.md / template に無いこと | persona 撤去対象 skill のみ |
| Template structure | テンプレート side のセクション heading 存在検証 | 新 template 導入時 |

## 4. Skill E2E Test の標準（`tests/e2e/<name>.bats`）

`claude -p --max-turns 1` で LLM 挙動を検証。**1 User Story = 1 @test**。User Story (Functional + Constraint) を user-stories.md に書いた順で並べる。

```bash
@test "F1: I want to <goal>, so that <reason>" {
  # claude に SKILL.md を読ませて goal が達成できるか単発質問
}
```

実行コマンド（手元検証）:
```bash
scripts/run-skill-e2e.sh --changed-files skills/<name>/SKILL.md
```

PR への証跡: **1 コメントを update し続ける**（`gh api -X PATCH /repos/.../issues/comments/<id>`）。複数コメントを並べない（`feedback_skill_e2e_handoff_comment.md`）。

### 4.1 AT lifecycle と outer→inner→outer の対応

| lifecycle | 状態 | タイミング |
|---|---|---|
| `[planned]` | AT 文言だけ acceptance-tests.md に列挙された状態 | コミット 3 (Plan + AT draft) |
| `[draft]` | `tests/e2e/<name>.bats` に @test 本体を書いた状態（実装は未着手なので **RED**） | コミット 4 / §1.1 ① |
| `[green]` | 実装完了で全 @test が pass | コミット 4 / §1.1 ⑦ |
| `[regression]` | merge 後、別 PR でも変更が入る場合に再実行 GREEN を維持 | merge 後継続 |

**outer→inner→outer の必須性**: `[draft]` で RED を目視確認しないまま実装に進むと、AT が「常に通る空テスト」になっていても気付けない。RED 確認は AT の検証能力を担保する不可欠ステップ。

---

## 5. PR 運用

### 5.1 Draft PR を開くタイミング

最初の commit を push したらすぐ `gh pr create --draft`。本文の Status checklist は B2 の以下のフォーマットを再利用。

```markdown
## Summary
- Closes #<NNN> (#179 Step B<n>)
- <skill 名> skill の本実装 + SAT 同一 PR
- B1 (#221) / B2 (#226) を踏襲

## Status
- [ ] PRD
- [ ] User Stories
- [ ] Plan + AT
- [ ] SKILL.md 実装 (≤200 行)
- [ ] Unit Test (BATS)
- [ ] Skill E2E Test (BATS)
- [ ] CHANGELOG 追記
- [ ] AT [planned] → [green]
- [ ] tests/test_v1_skill_skeletons.bats から削除

## Test plan
- Unit Test green
- Skill E2E Test green（証跡コメントを update で保持）
- tests/test_v1_skill_skeletons.bats green
```

PR description は **goal / non-goal / background** を必ず含む（`feedback_pr_description.md`）。AC リストだけは不可。

### 5.2 CI 監視

push 直後に `gh pr checks <PR>` を `run_in_background` で監視発動。状況報告メッセージを書く直前に `gh pr view <PR> --json statusCheckRollup` で最新化（`feedback_ci_tracking_responsibility.md`）。「待ちますか」とは聞かない。

### 5.3 ユーザー承認

draft の最終形が揃ったら **ユーザーが diff を確認 → 承認 → ready-for-PR-review** のフローを必須。AI は merge を勝手にやらない（`feedback_workflow_compliance.md`）。

---

## 6. コミットメッセージ規約

Conventional Commits + Issue/Step 明示 + `Refs:` / `Closes:`。B2 の以下を典型例とする。

```
feat(skill): <skill-name> skill 本実装 + Unit Test + Skill E2E Test (#179 Step B<n>)

- skeleton (HARD-GATE) を実装版に置き換え
- Output language Japanese 固定
- Unit Test N case 追加
- Skill E2E Test M case 追加（User Story 1:1）
- tests/test_v1_skill_skeletons.bats の SKELETON_SKILLS から除外
- AT N 件を [planned] → [green]
- CHANGELOG 追記

Closes #<NNN>
```

中間 commit (PRD / User Stories / Plan+AT) は `docs(skill): ...` で `Refs: #<NNN>`。

---

## 7. 設計判断の対話プロトコル（最重要）

### 7.1 数案提示する論点（breaking / 性質を決める変更）

これらは **AskUserQuestion で選択肢を提示し逐次承認**。draft で進めない（`feedback_draft_first_minimal_confirm.md`）。

- 責務境界（Upstream / Downstream skill との切れ目）
- 出力フォーマット（path / 言語 / セクション構造）
- 主要な flow 構造（対話単位 / 承認 gate 位置）
- 採用 / 不採用の方法論（例: persona、INVEST など）
- SAT の検証対象

### 7.2 draft で進める論点（軽い詳細）

- SKILL.md の章立て・並び順
- Unit Test の名前 wording
- E2E Test fixture の細かい文言
- CHANGELOG エントリの wording

### 7.3 1 単位 = AI が draft → ユーザー review

`feedback_skill_dialog_strictly.md` の正典:

| skill | 1 単位 |
|---|---|
| `defining-requirements` | 1 PRD セクション |
| `extracting-user-stories` | 全 Story 候補 batch |
| `writing-plan-and-tests` (B3) | Plan 全体 + AT 全件 batch |

**禁止**:
- 複数単位を 1 ターンで draft → push
- 単位 review 待ちで AI が次に進む
- 白紙質問（「Problem を教えてください」のような）
- 「進めて」を複数単位 skip 許可と解釈

---

## 8. 禁止事項チェックリスト

| 項目 | 禁止内容 | 根拠 |
|---|---|---|
| 廃止 skill | `discover` / `plan` / `atdd` / `verify` / `ship` / `ideate` / `issue` / `express` / `autopilot` / `auto-eval` は起動も案内もしない | `feedback_no_deprecated_skills.md` |
| persona | SKILL.md / template / Issue / AT に `As a [persona]` 形式を書かない | `feedback_no_deprecated_skills.md`, `project_atdd_kit_v1_redesign.md` |
| 旧テスト用語 | "SAT" / "L1 BATS gate" / "L2 Fast SAT" / "L3 Integration SAT" / "Fast layer" / "Integration layer" を新規 docs に使わない（履歴除く） | `feedback_skill_test_terminology.md` |
| public repo の private 情報 | private repo 名 / 個人名 / 廃止用語を Issue / PR / commit / docs に書かない | `feedback_public_repo_naming.md` |
| eval-guard bypass | skill 変更 PR で marker を手動作成しない（v1.0 では `auto-eval` 自体が廃止予定だが、現状残っていれば正規実行） | `feedback_no_eval_guard_bypass.md` |
| TaskCreate orchestrator | autopilot 廃止により Step B では使わない。Phase tracking は reasoning context 内で | `feedback_autopilot_no_orchestrator_tasks.md` |
| AT skip / 動作確認手動化 | reviewing-deliverables / merging-and-deploying は AT 再実行で動作確認を完結させる前提 | #179 PRD |

---

## 9. 各 Step B 固有の留意点

### B3 #190 (writing-plan-and-tests) ← **次に着手**

- AC: Plan は 2-5 分粒度タスク + verification（superpowers writing-plans 流）
- AC: AT 方針が AT lifecycle (`planned → draft → green → regression`) を表現
- AC: `design-doc` は **trade-off / alternatives がある時のみ** 生成（Ubl 2020、B8 連携）
- 数案提示候補: Plan の粒度ルール / AT の `planned` 表現方法 / design-doc 起動 trigger

### B4 #191 (running-atdd-cycle)

- AC: AT lifecycle (`draft → green → regression`) を**機構として駆動**
- AC: TDD inner loop が AT 内でネスト実行
- AC: `tests/acceptance/` への AT ファイル配置（story 単位）
- AC: C1-C5 ATDD 解釈（Concrete Examples / draft → green / TDD inner / story 単位 / 2 feedback loop）を機構として強制

### B5 #192 (reviewing-deliverables)

- AC: A3 で定義した 6 種 subagent (PRD/US/Plan/Code/AT/Final) を**直列実行**で呼び出し
- AC: 動作確認は AT で完結（preview / 手動確認は強制しない）

### B6 #193 (merging-and-deploying)

- AC: post-deploy AT 再実行（regression）
- **discover フェーズ確定タスク**: skill 系プロジェクトでの AT 再実行手段（#216 PRD Open Question #3 を本 Issue で解消）

### B7 #194 (launching-preview)

- AC: 手動起動コマンド `claude skill atdd-kit:launching-preview <args>` で動作
- AC: ローカル起動のみ（グローバル URL なし）
- **discover フェーズ確定タスク**: 引数仕様（#216 PRD Open Question #4 を本 Issue で解消）

### B8 #195 (writing-design-doc)

- AC: `docs/issues/<NNN>/design-doc.md` 出力
- AC: Ubl 2020 形式（Context / Goals / Non-Goals / Design / Trade-offs / Alternatives / Open Questions）

---

## 10. 参照テーブル（コピペで使える）

### 完成済みお手本

| 種別 | パス | 規模 |
|---|---|---|
| SKILL.md (B1) | `skills/defining-requirements/SKILL.md` | 64 行 |
| SKILL.md (B2) | `skills/extracting-user-stories/SKILL.md` | 63 行 |
| Unit Test (B1) | `tests/test_defining_requirements_skill.bats` | 6 @test |
| Unit Test (B2) | `tests/test_extracting_user_stories_skill.bats` | 13 @test |
| E2E Test (B1) | `tests/e2e/defining-requirements.bats` | — |
| E2E Test (B2) | `tests/e2e/extracting-user-stories.bats` | 4 @test |
| PRD 例 | `docs/issues/189-extracting-user-stories-skill/prd.md` | 軽量版 |
| User Stories 例 | `docs/issues/189-extracting-user-stories-skill/user-stories.md` | F1-F2 + C1-C3 |
| Plan 例 | `docs/issues/189-extracting-user-stories-skill/plan.md` | — |
| AT 例 | `docs/issues/189-extracting-user-stories-skill/acceptance-tests.md` | 5 件 |
| Template | `templates/docs/issues/prd.md` | 6 section |
| Template | `templates/docs/issues/user-stories.md` | persona-less |
| skeleton 追跡 | `tests/test_v1_skill_skeletons.bats` | `V1_SKILLS` / `SKELETON_SKILLS` array |

### 正典 docs

| 種別 | パス | 用途 |
|---|---|---|
| 6-step 正典 | `rules/atdd-kit.md` | Always-loaded、Workflow table |
| 開発規則 | `DEVELOPMENT.md` | Versioning / i18n / Tightening / Zero Deps |
| テスト体系 | `docs/testing-skills.md` | Unit Test / Skill E2E Test 正典 |
| v1.0 PRD | `docs/issues/179-atdd-kit-v1-redesign/prd.md` | 採用/不採用判断、Step 全体構成 |

### Step B 進行ルール（最重要 memo）

| memo | 内容 |
|---|---|
| `feedback_skill_dialog_strictly.md` | 1 単位 = AI draft → ユーザー review、白紙質問禁止 |
| `feedback_draft_first_minimal_confirm.md` | breaking は数案逐次、軽い詳細は draft |
| `feedback_skeleton_skill_freeflow.md` | skeleton HARD-GATE は「skill 仕様未実装」signal、人手で進める |
| `feedback_no_deprecated_skills.md` | 廃止 skill 起動禁止 |
| `feedback_ci_tracking_responsibility.md` | CI 監視は AI 責任、push 直後に発動 |
| `feedback_pr_description.md` | PR description に goal/non-goal/background 必須 |
| `feedback_skill_test_terminology.md` | Unit Test / Skill E2E Test 2 層に統一 |
| `feedback_skill_e2e_handoff_comment.md` | 証跡コメントは 1 件を update |
| `feedback_public_repo_naming.md` | private 情報を public artifact に書かない |
| `project_atdd_kit_v1_redesign.md` | epic 全体像、merged PR、不採用判断 |

---

## 11. セッション開始時のチェックリスト

新セッションで Step B を開始するとき、最初に以下を確認:

1. `gh issue view <Step B Issue 番号>` で AC と Dependencies を読む
2. 本 Playbook（このファイル）を読む
3. 直前の完成 Step（B1 #221 or B2 #226）の SKILL.md / Unit Test / E2E Test を眺める
4. `tests/test_v1_skill_skeletons.bats` の `SKELETON_SKILLS` array を確認
5. 該当 Issue の worktree / Draft PR が既にあるか確認、なければ作る
6. 標準フロー §1 の 4 コミットのうち、どこから再開するか宣言してユーザー ok をもらう

これだけ守れば、セッション間の挙動ブレは「単位の途中で中断したら次セッションでその単位の続きから」程度に収束する。
