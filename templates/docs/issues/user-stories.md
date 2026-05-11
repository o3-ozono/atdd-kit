# User Stories: [Issue タイトル]

## Functional Story

<!-- 機能要求を persona 抜き Connextra 形式で記述する。1 ストーリー = 1 ユーザーゴール。 -->

**I want to** [goal],
**so that** [reason].

<!-- 例:
**I want to** `docs/issues/NNN/` に置く artifact テンプレートをすぐ取得できる,
**so that** 新しい Issue ごとに構造をゼロから再導出せず作業を始められる.
-->

## Constraint Story (Non-Functional)

<!-- 非機能要求（NFR）を Story 形式で表現する（Pichler 2013）。
     システムが満たすべき品質特性（性能・セキュリティ・信頼性等）を制約として記述する。 -->

**I want to** [quality attribute が保証された状態],
**so that** [利用者が受ける恩恵].

<!-- 例:
**I want to** すべての保存トークンが at-rest で暗号化されている,
**so that** ストレージ漏洩時にトークンが平文露出しない.

または In-Order-To 変形:
In order to [quality attribute], the system must [NFR condition].
例:
In order to protect user data, the system must encrypt all stored tokens at rest.
-->
