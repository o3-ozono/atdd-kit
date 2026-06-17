# Acceptance Tests: atdd-kit 自身のテスト高速化（メタテスト撤去＋影響度ベース並列ランナー）

<!-- AT lifecycle: planned → draft → green → regression
     各エントリには状態マーカー [planned] / [draft] / [green] / [regression] を付与する。
     状態は実装の進行に合わせて更新する。
     注: [regression] AT は将来の任意ブランチで永続実行されるため、特定時点の値
     （現在の version 文字列・本日の日付・行数など）を exact-pin してはならない。不変条件をアサートする。 -->

## AT-100: AT-271 入れ子フルスイート再実行（AT-006）の撤去

- [ ] [planned] AT-100: AT-006 が撤去されている
  - Given: `tests/acceptance/AT-271.bats` の行311-336（コメント 311 行＋`@test "AT-006: ..."` ブロック 313〜336 行）に AT-006（スイート全体の入れ子再実行）が存在した
  - When: 本 Issue の変更後に AT-271.bats を検査する
  - Then: `AT-006` の `@test` ブロックおよび `run bats ... tests/` のネスト再実行が存在しない（`grep -c 'AT-006' tests/acceptance/AT-271.bats` == 0）

- [ ] [planned] AT-101: AT-006 撤去で入れ子フルスイート再実行という高速化阻害要因が構造的に消える
  - Given: AT-006 撤去前は AT-271.bats が `run bats ... tests/` でスイートをネスト再実行しており、これが全体時間（約 118s／AT-006 単独 116.44s）のボトルネックだった
  - When: AT-006 撤去後に AT-271.bats の構造を検査する
  - Then: AT-271.bats 内にスイート全体を入れ子で再実行するコード（`run bats` でディレクトリ `tests/` をネスト実行する箇所）が一切存在しない（構造的アサーション。壁時計の絶対秒数は CI ランナー差・負荷で揺れて flaky になるため green ゲートにせず、定量短縮効果は手動ベンチ注記として PRD Outcome に委ねる）

## AT-110: #271 回帰意図の担保（回帰検出力を落とさない）

- [ ] [planned] AT-110: 残存 AT が #271 の回帰意図を構造的に担保する
  - Given: AT-006 を撤去した AT-271.bats
  - When: `bats tests/acceptance/AT-271.bats` を実行する
  - Then: AT-001〜AT-005, AT-007（固定 reviewer agent 不在・README 構造・docs/skills 文言・version 整合・CS-3 不変条件）がすべて green で、#271 の回帰意図が引き続き検査される

- [ ] [planned] AT-111: フルスイート green は CI が担保する（撤去の前提）
  - Given: AT-006 撤去の回帰担保を CI のフルスイートに委ねる設計
  - When: CI ワークフローのフルスイート実行定義を確認する
  - Then: CI が引き続きフルスイートを回す（CI 側フルスイートは温存され、撤去されていない）

## AT-200: 依存なし並列ランナー `scripts/run-tests.sh`（コア数実行時検出）

- [ ] [planned] AT-200: コア数検出のフォールバック連鎖がマシン非依存に成立する
  - Given: `scripts/run-tests.sh` のコア数検出ロジック
  - When: `nproc` → `sysctl -n hw.ncpu` → `getconf _NPROCESSORS_ONLN` の各候補が利用可/不可な環境を模す
  - Then: 利用可能な最初の候補値を採用し、全候補が不在のときフォールバック 4 を返す（常に 1 以上の整数）

- [ ] [planned] AT-201: GNU parallel 等の外部依存なしで動作する
  - Given: `scripts/run-tests.sh`
  - When: GNU parallel 不在環境で `scripts/run-tests.sh --all` を実行する
  - Then: 外部パッケージ要求でエラーにならず、純 bash ＋ bats のみで並列実行が成立する（zero-dependency ポリシー遵守）

## AT-210: 両モード対象選択と並列シャーディング

- [ ] [planned] AT-210: `--all` で全件、`--impact --base <ref>` で影響範囲を選択する
  - Given: 既存 `impact_map.sh --layer BATS` 基盤
  - When: `run-tests.sh --all` と `run-tests.sh --impact --base <ref>` をそれぞれ実行する
  - Then: `--all` は全 BATS 集合を、`--impact` は差分対象集合を選び（既存 `bats_runner.sh` と同一対象）、新規選択ロジックを実装していない（#323 と非重複）

- [ ] [planned] AT-211: 重み均衡ファイルシャーディングで全件が検出コア数だけ並列分割される
  - Given: 検出コア数 N（`scripts/run-tests.sh` のコア数検出ロジックが返す値）
  - When: `scripts/run-tests.sh --all` を実行し、生成されるシャード構成を観測する
  - Then: 対象 BATS が N シャード（N == 検出コア数。対象数 < N の場合は対象数）へ重み均衡配分され並列起動される（構造的アサーション: シャード数 == min(検出コア数, 対象ファイル数)。直列比の壁時計短縮は CI ランナーのコア数・同時負荷で揺れて flaky になるため green ゲートにせず、手動ベンチ注記に留める）

- [ ] [planned] AT-212: シャードの失敗がランナー全体の失敗に集約される
  - Given: 並列シャードのいずれかに失敗テストを含む状態
  - When: `scripts/run-tests.sh --all` を実行する
  - Then: ランナー全体が exit 非0 を返す（全シャード pass のときのみ exit 0）

## AT-300: フェーズ別実行ポリシーの配線（フロースキル）

- [ ] [planned] AT-300: フロースキルにフェーズ別実行ポリシーが明文化されている
  - Given: `running-atdd-cycle` / `reviewing-deliverables` / `merging-and-deploying` の SKILL.md
  - When: 各 SKILL を検査する
  - Then: 「ATDD 各イテレーション＝影響範囲のみ」「ユーザー最終レビュー前＝必ず全件」が明文化され、各 SKILL の line-budget pin と BATS が green

- [ ] [planned] AT-302: reviewing-deliverables は line-budget を超えずリンク参照で担保する
  - Given: `skills/reviewing-deliverables/SKILL.md` は現状 224/240 行で残量が逼迫し、line-budget pin は既に1回引き上げ済み（DEVELOPMENT.md L59-61 は累計2回まで・3回目は分割）
  - When: フェーズ別ポリシー追記後の SKILL.md を検査する
  - Then: フェーズ別ポリシーは inline 本文展開ではなく `docs/methodology/test-execution-policy.md` への 1 行リンク参照で記述され、`reviewing-deliverables/SKILL.md` の行数が 240 行以下（line-budget pin を引き上げない）。`running-atdd-cycle` / `merging-and-deploying` は残量に余裕があるため直接明文化してよい

- [ ] [planned] AT-301: claude 系 e2e が影響度基準に統合されている
  - Given: claude 系 e2e（`tests/e2e/*.bats` 等）の従来はローカル/CI の物理置き場所基準だった実行可否
  - When: フェーズ別ポリシーの記述を確認する
  - Then: 物理置き場所ではなく影響度（修正がスキル本体等に及ぶか）で回す/回さないを判断する基準に統合されている

## AT-310: 既存ローカル/CI 実行分けの棚卸し

- [ ] [planned] AT-310: live e2e の実行条件が影響度基準で文書化されている
  - Given: 現状ローカル限定/CI 限定で回している live e2e 等の実行条件（skip ガード・専用ワークフロー）
  - When: `docs/methodology/test-execution-policy.md`（実行ポリシー専用の新規ドキュメント）を確認する
  - Then: 各実行条件が棚卸しされ、影響度基準との対応として整理・文書化されている（物理置き場所でなく影響度で説明できる）。かつ既存 `docs/methodology/test-mapping.md` の冒頭契約（"Loaded by: plan skill" / "AC → Test Layer Mapping"）が無変更で、実行ポリシーが同ファイルに混載されていない

- [ ] [planned] AT-311: test-execution-policy.md が言語ポリシー（English only）を満たす
  - Given: `docs/methodology/test-execution-policy.md` は docs ツリー配下の LLM-facing 配布文書で、DEVELOPMENT.md L31「docs は English only」および methodology/README.md L25「English only (LLM-facing documents)」の非交渉ルールが適用される
  - When: 文書の文字種を検査する
  - Then: 日本語文字（`[ぁ-んァ-ヶ一-龥]`）を一切含まない（`! grep -P '[ぁ-んァ-ヶ一-龥]' docs/methodology/test-execution-policy.md`。`test_us_quality_standard.bats` の Language policy AC と同型の pin で機械的に強制）

- [ ] [planned] AT-312: test-execution-policy.md が methodology/README.md に登録されている
  - Given: methodology ディレクトリの Conventions が「各文書を Documents テーブルに登録し、冒頭に `> **Loaded by:**` を置く」ことを規約化している
  - When: `docs/methodology/README.md` の Documents テーブルと新規文書の冒頭を検査する
  - Then: README の Documents テーブルに `test-execution-policy.md` 行が存在し（`grep -q 'test-execution-policy' docs/methodology/README.md`・`test_us_quality_standard.bats` AC6 と同型）、新規文書冒頭に `> **Loaded by:**` メタコメントがある。README は English only を維持（`! grep -P '[ぁ-んァ-ヶ一-龥]' docs/methodology/README.md`）

## AT-320: 配布メソドロジーへの展開

- [ ] [planned] AT-320: フェーズ別ポリシーが配布メソドロジーにドクトリンとして明文化されている
  - Given: atdd-kit を適用する各プロジェクトに展開される `docs/methodology/`
  - When: `docs/methodology/test-execution-policy.md`（実行ポリシー専用の新規ドキュメント）を確認する
  - Then: 「最終レビュー前＝全件 / ATDD 各回＝影響範囲のみ」が標準ドクトリンとして英語（English only / AT-311 で pin）で明文化され、#323（impact 選択ツールの一般化・配布）とは別軸である境界が明記されている。文書は methodology/README.md に登録済み（AT-312）

## AT-400: バージョニング不変条件（恒久回帰）

- [ ] [planned] AT-400: plugin.json version が CHANGELOG 最新リリース見出しと一致する
  - Given: 本 Issue は機能 PR であり minor bump ＋ CHANGELOG 更新が必須
  - When: `.claude-plugin/plugin.json` の version と `CHANGELOG.md` の最上位リリース見出しを照合する
  - Then: 両者が一致する（特定の version 文字列を exact-pin せず「version == 最新 CHANGELOG 見出し」という不変条件をアサート。AT-271:AT-005 が既に担保。#289 教訓準拠）

## ライフサイクル例

| 状態 | 意味 |
|------|------|
| [planned] | テスト設計済み・未実装 |
| [draft] | 実装中・まだ通過していない |
| [green] | テスト通過済み |
| [regression] | リグレッション対象として継続監視中 |
