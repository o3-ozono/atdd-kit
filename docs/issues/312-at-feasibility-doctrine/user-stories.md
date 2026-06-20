# User Stories: acceptance test の「計画前 feasibility 実地探索」を正典フローとして確立する

## Functional Story

<!-- 機能要求を persona 抜き Connextra 形式で記述する。1 ストーリー = 1 ユーザーゴール。 -->

### Story 1: 既存資産の棚卸し

**I want to** `docs/methodology/` 配下の正典 doc・関連 skill（launching-preview / running-atdd-cycle / writing-plan-and-tests）・過去調査（#278 / #222）・addon（ios / web）の MCP/preview 構成を棚卸しする,
**so that** AT feasibility doctrine を既存資産と矛盾しない土台の上に積み上げられる.

### Story 2: 外部調査による doctrine 根拠の収集

**I want to** deep-research ハーネスで agentic E2E / self-verifying AC / browser・mobile UI agent / API 探索→契約検証 を fan-out 調査し、「計画前の feasibility 実地探索」採用の有無・パターン・落とし穴を抽出する,
**so that** doctrine の方針が一次情報に裏付けられ、暗黙知ではなく根拠付きの正典として成立する.

### Story 3: AT feasibility 正典ドキュメントの執筆

**I want to** `docs/methodology/` に AT feasibility の正典ドキュメントを置き、(1) 普遍ルール（GUI=実操作／非 GUI=実 API call の二分岐と判定基準）, (2) 6-step flow へのフロー統合点, (3) 実現可能ルート不在/不安定時のユーザーゲート設計, (4) feasibility プローブのツール抽象, (5) autopilot design phase と Gate ② への反映 の 5 セクションを含める,
**so that** 計画段階で feasibility を前倒し検証する原則が技術スタック非依存の正典として確立し、実装フェーズでの手戻りを削減できる.

## Constraint Story (Non-Functional)

<!-- 非機能要求（NFR）を Story 形式で表現する（Pichler 2013）。
     システムが満たすべき品質特性（性能・セキュリティ・信頼性等）を制約として記述する。 -->

### Constraint 1: 既存正典との非矛盾と相互参照の健全性

**I want to** doctrine が既存 methodology doc（atdd-guide.md / test-mapping.md / definition-of-ready.md / test-execution-policy.md 等）と矛盾せず、相互参照リンクが張られている状態,
**so that** 正典群が一貫性を保ち、読者がどの doc から辿っても整合した方針に到達できる.

### Constraint 2: ツール非密結合（プローブ抽象）

**I want to** feasibility プローブが Playwright CLI / Xcode MCP / API client 等の具体手段に密結合せず「プローブ」という抽象で扱われ、addon が具体手段を供給する形になっている状態,
**so that** addon（ios / web）が増えても各スタックで方針が再発明されず、doctrine が普遍ルールとして再利用できる.

### Constraint 3: レビュー PASS（内部整合の検証可能性）

**I want to** doc-only 成果物として、必須 5 セクションの存在・既存 doc との相互参照健全性が `reviewing-deliverables` のレビューを PASS できる状態,
**so that** doctrine の内部整合と既存正典との非矛盾が機械的・構造的に担保される.
