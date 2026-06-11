# PRD: autopilot 設計ゲート差し戻しの未規定挙動 — コメントを再実行へ運ぶ配管の不在と部分承認の扱い

## Problem

`skills/autopilot/SKILL.md` の散文は「差し戻しコメントは findings として design loop に再投入される（`evidence_ref` = the human comment）」と約束するが、埋め込み Workflow script にこれを実現する配管がない:

1. **不伝達**: 再実行は新規 Workflow 呼び出しで `prevFindings` は `null` 初期化。args に差し戻しコメントを運ぶフィールドがなく、人間のコメントが generate に届かない
2. **カーディナリティ未規定**: 複合コメント（「セクション A は X、B は Y」)を 1 finding にするか N 件に分割するか未規定
3. **部分承認の未規定**: 「A は ok / B は要修正」への規律が暗黙で、部分承認を承認と誤読して impl phase へ早期進行するハザード

## Why now

#249 で設計承認ゲートを新設した直後であり、初の差し戻しが発生する前に配管を整備しないと、約束された挙動と実挙動の乖離がそのまま運用事故（コメント無視・早期 impl 進行）になる。

## Outcome

- 差し戻しコメントが design phase 再実行の iteration 1 の generate プロンプトに verbatim で到達する
- 非 'ok' 応答は成果物セット全体の差し戻しとして扱われる規律（部分承認は承認ではない）が SKILL.md に明文化されている
- コメントのセクション単位 finding 分割の規律が明文化されている
- BATS pin が新配管を固定し green

## What

- Workflow args に `rejectionFindings`（配列、各要素 `priority` + `evidence_ref` 付き）を追加し、design phase 再実行時に iteration 1 の generate プロンプトへ verbatim 埋め込み
- SKILL.md Flow 節に明文化: 非 'ok' 応答は全体差し戻し / コメントはセクション単位で分割して finding 化 / `evidence_ref` = 人間コメント
- BATS pin 追加

## Non-Goals

- 要件ゲート（Gate ①）・merge ゲートの差し戻し配管 — 本 Issue は design gate のみ（他ゲートは対話内で完結し Workflow 再実行を伴わない）
- reviewing-deliverables 本体の変更 — findings スキーマは既存のまま流用

## Open Questions

- `rejectionFindings` の priority 既定値（fail-safe 原則なら 0 = blocker 扱い）→ plan で決定
