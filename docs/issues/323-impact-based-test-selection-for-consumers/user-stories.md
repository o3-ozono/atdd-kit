# User Stories: 影響範囲ベースのテスト選択を利用プロジェクトにも提供する（一般化＋addon配布＋フロースキル配線）

## Functional Story

<!-- PRD ## What を一次ソースに、機能要求を persona 抜き Connextra 形式で記述する。1 ストーリー = 1 ユーザーゴール。 -->

**I want to** 影響度ランナーを bats / `@covers` 依存から切り離し、プラットフォーム別アダプタ（web: jest/vitest ＋ `src/**` glob、iOS: XCTest ＋ `*.swift`、other: bats ＋ `@covers`）が「変更パス集合 → 実行すべきテスト集合」を返す共通契約で動くよう一般化する,
**so that** atdd-kit 内部専用だった選択基盤がテストフレームワーク非依存になり、web / iOS の利用プロジェクトでもフレームワーク差をアダプタ内に閉じたまま影響テスト選択を再利用できる.

**I want to** atdd-kit 自身専用の現 `impact_rules.yml`（skills/lib/hooks…）からプラットフォーム別の配布用テンプレート（web: `src/**` `tests/**` 等、iOS: ターゲット構造）を切り出して用意する,
**so that** 利用プロジェクトが自分の構造に合わせたルールをゼロから書かず、テンプレートを起点に調整して使い始められる.

**I want to** `addons/ios` の deploy に iOS 向けランナー＋ルールテンプレートを追加し、新設する `addons/web` に web 向け一式を deploy して `/atdd-kit:init` / `setup-web` / `setup-ios` で配線する,
**so that** addon 経由で各プラットフォームに影響度ランナーが配布され、配布後に利用プロジェクトで `git diff → 影響テスト選択` が実際に動く.

**I want to** `running-atdd-cycle`（inner loop）・autopilot AT ゲート・`merging-and-deploying`（post-deploy 回帰）を既定で影響スコープ実行にする,
**so that** ATDD インナーループ・AT ゲート・回帰の各局面で毎回フルスイートを回さず、影響範囲が絞れる場面では実行範囲が絞られて開発ループが速くなる.

**I want to** 「影響範囲で実行を絞る／ゲートではフル実行」をプラットフォーム非依存の原則として `docs/methodology/` に記述する,
**so that** 一般化された運用方針が方法論文書として明文化され、利用プロジェクトと将来の実装者が同じ判断基準を共有できる.

## Constraint Story (Non-Functional)

<!-- PRD ## Outcome / ## Non-Goals を補足ソースに、非機能要求（NFR）を Story 形式で表現する（Pichler 2013）。 -->

**I want to** other（atdd-kit 自身、bats ＋ `@covers`）の `--impact` 既存挙動が一般化後も非破壊で温存されている,
**so that** アダプタ分離によって atdd-kit 自身の現行テスト選択が壊れず、横展開のリスクが既存運用に波及しない.

**I want to** マージゲート / CI ゲートでは影響スコープに絞らずフルスイートが強制される,
**so that** 「実行は絞る／ゲートはフル」の非対称が明示的に担保され、絞り込みによる取りこぼしがマージ前に検出される（安全側）.

**I want to** ルール未一致（unmatched）のパスはフル実行にフォールバックする保守的挙動が一般化後も維持される,
**so that** ルールが網羅しきれていない変更でも絞りすぎでテストを取りこぼさず、#135 の安全フォールバックが保たれる.
