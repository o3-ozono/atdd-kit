# Plan: atdd-kit 自身のテスト高速化（メタテスト撤去＋影響度ベース並列ランナー）

<!-- 2-5 分粒度のタスク行と verification 行を交互に配置する（superpowers writing-plans 形式）。
     各タスクは単一の操作に限定し、verification で完了条件を即確認できる粒度にする。 -->

## 設計概要

US と PRD を踏まえ、5 つの作業軸を以下の技術判断で実装する。

1. **AT-271:AT-006 の撤去（完全削除）** — `tests/acceptance/AT-271.bats` 行311-336 の `# --- AT-006 ...` コメント（311 行）＋`@test "AT-006: ..."` ブロック（313 行〜閉じ波括弧 336 行）を丸ごと削除する。AT-006 は `run bats "${repo_root}/tests/" "${acceptance_files[@]}"` でスイートをネスト再実行しており、計測で 116.44s（AT-271.bats 全体 118s の約 98%）を占める。#271 の回帰意図は同ファイルの AT-001〜AT-005 / AT-007（構造的検査）が担保し、フルスイート green は CI が担保するため冗長。完全削除を基本線とする（PRD Open Question で「撤去」確定済み）。
2. **依存なし並列ランナー新設** `scripts/run-tests.sh` — `bats_runner.sh` を**置き換えず、その上に乗る並列化レイヤー**として新設する。役割分担: `run-tests.sh` が「コア数検出＋重み均衡ファイルシャーディング＋並列起動」を担い、各シャードは内部で `bats <files...>` を直接呼ぶ。対象ファイル集合の決定（`--all` / `--impact --base <ref>`）は既存の `impact_map.sh --layer BATS`（`--all` / `--base <ref>`）をそのまま再利用する。コア数検出は `nproc` → `sysctl -n hw.ncpu` → `getconf _NPROCESSORS_ONLN` → フォールバック 4 の順。重みはファイル内 `@test` 行数を近似コストに用い、グリーディに N シャードへ均衡配分する。**`bats_runner.sh` の今後の位置づけ:** `bats_runner.sh`（`--all` / `--impact --base`）は run-tests.sh とほぼ同一の CLI 表面を持つが、本 Issue では `bats_runner.sh` を**温存（現状維持）**し置き換えない。run-tests.sh は影響範囲集合の算出のみ `impact_map.sh` に委譲し、bats_runner は経由しない（並列起動を bats_runner に持ち込まないため）。bats_runner の廃止・内部委譲化は本 Issue のスコープ外とし、将来の整理課題として別 Issue に切り出す（PRD Open Question の役割分担はこの方針で確定）。
3. **フェーズ別実行ポリシーの配線** — 「ATDD 各イテレーション＝影響範囲のみ（`--impact`）／ユーザー最終レビュー前＝必ず全件（`--all`）」を `running-atdd-cycle` と `reviewing-deliverables`（および merge gate を持つ `merging-and-deploying`）の SKILL.md に明文化する。claude 系 e2e は物理置き場所でなく影響度（修正がスキル本体等に及ぶか）で回す/回さないを判断する基準に統合する。**line-budget 配慮（DEVELOPMENT.md L59-61 準拠）:** `reviewing-deliverables/SKILL.md` は現状 224/240 行（pin は既に1回引き上げ済み）で残量が逼迫しているため、フェーズ別ポリシーを **inline で本文展開せず、`docs/methodology/test-execution-policy.md` への 1 行リンク参照に留める**（詳細はメソドロジー文書へ委譲）。残量に余裕のある `running-atdd-cycle`（75 行）/ `merging-and-deploying`（61 行）には簡潔なポリシー文言を直接明文化する。3 スキルとも `test_phase_test_policy.bats` が要求する文言（「影響範囲のみ」「全件」「影響度」相当）を含むこと。
4. **既存ローカル/CI 実行分けの棚卸し** — `tests/e2e/*.bats`（live e2e）の現状の skip ガード・専用ワークフローを調査し、影響度基準との対応表を **`docs/methodology/test-execution-policy.md`（新規・実行ポリシー専用ドキュメント）** に整理・文書化する。`test-mapping.md`（AC→Test Layer 対応・plan スキルがロードする既存ファイル）には**追記しない**（用途の過積載を避けるため別ファイルに分離）。
5. **配布メソドロジー化** — フェーズ別実行ポリシー（影響度＋フェーズ別）を **`docs/methodology/test-execution-policy.md`（適用先へ展開される実行ポリシー専用の配布メソドロジー）** にドクトリンとして明文化する。これは方針の明文化であり、impact 選択ツールの一般化・配布（#323）とは別軸（Non-Goal 境界を文中に明記）。**言語ポリシー（DEVELOPMENT.md L31 / methodology/README.md L25 の非交渉ルール「docs は English only」準拠）:** `test-execution-policy.md` は docs ツリー配下の LLM-facing 配布文書であるため **英語で記述する**。`test_us_quality_standard.bats` の Language policy AC と同型の「JA 文字（`[ぁ-んァ-ヶ一-龥]`）非含有」pin を `test_phase_test_policy.bats` に追加して機械的に強制する。**methodology/README.md 登録（同 README Conventions 準拠）:** 新規文書を `docs/methodology/README.md` の Documents テーブルに 1 行追加し、文書冒頭に `> **Loaded by:**` メタコメントを置く。テーブル行存在を `test_phase_test_policy.bats` に pin する（`test_us_quality_standard.bats` AC6 と同型）。

スコープ外（Non-Goal、PRD 準拠）: impact 選択ロジックの新規実装、ツールの他プロジェクト一般化（#323）、CI フルスイート実行の撤去、個々テストのアサーション改善。

## Implementation

- [ ] `tests/acceptance/AT-271.bats` の行311-336（`# --- AT-006 ...` コメント 311 行 ＋ `@test "AT-006: ..."` ブロック 313〜336 行）を削除する
- [ ] verify: `grep -c 'AT-006' tests/acceptance/AT-271.bats` が 0、かつ `bats tests/acceptance/AT-271.bats` が全 pass（AT-001〜005, 007 残存）

- [ ] `scripts/run-tests.sh` を新規作成し、`set -euo pipefail` ＋ usage（`--all` / `--impact --base <ref>` / `--jobs <n>` / `--repo <path>`）と引数パースを実装する
- [ ] verify: `bash scripts/run-tests.sh` 引数なしで usage エラー（exit 非0）、`--all` で起動すること

- [ ] `run-tests.sh` にコア数検出関数を実装する（`nproc` → `sysctl -n hw.ncpu` → `getconf _NPROCESSORS_ONLN` → フォールバック 4。`--jobs` 明示時はそれを優先）
- [ ] verify: 注入なしでも 1 以上の整数を返し、全候補コマンド不在の環境シミュレーション（PATH 制限）でフォールバック 4 を返す

- [ ] `run-tests.sh` の対象ファイル集合決定を `impact_map.sh --layer BATS`（`--all` / `--base <ref>`）に委譲する形で実装する
- [ ] verify: `--all` で全 BATS 集合、`--impact --base <ref>` で差分対象集合が選択される（既存 `bats_runner.sh` と同一の対象になる）

- [ ] `run-tests.sh` に重み均衡ファイルシャーディング（ファイル内 `@test` 数を重みとしたグリーディ N 分割）と並列起動（バックグラウンドジョブ＋`wait`、各シャード exit 集約）を実装する
- [ ] verify: 検出コア数 N でシャードが生成され、いずれかのシャードが fail したとき `run-tests.sh` 全体が exit 非0、全 pass で exit 0

- [ ] `scripts/README.md` の Scripts 表に `run-tests.sh` の行を追加する
- [ ] verify: `grep -q 'run-tests.sh' scripts/README.md` が真、Purpose/Usage 列が埋まっている

## Testing

- [ ] `tests/test_run_tests.bats`（`# @covers: scripts/run-tests.sh`）を新規作成し、AT-200 / AT-201 / AT-210 / AT-211 / AT-212 の受け入れ観点（コア数検出フォールバック・外部依存なし・両モード対象選択・重み均衡シャード分割・fail 集約）を pin する
- [ ] verify: `bats tests/test_run_tests.bats` が全 green

- [ ] AT-271 から AT-006 を撤去しても #271 回帰意図が残存 AT で担保されることを確認する（AT-001〜005, 007 の green 維持）
- [ ] verify: `bats tests/acceptance/AT-271.bats` が green、かつ `grep -c 'AT-006' tests/acceptance/AT-271.bats` == 0 ／ ネスト再実行（`run bats ... tests/`）が存在しないことを構造的に確認（高速化は構造で担保。壁時計の絶対秒数はゲートにしない＝flaky 回避）

- [ ] フェーズ別ポリシー文言の存在を pin する BATS（`tests/test_phase_test_policy.bats`、`# @covers: docs/methodology/test-execution-policy.md` ＋関連 SKILL）を新規作成する。次の AC を含める: (a) ポリシー文言（「最終レビュー前＝全件」「ATDD 各回＝影響範囲のみ」「影響度基準」）が SKILL/メソドロジーに存在、(b) **言語ポリシー pin** — `! grep -P '[ぁ-んァ-ヶ一-龥]' docs/methodology/test-execution-policy.md`（`test_us_quality_standard.bats` Language policy AC と同型・JA 文字非含有）、(c) **README 登録 pin** — `grep -q 'test-execution-policy' docs/methodology/README.md`（Documents テーブル行存在・`test_us_quality_standard.bats` AC6 と同型）、(d) **Loaded-by メタ pin** — `test-execution-policy.md` 冒頭に `> **Loaded by:**` が存在
- [ ] verify: `bats tests/test_phase_test_policy.bats` が green（ポリシー文言・JA 文字非含有・README テーブル登録・Loaded-by メタの全 AC が pass）

- [ ] 全件スイートを依存なし並列ランナーで実行し緑を確認する
- [ ] verify: `bash scripts/run-tests.sh --all` が exit 0（外部依存なしで全シャード pass）。並列短縮効果は構造で担保（シャード数 == 検出コア数 ／ 入れ子フルスイート再実行が存在しない）し、壁時計の相対比較は手動ベンチ注記に留める（CI ランナー負荷で揺れる相対秒数を green ゲートにしない＝flaky 回避）

## Finishing

- [ ] `running-atdd-cycle`（75 行）/ `merging-and-deploying`（61 行）の SKILL.md にフェーズ別実行ポリシー（影響度＋フェーズ別、claude 系 e2e の扱い含む）を簡潔に直接明文化する。`reviewing-deliverables`（224/240 行・残量逼迫）は **inline 展開を避け、`docs/methodology/test-execution-policy.md` への 1 行リンク参照のみ追加**し、line-budget 240 行を超えない（DEVELOPMENT.md L59-61 の累計2回までの引き上げ制約に既に近いため3回目の引き上げ＝分割を回避）
- [ ] verify: 各 SKILL の BATS（`tests/test_<skill>_skill.bats`）が green、`reviewing-deliverables/SKILL.md` が 240 行以下（line-budget pin を引き上げない）、`tests/test_phase_test_policy.bats` が参照する文言（reviewing-deliverables はリンク先の test-execution-policy.md 側で担保）が存在

- [ ] `docs/methodology/test-execution-policy.md`（新規・実行ポリシー専用・**英語で記述**）にフェーズ別実行ポリシー（配布ドクトリン）と live e2e 実行条件の棚卸し対応表を記述し、#323 との別軸境界を明記する。文書冒頭に `> **Loaded by:**` メタコメントを置く（既存 `test-mapping.md` は AC→Test Layer 用途のまま不変更）
- [ ] verify: `bats tests/test_phase_test_policy.bats` が green（JA 文字非含有・Loaded-by メタ存在を含む）、#323 との重複回避（impact ツール一般化は非対象）の記述がある、`test-mapping.md` の冒頭契約（"Loaded by: plan skill" / "AC → Test Layer Mapping"）が無変更

- [ ] `docs/methodology/README.md` の Documents テーブルに `test-execution-policy.md` 行（File リンク＋ Description）を追加する（methodology README Conventions「各文書を Documents テーブルに登録」準拠）
- [ ] verify: `grep -q 'test-execution-policy' docs/methodology/README.md` が真、`! grep -P '[ぁ-んァ-ヶ一-龥]' docs/methodology/README.md`（README は English only 維持）、`bats tests/test_phase_test_policy.bats` の README 登録 AC が green

- [ ] `.claude-plugin/plugin.json` の version を minor bump し、`CHANGELOG.md` の最新リリース見出しと一致させる
- [ ] verify: `bats tests/acceptance/AT-271.bats` の AT-005（version == 最新 CHANGELOG 見出し）が green

- [ ] `CHANGELOG.md` に本 Issue の Added（run-tests.sh）/ Changed（フェーズ別ポリシー）/ Removed（AT-006）を Keep a Changelog 形式で追記する
- [ ] verify: 最新リリースセクションに run-tests.sh・AT-006 撤去・ポリシー明文化のエントリがある

- [ ] ドキュメント整合性チェック（scripts/README.md・tests/README.md・`docs/methodology/README.md`・`docs/methodology/test-execution-policy.md`・`test-mapping.md`・SKILL の相互整合）
- [ ] verify: 関連ドキュメントが変更内容と整合し（`docs/methodology/README.md` の Documents テーブルに新規文書行が存在）、フルスイート（`bash scripts/run-tests.sh --all`）が green
