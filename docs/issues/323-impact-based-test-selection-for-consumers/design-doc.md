<!-- このファイルは trade-off または alternatives の検討がある場合にのみ使用します -->

# Design Doc: 影響範囲ベースのテスト選択の一般化と利用プロジェクトへの配布

## Context

#135 で `impact_map.sh` / `bats_runner.sh --impact` / `config/impact_rules.yml` / `@covers` 注釈による影響範囲ベースのテスト選択が atdd-kit 内部に実装済み。しかし bats ＋ `@covers` 専用で、利用プロジェクトの jest/vitest（web）や XCTest（iOS）には流用できず、addon の deploy にも含まれないため配布されていない。`run-tests.sh` が `impact_map.sh` に対象集合の決定を委譲する構造は既にあるが、決定ロジック自体が bats 前提に固着している。本 Issue はこの固着を解いて配布する。設計判断が必要な論点が PRD Open Questions として 3 つ顕在化している（アダプタ interface の切り方／テンプレート配布方式／ゲートでのフル実行強制点）。

## Goals

- 「変更パス集合 → 実行すべきテスト識別子集合」をプラットフォーム非依存の共通契約に統一する。
- `other`（atdd-kit 自身、bats/`@covers`）の現行挙動を非破壊で温存する。
- web / iOS の利用プロジェクトに addon 経由で影響度ランナー＋ルールテンプレートを配布する。
- フロースキルを既定で影響スコープ実行にし、マージ/CI ゲートはフルスイートを強制する非対称を担保する。
- unmatched パスのフル実行フォールバック（#135 の保守的挙動）を全プラットフォームで維持する。

## Non-Goals

- import/AST ベースの精密な依存追跡（アダプタはパス glob ／ `@covers` ／ 単純ターゲット対応に留める）。
- `addons/web` の包括設計（MCP/hooks/CI フラグメント）。本 Issue は影響度ランナー deploy に必要な最小構成のみ。
- #135 の選択アルゴリズム本体の再設計。
- 利用プロジェクトの CI YAML 自動改変。
- 時間短縮率の定量保証。

## Proposal

`impact_map.sh` に `--platform {web|ios|other}` を追加し、選択ロジックを内部関数に分岐する。共通契約は「変更パス集合（git diff）→ テスト識別子集合（stdout, 1 行 1 件）」で固定し、フレームワーク差は各 `select_*` 関数内に閉じる。

```
impact_map.sh --platform <p> --base <ref> --layer <layer> --config <rules>
  └─ get_diff_files            # 共通: git diff → 変更パス集合
  └─ dispatch by --platform:
       select_other()  # 現行 bats/@covers 抽出（非破壊。--platform 省略時の既定）
       select_web()    # src/** 等 glob → jest/vitest テスト識別子
       select_ios()    # *.swift → XCTest ターゲット識別子
  └─ unmatched あり → フル実行フォールバック（全プラットフォーム共通の既定）
```

ルールはプラットフォーム別の**静的テンプレート**（`addons/web/config/impact_rules.yml` / `addons/ios/config/impact_rules.yml`）として配布。`addons/web` を新設し、`addons/ios` の deploy にランナー＋テンプレートを追加。`setup-web` / `setup-ios` / `init` で配線する。

ゲートのフル実行強制は**スキル分岐**で行う（ランナーには持たせない）: `merging-and-deploying` と autopilot マージゲートが `--all` を明示呼び出しし、inner loop・AT ゲート・post-deploy 回帰は `--impact` を既定にする。

## Alternatives Considered

- **アダプタ interface: プラットフォーム別スクリプトの差し替え（`impact_map_web.sh` 等を deploy）** — 却下。共通の diff 取得・フォールバック・契約をスクリプトごとに重複させ、`other` 非破壊保証の回帰面が広がる。`--platform` 内部分岐なら共通部を 1 箇所に保てる。
- **テンプレート配布: 利用プロジェクト構造からの半自動生成** — 却下（Non-Goal）。構造推定の精度に依存し、過剰実装になる。静的テンプレート＋利用側調整で十分。必要なら後続 Issue。
- **ゲート強制点: ランナー（`--gate` フラグ）または CI 設定でフル実行を強制** — 却下。CI は既にフル実行が既定（安全側）で自動改変は Non-Goal。ランナーにゲート概念を持たせると「実行は絞る／ゲートはフル」のフェーズ判断がランナーに漏れ、責務が曖昧になる。フェーズを知るスキル層が `--all`/`--impact` を選ぶのが素直。
- **iOS 選択深度: ターゲット依存の解釈** — 却下（Non-Goal）。単純 glob で開始し、精度不足が実証されたら後続で深める。

## Trade-offs

- **得るもの**: 共通契約への一本化で `other` 非破壊を 1 関数の同値性で保証でき、回帰面が最小。フェーズ判断をスキル層に集約し、ランナーは「絞り込みの実行器」に純化。静的テンプレートでゼロ依存・即配布。
- **失うもの**: web/iOS のテスト識別子粒度が glob 精度に縛られ、import レベルの取りこぼし最適化はできない（フォールバックで安全側に倒すため正しさは損なわれず、速度上限が下がるだけ）。テンプレートは利用プロジェクト側の手調整を前提とする。

## Risks

- **`other` 挙動の退行** — アダプタ抽出で bats/`@covers` 結果が変わるリスク。軽減: 抽出を純粋なリファクタに留め、AT-006 で分離前後の出力等価を固定。
- **フォールバックの絞りすぎ** — 新規 web/ios 分岐で unmatched をフォールバックに乗せ損ねると取りこぼす。軽減: AT-008 で全プラットフォームのフル実行フォールバックを固定。
- **ゲート非対称の緩み** — マージゲートが誤って `--impact` を呼ぶと安全側が崩れる。軽減: AT-007 でマージ/CI の `--all` 強制を固定。
- **methodology doc の二重管理** — `test-execution-policy.md` の #323 保留節を更新し損ねると、完了後も「out of scope」が残り誤誘導する。軽減: AT-005 で保留文言の除去を固定。
