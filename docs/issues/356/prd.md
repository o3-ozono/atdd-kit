# PRD: pre-merge フェイルセーフゲートの契約再定義 — `--all` を acceptance/ 再帰化＋影響選択 e2e を配線

## Problem

**現状**: `scripts/run-tests.sh --all` は merging-and-deploying で「フェイルセーフ保証の必須 pre-merge ゲート」と位置付けられているが（SKILL.md L63）、`collect_all_bats` が `find tests -maxdepth 1` で **`tests/` 直下のみ**を収集し、`tests/acceptance/*.bats`（43 ファイル / 524 tests）・`tests/e2e/*.bats`（11 ファイル）を構造的に除外している。

**困ること**: 決定的に失敗する acceptance AT があっても `--all` は一度も実行せず `ALL_EXIT:0`（green）を返す（**false-green**）。必須マージ防壁が機能していない。実際 #341 実走で post-deploy regression（`--impact`）が 2 件の赤を検出したが、pre-merge の `--all` は通過していた。終了コード集約（`run_shards_parallel` の `overall_exit`）自体は正しく動作しており、真因は**収集スコープの除外**にある。

さらに、merging-and-deploying L72 は「claude-based e2e tests は merge gate の full suite に含まれる」と**記述**しているが、`--all` は e2e/ も別 runner（`run-skill-e2e.sh`）も呼ばないため、**文書と実装が乖離**している（merge gate は実際には e2e を一切走らせていない）。

**根本原因の分類**: この除外は #324 の AC `AT-210f` が「意図的な設計トレードオフ（acceptance/・e2e/ 除外、フルカバレッジは CI に委譲）」として明示承認済み。現コードは AC どおりで、ロジック誤り（Type C）でもテスト不足（Type B）でもなく、**Type A（AC Gap）= 契約レベルの矛盾**。本 PRD はこの契約を再定義する（bugfix → full feature route 昇格、cause-agreement gate 承認済み）。

## Why now

`run-tests.sh --all` は merge 前の最終防壁であり、これが false-green を返す状態は「赤を見落としたままマージできる」ことを意味する最優先の防壁欠陥。#355（脆弱ゲートが done を誤判定）の姉妹事象だが、こちらは**必須マージゲート自体が赤を見落とす**ため独立・最優先。#341 実走で顕在化しており、放置するほど誤マージのリスクが累積する。

## Outcome

完了時に以下が成立している（測定可能）：

1. `run-tests.sh --all` が `tests/acceptance/*.bats` を再帰収集・実行し、直接 `bats` で落ちる acceptance AT を確実に FAIL として集約して**非 0 を返す**。
2. 同一リポジトリ状態で `--all`（必須側）と `--impact`（FALLBACK 時）の BATS 判定が一致する。
3. merge gate が **影響選択した skill-e2e** を実行する（`run-skill-e2e.sh --changed-files <main との diff>` 経由）。変更が触れた skill の e2e のみが走り、無関係な e2e の無駄な `claude -p` 起動を避ける。
4. `AT-210f`（#324）と merging-and-deploying L72・`test-execution-policy.md` が、新しい契約（acceptance/ は `--all` に含む／e2e は影響選択で merge gate に配線）と整合するよう改訂され、文書と実装の乖離が解消される。

## What

スコープ内（full feature route 昇格に伴い、Issue 当初スコープ「run-tests.sh 内」から merge gate 契約まで拡張）：

1. **`collect_all_bats` の再帰化（BATS レイヤー / 核心修正）**: `find tests -maxdepth 1` → `find tests`（再帰）に変更し `tests/acceptance/*.bats` を収集対象に含める。`addons/*/tests/*.bats` は現状どおり。**e2e/ は run-tests.sh の BATS 収集には含めない**（e2e は別レイヤー・別 runner のため。下記 3 で扱う）。
2. **回帰テスト（赤→緑 oracle）**: `--all` が acceptance/ の赤を集約して非 0 を返すことを検証する AT を追加（現 false-green 状態で赤、修正後に緑）。`tests/test_run_tests.bats` の `AT-210f` を新契約に合わせて改訂。
3. **影響選択 e2e の merge gate 配線（skill-e2e レイヤー）**: merging-and-deploying の merge gate に `run-skill-e2e.sh --changed-files <branch の main 比 diff>` を追加し、影響を受ける skill の e2e のみを実行する。`run-skill-e2e.sh` 内蔵の path-based impact mapping（`skills/<X>` → `tests/e2e/<X>.bats` 等）を再利用（新規ロジックは作らない）。
4. **文書整合**: `AT-210f`（#324 acceptance-tests.md・コード内コメント L117-127）、merging-and-deploying L72、`docs/methodology/test-execution-policy.md` を新契約に改訂。

## Non-Goals

- **個別 AT の内容修正**（AT-314 の inventory ドリフト由来の赤＝#350、AT-318-A1 の reviewer-oracle 由来の赤）は別 Issue。本 PRD はゲートが赤を**検出する**ことを保証するのみで、検出された個別 AT の中身は直さない。
- **e2e の全件実行を merge gate に課すこと**はしない（コスト過大）。影響選択（impact mapping）に限定する。
- **`run-skill-e2e.sh` / `impact_map.sh` の影響マッピングロジックの新規実装・改変**はしない（既存の取捨選択ロジックを再利用するのみ）。
- **CI（pr.yml）の変更**はしない。CI は既に `bats tests/`（再帰）で acceptance/ をカバーしている。本件はローカル/headless の merge gate の修正であり CI 設定には触れない。
- **並列シャーディング機構そのものの再設計**はしない（収集スコープの修正のみ）。

## Open Questions

1. **e2e の認証不在時の挙動**: merge gate でローカルに claude 認証が無い／`claude -p` が使えない場合、影響選択 e2e を fail-closed（ゲート失敗扱い）にするか、skip 明示（記録の上で通過）にするか。→ **要決定**（writing-plan-and-tests で AC 化）。暫定方針: skip を明示ログした上で BATS ゲートは必須、を案とする。
2. **acceptance/ 524 tests を `--all` に含めることによる所要時間**: 並列シャーディングに乗るが、ローカル merge gate の実時間が増える。#324 が撤去した重いネスト再実行（AT-006）は既に無いため致命的ではない見込みだが、実測で確認する（壁時計はゲートにしない＝flaky 回避、構造で担保）。
3. **e2e 配線先の責務境界**: 影響選択 e2e の起動を merging-and-deploying（merge gate）に置くか、autopilot の収束ゲート側にも反映するか。→ writing-plan-and-tests で整理。
