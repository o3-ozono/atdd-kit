# PRD: 影響範囲ベースのテスト選択を利用プロジェクトにも提供する（一般化＋addon配布＋フロースキル配線）

## Problem

atdd-kit には **影響範囲ベースのテスト選択基盤が #135 で実装済み**だが、**atdd-kit 自身の開発リポジトリ内部専用**に閉じており、利用プロジェクトには一切届いていない。

現状（調査済み）:

- `scripts/impact_map.sh`（git diff → 影響テスト）／ `scripts/bats_runner.sh --impact` ／ `config/impact_rules.yml` ／ `@covers:` 注釈が存在するが、**bats ＋ `@covers` 専用**。利用プロジェクトの jest/vitest（web）や XCTest（iOS）には流用できない。
- **フロースキル・addon・command からの参照がゼロ**、`addons/*/addon.yml` の deploy にも非含有 → 利用プロジェクトに配布されない（しかも `addons/web` 自体がまだ存在しない）。
- `impact_rules.yml` のパスルールも atdd-kit 自身の構造（skills/lib/hooks/agents/scripts/tests）専用で、利用プロジェクトの構造に一致しない。

結果として、利用プロジェクトは ATDD インナーループ・autopilot AT ゲート・post-deploy 回帰で **毎回フルスイートを実行**せざるを得ず、影響範囲が絞れる局面でも実行範囲を絞れない。開発ループが不必要に遅い。

## Why now

- **基盤が既に存在し、横展開だけが未了** — #135 で影響度ベースのテスト選択（`impact_map.sh` / `bats_runner.sh --impact` / `impact_rules.yml` / `@covers`）が atdd-kit 内部に実装・運用済み。ゼロから作るのではなく **既存資産を一般化して配布する**フェーズに入っており、投資対効果が高い今が着手時。
- **実需が顕在化した** — #308（bugfix ルート）作業中にフルスイートが遅くボトルネックになり、原因が AT-271 の冗長実行と判明。**並列化（#324/#325）より影響スコープ化が本質的**と結論づけた直接の発端があり、同じ痛みは利用プロジェクトでも構造的に起きる。
- **配布基盤がそろった** — `addons/*/addon.yml` の deploy 機構と `/atdd-kit:init` / `setup-*` の配線フローが既に整備済みで、影響度ランナーを「もう一つの配布物」として載せる受け皿が完成している。
- **後回しのコストが累積する** — 利用プロジェクトが増えるほど「毎回フルスイート」の浪費が全プロジェクトで積み上がる。今一般化すれば以後の全利用プロジェクトの開発ループに効く。

## Outcome

完了時に以下が達成されている:

- **影響度ランナーがプラットフォーム非依存に一般化されている** — `impact_map.sh` の bats/`@covers` 依存が分離され、テストフレームワーク別アダプタ（web: jest/vitest ＋ `src/**` glob、iOS: XCTest ＋ `*.swift`、other: bats/`@covers`）で動く。atdd-kit 自身（other）の既存挙動は非破壊。
- **利用プロジェクトに addon 経由で配布される** — `addons/ios`（＋新設する `addons/web`）の deploy に各プラットフォーム向け `impact_rules.yml` テンプレート＋ランナーが含まれ、`/atdd-kit:init` / `setup-*` で配線される。配布後、利用プロジェクトで `git diff → 影響テスト選択` が動く。
- **フロースキルが既定で影響スコープ実行になる** — `running-atdd-cycle`（inner loop）・autopilot AT ゲート・`merging-and-deploying`（post-deploy 回帰）が影響スコープ実行を既定とする。
- **ゲートではフルスイートが強制される（安全側）** — マージゲート / CI では影響スコープに絞らずフル実行。「実行は絞る／ゲートはフル」の非対称が明示的に担保される。
- **安全フォールバックが保たれる** — unmatched パス（ルール未一致）はフル実行にフォールバックする保守的挙動を維持し、絞りすぎで取りこぼさない。
- **一般原則が methodology 文書化される** — 「影響範囲で実行を絞る／ゲートではフル実行」をプラットフォーム非依存の原則として `docs/methodology/` に記述。

## What

スコープ内:

1. **ランナーの一般化（アダプタ化）** — `impact_map.sh` の bats/`@covers` 依存を分離し、プラットフォーム別アダプタ interface を切る:
   - **web**: jest/vitest ＋ `src/**` glob ベースの影響テスト選択
   - **iOS**: XCTest ＋ `*.swift` ベースの選択
   - **other**: 既存 bats ＋ `@covers`（atdd-kit 自身の現挙動を非破壊で温存）
   アダプタは「変更パス集合 → 実行すべきテスト集合」を返す共通契約に統一し、フレームワーク差をアダプタ内に閉じる。

2. **`impact_rules.yml` のテンプレート化** — atdd-kit 自身専用の現ルール（skills/lib/hooks…）を切り離し、プラットフォーム別の **配布用テンプレート**（web: `src/**` `tests/**` 等、iOS: ターゲット構造）を用意。利用プロジェクトはテンプレートを起点に調整する（自動生成は Open Question）。

3. **addon 配布** — `addons/ios` の deploy に iOS 向けランナー＋ルールテンプレートを追加。**`addons/web` を新設**し web 向け一式を deploy。`/atdd-kit:init` / `setup-web` / `setup-ios` で配線する。

4. **フロースキル配線** — `running-atdd-cycle`（inner loop）・autopilot AT ゲート・`merging-and-deploying`（post-deploy 回帰）を **既定で影響スコープ実行**にする。ただし **マージゲート / CI ゲートではフルスイート**（安全側）を強制する分岐を明示。

5. **安全フォールバック** — unmatched パスはフル実行にフォールバック（#135 の保守的挙動を一般化後も維持）。

6. **methodology 文書化** — 「影響範囲で実行を絞る／ゲートではフル実行」をプラットフォーム非依存の原則として `docs/methodology/` に記述。

## Non-Goals

- **`addons/web` の全体設計（MCP サーバ / hooks / CI フラグメント等）** — 本 Issue では「影響度ランナー＋ルールテンプレートを deploy できる最小の `addons/web`」のみ新設し、web addon の包括設計は別 Issue に切る（スコープ膨張防止）。
- **テストフレームワークの依存グラフ解析・高精度な影響推定** — アダプタはパス glob ／ `@covers` ／ 単純なターゲット対応に留め、import 解析や AST ベースの精密な依存追跡は対象外（過剰実装回避。必要なら後続 Issue）。
- **#135 の影響度基盤そのものの再設計** — `impact_map.sh` 等は一般化（アダプタ分離）するが、選択アルゴリズムの本質的書き換えはしない。other（bats/`@covers`）の現挙動は非破壊で温存。
- **CI ワークフロー定義の自動改変** — 「ゲートではフル実行」は原則として明示・配線するが、利用プロジェクトの CI YAML を自動で書き換える仕組みは作らない（CI はフル実行が既定で安全側のため）。
- **flaky / 不安定テストの扱い** — 影響スコープ選択と flaky 対応（#322）は別軸。本 Issue は実行範囲の絞り込みに限定。
- **時間短縮率の定量保証** — 短縮効果はプロジェクト構造依存のため、特定の高速化数値を DoD にしない（「影響スコープ時の実行テスト数 < フル」のスモーク確認に留める）。

## Open Questions

- **アダプタ interface の切り方** — 「変更パス集合 → 実行テスト集合」を返す共通契約の具体形（シェル関数の規約か、プラットフォーム別スクリプトの差し替えか）— plan で確定。
- **`impact_rules.yml` の配布方式** — プラットフォーム別テンプレートの静的配布にするか、利用プロジェクト構造からの半自動生成まで踏み込むか — plan で確定。
- **iOS XCTest アダプタの選択深度** — `*.swift` 変更 → 対象テストターゲットの対応を単純 glob にするか、ターゲット依存をある程度解釈するか — plan で確定。
- **`addons/web` 新設の最小範囲** — 影響度ランナー deploy に必要な最小構成（addon.yml の deploy/detect だけか、setup-web 配線まで含むか）— plan で確定。
- **「ゲートはフル実行」の強制実装点** — autopilot マージゲートと CI の両方で、どのレイヤ（スキル分岐 / ランナーのフラグ / CI 設定）で強制するか — plan で確定。
- **unmatched フォールバックの挙動** — フル実行フォールバックを既定にするか、警告のみのモードも用意するか（#323 論点）— plan で確定。
- **other（atdd-kit 自身）の回帰検証** — 一般化後に atdd-kit 自身の `--impact` 挙動が非破壊であることをどう保証するか（既存 AT で十分か追加が要るか）— plan で確定。
