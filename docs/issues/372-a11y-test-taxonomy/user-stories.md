# User Stories: docs/methodology/a11y-test-taxonomy.md 新設 — a11y テスト手段の3分割と「自動 green ≠ 達成」の明文化

## Functional Story

<!-- 機能要求を persona 抜き Connextra 形式で記述する。1 ストーリー = 1 ユーザーゴール。 -->

### FS-1: テスト手段の3分割を参照できる

**I want to** a11y テスト手段が「自動・静的」「自動・操作」「手動」の3カテゴリに分割され、各手段のカバー対象・粒度・実行タイミング（unit / CI ゲート / E2E / design review）が定義されたドキュメントを参照できる,
**so that** どの手段で何を検証するかの共通認識を持ち、カバレッジの抜けや重複を避けて a11y 対応を進められる.

### FS-2: 「自動 green ≠ a11y 達成」を根拠付きで確認できる

**I want to** 自動ツールが WCAG 違反の一部のみを検出するという事実を Playwright ドキュメント・Deque 分析を一次情報として引用した形で読み取り、手動 review を design review 必須ゲートとする理由を確認できる,
**so that** 自動検査が緑になった段階で手動レビューを省略する誤解を避け、design review 必須化の根拠として参照できる.

### FS-3: 適用基準（WCAG 2.2 AA / JIS 版差）を参照できる

**I want to** WCAG 2.2 AA を第一候補とする根拠と、JIS X 8341-3:2016 が WCAG 2.0 相当であり版差（WCAG 2.0 ↔ 2.2）に留意が必要である旨の注記を、適用基準節として読み取れる,
**so that** どの適合基準を土台に a11y を設計・検証すべきかを迷わず判断できる.

### FS-4: 「テスト手段の分け方」と「WCAG SC トリアージ」が別軸だと確認できる

**I want to** テスト手段の分類（本ドキュメントの主題）と WCAG SC レベルのトリアージ（どの SC をどこまで狙うか）が独立した設計判断軸であり混同しないことが明記されているのを読み取れる,
**so that** 手段の整理とレベルの選択を混同せず、それぞれ適切なフェーズ・Issue で扱える.

### FS-5: ドキュメント構造を自動検証できる

**I want to** `docs/methodology/a11y-test-taxonomy.md` のファイル存在と必須セクション（3分割・自動 green ≠ 達成・適用基準・別軸）の構造を検証する BATS テストが `tests/` 配下に存在する,
**so that** ドキュメントの必須構成が欠落・退行した場合に自動で検知できる.

## Constraint Story (Non-Functional)

<!-- 非機能要求（NFR）を Story 形式で表現する（Pichler 2013）。
     システムが満たすべき品質特性（性能・セキュリティ・信頼性等）を制約として記述する。 -->

### CS-1: 一次情報のトレーサビリティ

**I want to** 「自動 green ≠ a11y 達成」の主張が Playwright ドキュメントおよび Deque 分析という一次情報に裏付けられ、参照元をたどれる状態になっている,
**so that** ドキュメントの主張が独自解釈ではなく検証可能な根拠に立脚していると信頼できる.

### CS-2: バージョニング規約の遵守

**I want to** 本 Issue のマージに伴って CHANGELOG.md が更新され、`.claude-plugin/plugin.json` の patch version が 1 上がっている,
**so that** DEVELOPMENT.md の Versioning 規約に準拠し、変更が追跡可能な形でリリースに反映される.
