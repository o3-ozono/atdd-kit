# User Stories: docs/methodology — 要件抽出の技法カタログ（Pre-mortem / Job Story / One question at a time / Out-of-scope question）を一次情報付きで新設

## Functional Story

<!-- 機能要求を persona 抜き Connextra 形式で記述する。1 ストーリー = 1 ユーザーゴール。 -->

### FS-1: 4 技法の一次情報付きカタログ

**I want to** `docs/methodology/elicitation-techniques/` 以下で Pre-mortem / Job Story / One question at a time / Out-of-scope question の 4 技法を一次情報（著者・出典・発行年・URL または書誌情報）付きで参照できる,
**so that** セッションごとに技法の使い方がブレず、原典から乖離した独自解釈の定着を防ぎながら要件を安定した質で引き出せる.

### FS-2: 各技法ドキュメントの統一フィールド

**I want to** 各技法ドキュメントが「目的 / 問いの型 / 適用先マッピング / 一次情報 / 例」の統一フィールドを備えている,
**so that** どの技法でも「いつ・何を・どう問うか」を同じ構造で参照でき、技法ごとの適用タイミング・目的・問いの型を横並びで把握できる.

### FS-3: 共通原則の独立ドキュメント

**I want to** 4 技法に横断する共通原則（対話のキャッチボールで埋める / 上位工程の責務を侵さない / 対話ログを残す）を独立ドキュメント（`common-principles.md` 相当）として配置し、各技法ドキュメントから参照する,
**so that** 共通原則を各技法に分散させず一箇所で管理でき、技法カタログ全体の運用指針を一貫して辿れる.

### FS-4: SKILL.md からのマッピング参照

**I want to** `defining-requirements/SKILL.md` および `batch-discovery/SKILL.md` の各節から、対応する技法ドキュメントへのマッピング参照（節名 → doc リンク）だけを持ち、詳細手順・一次情報・例は doc 側に委ねる,
**so that** SKILL.md が肥大化せず、スキル実行者が「どこに何があるか」を把握しやすい状態を保てる.

## Constraint Story (Non-Functional)

<!-- 非機能要求（NFR）を Story 形式で表現する（Pichler 2013）。
     システムが満たすべき品質特性（性能・セキュリティ・信頼性等）を制約として記述する。 -->

### CS-1: 一次情報への忠実性

**I want to** 各技法の「目的」が一次情報に忠実に記述され、独自解釈を加える箇所には `[独自]`（共通原則では `[独自整理]`）が明示されている,
**so that** 原典に基づく記述と独自整理の境界が読み手に判別でき、技法の変質（原典から乖離した独自解釈の定着）を抑止できる.

### CS-2: 構造検証の自動ピン

**I want to** `docs/methodology/elicitation-techniques/` の構造（ファイル一覧・必須フィールドの存在）を検証する BATS テストが追加されている,
**so that** カタログのファイル欠落や必須フィールドの抜けが自動で検出され、カタログ構造が継続的に担保される.

### CS-3: バージョン・CHANGELOG 規約準拠

**I want to** CHANGELOG.md に本変更が記載され、`.claude-plugin/plugin.json` の patch version が DEVELOPMENT.md Versioning 規約に従って bump されている,
**so that** リリース履歴とバージョンが規約通り一貫して管理され、変更の追跡と配布が破綻しない.
