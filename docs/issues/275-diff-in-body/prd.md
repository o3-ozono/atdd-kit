# PRD — autopilot User gate 提示への Diff-in-body 必須化 (#275)

## 問題

autopilot の設計承認ゲート（Flow step 3）とマージゲート引き継ぎ（step 5）の提示が要約のみで、ユーザーが差分を見るには毎回「差分を見せて」と追加要求する必要がある。stockbot-jp Issue #61 の運用で発生: 差し戻し findings 修正後の再提示が対応サマリ表のみで、diff は追加質問で初めて提示された。

User gate は承認判断の場であり、判断材料（実際に何がどう変わったか）は提示メッセージ本文に最初から含まれているべき。

## 要求（AC）

- **AC-1（再提示）**: 差し戻し修正後の再提示では、finding ごとに整理した diff ブロック（変更ハンク）を、セッション内メッセージと GitHub ゲートコメントの**両方**の本文へインライン提示する。各ハンクの key lines を明示する。
- **AC-2（初回提示）**: 初回提示では、各成果物の key decisions を file/line 参照付きで示す。要約のみの提示（ユーザーに diff を追加要求させる形）を禁止する。
- **AC-3（ハンドオフ）**: マージゲート引き継ぎ（step 5）では、実装 diff（per-file stat + key hunks）を本文へインライン提示する。green ステータスの要約だけにしない。
- **AC-4（操作的定義）**: key lines / key decision は操作的定義を持つ（形式準拠だが無内容な提示でルールを満たせないこと）。
  - *key lines* = AC を直接実装する行・公開インターフェースを変える行・rejection finding に引用された行
  - *key decision* = 覆すと少なくとも 1 つの AC か plan のステップ構成が変わる判断（整形上の選択・Issue 本文から導出可能な事項 (#254) は対象外）

## 制約

- #267 の提示チャネル規定と補完関係を保つ: 成果物本体は引き続き Draft PR diff として提示。インラインハンクは判断根拠であり、代替チャネルではない。
- C1: flow skill 本体は編集しない。変更は `skills/autopilot/SKILL.md`（オーケストレータ）のみ。

## Non-Goals

- ゲート数・ゲート位置の変更（AL-1 は不変）
- reviewing-deliverables / merging-and-deploying 側の変更
