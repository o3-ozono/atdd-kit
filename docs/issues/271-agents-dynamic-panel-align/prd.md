# PRD: 固定 reviewer agents の存廃確定と agents/ 配下レガシー記述の #234 整合

## Problem

#234 で `reviewing-deliverables`(Step 5)は動的レンズパネル × 並列 Workflow に移行済みだが、旧機構(固定 5 specialist reviewer → final-reviewer 47 基準集約)を前提とした記述とファイルが残存し、現行実装と矛盾する:

1. **未使用ファイル**: `agents/{prd,us,plan,code,at,final}-reviewer.md` の 6 ファイルは、現行の reviewing-deliverables Workflow から参照されない(動的ペルソナ生成のみ。`agentType` 指定なし — grep 確認済み)。#234 Out of Scope「削除 or 流用」が未消化のまま放置されている
2. **レガシー記述**: `agents/README.md` Usage 節(「dispatches the five specialist reviewers … the final reviewer aggregates」)、各 agent description(「Spawned by reviewing-deliverables skill」)、`docs/methodology/definition-of-ready.md:30`(prd-reviewer 参照)、`docs/guides/getting-started.md:130`(「spawns dedicated reviewer subagents (such as code-reviewer and at-reviewer)」)、`DEVELOPMENT.md` / `DEVELOPMENT.ja.md` の Repository Structure・Agents 節

存在しない実行経路を説明するファイル群はセッションの実行像を誤誘導する(#269 で実証済みのパターン)。さらに Agent ツールのレジストリに「Spawned by reviewing-deliverables skill」と自己申告する 6 agent が常駐し続け、誤って spawn される余地がある。

## Why now

#269(workflow-detail.md の同種矛盾)の修正が完了し、リポジトリ内の #234 レガシー残存は agents/ 配下が最後のまとまり。#269 の PRD 策定時に発見され Non-Goals として切り出された繰り越し分であり、存廃判断(本 Issue の Gate ①)を確定しないと記述整合の方向も決まらない。

## Outcome

- #234 Out of Scope「固定 reviewer agents の扱い(削除 or 流用)」が確定し、記録される
- リポジトリ全体で `prd-reviewer|us-reviewer|plan-reviewer|code-reviewer|at-reviewer|final-reviewer` への参照が、歴史的記録(CHANGELOG / docs/issues/)を除き 0 件になる
- `agents/README.md` が現行実装(動的パネル + #259 モデルポリシー)を正しく説明する
- BATS suite 全体が green

## What

(Gate ① の存廃判断が「削除」の場合 — 本 PRD の推奨案)

- `agents/{prd,us,plan,code,at,final}-reviewer.md` の 6 ファイルを削除する
- `agents/` ディレクトリと `agents/README.md` は**存置**し、README を再構成する: 固定 roster の表と Usage 節を削除し、(a) ディレクトリの現行役割(将来のカスタム agent 置き場)、(b) #259 モデル割り当てポリシー(autopilot SKILL.md から参照されている既存記述を維持)、(c) レビューは reviewing-deliverables の動的パネルが担う旨を記載
- レガシー参照の置換: `docs/methodology/definition-of-ready.md`(prd-reviewer → 動的パネルの該当レンズ)、`docs/guides/getting-started.md`(固定 subagent 記述 → 動的パネル記述)、`DEVELOPMENT.md` / `DEVELOPMENT.ja.md`(Repository Structure・Agents 節・Reviewer Aggregation 言及)、`README.md` / `README.ja.md`(該当があれば)
- `tests/test_reviewer_subagents.bats`(#186 の固定 6 agent 構造 smoke test)を削除し、代わりに「固定 reviewer への参照が docs/skills/commands/rules に存在しない」回帰 pin を追加する
- `CHANGELOG.md` に `### Removed` エントリ + `.claude-plugin/plugin.json` **minor** bump(agents はスキルではないため DEVELOPMENT.md のスキル rename = major 規定の対象外。プラグイン表面の機能除去として minor)
- `tests/README.md` の test_reviewer_subagents.bats 行を更新

## Non-Goals

- `skills/reviewing-deliverables/SKILL.md` の変更 — 現行実装が正(#269 と同方針)
- `docs/issues/` / `CHANGELOG.md` の過去エントリの書き換え — 歴史的記録は保全する
- #259 モデル割り当てポリシーの内容変更 — 置き場所(agents/README.md)と参照(autopilot SKILL.md)を維持したまま周辺記述のみ更新

## Open Questions

1. **存廃判断: 削除(案 A・推奨)か、記述整合のみで存置(案 B)か** —
   - **案 A(削除)**: 未使用コードパスの完全除去。誤 spawn の余地と将来の記述ドリフト(本 Issue の再発)を構造的に防ぐ。コスト: 上記 What の全件(テスト差し替え含む)。minor bump。
   - **案 B(存置 + 記述整合)**: 6 ファイルの description と README を「手動 spawn 可能なレガシーロール(現行フローでは未使用)」へ書き換えるだけ。コスト小・patch bump。ただし未使用ファイルの保守義務が残り、#234 Out of Scope の「扱い確定」を再び先送りする。
   → **Resolved(Gate ① 承認, 2026-06-11)**: 案 A(削除)を採用。
2. **削除時の version 区分** — 本 PRD は minor を提案(スキル rename = major 規定は skills/ 対象であり agents/ は対象外と解釈)。
   → **Resolved(Gate ① 承認, 2026-06-11)**: minor 確定。
