# Plan: session-start の「別セッション作業中」検出を branch-lease store ベースにする

<!-- 2-5 分粒度のタスク行と verification 行を交互に配置する（superpowers writing-plans 形式）。
     各タスクは単一の操作に限定し、verification で完了条件を即確認できる粒度にする。 -->

## 設計判断サマリ（詳細は design-doc.md）

- **検出ロジックは抽出した読み取り専用ヘルパ `scripts/session-lease-scan.sh` に置く。** SKILL.md は「このヘルパを呼び、出力された branch を `🔒 別セッション作業中` として扱う」と指示するだけ。理由: AT を exit-code ベース（Story 7）で回せるのは実行可能なシェルだけであり、SKILL.md 本文の grep アサーションでは「非 Draft・green・mergeable でも推薦しない」という振る舞いを機械的に担保できない。
- **freshness / encode / TTL は二重定義しない（Story 4）。** ヘルパは `hooks/branch-lease-guard.sh` と同じ env（`BRANCH_LEASE_DIR` 既定 `/tmp/claude-branch-leases`、`BRANCH_LEASE_TTL_LOCAL` 既定 7200s）・同じ `now - timestamp <= ttl` 判定・同じ encode（`%2F %2E %20 %23 %7E`）を採用する。共通ロジックの実体配置（フックから関数を source するか定数だけ揃えるか）は design-doc の決定事項。
- **session 同定は案A（PRD Open Questions）を採用。** session-start は通常 `main` 上で走り feature branch 未接触のため、その時点の fresh branch-lease は定義上すべて「別セッションのもの」。自 session_id の取り回しを不要にし最も単純・堅牢にする。詳細・却下案は design-doc.md。
- **Draft 非依存（中核修正）。** ヘルパは `has_open_draft_pr` を**呼ばない**。「open PR かつ別セッションが fresh lease 保持」だけで検出する。これがフック（Layer 2, Draft 必須）との意図的な差。

## Implementation

- [ ] `scripts/session-lease-scan.sh` を新規作成し、`BRANCH_LEASE_DIR` / `BRANCH_LEASE_TTL_LOCAL` を `hooks/branch-lease-guard.sh` と同じ既定値・同じ env 名で読む先頭部を書く
- [ ] verify: `bash -n scripts/session-lease-scan.sh` が構文エラーなし、かつ `grep` で両 env 名が含まれることを確認

- [ ] freshness 判定（`now - timestamp <= ttl`、TTL_LOCAL 既定 7200s）と encode（`%2F %2E %20 %23 %7E` の 5 文字セット）をヘルパに実装し、フックと同一ロジックにする（独自 TTL 値・独自 encode を書かない）
- [ ] verify: `grep -oE '%2F|%2E|%20|%23|%7E' scripts/session-lease-scan.sh | sort -u | wc -l` が 5、かつ 7200 以外の独自 TTL 既定が無い

- [ ] ヘルパ主処理: `BRANCH_LEASE_DIR` 内の各 `<branch>.json` を走査し、fresh かつ `session_id` が空でない lease を持つ branch 名を 1 行ずつ stdout に出す（lease 無し／stale はスキップ）。案A のため自セッション突合はしない
- [ ] verify: fresh lease ファイルを 1 つ用意したテンポラリ `BRANCH_LEASE_DIR` で実行すると、その branch 名が stdout に 1 行出る

- [ ] store が空・未生成のとき（Story 6）はヘルパが exit 0・stdout 空で返り、エラーを出さない（fail-safe: 新フォールバック機構を足さない）
- [ ] verify: 存在しない `BRANCH_LEASE_DIR` を渡して実行 → exit 0 かつ stdout 空

- [ ] `skills/session-start/SKILL.md` Phase 1-B / Previous Work を改訂: open PR 各件について、ヘルパ出力に headRefName が含まれるなら Draft/非 Draft・CI 状態・mergeable を問わず `🔒 別セッション作業中` として read-only 表示し Recommended Tasks から除外すると明記する（「非 Draft = ready = 推薦」「green = マージ」既定を上書き）
- [ ] verify: `grep -q 'session-lease-scan' skills/session-start/SKILL.md` かつ「非 Draft」「green」「mergeable」を問わず除外する旨の文言が存在する

- [ ] SKILL.md Task Recommendation Rules Step 1 の EXCLUDE_SET 構築に「ヘルパが返した branch を持つ open PR の Issue」を追加する
- [ ] verify: Step 1 セクションに lease ベース除外の項目が追加されている

- [ ] SKILL.md Step 2.1（CONFLICTING rebase 推奨）に「対象 branch がヘルパ出力に含まれない（＝別セッションの fresh lease を保持していない）こと」を前提条件として追記する（Story 3）
- [ ] verify: Step 2.1 本文に lease 未保持を前提とする条件文が存在し、AT-316 が要求する `@me` / `非 Draft` 制限文言が維持されている

## Testing

- [ ] `tests/acceptance/AT-343.bats` を新規作成し、テンポラリ `BRANCH_LEASE_DIR` を使った exit-code ベース回帰 AT を書く（AT-316.bats のヘルパ規約に倣う）
- [ ] verify: `bats tests/acceptance/AT-343.bats` が green

- [ ] AT に「非 Draft・green・mergeable だが別セッションが fresh lease 保持中の branch」をヘルパが検出する（出力に含む）ケースを入れる（Story 2/7 の中核回帰）
- [ ] verify: 当該 test が green、かつ検出判定が exit-code ベースである

- [ ] AT に「lease 無し」「stale lease（TTL 超過）は検出しない」「store 未生成は exit 0・空」の各ケースを入れる（Story 1/6）
- [ ] verify: 各 test が green

- [ ] AT に SKILL.md の Draft 非依存・lease 参照・Step 2.1 前提条件・二重定義禁止（同一 env 名）を検査する grep アサーションを入れ、`[regression]` で点値ピン禁止（plugin.json version は CHANGELOG 最上位見出しとの一致で検査）
- [ ] verify: `bats tests/acceptance/AT-343.bats` 全 green、version 検査が `== "3.x.x"` の固定値でなく不変条件で書かれている

## Finishing

- [ ] `.claude-plugin/plugin.json` を minor bump（新挙動＝新ゲート追加相当 / DEVELOPMENT.md）し `CHANGELOG.md` に Keep a Changelog 形式で追記
- [ ] verify: AT-343 / AT-316 の version 不変条件テストが green

- [ ] `scripts/README.md` に `session-lease-scan.sh` 行を追加、`tests/README.md` に AT-343 行を追加（DEVELOPMENT.md Directory READMEs）
- [ ] verify: `grep -q session-lease-scan scripts/README.md` かつ `grep -q AT-343 tests/README.md`

- [ ] ドキュメント整合性チェック（SKILL.md 改訂と AT がカバー範囲で食い違わない／session-start 既存 BATS が壊れていない）
- [ ] verify: `bats tests/test_session_start_*.bats tests/acceptance/AT-316.bats tests/acceptance/AT-343.bats` が全 green
