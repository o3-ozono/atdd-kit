# Plan: フェーズ別モデル割り当て — impl / review の Sonnet 化（What 1〜3 すべて採用）

<!-- 2-5 分粒度のタスク行と verification 行を交互に配置する（superpowers writing-plans 形式）。
     各タスクは単一の操作に限定し、verification で完了条件を即確認できる粒度にする。 -->

対象 Issue: #259 / ブランチ: `feat/259-phase-model-assignment`

変更対象は `skills/reviewing-deliverables/SKILL.md`（Workflow script）、`skills/autopilot/SKILL.md`（ガイダンス節）、`skills/running-atdd-cycle/SKILL.md`（ガイダンス注記）、`agents/README.md`（ポリシー更新）と対応 BATS のみ。design phase の flow skill（`extracting-user-stories` / `writing-plan-and-tests`）、メインループ（オーケストレータ）、`agents/*.md` の frontmatter、`lib/` は変更しない（CS-3、#105 pin 互換）。

## Open Questions の決定（PRD より持ち越し）

1. **escalation のトリガー定義**: Sonnet で実行された収束サイクルが **収束失敗系の halt**（`MAX_ITERATIONS` / `sameness-detector` / `stuck`）で `COMPLETED_WITH_DEBT` 終了したとき、人間介入後の**次の収束サイクル**から該当 step の impl / review subagent を**セッションモデルへ昇格**する。昇格は Issue 内で一方向（同一 Issue 中は Sonnet に戻さない）。`ac-drift` / `record-error` はアンカー・監査の整合性 halt でありモデル品質シグナルではないため昇格トリガーに含めない。
2. **ベンチ成果物の要点の docs 反映**: `agents/README.md` のモデルポリシー節に要点のみ記録する（実施日 2026-06-10〜11、2 Issue × 3 モデル × 10 run = 60 実装 + ジャッジ 76 本、機能品質同等、コスト比 Sonnet 1.0 : Opus 2.2 : Fable 4.1、設計判断一貫性 Fable 20/20）。独立ドキュメントは作らず、ベンチ再実行・自動化はしない（Non-Goal）。

design doc は作成しない: 採否のトレードオフはベンチと Gate ① で解消済みで、競合する代替案は残っていない（残決定 2 点は上記に記録）。

## Implementation

### US-1: reviewing-deliverables Workflow script の Sonnet 恒久化

- [ ] `skills/reviewing-deliverables/SKILL.md` の Scout の `agent()` オプションに `model: 'sonnet'` を追加する（`{ phase: 'Scout', model: 'sonnet', schema: SCOUT_SCHEMA }`）
- [ ] verify: `grep -n "phase: 'Scout', model: 'sonnet'" skills/reviewing-deliverables/SKILL.md` がヒットする

- [ ] Generate（panel 生成）の `agent()` オプションに `model: 'sonnet'` を追加する
- [ ] verify: `grep -n "phase: 'Generate', model: 'sonnet'" skills/reviewing-deliverables/SKILL.md` がヒットする

- [ ] Review（`label: \`review:${lens.key}\``）の `agent()` オプションに `model: 'sonnet'` を追加する
- [ ] verify: `grep -n "phase: 'Review', model: 'sonnet'" skills/reviewing-deliverables/SKILL.md` がヒットする

- [ ] Verify（`label: \`verify:${lens.key}\``）の `agent()` オプションに `model: 'sonnet'` を追加する
- [ ] verify: `grep -n "phase: 'Verify', model: 'sonnet'" skills/reviewing-deliverables/SKILL.md` がヒットする

- [ ] Aggregate の `agent()` には `model` を付けず、直前に理由コメントを 1 行追加する（`// #259: Aggregate inherits the session model — final PASS/FAIL judgment stays on the strongest model`）
- [ ] verify: Aggregate の `agent()` オプション（`{ phase: 'Aggregate', schema: AGG_SCHEMA }`）に `model` が含まれず、`grep -n '#259' skills/reviewing-deliverables/SKILL.md` でコメントがヒットする

- [ ] 「Review mechanism」節の冒頭（Five phases の前後）に、モデル割り当ての 1-2 行注記を追加する: Scout〜Verify は `model: 'sonnet'`（ベンチ #259 で機能品質同等・コスト約 1/4 を実証）、Aggregate のみセッションモデル
- [ ] verify: `grep -n 'sonnet' skills/reviewing-deliverables/SKILL.md` が prose 注記と script の両方でヒットし、`wc -l` が 240 行以内（line budget pin）

### US-2: impl phase の推奨モデルガイダンス明文化

- [ ] `skills/autopilot/SKILL.md` に「Model assignment (#259)」の短い節（8 行以内）を追加する。内容: (a) impl phase の subagent（gen / review）は Sonnet 標準（ベンチ実証済み）、(b) 設計絡みの Issue（アーキテクチャ判断・トレードオフを含む）は最初からセッションモデルへ昇格、(c) escalation トリガー = Sonnet サイクルが収束失敗系 halt（`MAX_ITERATIONS` / `sameness-detector` / `stuck`）で `COMPLETED_WITH_DEBT` 終了 → 次サイクルからセッションモデル（Issue 内一方向）、(d) design phase（extracting-user-stories / writing-plan-and-tests）とオーケストレータは対象外でセッションモデル維持
- [ ] verify: `grep -n 'Model assignment' skills/autopilot/SKILL.md` がヒットし、`wc -l skills/autopilot/SKILL.md` が 260 行以内（line budget pin）

- [ ] `skills/running-atdd-cycle/SKILL.md` に推奨モデル注記（2-3 行）を追加する: autopilot の impl phase subagent として実行される場合の推奨モデルは Sonnet 標準・設計絡みはセッションモデルへ昇格（詳細は autopilot SKILL.md の Model assignment 節と agents/README.md を参照）。通常フロー（メインセッション実行）には影響しない
- [ ] verify: `grep -n -i 'sonnet' skills/running-atdd-cycle/SKILL.md` がヒットし、`wc -l` が 200 行以内（line budget pin）

### US-3: agents/README.md のモデルポリシー更新

- [ ] `agents/README.md` の「Model and effort are intentionally unset」blockquote を新ポリシーに置換する。内容: (a) impl / review phase の subagent は Sonnet 標準（reviewing-deliverables の Workflow script の `agent()` オプションで指定。`agents/*.md` の frontmatter には書かない — #105 の継承設計を維持）、(b) design phase とオーケストレータはセッションモデルを継承（変更対象外）、(c) escalation path: 収束失敗系 halt（`MAX_ITERATIONS` / `sameness-detector` / `stuck`）→ 次サイクルからセッションモデルへ昇格（Issue 内一方向）、(d) effort は引き続き unset（セッション継承）
- [ ] verify: `grep -c 'intentionally unset' agents/README.md` が 0、`grep -n -i 'sonnet' agents/README.md` と `grep -n -i 'escalation' agents/README.md` がヒットし、`grep -qi 'session' agents/README.md` も引き続きヒットする（#105 AC3 pin 維持）

- [ ] 同節にベンチ要点を 2-3 行で記録する: 2026-06-10〜11、2 Issue × 3 モデル × 10 run（60 実装 + ジャッジ 76 本）、機能品質同等、コスト比 Sonnet 1.0 : Opus 2.2 : Fable 4.1、設計判断一貫性は Fable 20/20（design phase 据え置きの根拠）
- [ ] verify: `grep -n '1.0' agents/README.md` 等でコスト比とベンチ条件が確認でき、Agent table に `| Model |` / `| Effort |` 列を追加していない（#105 AC3 pin 維持）

## Testing

- [ ] `tests/test_reviewing_deliverables_skill.bats` に #259 pin テストを追加する: (a) Scout / Generate / Review / Verify の 4 つの `agent()` オプションに `model: 'sonnet'` が存在する、(b) Aggregate のオプション `{ phase: 'Aggregate', schema: AGG_SCHEMA }` に `model` が存在しない — を grep で pin する
- [ ] verify: `bats tests/test_reviewing_deliverables_skill.bats` が追加分を含め全件 pass する

- [ ] `tests/test_autopilot_skill.bats` に #259 pin テストを追加する: Model assignment 節が存在し、Sonnet 標準・escalation トリガー（`MAX_ITERATIONS` / `sameness-detector` / `stuck`）・design phase 対象外、の 3 点が読み取れることを grep で pin する
- [ ] verify: `bats tests/test_autopilot_skill.bats` が全件 pass する（line budget 260 行 pin 含む）

- [ ] `tests/test_running_atdd_cycle_skill.bats` に #259 pin テストを追加する: 推奨モデル注記（Sonnet / 昇格 / autopilot 参照）の存在を grep で pin する
- [ ] verify: `bats tests/test_running_atdd_cycle_skill.bats` が全件 pass する（line budget 200 行 pin 含む）

- [ ] 新規 `tests/test_phase_model_assignment.bats`（`# @covers: agents/**` ヘッダ付き）を作成し、agents/README.md ポリシーを pin する: (a) `intentionally unset` が消えている、(b) Sonnet ポリシーと escalation path が存在する、(c) ベンチ要点（コスト比）が存在する、(d) design phase / オーケストレータの除外が明記されている
- [ ] verify: `bats tests/test_phase_model_assignment.bats` が全件 pass し、`scripts/check_bats_covers.sh` が OK を返す

- [ ] 既存リグレッション確認: `bats tests/test_issue_105_frontmatter_session_inheritance.bats` を実行する（`agents/*.md` frontmatter 無変更・README の session 言及維持・Model/Effort 列なし）
- [ ] verify: #105 の 4 テストが全件 pass する

- [ ] BATS スイート全体を実行する
- [ ] verify: `bats tests/` が全件 pass する

- [ ] 変更ファイルが対象に限定されていることを確認する（CS-3）
- [ ] verify: `git diff --name-only main` に `skills/extracting-user-stories/` / `skills/writing-plan-and-tests/` / `agents/prd-reviewer.md` 等の `agents/*.md` / `lib/` が含まれない

## Finishing

- [ ] `tests/README.md` に新規テストファイル `test_phase_model_assignment.bats` の行を追加する
- [ ] verify: `grep -n 'test_phase_model_assignment' tests/README.md` がヒットする

- [ ] `skills/README.md` を通読し、今回のスキル本文変更（reviewing-deliverables / autopilot / running-atdd-cycle）と矛盾する記述があれば同期する
- [ ] verify: skills/README.md の記述が変更後のスキル内容と整合している

- [ ] `.claude-plugin/plugin.json` の version を 3.8.1 → 3.9.0 に bump する（ポリシー変更 + スキル機能変更 = minor）
- [ ] verify: `grep '"version"' .claude-plugin/plugin.json` が `3.9.0` を返す

- [ ] `CHANGELOG.md` に Changed エントリ（フェーズ別モデル割り当て: review Workflow の Scout〜Verify を Sonnet 化、impl phase ガイダンス明文化、agents/README ポリシー更新 + escalation path、refs #259）を追加する
- [ ] verify: `grep -n '#259' CHANGELOG.md` がヒットし、Keep a Changelog 形式に沿っている

- [ ] ドキュメント整合性チェック: agents/README.md・autopilot SKILL.md・reviewing-deliverables SKILL.md・running-atdd-cycle SKILL.md の 4 箇所でモデルポリシー（Sonnet 範囲・escalation トリガー・design phase 除外）の記述が相互に矛盾しないか通読する
- [ ] verify: 関連ドキュメントが変更内容と整合している（escalation トリガー定義が全箇所で同一）
