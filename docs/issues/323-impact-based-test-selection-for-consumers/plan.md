# Plan: 影響範囲ベースのテスト選択を利用プロジェクトにも提供する（一般化＋addon配布＋フロースキル配線）

<!-- 2-5 分粒度のタスク行と verification 行を交互に配置する（superpowers writing-plans 形式）。
     各タスクは単一の操作に限定し、verification で完了条件を即確認できる粒度にする。 -->

## 設計メモ（Open Questions の確定）

PRD の Open Questions を以下に確定する（詳細トレードオフは `design-doc.md` 参照）:

- **アダプタ interface** — `impact_map.sh` に `--platform {web|ios|other}` を追加し、プラットフォーム別の選択ロジックを内部関数（`select_web` / `select_ios` / `select_other`）に分岐する。共通契約は「変更パス集合 → 実行すべきテスト識別子集合（stdout, 1 行 1 件）」。`other` は現行 bats/`@covers` ロジックをそのまま温存（非破壊）。
- **`impact_rules.yml` の配布** — プラットフォーム別の**静的テンプレート**を配布（半自動生成は Non-Goal）。`config/impact_rules.yml`（atdd-kit 自身＝other 用）は現状維持。
- **iOS 選択深度** — `*.swift` 変更 → 単純 glob でのテストターゲット対応に留める（依存解釈は Non-Goal）。
- **`addons/web` の最小範囲** — 影響度ランナー＋ルールテンプレートの deploy ＋ detect ＋ setup-web 配線のみ。MCP/hooks/CI フラグメントは Non-Goal。
- **「ゲートはフル」の強制点** — スキル分岐（`merging-and-deploying` / autopilot マージゲート）で `--all` を強制。ランナーやテンプレートにゲート判定は持たせない。
- **unmatched フォールバック** — 全プラットフォームでフル実行フォールバックを既定維持（警告のみモードは作らない）。
- **other 回帰検証** — 既存 BATS（`impact_map` を覆うもの）＋ 本 Issue で追加する非破壊 AT で保証する。

## Implementation

### ランナーの一般化（アダプタ化）

- [ ] `scripts/impact_map.sh` に `--platform {web|ios|other}` オプションを追加し、未指定時は `other`（現行挙動）にフォールバックする
- [ ] verify: `impact_map.sh --platform other --all --layer BATS` が `--platform` 無し実行と同一の出力を返す（diff 空）

- [ ] `impact_map.sh` の bats/`@covers` 選択ロジックを内部関数 `select_other()` に切り出し、main から呼ぶ（挙動は変えない純粋な抽出）
- [ ] verify: 抽出前後で `impact_map.sh --base HEAD~1 --layer BATS` の出力が一致する

- [ ] `select_web()` を追加する — 変更パスを web 用 `impact_rules.yml` の `src/**` 等の glob に照合し、対応するテストファイル（jest/vitest）識別子を返す
- [ ] verify: web 用ルールを与えた `--platform web` 実行で、`src/foo.ts` 変更が対応テストを 1 件以上返す

- [ ] `select_ios()` を追加する — `*.swift` 変更を iOS 用 `impact_rules.yml` のターゲット glob に照合し、対応する XCTest ターゲット識別子を返す
- [ ] verify: iOS 用ルールを与えた `--platform ios` 実行で、`Sources/Foo.swift` 変更が対応テストターゲットを返す

- [ ] 各プラットフォームで unmatched パスをフル実行フォールバックに乗せる（`select_other` の現行フォールバックと同じ分岐を web/ios にも適用）
- [ ] verify: ルール未一致パスを与えた `--platform web` / `--platform ios` 実行が「全テスト」を出力し exit 0 になる

### `impact_rules.yml` テンプレート化

- [ ] `addons/web/config/impact_rules.yml`（テンプレート）を新規作成 — `src/**` `tests/**` 等 web 標準構造のパスルールを記述
- [ ] verify: テンプレートが `impact_map.sh` のパーサでエラーなく読める（`--config <tmpl> --all --layer skill-e2e` が exit 0）

- [ ] `addons/ios/config/impact_rules.yml`（テンプレート）を新規作成 — iOS ターゲット構造（`Sources/**` `Tests/**` 等）のパスルールを記述
- [ ] verify: テンプレートが `impact_map.sh --config <tmpl> --all` で exit 0

### addon 配布

- [ ] `addons/web/` を新設し `addon.yml` を作成（`name` / `display_name` / `deploy`（ランナー＋ルールテンプレート）/ `detect`（`package.json` 等の web 判定パターン））
- [ ] verify: `addons/web/addon.yml` が `addons/README.md` の addon.yml スキーマの必須フィールドを満たす

- [ ] `addons/ios/addon.yml` の `deploy:` に iOS 向け影響度ランナー（`impact_map.sh` 派生 or 参照）＋ `config/impact_rules.yml` テンプレートを追加する
- [ ] verify: `addons/ios/addon.yml` の deploy エントリに新規 src→dest ペアが含まれる

- [ ] `commands/setup-web.md` のプレースホルダを実装に置き換え（addon.yml 読込 → ランナー＋ルールテンプレート deploy → サマリ表示）
- [ ] verify: `setup-web.md` から「placeholder」「not yet available」の文言が消え、deploy 手順が記述されている

- [ ] `commands/setup-ios.md` の deploy 表に影響度ランナー＋ルールテンプレートの行を追加する
- [ ] verify: `setup-ios.md` の Deploy Scripts 表に新規行が含まれる

- [ ] `/atdd-kit:init` の addon 配線手順に web addon を含める（init が addons を列挙する箇所に web を追加）
- [ ] verify: init の手順から `addons/web` が参照される

### フロースキル配線

- [ ] `skills/running-atdd-cycle/SKILL.md` の inner loop 実行を、利用プロジェクトでもプラットフォーム別影響スコープ実行になるよう記述更新（`run-tests.sh --impact` のプラットフォーム解決を明示）
- [ ] verify: running-atdd-cycle の該当節がプラットフォーム別影響実行に言及している

- [ ] autopilot AT ゲートの実行を既定で影響スコープ実行にする（該当スクリプト/スキルの AT 実行コマンドを `--impact` 経路に揃える）
- [ ] verify: autopilot AT ゲートの実行経路が影響スコープ実行を既定にしている

- [ ] `skills/merging-and-deploying/SKILL.md` の post-deploy 回帰を影響スコープ実行に、**マージゲートはフルスイート強制**（`--all`）になるよう分岐を明示する
- [ ] verify: merging-and-deploying がマージゲート＝`--all` 強制、post-deploy 回帰＝影響スコープであることを明記している

### methodology 文書化

- [ ] `docs/methodology/test-execution-policy.md` の「Scope Boundary with #323」を更新 — 一般化・配布が #323 で**完了**した旨と、利用プロジェクトでもプラットフォーム別影響実行が標準ドクトリンになったことを反映する
- [ ] verify: 「out of scope here / owned by #323」の保留文言が、完了を示す記述に置き換わっている

- [ ] 「影響範囲で実行を絞る／ゲートではフル実行」のプラットフォーム非依存原則を `docs/methodology/` に明記（既存 policy doc の拡張で足りるか別ファイル化が要るかは記述量で判断）
- [ ] verify: methodology doc が web/iOS/other いずれにも適用される一般原則として「絞る／ゲートはフル」を記述している

## Testing

- [ ] `tests/` に impact_map のプラットフォーム分岐 BATS を追加（`@covers scripts/impact_map.sh`）— other 非破壊・web/ios 選択・unmatched フォールバックを覆う
- [ ] verify: 追加 BATS が green（`scripts/run-tests.sh --impact --base <base>` 経由）

- [ ] `addons/web/tests/` / `addons/ios/tests/` に addon.yml deploy エントリと impact_rules テンプレートの構造 BATS を追加
- [ ] verify: 追加 addon BATS が green（`bats addons/web/tests/ addons/ios/tests/`）

## Finishing

- [ ] バージョン bump（`.claude-plugin/plugin.json`）— 新 addon（web）＋新規 setup-web 実装は minor。スキル rename は無いため major 不要
- [ ] verify: plugin.json の version が直前リリースより上がっている

- [ ] `CHANGELOG.md` に本 Issue のエントリを追加（Added: addons/web、影響度ランナー一般化、配布；Changed: フロースキル配線、methodology doc）
- [ ] verify: CHANGELOG 最上段リリース見出しに #323 の変更が記載されている

- [ ] ディレクトリ README 更新（`addons/README.md` の表に web 追加、`scripts/README.md` の impact_map 説明、`commands/README.md` の setup-web、必要なら `config/README.md`）
- [ ] verify: 変更した各ディレクトリの README が新規/変更ファイルと整合している

- [ ] ドキュメント整合性チェック
- [ ] verify: 関連ドキュメント（DEVELOPMENT 構造図・docs/README・testing-skills）が変更内容と整合している
