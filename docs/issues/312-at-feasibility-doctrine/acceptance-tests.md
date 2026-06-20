# Acceptance Tests: acceptance test の「計画前 feasibility 実地探索」を正典フローとして確立する

<!-- AT lifecycle: planned → draft → green → regression
     各エントリには状態マーカー [planned] / [draft] / [green] / [regression] を付与する。
     状態は実装の進行に合わせて更新する。

     本 Issue は doc-only 成果物のため、AT はすべて構造テスト（bats）として実装する
     （`tests/acceptance/AT-312.bats`）。doctrine 本文の文言・存在・相互参照を
     不変条件（invariant）として検証し、point-in-time の値（version 数値・行数・日付）は固定しない。 -->

## AT-312-01: doctrine ファイルが存在し Loaded-by メタを持つ

- [x] [green] AT-312-01: 正典ドキュメントが規定パスに存在し、冒頭に参照 skill を列挙する `> **Loaded by:**` メタコメントを持つ
  - Given: methodology 正典群の配置規約（`docs/methodology/README.md` Conventions）に従う
  - When: `docs/methodology/acceptance-test-feasibility.md` を検査する
  - Then: ファイルが実在し、本文に `> **Loaded by:**` 行が含まれる

## AT-312-02: 普遍ルール（GUI / 非 GUI 二分岐と判定基準）

- [x] [green] AT-312-02: doctrine が技術スタック非依存の「計画前 feasibility 実地探索」原則として、GUI=実操作／非 GUI=実 API call の二分岐とその判定基準を明記する
  - Given: doctrine 本文を読む
  - When: 普遍ルール節を検査する
  - Then: GUI（実操作）と 非 GUI（実 API call）の二分岐、および両者を振り分ける判定基準が記述されている

## AT-312-03: フロー統合点（[planned] 確定前のプローブ）

- [x] [green] AT-312-03: doctrine が 6-step flow への統合点として、AT を `[planned]` 確定にする前に feasibility プローブを通すこと、および `writing-plan-and-tests` を統合点として言及する
  - Given: doctrine 本文を読む
  - When: フロー統合点節を検査する
  - Then: `[planned]` と `writing-plan-and-tests` への言及があり、プローブを `[planned]` 確定前に通す旨が記述されている

## AT-312-04: ユーザーゲート（ルート不在／不安定時）

- [x] [green] AT-312-04: doctrine が、実現可能ルートが見つからない／不安定なときに計画段階でユーザー判断を仰ぐゲートを記述する
  - Given: doctrine 本文を読む
  - When: ユーザーゲート節を検査する
  - Then: 「ルート不在／不安定 → 計画段階でユーザー判断を仰ぐ」というゲート条件が記述されている

## AT-312-05: ツール抽象（プローブ抽象・非密結合）

- [x] [green] AT-312-05: doctrine が feasibility プローブを抽象として扱い、addon が具体手段（Playwright CLI / Xcode MCP / API client 等）を供給する非密結合の形を記述する
  - Given: doctrine 本文を読む
  - When: ツール抽象節を検査する
  - Then: 「プローブ」抽象と、具体手段を addon が供給し特定ツールに密結合しない旨が記述されている

## AT-312-06: autopilot 整合（design phase / Gate ②）と相互参照健全性

- [x] [green] AT-312-06: doctrine が autopilot design phase での feasibility プローブ実行と Gate ②（設計承認）への反映を記述し、既存 methodology doc への相互参照リンクが健全で README に登録されている
  - Given: doctrine 本文と `docs/methodology/README.md` を読む
  - When: autopilot 整合節と相互参照を検査する
  - Then: design phase と Gate ②（設計承認）への反映が記述され、doctrine が参照する既存 doc（atdd-guide / test-mapping / definition-of-ready / test-execution-policy）の相対リンク先がすべて実在し、README の Documents 表に `acceptance-test-feasibility.md` 行が存在する

## AT-312-07: 外部調査根拠節（一次情報リンク付き 3 件以上）

- [x] [green] AT-312-07: doctrine の根拠節に、agentic E2E / browser・mobile UI agent / API 探索検証の 3 領域にわたる外部調査が、一次情報 URL 付きで 3 件以上要約・引用されている
  - Given: PRD Outcome line 24 — 外部調査（agentic E2E / self-verifying AC / browser・mobile UI agent / API 探索検証）の傾向・採用事例・落とし穴が doctrine の根拠として要約・引用されている
  - When: docs/methodology/acceptance-test-feasibility.md の外部調査根拠節を検査する
  - Then: 外部調査根拠節の見出しが存在し、https:// URL が 3 件以上あり、3 領域（agentic E2E、browser/mobile UI agent、API contract verification）が言及されている

## AT-312-08: 既存 4 doc からの逆参照（双方向相互参照）

- [x] [green] AT-312-08: 既存 methodology 4 doc（atdd-guide / test-mapping / definition-of-ready / test-execution-policy）がそれぞれ acceptance-test-feasibility.md を逆参照している
  - Given: PRD Outcome line 23 — 「既存 methodology doc と矛盾せず、相互参照が張られている」（双方向を含意）
  - When: 各既存 doc を検査する
  - Then: 4 doc それぞれに acceptance-test-feasibility への参照（リンクまたは言及）が存在する

<!-- 実装開始後は [planned] → [draft] に変更する -->
<!-- テストが通過したら [draft] → [green] に変更する -->
<!-- リグレッション対象になったら [green] → [regression] に変更する -->

## ライフサイクル例

| 状態 | 意味 |
|------|------|
| [planned] | テスト設計済み・未実装 |
| [draft] | 実装中・まだ通過していない |
| [green] | テスト通過済み |
| [regression] | リグレッション対象として継続監視中 |
