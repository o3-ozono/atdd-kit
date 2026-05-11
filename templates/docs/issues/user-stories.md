# User Stories: [Issue タイトル]

## Functional Story

<!-- 機能要求を Connextra 形式で記述する。1 ストーリー = 1 ユーザーゴール。 -->

**As a** [persona],
**I want to** [goal],
**so that** [reason].

<!-- 例:
**As a** Hiro（solo developer）,
**I want to** `docs/issues/NNN/` に置く artifact テンプレートをすぐ取得できる,
**so that** 新しい Issue ごとに構造をゼロから再導出せず作業を始められる.
-->

## Constraint Story (Non-Functional)

<!-- 非機能要求（NFR）を Story 形式で表現する（Pichler 2013）。
     システムが満たすべき品質特性（性能・セキュリティ・信頼性等）を制約として記述する。 -->

**As a** [persona],
**I want to** [quality attribute が保証された状態],
**so that** [利用者が受ける恩恵].

<!-- In order to [quality attribute], as a [persona], the system must [NFR condition].
     例:
     In order to protect user data, as a Hiro, the system must encrypt all stored tokens at rest.

     または Connextra 変形:
     **As a** Hiro,
     **I want to** テンプレートが UTF-8 で保存されている,
     **so that** 日本語コンテンツをそのまま利用できる.
-->
