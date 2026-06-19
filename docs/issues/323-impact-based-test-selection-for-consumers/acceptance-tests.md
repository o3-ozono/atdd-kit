# Acceptance Tests: 影響範囲ベースのテスト選択を利用プロジェクトにも提供する（一般化＋addon配布＋フロースキル配線）

<!-- AT lifecycle: planned → draft → green → regression
     各エントリには状態マーカー [planned] / [draft] / [green] / [regression] を付与する。
     状態は実装の進行に合わせて更新する。 -->

## AT-001: ランナーのプラットフォーム別アダプタ一般化

- [ ] [planned] AT-001: `--platform` で選択ロジックがプラットフォーム別に分岐する
  - Given: `impact_map.sh` に `--platform {web|ios|other}` が実装され、各プラットフォーム用の `impact_rules.yml` が与えられている
  - When: 同じ変更パス集合を `--platform web` / `--platform ios` / `--platform other` で実行する
  - Then: それぞれのアダプタが「変更パス集合 → 実行すべきテスト識別子集合」の共通契約で、各フレームワークに対応した識別子（web: テストファイル、iOS: テストターゲット、other: bats ファイル）を stdout に 1 行 1 件で返す

## AT-002: `impact_rules.yml` のプラットフォーム別テンプレート配布

- [ ] [planned] AT-002: 配布用テンプレートがパーサで読め、構造起点になる
  - Given: `addons/web/config/impact_rules.yml` と `addons/ios/config/impact_rules.yml` がテンプレートとして存在する
  - When: 各テンプレートを `impact_map.sh --config <tmpl> --all` で読み込む
  - Then: パースエラーなく exit 0 で終了し、テンプレートが利用プロジェクト構造（web: `src/**` 等、iOS: ターゲット構造）のパスルールを含む

## AT-003: addon 経由の配布と setup 配線

- [ ] [planned] AT-003: web/iOS addon が影響度ランナー＋ルールテンプレートを配布する
  - Given: `addons/web/addon.yml`（新設）と `addons/ios/addon.yml`（更新）の `deploy:` に影響度ランナーとルールテンプレートの src→dest が宣言され、`setup-web` / `setup-ios` がそれを参照する
  - When: addon.yml の deploy 宣言と setup コマンドの deploy 手順を突き合わせる
  - Then: 各 addon.yml の deploy エントリと setup コマンドの記述が一致し、`addons/web/addon.yml` が `addons/README.md` の必須スキーマフィールドを満たす

## AT-004: フロースキルが既定で影響スコープ実行になる

- [ ] [planned] AT-004: inner loop・AT ゲート・post-deploy 回帰が影響スコープを既定にする
  - Given: `running-atdd-cycle`・autopilot AT ゲート・`merging-and-deploying`（post-deploy 回帰）の各実行経路がある
  - When: 各スキル/経路のテスト実行コマンドを確認する
  - Then: いずれも既定で影響スコープ実行（`--impact`）を指しており、毎回フルスイートを呼んでいない

## AT-005: 「実行は絞る／ゲートはフル」原則の methodology 文書化

- [ ] [planned] AT-005: 一般原則がプラットフォーム非依存で明文化される
  - Given: `docs/methodology/test-execution-policy.md`（および必要なら追加 methodology doc）がある
  - When: methodology doc を読む
  - Then: 「影響範囲で実行を絞る／ゲートではフル実行」がプラットフォーム非依存の標準ドクトリンとして記述され、#323 の一般化・配布が**完了済み**として反映されている（「out of scope / owned by #323」の保留文言が残っていない）

## AT-006: other（atdd-kit 自身）の非破壊温存

- [ ] [planned] AT-006: 一般化後も `other` の `--impact` 既存挙動が変わらない
  - Given: アダプタ分離後の `impact_map.sh`
  - When: `--platform other`（および `--platform` 省略時）で `--all` / `--base <ref>` を実行する
  - Then: 出力が分離前の bats/`@covers` 選択結果と等価で、atdd-kit 自身の現行テスト選択が壊れていない

## AT-007: マージ/CI ゲートでのフルスイート強制

- [ ] [planned] AT-007: ゲートでは影響スコープに絞らずフル実行が強制される
  - Given: `merging-and-deploying`（マージゲート）と autopilot マージゲートの実行経路がある
  - When: マージゲートのテスト実行コマンドを確認する
  - Then: マージゲート/CI は `--all`（フルスイート）を強制しており、影響スコープへ絞り込んでいない（「実行は絞る／ゲートはフル」の非対称が担保されている）

## AT-008: unmatched パスのフル実行フォールバック

- [ ] [planned] AT-008: ルール未一致パスは全プラットフォームでフル実行に落ちる
  - Given: 各プラットフォーム用 `impact_rules.yml` のどのルールにも一致しない変更パスがある
  - When: そのパスを `--platform web` / `--platform ios` / `--platform other` で実行する
  - Then: いずれも全テストを出力し exit 0 で終了する（#135 の保守的フォールバックが一般化後も維持され、絞りすぎで取りこぼさない）

## AT-009: 配布物のバージョン・CHANGELOG 整合（regression 不変条件）

- [ ] [planned] AT-009: feature 変更がバージョンと CHANGELOG に整合反映される
  - Given: 本 Issue で addon（web 新設）・ランナー一般化・配布が追加される
  - When: `.claude-plugin/plugin.json` の version と `CHANGELOG.md` 最上段リリース見出しを突き合わせる
  - Then: plugin.json の version が CHANGELOG 最上段のリリース見出しと一致する（特定バージョン文字列に固定せず「両者が一致する」不変条件で判定する）

## ライフサイクル例

| 状態 | 意味 |
|------|------|
| [planned] | テスト設計済み・未実装 |
| [draft] | 実装中・まだ通過していない |
| [green] | テスト通過済み |
| [regression] | リグレッション対象として継続監視中 |
