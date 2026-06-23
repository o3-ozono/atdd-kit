# Plan: pre-merge フェイルセーフゲートの契約再定義（--all 再帰化＋影響選択 e2e 配線）

設計概要:
- **核心修正（FS1）**: `collect_all_bats` の `find tests -maxdepth 1` を `find tests`（再帰）に変更し `tests/acceptance/*.bats` を `--all` の収集対象に含める。`addons/*/tests/*.bats` は現状どおり。e2e/ は run-tests.sh の BATS 収集には含めない（別レイヤー）。
- **e2e 配線（FS2/CS2）**: merge gate（merging-and-deploying）に `run-skill-e2e.sh --changed-files <main 比 diff>` を追加。既存の impact mapping を再利用、新規ロジックは作らない。
- **Open Questions 確定**: OQ1 = e2e 認証不在時は **skip を明示ログした上で通過、BATS ゲート（`--all`）は必須**。OQ2 = 所要時間は壁時計をゲートにせず構造で担保（flaky 回避）。OQ3 = 配線先は merging-and-deploying の merge gate（autopilot 内ループは現状どおり `--impact`）。

## Implementation

- [ ] `collect_all_bats`（`scripts/run-tests.sh` L129-133）の `find "${repo}/tests" -maxdepth 1 -name "*.bats"` から `-maxdepth 1` を削除し `tests/` を再帰収集にする
- [ ] verify: `bash -c "source scripts/run-tests.sh --_source-only; collect_all_bats $(pwd)"` の出力に `tests/acceptance/AT-` を含む行が 1 件以上ある

- [ ] `collect_all_bats` のコードコメント（L117-127）を新スコープ（acceptance/ を含む再帰収集、e2e/ は別レイヤー）に改訂し、旧「maxdepth 1 により acceptance/・e2e/ 除外」の記述を除去
- [ ] verify: `grep -n "maxdepth 1" scripts/run-tests.sh` が collect_all_bats 内に存在しない／コメントが acceptance 包含を説明している

- [ ] `skills/merging-and-deploying/SKILL.md` の Pre-merge gate セクション（L59-63 周辺）に `scripts/run-skill-e2e.sh --changed-files "$(git diff --name-only origin/main...HEAD | paste -sd, -)"` を追加し、影響選択 e2e を merge gate に配線
- [ ] verify: `grep -q 'run-skill-e2e.sh --changed-files' skills/merging-and-deploying/SKILL.md`

- [ ] 同 SKILL.md L72 の「claude-based e2e tests ... included in the full suite at merge gate」を「impact-selected skill-e2e（影響選択）を merge gate で実行」に改訂。認証不在時は skip 明示＋BATS ゲート必須の方針を明記
- [ ] verify: `grep -qE 'impact-selected|影響選択' skills/merging-and-deploying/SKILL.md` かつ「full suite に e2e 全件」を意味する旧記述が無い

## Testing

- [ ] `tests/test_run_tests.bats` に FS1 の behavioral AT を追加（fixture: tmp repo に `tests/acceptance/at_fail.bats`（必ず失敗する @test）を置き `run-tests.sh --all --repo <tmp>` が非 0 を返すことを検証）
- [ ] verify: 修正前は赤（現 false-green で exit 0）、修正後に緑（exit != 0）

- [ ] `tests/test_run_tests.bats` の `AT-210f`（#324 由来・maxdepth スコープ承認）を新契約（acceptance/ 再帰収集）に改訂
- [ ] verify: `bats tests/test_run_tests.bats` が全 green

- [ ] CS1（--all と --impact FALLBACK の一致）AT を追加（同 fixture で両モードがともに非 0）
- [ ] verify: fixture 上で `--all` と `--impact`(FALLBACK) がともに exit != 0

- [ ] FS2/CS2/CS3 の構造 pin AT を追加（merge gate の run-skill-e2e 配線・影響選択である旨・AT-210f 改訂・test-execution-policy.md 整合）
- [ ] verify: 各 grep pin が修正前赤・修正後緑

- [ ] CS4（既存ロジック再利用・CI 不変）AT を追加（merge gate が新規 impact mapping を再実装せず run-skill-e2e.sh を呼ぶ／`.github/workflows/pr.yml` の `bats tests/ addons/...` 行が不変）
- [ ] verify: pr.yml の再帰 bats 行が存在し、merging-and-deploying に独自マッピング関数が無い

## Finishing

- [ ] `docs/methodology/test-execution-policy.md` と #324 `acceptance-tests.md` の AT-210f を新契約に整合
- [ ] verify: 両文書が「`--all` は acceptance/ を含む full BATS、e2e は影響選択で merge gate」に一致

- [ ] CHANGELOG.md 更新（Keep a Changelog 形式、feature/fix エントリ）
- [ ] verify: `bats tests/test_changelog_format.bats` が green

- [ ] ドキュメント整合性チェック（run-tests.sh コメント・scripts/README.md・merging-and-deploying・test-execution-policy）
- [ ] verify: 関連ドキュメントが変更内容と整合している
