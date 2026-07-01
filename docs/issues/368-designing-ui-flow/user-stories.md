# User Stories: 新スキル `designing-ui` + 方法論 doc 2 本 — UI/UX 設計フロー

## Functional Story

<!-- 機能要求を persona 抜き Connextra 形式で記述する。1 ストーリー = 1 ユーザーゴール。 -->

### US-1: designing-ui スキルの起動

**I want to** `claude skill atdd-kit:designing-ui <issue>` で新スキル `designing-ui` を起動できる,
**so that** PRD 承認後の UI/UX 設計工程を明示的な方法論に沿って開始できる.

### US-2: UI 要件フェーズの引き出し

**I want to** designing-ui が UI 要件確認フェーズで機能要件と画面の対応を問いで引き出し `docs/issues/<NNN>/ui-requirements.md` を生成する,
**so that** 機能要件がどの画面に落ちるかを暗黙知にせず対応表として残せる.

### US-3: 情報設計フェーズの確定

**I want to** designing-ui が情報設計フェーズで画面単位・階層・遷移を確定し `docs/issues/<NNN>/information-architecture.md` を生成する,
**so that** ワイヤー着手前に画面の単位が固まり後続工程が構造を前提にできる.

### US-4: ワイヤーフレームフェーズの骨格記述

**I want to** designing-ui がワイヤーフレームフェーズで骨格・配置・遷移を装飾なしで記述し `docs/issues/<NNN>/wireframes.md` を生成する,
**so that** 色やフォントに先立って画面の構造的意思決定を明示できる.

### US-5: ビジュアル方針フェーズの選択根拠

**I want to** designing-ui がビジュアル方針フェーズでプラットフォームと Design system の選択根拠を記録し `docs/issues/<NNN>/visual-policy.md` を生成する,
**so that** 装飾の意思決定が参照規格（HIG / Material Design / Baseline）に紐づいた形で残る.

### US-6: 実装連携フェーズの handoff

**I want to** designing-ui が実装連携フェーズでコンポーネント・トークン・アクセシビリティ注記を `docs/issues/<NNN>/implementation-handoff.md` にまとめる,
**so that** エンジニアが実装に必要な粒度の情報を受け取れる.

### US-7: 引き出し型の 5 フェーズ駆動

**I want to** designing-ui が UI 要件 → 情報設計 → ワイヤー → ビジュアル方針 → 実装連携 の 5 フェーズを引き出し型（pull）対話で順に駆動する,
**so that** 作り手の頭の中にある設計を問いで顕在化しながら段階的に決めていける.

### US-8: 方法論 doc1（骨格まで）の参照

**I want to** `docs/methodology/designing-ui-doc1.md` が UI 要件・情報設計・ワイヤーフレームの規律（装飾なし・骨格まで）を示す,
**so that** UI 構造の意思決定規律を doc として参照できる.

### US-9: 方法論 doc2（装飾・実装連携）の参照

**I want to** `docs/methodology/designing-ui-doc2.md` がビジュアル方針・プラットフォーム作法・Design system 再利用・実装連携の規律を示す,
**so that** 装飾の文法とプラットフォームへの落とし込み規律を doc として参照できる.

### US-10: writing-design-doc との住み分け

**I want to** designing-ui の責任境界が「画面設計の工程駆動」に限定され、技術アーキテクチャのトレードオフ記録は `writing-design-doc` が担う旨がスキルに明記される,
**so that** 二つのスキルの役割が重複せず適切に使い分けられる.

## Constraint Story (Non-Functional)

<!-- 非機能要求（NFR）を Story 形式で表現する（Pichler 2013）。
     システムが満たすべき品質特性（性能・セキュリティ・信頼性等）を制約として記述する。 -->

### CS-1: 概念とプラットフォーム作法の分離

**I want to** 「何を出すか（概念・コンテンツ）」はプロダクト側（PRD）が決め、「どう見せるか（実装の作法）」は対象プラットフォームの規約に従い、独自判断は [独自] と明示される中核思想がスキルと doc に一貫して体現されている,
**so that** UI 設計の意思決定の責任所在が曖昧にならず判断根拠を追跡できる.

### CS-2: アクセシビリティの横串適用

**I want to** アクセシビリティ（WAI-ARIA / WCAG 2.2 / JIS Z 8520）がフェーズ横断の哲学として扱われ、ワイヤーフェーズから組み込まれている,
**so that** アクセシビリティが後付けではなく設計初期から担保される.

### CS-3: designing-ui のスコープ限定

**I want to** designing-ui が UI 設計成果物のみを生成し、コード実装・AT 実装・Plan 作成を担わない責任境界を守っている,
**so that** 各スキルの役割分担が崩れず後続の writing-plan-and-tests との接続が明確になる.

### CS-4: 成果物ファイル配置と命名の一貫性

**I want to** 成果物が `docs/issues/<NNN>/` 配下に承認済み命名（ui-requirements / information-architecture / wireframes / visual-policy / implementation-handoff）で、方法論 doc が新設 `docs/methodology/` 配下に配置される,
**so that** どの Issue でも同じ構造で UI 設計成果物と方法論を参照できる.

### CS-5: 構造検証 BATS pin

**I want to** `skills/designing-ui/SKILL.md`・`docs/methodology/designing-ui-doc1.md`・`docs/methodology/designing-ui-doc2.md` の存在を確認する BATS pin が追加されている,
**so that** 追加ファイルの欠落を構造検証で自動的に検知できる.

### CS-6: バージョンと変更記録の整合

**I want to** 新スキル追加に伴い `plugin.json` の minor version が bump され `CHANGELOG.md` に本 Issue 変更が記録される,
**so that** DEVELOPMENT.md の Versioning 規約に沿ってリリース履歴が一貫する.
