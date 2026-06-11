# User Stories: autopilot 設計ゲート差し戻しの未規定挙動 — コメントを再実行へ運ぶ配管の不在と部分承認の扱い

## Functional Story

<!-- 機能要求を persona 抜き Connextra 形式で記述する。1 ストーリー = 1 ユーザーゴール。 -->

### US-1: 差し戻しコメントの再実行への配管

**I want to** 設計ゲートで差し戻したコメントが Workflow args の `rejectionFindings`（各要素 `priority` + `evidence_ref` 付きの配列）として design phase 再実行に渡り、iteration 1 の generate プロンプトに verbatim で到達する,
**so that** 人間の指摘が `prevFindings = null` 初期化で握り潰されることなく、確実に修正へ反映される.

### US-2: 部分承認は承認ではない規律の明文化

**I want to** 設計承認ゲートへの非 'ok' 応答（「A は ok / B は要修正」を含む）が成果物セット全体の差し戻しとして扱われる規律が SKILL.md Flow 節に明文化されている,
**so that** 部分承認を承認と誤読して ATDD（impl phase）へ早期進行する運用事故を防げる.

### US-3: コメントのセクション単位 finding 分割の明文化

**I want to** 複合コメント（「セクション A は X、B は Y」）をセクション単位で分割して N 件の finding にし、各 finding の `evidence_ref` を人間コメントとする規律が SKILL.md に明文化されている,
**so that** 複数の指摘が 1 finding に潰れて一部が取りこぼされることなく、個別に追跡・修正される.

## Constraint Story (Non-Functional)

<!-- 非機能要求（NFR）を Story 形式で表現する（Pichler 2013）。
     システムが満たすべき品質特性（性能・セキュリティ・信頼性等）を制約として記述する。 -->

### CS-1: BATS pin による配管の固定

**I want to** `rejectionFindings` の新配管が BATS pin で固定され green である,
**so that** 将来の SKILL.md / Workflow script 変更で配管が黙って壊れたとき、約束された挙動と実挙動の乖離（コメント無視・早期 impl 進行）が運用事故になる前に検知できる.
