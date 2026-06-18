# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [3.26.0] - 2026-06-18

### Added

- **Draft PR 作成時に in-progress 付与 ＋ full-autopilot dispatch の GitHub-state プリフィルタ（#326）**。
  - `hooks/in-progress-label.sh` を新規作成。`gh pr create --draft` を PostToolUse hook が検知し、リンク Issue（`Closes #<N>` body パターン / branch 名プレフィックス `<N>-...`）へ `in-progress` ラベルを付与する。`gh pr close` / `gh pr merge` 検知時は除去する。冪等（`--add-label`/`--remove-label` は既存状態でも no-op）。fail-safe: 空 stdin / 不正 JSON / 非 Bash tool_name / jq 不在 / gh 不在はすべて exit 0（副作用ゼロ）。`hooks/hooks.json` の PostToolUse(Bash) hooks 配列に登録（timeout=15s）。`tests/test_in_progress_label.bats`（AT-326-1〜6: 付与 / 番号解決2経路 / 負例 / 除去 / 冪等 / fail-safe、18 tests）。
  - `lib/full-autopilot-dispatch.sh` に `is_issue_busy()` を追加。open PR または `in-progress` ラベルを持つ Issue を `cmd_select` の前段で除外し、lease 取得前に二重 dispatch を冪等にブロックする（C2）。`FAD_BUSY_CMD` env 注入でテスト/統合層が GitHub 問い合わせを差し替え可能（C1 純粋性維持）。`tests/test_full_autopilot_dispatch.bats` に FAD-6〜8（busy 除外 / lease 非取得 / 既存 FAD-1〜4 回帰）を追加。

## [3.25.0] - 2026-06-18

### Added

- **full-autopilot — キュー方式で複数 issue を並列・無人で merge まで回す（#318）**。`ready-to-go`（PRD 承認済み）の Issue をキューに積めば、実装〜レビュー〜merge を無人・並列で消化する上位オーケストレータ。人間の関与は冒頭の要件壁打ちのみ。`skills/full-autopilot/SKILL.md` を新規作成し、3 つのライブラリを束ねる:
  - `lib/lease-store.sh` — 汎用 lease（issue-lease / merge-lease）。容量1/キー、pool 名前空間で分離。排他は lease の存在意義のため、取得は **アトミック（`mkdir` ロック）＋ fail-closed**（holder 永続化に失敗したら lock を返し取得失敗にし、未永続化を「取得成功」と誤報しない）。TTL orphan 掃除は holder.json ts ／無ければ lock dir mtime を使い、winner が holder を書く前の一瞬を loser が stale 誤判定する race を排除。緊急上書き `ATDD_LEASE_FORCE` は **監査証跡必須**（stderr ＋ `LEASE_AUDIT_LOG` に prev holder/取得者を記録）＋ **スコープ可能**（`1`=全, `pool:key`=その1件のみ。共有 /tmp で他プロジェクトの稼働中 lease を巻き込まない）。`tests/test_lease_store.bats`（LS-1..12、並列レース LS-8・fail-closed LS-9・FORCE LS-10・FORCE 監査 LS-11・scoped FORCE LS-12 含む）/ `tests/acceptance/AT-318-D.bats`。
  - `lib/merge-coordinator.sh` — `merge-ready` を容量1（merge-lease）で直列 drain。`rebase→フル再ゲート→merge→regression` の順序保証（broken-together 防止）と、失敗の自動差し戻し→閾値 N で human エスカレーション。post-merge regression 失敗は沈黙させず `merged:regression-failed` ＋非ゼロで上げる。外部ステップは env 注入で差し替え可能。カウンタ永続化失敗（ENOSPC/EROFS/EACCES）は無限 retry でなく fail-closed で escalate。`tests/test_merge_coordinator.bats`（MC-1..7）/ `tests/acceptance/AT-318-C.bats`。
  - `lib/full-autopilot-dispatch.sh` — K スロット下で issue-lease を取りつつ起動対象を選ぶ `select`、worker 完了/失敗/回収時の `release`（数珠つなぎでスロットを空ける実コード）。`tests/test_full_autopilot_dispatch.bats`（FAD-1..5）。
  - `lib/full-autopilot-run.sh` — dispatcher ランタイム（数珠つなぎ本体）: queue 取得→select→headless worker 起動→完了監視（bash 3.2 移植 `kill -0` poll）→merge-ready なら merge-lease 保持下で coordinator→issue-lease 解放→スロット再充填。外部ステップ（queue/launch/result/merge/notify）は env 注入可能。堅牢化: **本番 merge 経路 `__default_merge` に実 git ステップ（`lib/fa-merge-steps.sh` rebase/merge）を配線**（未配線だと process() が空コマンド＝no-op success で「実際には何も merge しない」事故 → throwaway repo 統合テスト `tests/test_fa_merge_steps.bats` FM-1/FM-2 で実 merge を pin）/ `FA_WORKER_TIMEOUT`（既定 3600s, 0=無効）でハング worker を **プロセスツリー単位で kill**（`claude -p` 孫を孤児化しない）して失敗扱い / merge exit 2（post-merge regression=main 破損）は escalate、exit 3（merge-lease busy・retryable）は bounded retry 後 escalate（false merge-failed にしない, FM-3）/ notifier 失敗は FA_LOG に `notify-failed` 記録 / lease store を **リポジトリ単位にスコープ ＋ dispatcher session を一意化**（/tmp 共有での issue 番号衝突・holder 一致誤許可を排除）/ graceful shutdown 時 trap で in-flight lease を解放。`--hand-off` は `FA_HANDOFF=1` 安全マーカーが在るときだけ honored（人間の素 `--hand-off` ではバイパス不可・3ゲート維持）。決定論 E2E `tests/acceptance/AT-318-B.bats`（mock worker: B2 並列度 / B3 連鎖 / E1 フル無人ループ / lease 解放 / 失敗ハンドリング）＋ **実 `claude -p` worker × K=2 で live 実走確認**（並列起動・async 監視・結果回収・merge handoff・lease 解放・連鎖・clean drain）。
- **観測・通知層（無人運転の可視化／エスカレーション）**。core `lib/full-autopilot-run.sh` は**サービス非依存の汎用フック** `FA_NOTIFY_CMD <event> <issue> <detail>` を `dispatch`/`merge-ready`/`merged`/`merge-failed`/`worker-failed`/`escalate` で発火（既定 no-op）。hand-off は実行中に対話質問せず、人間関与は「進行通知」と「非同期エスカレーション」のみ。粒度は **`FA_NOTIFY_LEVEL`**（`quiet`=alert のみ / `normal`=alert+milestone 既定 / `verbose`=detail 含む全部）で段階制御（フィルタは core 側＝サービス非依存）。`tests/acceptance/AT-318-B.bats`（notify hook 発火＋粒度ゲート）。
- **Discord 通知 addon（opt-in, `addons/discord/`）**。`FA_NOTIFY_CMD` の Discord 実装。**issue ごとに forum スレッドを立て**状況・ログを流す（webhook `thread_name` で生成→`thread_id` 追記、>1900字分割、`escalate` は `FA_DISCORD_MENTION` でメンション、HTTP は `FA_HTTP_POST` で差し替え可能）。**opt-in 厳守** — 自動有効化せず session-start が `[y/N]`（既定 N）で尋ねるか `/atdd-kit:setup-discord` でのみ有効化。Discord 固有コードは addon に隔離し core は非依存（旧 #169 全面削除ポリシーを「隔離 opt-in addon」へ置換）。堅牢化: `curl --fail` で 4xx/5xx を握り潰さない / `json_str` は python3→jq→純 bash でフォールバック（python3 不在でも壊さない）/ HTTP 終了コードを検査し失敗を `FA_NOTIFY_ERRLOG` に記録（通知の無音喪失を防ぐ）。`addons/discord/tests/test_fa_notify_discord.bats`（DN-1..7、HTTP 失敗検知 DN-7 含む）/ `tests/test_discord_addon.bats`（隔離・opt-in DA-1..7）。`commands/setup-discord.md` 追加、`skills/session-start` に opt-in 確認、CI に addon テスト追加。
- 並列 worker は **独立 headless プロセス**（`claude -p "/atdd-kit:autopilot <issue> --hand-off"` を `run_in_background`）として起動。各 worker が top-level プロセスのため内部 Workflow が入れ子制約に当たらないこと・ログ3層（stdout json / `--session-id` 確定の transcript / 入れ子 Workflow の `subagents/workflows/wf_*/`）を回収できることを実証済み。worker lifecycle（timeout・完了検出・crash 時 lease 解放3経路）と worker 起動の `--allowed-tools` 最小集合は `skills/full-autopilot/SKILL.md` に仕様化。暴走防止の安全弁（intake を `ready-to-go` に限定）は `tests/acceptance/AT-318-E.bats`（E2）で pin。

### Changed

- **autopilot に hand-off モード（`--hand-off`）を追加（#318・full-autopilot 限定）**。`skills/autopilot/SKILL.md` に hand-off 節を追加し、`docs/methodology/autopilot-iron-law.md` に §AL-1 under full-autopilot を新設。hand-off 時のみ AL-1 三ゲートの担い手が移る（①=queue 事前承認 / ②=reviewer-oracle で自動承認 / ③=merge coordinator）。**通常 autopilot（フラグ無し）の厳密3ゲートは不変** — invariant を `tests/acceptance/AT-318-A.bats`（A2）で pin。`tests/test_skill_structure.bats` の `ALL_SKILLS` に full-autopilot を登録。`lib/README.md`・`skills/README.md`・`tests/README.md` を同一 PR 内で更新。

## [3.24.0] - 2026-06-17

### Added

- **bugfix 専用の軽量ルート `fixing-bugs`（フル機能ルートと分離）（#308）**。新スキル `skills/fixing-bugs/SKILL.md` を新設。既存スキルの**再利用のみ**で構成する thin orchestration スキルで、`bug → debugging → running-atdd-cycle → reviewing-deliverables → merging-and-deploying` の 5 連鎖を構成し、定義系 3 スキル（`defining-requirements` / `extracting-user-stories` / `writing-plan-and-tests`）を**スキップ**する。`bug` のハードコード forward chain（`defining-requirements` への routing）を **orchestrator-driven invocation** で上書きするが `bug` SKILL.md は未編集（被連鎖スキルの「Next Step」は本ルート下では advisory）。再現確認は platform-aware（web: `playwright-cli`/`verify` 外部スキル、iOS: Xcode/simulator MCP + `sim-pool`、other: CLI/bats）に分岐し、失敗テスト（赤→緑 オラクルアンカー）へ符号化する。中間 User gate は design-approval から **cause-agreement**（承認対象 = 根本原因分類 A/B/C・evidence 付き ＋ 失敗再現テスト）へ specialize（AL-1 三ゲート不変条件維持・ゲート数は三のまま）、マージは常に User merge gate（自動マージしない）。Type A（AC Gap）の根本原因はフル機能ルート（`debugging → defining-requirements`）へ昇格する。明示コマンド `commands/autofix.md`（`/atdd-kit:autofix <issue>`）を新設。ルーティング判定信号は `docs/methodology/route-eligibility.md`（SoT）に追記（`type:bug` ラベル＋キーワード＋低確信時の #305 ワンタップ User 確認、No Auto-Routing 不変条件維持）、autopilot SKILL.md は loader-stub で参照のみ（≤280 行維持・第 3 回行バジェット昇格なし）。AL-3 の `AC→AT coverage` 項を bugfix では「失敗再現テスト被覆（赤→緑が外部コンテキストで確認）」へ specialize し、`docs/methodology/autopilot-iron-law.md`（AL-1/AL-3 特化）と `docs/methodology/autopilot-design-gate.md`（presentation contract）の両文書に **cause-agreement** 安定トークンで整合させる。`tests/test_fixing_bugs_skill.bats`（15 件）と `tests/acceptance/AT-308.bats`（14 件）を新設、`tests/test_autopilot_skill.bats` に bugfix wiring pin 3 件を追加。flaky-test-fix ルートは half-scope として #322 にフォローアップ defer。
- **autopilot halt 終端レコードの JSONL 監査ログ追記（#299）**。`lib/autopilot_convergence.sh` に `record_halt <jsonl> <step> <reason> <findings_digest>` 関数を追加し、収束失敗系 halt（`MAX_ITERATIONS` / `sameness-detector` / `stuck` / `ac-drift` / `log-integrity`）のみ終端 HALT レコードを JSONL に 1 行 append する。`reason` を enum に限定（範囲外は非ゼロ return）、`findings_digest` は整形済み JSON 配列値として verbatim 埋め込み（ネストした JSON 配列 — エスケープ済み文字列スカラではない）。`record_iteration` に `timestamp`（ISO 8601 UTC）フィールドを追加。`skills/autopilot/SKILL.md` の収束失敗系 halt 経路に `audit-halt:${step}` agent 呼び出しを挿入（`record_halt` + ログ単独 stage/commit、`recorded` 非インクリメント・`check_log_integrity` 再走なしの不変条件コメント付き）。`tests/test_autopilot_convergence.bats` に 14 件の新規 AT（record_halt 正常系・異常系・timestamp 付与・決定論不変）、`tests/test_autopilot_skill.bats` に 5 件の構造 pin（AT-299-5b/6/7/8/8b）、`tests/acceptance/AT-299.bats` に 9 件の Acceptance Tests を追加。全 70+97+165 テスト green。

## [3.22.0] - 2026-06-16

### Added

- **branch-lease guard フック新設（#316）**。`hooks/branch-lease-guard.sh` を新規作成し、`git push` / `gh pr edit` / `gh pr merge` / `gh pr ready` などの write-back 操作を PreToolUse 層で hard block する。対象ブランチに open Draft PR があり、かつ別セッションが共有 lease store（`/tmp/claude-branch-leases/`、`BRANCH_LEASE_DIR` env で override 可）に fresh リースを保有している場合のみ `permissionDecision: "deny"` を返す。main/master / 非 write-back 操作 / 想定外条件はすべて fail-safe allow。TTL は `BRANCH_LEASE_TTL_LOCAL`（default 7200s）/ `BRANCH_LEASE_TTL_CI`（default 2400s）で制御し、アクセス時 orphan 掃除で stale リースを自動削除。`ATDD_BRANCH_LEASE_FORCE=1` で緊急上書き可能。`hooks/hooks.json` の PreToolUse Bash matcher に登録。`tests/test_branch_lease_guard.bats`（35 件）と `tests/e2e/branch-lease-guard.bats`（9 件）で挙動を pin。`hooks/README.md`・`tests/README.md` も同一 PR 内で更新。

### Changed

- **session-start の CONFLICTING rebase 推奨を ready（非 Draft）＋ @me に限定（#316 Layer 1）**。`skills/session-start/SKILL.md` Step 2 の「Highest priority: CONFLICTING → rebase」推奨を ready（非 Draft）かつ `@me` の PR にのみ適用するよう条件を明記。Draft PR は `🔒 別セッション作業中` の read-only 表示として Previous Work にのみ掲載し、actionable task・rebase / checkout / push 提案対象外である旨を明記。`tests/test_session_start_task_recommendation.bats` に #316 pin 6 件追加（全 23 件 green）。

## [3.21.0] - 2026-06-16

### Added

- **autopilot express 適格プリチェック（pre-flight advisory）＋ route-eligibility.md 抽出（#304）**。`skills/autopilot/SKILL.md` に "Express precheck" セクション（Gate ① 手前の pre-flight advisory）を追加。express 適格 Issue（`docs/methodology/route-eligibility.md` 基準）に対して「express の方が低コストです。autopilot で続行しますか？」を一度だけ提示し、明示 `ok` なしでは進めない。非適格時は無言で続行。auto-route は一切行わず、User gates は 3 件のまま（AL-1 不変）。`docs/methodology/route-eligibility.md` を新規作成し、express 適格信号 / autopilot 信号 / 曖昧時フォールバック / 推奨のみ不変条件を集約。`skills/session-start/SKILL.md` Step 3 を `route-eligibility.md` への参照ポインタに置き換え（二重管理解消）。`tests/test_autopilot_skill.bats` に AT-301〜AT-403 (#304) を追加して全 92 tests green（既存 86 + 新規 6）。SKILL.md 行数は 280→268 行に削減（headroom 12 確保、第 3 回引き上げなし）。ロール分掌（Responsibility Boundary）は `docs/methodology/autopilot-overview.md` 新規作成で保全（FS-2 移設）。

## [3.20.0] - 2026-06-16

### Changed

- **autopilot impl phase の 6 つの agent() 呼び出しに `model: MODEL` を付与（#311）**。`skills/autopilot/SKILL.md` の Workflow スクリプトに `const MODEL = PHASE === 'impl' ? 'sonnet' : undefined` 定数を `const PHASE` 直後に追加し、impl ループ内の `gen:${step}` / `review:${step}` / `at-gate:${step}` / `coverage:${step}` / `audit:${step}` / `rails:${step}` の各 `agent()` opts に `model: MODEL` をインライン付与。design phase / `freeze:anchor` オーケストレーターはセッションモデルを継承（`MODEL = undefined`）。行数は 279→280 で budget ≤ 280 を維持。`tests/test_autopilot_skill.bats` に AT-001～AT-004 (#311) を追加して全 86 tests green。

## [3.19.0] - 2026-06-16

### Changed

- **autopilot GEN_GUARD に foreign 未追跡ファイル不可触ガードと COMPLETED_WITH_DEBT エスカレーション指示を追記（#297）**。`skills/autopilot/SKILL.md` の `GEN_GUARD` 定数（L120、既存の audit log / pin 保護文）に、impl 生成エージェントが当該 Issue スコープ外の未追跡・未コミットファイルを変更・コミット・exclude 等で回避しないよう指示し、foreign 由来のゲート失敗は `COMPLETED_WITH_DEBT` として人間にエスカレーションする旨を既存行内に追記。行数は 279→279（変化なし）で budget <= 280 を維持。
- **autopilot reviewScope の impl scope 文にスコープ外パス P0 検出指示を追記（#297）**。`reviewScope(step)` の `PHASE === 'impl'` 分岐文字列に、`git diff main...HEAD` に現れる当該 Issue スコープ外パス（`pyproject.toml` / CI 設定 / 他 Issue ソース等）へのコミット済み変更を P0 finding として検出する旨を既存行内に追記。satisfaction oracle の `blocking.length === 0` 判定が混入スコープ外コミットで green 誤認するのを構造的に防止する。

## [3.18.0] - 2026-06-16

### Changed

- **VERDICT_SCHEMA.overall_correctness を enum 制約化（#296）**。`skills/autopilot/SKILL.md` の `VERDICT_SCHEMA` 内 `overall_correctness` を `{ type: 'string' }` から `{ type: 'string', enum: ['correct', 'incorrect'] }` に変更。構造化出力ツール段での prose 混入を防ぎ、satisfaction oracle の厳密一致（`=== 'correct'`）と乖離した値が返って収束できない偽 stuck halt を構造的に排除する（既存の判定ロジックは無改修で整合）。
- **running-atdd-cycle に時点依存ピン禁止ガイダンスを追加（#300-1）**。`skills/running-atdd-cycle/SKILL.md` の C2 バレット末尾に `[regression]` AT は version 等の時点依存値を完全一致でピンせず不変条件で assert する旨のガイダンスを追記（`writing-plan-and-tests/SKILL.md` の既存記述 #289 と整合）。
- **AT-302 AC6 の git-diff 依存チェックを不変条件チェックへ置換**。点時間依存の `git diff --name-only` による "autopilot SKILL.md 変更禁止" チェックを、autopilot SKILL.md が存在し VERDICT_SCHEMA を持つという構造的不変条件チェックへ置換（#289 パターン遵守）。

### Added

- **changelog_latest_release ヘルパーを集約（#300-2）**。`tests/acceptance/helpers/changelog.bash` に `changelog_latest_release <changelog_path>` 関数を新設。`## [Unreleased]` をスキップして先頭の `## [X.Y.Z]` から `X.Y.Z` を出力する。`AT-271.bats`（AT-005）と `AT-284.bats`（AT-010）のインライン抽出重複をヘルパー呼び出しへ置換し、同ロジックの散在を解消。

## [3.17.0] - 2026-06-16

### Changed

- **3 つの User gate を選択肢提示（ワンタップ承認）化（#305）**。要件承認（`defining-requirements` Step 10）・設計承認（`autopilot` Flow step 3）・マージ（`merging-and-deploying` Trigger confirm）の各ゲートを **AskUserQuestion 形式**に書き換え、第一選択肢を `(Recommended)` 付きのワンタップ承認（要件・設計は `承認 (ok)`、マージは `マージ`）にした。文脈別の差し戻し選択肢（要件: Problem / Outcome / スコープ、設計: User Stories / Plan / Acceptance Tests、マージ: 保留）を併せて提示。`Other`（自由記述）は harness 自動付与で手動列挙せず、非対応チャネルでは `Recommended: ... — reply 'ok'` 行による従来の `ok` テキスト入力にフォールバック。**提示方法のみの変更で、承認/差し戻しの意味論（非 `ok` = 全体差し戻し＋セクション単位 finding 化、部分承認は承認ではない）と User gate 数 3（AL-1）は不変**。マージゲートは既存の `Y/n` confirm の**置換**であり新規 in-skill Flow ゲートを追加しない。autopilot SKILL.md のライン・バジェット枯渇（279/280、第 3 の昇格は禁止）に対応するため、設計承認ゲートの詳細を `docs/methodology/autopilot-design-gate.md`（新規）へ loader-stub 分割（DEVELOPMENT.md §SKILL.md Line-Budget Raises / #283）。`docs/guides/skill-authoring-guide.md` (f) に autopilot 設計ゲート・merging マージゲートの decision point を追記。`tests/acceptance/AT-305.bats`（AC1–AC6 の構造アサーション 14 件）を追加し、各スキル bats（defining-requirements / autopilot / merging-and-deploying）にもゲート別アサーションを追加、全 green。

## [3.16.0] - 2026-06-16

### Added

- **session-start に autopilot / express 経路推奨ステップを追加（#302）**。`session-start` の `### Recommended Tasks` 出力テンプレートに「推奨経路」列を追加し、`### Task Recommendation Rules` に **Step 3: Route recommendation** を追記。判定主体はハイブリッド（labels・キーワードの決定的ガードレール＋ Issue title/body への LLM 判断の併用）。express 適格信号（docs/README/typo/gitignore/version-bump のみ・挙動変更なし）と autopilot 信号（コード変更・新機能・CI/hooks・依存・セキュリティ）を定義。曖昧時は安全側 autopilot へフォールバック。推奨のみ・auto-route しない不変条件を明記。`tests/acceptance/AT-302.bats` に AC1–AC7 の構造アサーション 14 件を追加し全件 green。

## [3.15.1] - 2026-06-15

### Fixed

- **autopilot Workflow の `agent()` 戻り値 null フェイルセーフ化（#292）**。`at-gate` / `coverage` / `review` / `freeze` / `audit` / `rails` の各ゲートで `agent()` が null を返した場合にクラッシュ（TypeError）または fail-open（null を収束/PASS と誤判定）していた欠陥を修正。すべての null 経路を fail-closed に倒す: loop-continuation gates（at-gate / coverage / review）は null=未通過でループ継続、terminal gates（freeze / audit / rails）は null=COMPLETED_WITH_DEBT でフェイルクローズ。`never fail-open` 不変条件を satisfaction oracle コメントに明記。SKILL.md +2 行（279 行 / 上限 280 行）。BATS 構造アサーション AT-001…AT-007（#292）を追加し全 74 件 green。

## [3.15.0] - 2026-06-15

### Added

- **autopilot 収束レールに監査ログ corruption guard を追加（#248, AL-4 完全性 / #246 2nd review 繰り越し）**。`lib/autopilot_convergence.sh` の `_fingerprints` は FAIL 行から fingerprint を `grep -o` 抽出する際、部分書込・外部破損で fingerprint が欠落/不正な行を**黙って drop** しており、`check_sameness` / `check_stuck` の比較母集団からデータ点が消えて fail-OPEN（偽 continue＝記憶喪失）になり得た。修正: 候補 FAIL 行数と well-formed fingerprint 数（非空・`record_iteration` と同じ charset `[A-Za-z0-9._:-]` 制限）が一致しなければ corruption とみなし非ゼロ（3）を返す。`check_sameness` / `check_stuck` はその exit code を伝播し、ログ破損時は黙って continue せず halt（escalation）する。PASS 行は FAIL-only 母集団（#277）の対象外なので破損 PASS 行で偽 halt しない。`tests/test_autopilot_convergence.bats` に #248 corruption テスト 6 件を追加（truncated/missing fingerprint で halt・step スコープ検出・PASS 行と正常ログの陰性）、計 56 件 green。

  繰り越し 3 項目のうち本リリースで対応したのは項目1（corruption guard）のみ。**項目2（step 跨ぎログ分離/順序付け）は #272（rails の step スコープ化）/ #277（FAIL-only 母集団）/ #262（line-count log-integrity）で実質解消済みのためクローズ。項目3（halt 理由・findings の JSONL 記録 + timestamp）は #262 の log-integrity counter / #288 の即コミットフローとの整合に設計判断が必要なため別 Issue へ繰り越し（現実リスクは低く return 値で機能している）。**

## [3.14.5] - 2026-06-15

### Fixed

- **`tests/acceptance` のバージョン文字列完全一致ピンが version bump のたびに post-merge regression を恒久 red にする問題を修正**（#289）。`tests/acceptance/AT-271.bats` AT-005（`version is 3.12.0` を完全一致でピン、v3.13.0 以降ずっと red）と `tests/acceptance/AT-284.bats` AT-010（`version is 3.14.0`、v3.14.1 bump で破損）が、時点依存の plugin バージョンを literal にピンしていた。`[regression]` AT は将来の任意ブランチでも成立すべきなので、両テストを `tests/acceptance/AT-269.bats` AT-004（#272 hardening で確立済み）と同じ不変条件 — **plugin.json version が CHANGELOG 最新リリース見出し（`grep -oE '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' | head -1`）と一致する** — へ書き換え。#271 の永続記録（CHANGELOG `[3.12.0]` ### Removed の存在）は履歴検証として保持。再発防止として `skills/writing-plan-and-tests/SKILL.md` の `[regression]` lifecycle 定義に「regression AT は時点依存値（現行 version / 日付 / 行数）を完全一致でピンせず不変条件で書く」ガイダンスを明文化。これで AT-271 AT-006（全 suite 再帰実行）への連鎖失敗も解消。`bats tests/acceptance/` 全 green。

## [3.14.4] - 2026-06-14

### Fixed

- **autopilot impl phase の halt 後再入で findings 配管がなく、gen agent の作業ツリー巻き戻しが未コミット audit log を破壊する問題を修正**（#288）。`skills/autopilot/SKILL.md` の Workflow スクリプトに 3 つの修正を反映（#277 / 別 Issue #24 の 2 セッションで独立再現）:
  - **欠陥2（findings 運搬欠如）**: impl phase の halt は新しい Workflow 呼び出しで再入し `prevFindings = null` で始まるため、halt 時点の未解決 findings（review / coverage gate の uncovered AC）が iteration 1 の gen に届かず同じ否決を繰り返していた。design phase の `rejectionFindings`（#261）に対応する **`args.implSeedFindings`** を新設（同型の fail-closed 検証: 非空配列・各要素に非空 `evidence_ref`・**impl phase 限定**で design では拒否）。`SEED_FINDINGS = PHASE === 'design' ? REJECTION_FINDINGS : IMPL_SEED_FINDINGS` で両 phase の seed を統一し、`prevFindings` の seed として priorityOf 正規化込みで iteration 1 の gen に verbatim 埋め込み。canonical なエスカレーション記述に impl 再入時の運搬手順も追記。
  - **欠陥1a（audit 行の破壊）**: gen agent（running-atdd-cycle）の作業ツリー巻き戻し（git restore / checkout）が未コミットの audit 行を削除し、log-integrity rail が偽発火していた。audit agent のプロンプトに **record_iteration 成功後にログファイルのみを即コミット**するステップ (4) を追加し、後続 gen の巻き戻しから audit trail を保護。
  - **欠陥1b（偽行追記の変種）**: gen/fix subagent が `record_iteration` を経由せず audit log へ偽 PASS 行を直接追記する変種（#24 で再現）も塞ぐため、gen プロンプトに `GEN_GUARD`（audit log / pin は orchestrator 所有・読み書き・追記・削除・コミット・git restore/checkout/stash を双方向に禁止）を両分岐へ挿入。
  - `tests/test_autopilot_skill.bats` に AT-001〜AT-004（#288）を追加、#261 の AT-001/AT-003 を `SEED_FINDINGS` 統一に追随更新。autopilot BATS 63 → 67 件 green、全スイート 1220 件 green。

## [3.14.3] - 2026-06-13

### Fixed

- **autopilot rails subagent が実ログでなく合成フィクスチャに対して check_stuck を実行し偽 halt を報告する問題を修正**（#287）。`skills/autopilot/SKILL.md` の rails ステップ（`label: rails:step`）プロンプトは `"<dir>"` / `"<log>"` プレースホルダのみで指示しており、freeze / audit ステップにある「Resolve the issue directory matching `docs/issues/${NNN}-*`」実パス解決指示を欠いていた。そのため rails subagent（Sonnet）がプレースホルダを実パスに解決せず、`/tmp` に合成フィクスチャ（架空の FAIL 行）を自作して `check_stuck` を実行し、その exit 1 を `stuckExit` として誤報告 → 偽 `COMPLETED_WITH_DEBT (stuck)` halt を起こしていた（#277 impl phase 実走で発生）。修正: rails プロンプト冒頭に freeze / audit と同形の実ディレクトリ・実ログ解決指示を追加し、合成フィクスチャ・サンプル FAIL 行・`/tmp` コピーの作成を明示的に禁止（「invented data に対する check は偽 halt を返す」根拠を明記）。`tests/test_autopilot_skill.bats` に AT-007（#287）を追加し rails プロンプトの実パス解決指示＋フィクスチャ禁止文言を構造 pin、計 63 件 green。

## [3.14.2] - 2026-06-13

### Changed

- **「人間ゲート」/「human gate」表記を「User gate」へ統一（現役ドキュメントのみ）**（#281）。対象: `skills/autopilot/SKILL.md`（description / AL-1 要約 / `## User gates` 見出し / Flow step 3 の `(User gate)` 注記 / User merge gate ほか）、`skills/README.md`、`docs/methodology/autopilot-iron-law.md`（AL-1 見出し・AL-6・役割シフト節）、`README.md` / `README.ja.md`、`tests/README.md`。`tests/test_autopilot_skill.bats` の pin を更新: `grep 'user gate'` + 旧表記（`human gate|人間ゲート`）の不存在アサーションを追加し、`## Human gates` 見出し依存の sed 範囲を `## User gates` に追随。行為者としての「human」単独表記（the human / human-facing / human comment / human-approved 等）は対象外として保持。CHANGELOG 過去エントリと `docs/issues/` アーカイブは履歴として無変更。BATS 62 件 green。
- **SKILL.md 行バジェット引き上げの分割介入閾値を DEVELOPMENT.md に規定**（#283）。`DEVELOPMENT.md` / `DEVELOPMENT.ja.md` に「SKILL.md Line-Budget Raises」節を追加: 行バジェット pin の引き上げは 1 ファイルにつき累計 2 回まで、3 回目が必要になった時点で loader stub + `docs/methodology/` 詳細 doc への分割を必須とする。`rules/atdd-kit.md` の 60 行分割方針との非対称（#276 round-4 レビュー指摘）を解消。

## [3.14.1] - 2026-06-13

### Fixed

- **sameness/stuck rails の比較母集団を同一 step の FAIL 行のみに絞る**（#277）。`_fingerprints` に `grep -F '"verdict":"FAIL"'` フィルタを追加し、`check_sameness` / `check_stuck` の比較母集団から PASS 行を除外する。これにより、空 blocking findings（= 同一 fingerprint）の PASS イテレーションが続いた後に FAIL が来ても偽 stuck/sameness halt が発生しなくなる（stockbot-jp Issue #61 の設計ゲート差し戻し再入シナリオで確認）。step 引数の有無にかかわらず全モードで適用（Gate ① 全モード）。意味論ピン: FAIL→PASS→FAIL の跨 run 同一 fingerprint 再発は引き続き halt — FAIL-only 母集団では PASS が除外されて FAIL 行が隣接するため「同じ失敗の繰り返し」として正当に検出される（AT-006）。`tests/test_autopilot_convergence.bats` に AT-001〜AT-006（計 4 テスト追加・AT-003 更新）、合計 49 件全 green。
## [3.14.0] - 2026-06-12

### Added

- **`express` skill の再導入 — 機能破壊リスクのないドキュメント級タスクの省略経路**（#284）。v1.0 の capability-name skill 体系に合わせ `skills/express/SKILL.md` と `/atdd-kit:express <issue>` コマンド（`commands/express.md`）を新設。Issue → 実装 → CI → merge の最短経路を提供し、PRD / US / plan / AT / 構造化レビューをスキップ。発動は明示コマンドのみ（keyword auto-trigger 禁止）。Step 1: Issue 番号必須・not found / closed / in-progress 付き Issue は STOP。Step 2: OK/NG 適用基準（OK: docs/README 追記・typo・コメント・gitignore・version bump のみ等 / NG: 新機能・振る舞い変更・依存追加・CI/hooks 変更・セキュリティ影響等）を SKILL.md に内蔵し、判断に迷う場合は `defining-requirements` へフォールバック。`<APPROVAL-GATE>` でユーザーの明示的承認 + 該当 OK 基準の提示を必須化（AC1/AC2）。Step 3: `express/<N>-<slug>` ブランチ作成・実装中に diff が適用基準を超えたらスコープ逸脱として即中断し `defining-requirements` へ誘導（AC9）。atdd-kit 自身が対象の場合 version bump + CHANGELOG 更新を同一 PR で義務化（AC7）。Step 4: `express-mode` ラベル + PR body の `## Express Mode` セクション（適用基準の理由を記録）。ラベル欠落時は `setup-github` を案内（AC5/AC6）。Step 5: `<HARD-GATE>` で CI green まで merge 不可、自動 merge なし（AC4）。skill-gate の Pre-check: Issue Work Routing に express 分岐を追加し正規ルートとして認識（AC8）。`commands/setup-github.md` に `express-mode` ラベル作成行を追加。`tests/test_express_skill.bats` 25 件 + `tests/acceptance/AT-284.bats` 35 件を新設、`tests/test_skill_structure.bats` の `ALL_SKILLS` に `express` を追加し全 BATS suite green 確認。

## [3.13.1] - 2026-06-12

### Fixed

- **autopilot の User gate 提示に Diff-in-body（差分の本文内提示）を必須化**（#275）。設計承認ゲート（Flow step 3）とマージゲート引き継ぎ（step 5）の提示が要約のみで、ユーザーが diff を見るのに毎回追加要求が必要だった（stockbot-jp Issue #61 の運用で発生）。`skills/autopilot/SKILL.md` に追記: (1) **step 3** — ゲートメッセージ本文（セッション内 + GitHub ゲートコメントの両方）への判断材料インライン提示。差し戻し修正後の再提示は finding ごとに整理した diff ブロック + key lines（= AC を直接実装する行・公開インターフェースを変える行・rejection finding に引用された行）、初回提示は各成果物の key decisions（= 覆すと少なくとも 1 つの AC か plan のステップ構成が変わる判断。整形上の選択や Issue 本文から導出可能な事項 (#254) は対象外）を file/line 参照付きで提示。要約のみの提示（ユーザーに diff を追加要求させる形）を禁止。(2) **step 5** — 実装 diff（per-file stat = `git diff --stat` 形式のサマリ + key hunks = step 3 の key lines を含むハンク）の本文内提示を必須化、green ステータス要約のみを禁止。(3) #261 の `rejectionFindings` バリデーションに**空配列 fail-closed ガード**を追加（`[]` は JS で truthy かつ `.some()` が空虚に false のため、全ガードを素通りして finding ゼロの再提示パスへ到達していた — #276 round-4 レビュー検出）。#267 の提示チャネル規定とは補完関係（成果物本体は引き続き Draft PR diff、インラインハンクは判断根拠であって代替チャネルではない）と明文化。レビュー指摘（#276 round-1/round-2 FAIL）を受け: `tests/test_autopilot_skill.bats` に pin 7 件（境界 canary AT-000: sed 範囲の節見出しリネームによる無音 false-pass を防止 / AT-001〜AT-005: 再提示 diff ハンク・再提示判別条件 / 初回 key decisions / ハンドオフ per-file stat / 操作的定義 / #267-#275 調停句の両節 pin。禁止文言は anchored grep で極性固定 / 空配列 `rejectionFindings` の fail-closed 拒否 pin）、`tests/e2e/autopilot.bats` に US-1 ランタイム回復テスト（実 `claude -p` で再提示シナリオの diff-in-body 回復を検証）を追加。Dialog economy 節（#267）にも補完関係（complements — does not override）を明文化し、再提示の機械判別条件（= `rejectionFindings` 付き再呼び出し, #261）を規定。`docs/issues/275-diff-in-body/`（prd / user-stories / plan / acceptance-tests の 4 点セット）を作成し、`skills/README.md` / `tests/README.md` を同期。
## [3.13.0] - 2026-06-12

### Added

- **`check-plugin-version.sh` に `RESTART_REQUIRED` / `STALE_SESSION` 検知と CHANGELOG 集計ガードを追加**（#280）。(1) `RESTART_REQUIRED`: `~/.claude/plugins/installed_plugins.json` の当該プロジェクトエントリを読み、インストール済みバージョンがロード中バージョンより新しい場合に出力。セッション再起動を促す。マーカー非更新。(2) `STALE_SESSION`: ロード中バージョンがマーカー版より古い（別の新しいセッションがマーカーを先に更新済み）場合に出力。ダウングレード上書き防止のため E2 Auto-Sync をスキップ。マーカー非更新。(3) CHANGELOG 集計ガード: UPDATED 経路でマーカー版のバージョン見出し（`[x.y.z]`）が CHANGELOG に存在しない場合 `VERSIONS: UNKNOWN` を出力（全件誤集計を防止）。(4) 優先順位: STALE_SESSION > RESTART_REQUIRED > UPDATED/NO_UPDATE/FIRST_RUN。(5) `installed_plugins.json` 不在・パース不能・該当エントリなしの場合は従来動作へフォールバック。(6) `skills/session-start/SKILL.md` の Phase 1-E パース表と E2 Auto-Sync 発火条件・Phase 3 レポートテンプレートを更新。BATS テスト 14 件追加（AT-001〜AT-008 系）。

## [3.12.0] - 2026-06-12

### Removed

- **固定 reviewer agent 6 ファイル削除と agents/ 配下レガシー記述の #234 整合**（refs #271 #234 #269）。(1) `agents/prd-reviewer.md` / `agents/us-reviewer.md` / `agents/plan-reviewer.md` / `agents/code-reviewer.md` / `agents/at-reviewer.md` / `agents/final-reviewer.md` を `git rm` で削除。(2) `agents/README.md` を再構成: 固定 roster 表・Usage 節（五専門 reviewer / final aggregator）を削除し、(a) ディレクトリの現行役割（将来のカスタム agent 置き場）、(b) #259 モデルポリシー blockquote（文言無変更）、(c) レビューは reviewing-deliverables の動的レンズパネル × 並列 Workflow（#234）が担う旨の 3 点構成に置換。(3) `docs/methodology/definition-of-ready.md`・`docs/guides/getting-started.md`・`DEVELOPMENT.md`・`DEVELOPMENT.ja.md`・`README.md`・`README.ja.md` のレガシー参照（prd-reviewer / specialist reviewer subagents / 47 criteria 等）を動的パネル記述に置換。(4) `tests/test_reviewer_subagents.bats`（#186 固定 6 agent smoke test）を削除し、`tests/test_agents_dynamic_panel_align.bats`（回帰 pin: 6 ファイル不存在・レガシー参照 0 件・動的パネル言及確認）を新規追加。`tests/test_issue_105_frontmatter_session_inheritance.bats` AC1/AC2 を glob ベースに書き換え（削除済みファイル参照を除去）。`tests/README.md` を同期。全 BATS suite green 確認済み。

## [3.11.4] - 2026-06-12

### Fixed

- **Skill E2E テストの `claude` 起動に `--model`（デフォルト sonnet・`SKILL_E2E_MODEL` で上書き）を指定し、モデル未指定によるトークン過大消費を解消**（#278）。`tests/e2e/*.bats` 全 11 ファイルの `_run_claude` に `E2E_MODEL="${SKILL_E2E_MODEL:-sonnet}"` 変数定義と `--model "${E2E_MODEL}"` フラグを 3 分岐（`timeout` / `gtimeout` / フォールバック）すべてに追加。回帰 pin 2 件（モデル変数 pin + 全分岐 pin）を `tests/test_skill_test_coverage.bats` に追加し、既存 4 件と合わせて 6 件 green。モデルポリシーを `tests/README.md` の Skill E2E Tests 節に追記。変更スコープは `tests/e2e/*.bats` / `tests/test_skill_test_coverage.bats` / `tests/acceptance/AT-278.bats` / `tests/README.md` / `CHANGELOG.md` / `.claude-plugin/plugin.json` / `docs/issues/278-*` に限定（Non-Goals の `_run_claude` 共通ファイル化・`tests/fixtures/headless/` / `scripts/run-skill-e2e.sh` は無変更）。

## [3.11.3] - 2026-06-12

### Fixed

- **`check_sameness` / `check_stuck` の step スコープ化と audit fingerprint への oracle 状態込み拡張 — 偽 sameness halt（#269 再現）の解消**（#272）。(1) `lib/autopilot_convergence.sh` の `_fingerprints` に省略可能な第 2 引数 `step` を追加: 非空のとき `grep -F "\"step\":\"<step>\""` で該当 step の行に絞り込み、クロス step fingerprint の混入を防ぐ。`check_sameness <jsonl> [step]` / `check_stuck <jsonl> <window> [step]` がそれぞれ `_fingerprints` に step を透過。step 省略時は現行挙動（ログ全体を単一系列）を維持（後方互換）。(2) `skills/autopilot/SKILL.md` の rails ステップを `check_sameness "<log>" "${step}"` / `check_stuck "<log>" 3 "${step}"` に更新し、常に現在の step を渡す。(3) audit ステップの fingerprint payload を `${JSON.stringify(blocking)}` 単独から `${JSON.stringify({ atGreen, coverageOk, uncovered, blocking })}` に拡張（oracle gate 状態の変化だけで fingerprint が変わり、偽 sameness を防ぐ）。`uncovered` 変数をループスコープに持ち上げて audit から参照可能にした。(4) 回帰 BATS pin を `tests/test_autopilot_convergence.bats`（AT-001〜004c: 6 件）と `tests/test_autopilot_skill.bats`（AT-005〜006: 2 件）に追加し、全 100 件 green を確認。

## [3.11.2] - 2026-06-11

### Fixed

- **workflow-detail.md のレビュー記述を #234 の動的・並列 Workflow パネルへ整合**（#269）。`docs/workflow/workflow-detail.md` Execution Mode 節の Review step bullet「specialist reviewer subagents … serially spawn → final aggregator」を現行実装（Scout → Generate (dynamic lens panel) → Review (parallel, `parallel()` / `pipeline()`) → Verify (adversarial) → Aggregate (PASS/FAIL + per-lens notes)）の記述に置換。`## Reviewer Aggregation Flow` 節の導入文・mermaid 図（固定 5 reviewer ノード / `final-reviewer: aggregate 47 criteria`）を同フェーズ構成を描く flowchart に差し替え、節見出しを `## Review Workflow Flow` へ変更。回帰 pin として `tests/test_docs_restructure.bats` に 8 件（#269 AT-001〜003 相当）を追加し、`tests/README.md` を同期。変更スコープは `docs/workflow/workflow-detail.md` / `CHANGELOG.md` / `.claude-plugin/plugin.json` / `tests/` / `docs/issues/269-*` に限定（CS-2）。

## [3.11.1] - 2026-06-11

### Fixed

- **成果物提示を Draft PR ベースに統一 — workflow-detail.md のレガシー記述矛盾と defining-requirements の承認後書き込み順序を修正**（#267）。(1) `docs/workflow/workflow-detail.md` Execution Mode 節のレガシー行「Deliverables flow through Issue / PR comments … never written to ad-hoc repository paths」を Workflow 表と整合する規定（成果物は作業ブランチへコミットし **Draft PR 差分**として提示、Issue/PR コメントは**状態通知・承認依頼のみ**）に置換。(2) `skills/defining-requirements/SKILL.md` の Flow を「draft 書き込み → commit/push/Draft PR 作成 → 承認ゲート（PR 上）」の順序に変更し、承認ゲートはターミナルに PR リンク + 判断が必要な点のみを提示（全文展開禁止）、修正は再 commit/push で PR 差分を更新。規定はモード非依存（どの呼び出し元から実行されても同一 — 'autopilot' の語は不使用で既存 C1 pin と両立）。(3) `skills/autopilot/SKILL.md` の Dialog economy 節に提示チャネル規定を追記: Gate ①/② とも成果物本体は Draft PR 差分として提示し、承認依頼・状態通知の全チャネル同期（ターミナル + GitHub に同一内容）は維持。`rules/atdd-kit.md` は無変更（CS-3）。回帰 pin として `tests/test_docs_restructure.bats` に 2 件、`tests/test_defining_requirements_skill.bats` に 4 件、`tests/test_autopilot_skill.bats` に 3 件を追加し、`tests/README.md` を同期。

## [3.11.0] - 2026-06-11

### Changed

- **フェーズ別モデル割り当て — impl / review subagent の Sonnet 化と escalation path の規定**（#259）。モデルベンチ（2026-06-10〜11、2 Issue × 3 モデル × 10 run = 60 実装 + ジャッジ 76 本: 機能品質同等、コスト比 Sonnet 1.0 : Opus 2.2 : Fable 4.1、設計判断一貫性 Fable 20/20）にもとづき、(1) **review Workflow の Sonnet 恒久化** — `skills/reviewing-deliverables/SKILL.md` の埋め込み Workflow script で Scout / Generate / Review / Verify の `agent()` オプションに `model: 'sonnet'` を指定。Aggregate のみ `model` 無指定でセッションモデルを継承（最終 PASS/FAIL 判定は最強モデルに残す。理由コメント付き）。 (2) **impl phase の推奨モデルガイダンス明文化** — `skills/autopilot/SKILL.md` に Model assignment 節を新設（impl subagent は Sonnet 標準・設計絡み Issue は最初からセッションモデル・escalation トリガー = 収束失敗系 halt（`MAX_ITERATIONS` / `sameness-detector` / `stuck`）による `COMPLETED_WITH_DEBT` → 人間介入後の次サイクルからセッションモデルへ Issue 内一方向昇格。`ac-drift` / `record-error` はアンカー・監査整合性 halt のため対象外）。`skills/running-atdd-cycle/SKILL.md` にも参照注記を追加（通常フローは影響なし）。 (3) **agents/README.md のモデルポリシー更新** — 「Model and effort are intentionally unset」を新ポリシー + escalation path + ベンチ要点に置換（指定は Workflow script の `agent()` オプションのみで `agents/*.md` frontmatter には書かない — #105 の継承設計を維持。effort は引き続き unset）。design phase（`extracting-user-stories` / `writing-plan-and-tests`）とオーケストレータは対象外でセッションモデル維持。BATS pin を `tests/test_reviewing_deliverables_skill.bats`（3 件）/ `tests/test_autopilot_skill.bats`（3 件）/ `tests/test_running_atdd_cycle_skill.bats`（1 件）に追加し、新規 `tests/test_phase_model_assignment.bats`（7 件、`@covers: agents/**`）で README ポリシーと両ファイル間の escalation トリガー定義の同一性を pin。`tests/README.md` を同期。

## [3.10.0] - 2026-06-11

### Added

- **autopilot 設計ゲート差し戻しコメントを再実行へ運ぶ `rejectionFindings` 配管と全体差し戻し規律を追加**（#261）。従来、design-approval ゲートの差し戻しコメントは「findings として design phase 再実行に投入される」と宣言されていたが、再実行は**新規 Workflow 呼び出し**で `prevFindings` が `null` 初期化されるため、コメントを generate に届ける配管が存在せず握り潰されていた。`skills/autopilot/SKILL.md` の埋め込み Workflow script に (1) **`rejectionFindings` args**: args parse 直後（FREEZE より前）の fail-closed バリデーション — 非配列で throw / 各要素に非空文字列 `evidence_ref` 必須（AL-4）/ `phase !== 'design'` で throw（design ゲート専用配管・不正 args では 1 イテレーションも走らない）、(2) **iteration 1 シード**: `prevFindings` の `null` 固定初期化を `REJECTION_FINDINGS` シードに置換し、既存 `priorityOf` 正規化（priority 無指定 → 0 = blocker、fail-safe）を適用して既存の `JSON.stringify(prevFindings)` 分岐で generate プロンプトに verbatim 到達させる — を追加。あわせて Flow step 3 に差し戻し規律を明文化: **部分承認（「A は ok / B は要修正」等）は承認ではなく成果物セット全体の差し戻し**（impl phase へ進まない）、コメントは**セクション単位**で分割（1 セクションの指摘 = 1 finding）、各 finding の `evidence_ref` = 該当部分の人間コメント verbatim、`args = { issue: NNN, phase: 'design', rejectionFindings: [...] }` で再呼び出し。`tests/test_autopilot_skill.bats` に pin 4 件（AT-001〜AT-005: 配管・バリデーション・priorityOf 正規化・規律文言）を追加。`lib/autopilot_convergence.sh`・`reviewing-deliverables`・Workflow ツール側は無変更。`skills/README.md` / `tests/README.md` を同期。

## [3.9.0] - 2026-06-11

### Added

- **autopilot 監査ログに fail-closed ガード `check_log_integrity` を追加 — ログ削除・巻き戻しで sameness / stuck が無音リセットされる fail-open を解消**（#262）。`check_sameness` / `check_stuck` は `autopilot-log.jsonl` の履歴に依存するため、run 途中のログ削除・truncate でレールが黙って return 0 していた。機構は**イテレーション連続性検証**（design-doc 案 A）: orchestrator（Workflow script）が期待行数を**プロセスメモリ上**で追跡し（freeze 時に `logLines` baseline を取得 → `record_iteration` 成功ごとに `recorded++`）、rails の 5 項目目として `check_log_integrity <jsonl> <expected-lines>` に渡す。真実をディスク外に置くことで「ログを消す操作では期待値を消せない」を構造的に保証。検証は**完全一致**（actual == expected）— 削除・巻き戻しに加え外部追記も両方向 halt（fail-closed, #256 原則）。ログ未存在は expected=0（正当な初回）のみ通過し、再入（design-gate 差し戻し）・phase 跨ぎの既存行は baseline 吸収で誤検出ゼロ。expected が空・非数値・注入文字列なら stderr + status 2（`check_stuck` の window 検証と同等）。halt 理由 `log-integrity` は `ac-drift` 直後・sameness / stuck より先に判定（両者はログ前提のため）。`tests/test_autopilot_convergence.bats` に検出・非検出 8 件、`tests/test_autopilot_skill.bats` に配管 pin 2 件（AT-006/AT-007）を追加し、`tests/README.md` を同期。

## [3.8.1] - 2026-06-11

### Fixed

- **`.gitignore` に Python バイトコード（`__pycache__/` / `*.pyc`）を追加**（#260）。`hooks/main_branch_guard.py` の実行で自動生成される `hooks/__pycache__/*.pyc` が untracked のまま残り、`git add -A` でコミットに混入するリスクがあった（#254/#256 のモデルベンチマークで 3 回実際に発生し、レビューで major 判定）。Zero Dependencies 原則（"Pure markdown + bash scripts only"）に反するバイナリの履歴汚染を入口で防止する。

## [3.8.0] - 2026-06-11

### Added

- **autopilot に Dialog economy 指針を新設 — 人間への質問を「人間にしか決められない点」のみに限定**（#254）。#251 の初回実運用で Gate ① の壁打ちが `defining-requirements` の通常フロー設計（6 セクション逐次確認）のまま走り、自明なセクションにも毎回 ok 応答が必要だったフィードバックへの対処。`skills/autopilot/SKILL.md` に `## Dialog economy — all human-facing dialog under autopilot` セクションを追加し、(a) **聞くべき**: 設計判断が分かれるトレードオフ・割り切り / スコープ増減 / Outcome 合否基準のみ（ask ONLY、最少の質問数に束ねる）、(b) **聞かない**: Issue 本文・文脈から自明に導けるドラフトの逐次確認（never ask section-by-section）— ドラフトは一括提示（batch-present）し固定ゲート（PRD 承認 / 設計承認 / merge）で各 1 回承認・差し戻し、を明文化。`defining-requirements` の「one question at a time」は通常フロー設計として不変で、autopilot 下でのみ本指針がオーバーライドする（C1: flow skill 本体は無変更）。ゲートは AL-1 の 3 点固定のまま（削減はゲート間・ゲート内のマイクロ確認のみ）。`tests/test_autopilot_skill.bats` に pin 4 件（US-1/US-2/US-3/CS-1）を追加し、line budget を 240 → 260 行に更新（根拠コメント付き）。`tests/README.md` を同期。

## [3.7.3] - 2026-06-11

### Fixed

- **autopilot 埋め込み Workflow script の `args.phase` フォールバック既定値を廃止 — fail-closed 検証に置換**（#256）。旧実装の `const PHASE = A.phase === 'impl' ? 'impl' : 'design'` は、Workflow `args` が JSON 文字列で届くと（#251 で実際に発生）`A.phase` が undefined になり **impl 実行が無言で design に化ける**危険があった（設計承認ゲートの実質迂回）。`if (A.phase !== 'design' && A.phase !== 'impl') throw new Error('args.phase missing or invalid — refusing to default to design')` に置換し、ガードは FREEZE（`pin_anchor`）・イテレーションループより前の args parse 直後に配置（不正 args では 1 イテレーションも走らない）。あわせて Flow 節の design / impl 両 invoke 指示に「args は JSON オブジェクトとして渡す（文字列化した JSON を渡さない）」注記を追加し、`tests/test_autopilot_skill.bats` に回帰 pin 1 件（ガード存在・旧フォールバック不在・注記 2 箇所を検証）を追加。`lib/autopilot_convergence.sh` と Workflow ツール側は無変更。本エントリは 3.7.2 の #252 エントリで**先行対処**済みの defensive parse / `args.issue` ガードに続く #256 の残差分（phase フォールバック廃止）である。

## [3.7.2] - 2026-06-10

### Fixed

- **autopilot 収束ループのプロンプト欠陥 3 点を修正**（#252）。#251 の初回実運用で発覚した欠陥への対処: (1) **placeholder fingerprint** — `audit:` プロンプトの `Run EXACTLY: printf '%s' "<the blocking findings text, verbatim>" | fingerprint` が逐語実行され、毎イテレーション同一の定数ハッシュ `2aed7ea6…` が記録されて sameness / stuck レールが実質無効化していた。blocking findings の JSON（`JSON.stringify(blocking)`）を `BEGIN-PAYLOAD` / `END-PAYLOAD` マーカー付きでプロンプトに直接埋め込み、quoted heredoc で一時ファイルへ書き出してから `fingerprint` に渡す手順へ書き換え。 (2) **review スコープ未指定** — design phase のレビューが「プロダクションコード不在・実行可能 AT 不在」を P0 として返し収束不能だった。phase × step のスコープ節を返す `reviewScope` ヘルパーを追加し `review:` プロンプトに連結（`extracting-user-stories` ステップは prd.md ↔ user-stories.md の整合のみ）。 (3) **findings 不伝達** — fresh-context の gen エージェントに「fix them verbatim」とだけ指示して findings 本文を渡していなかった。iteration 2 以降は前回 `verdict.findings` の JSON を gen プロンプトに埋め込む分岐を追加（iteration 1 は従来文言を維持）。あわせて **args の防御パース**（#256 の先行対処）: Workflow `args` が JSON 文字列で届いた場合の正規化と、`Number.isInteger(args.issue)` の fail-closed 検証（不正なら throw）を冒頭に追加。回帰 pin として `tests/test_autopilot_skill.bats` に 5 件、`tests/test_autopilot_convergence.bats` に placeholder 定数の再計算 pin 1 件を追加。`lib/autopilot_convergence.sh` は無変更。

## [3.7.1] - 2026-06-10

### Fixed

- **main-branch-guard の偽陽性 2 モードを解消 — 判定を「プロジェクトリポジトリ × 対象 worktree ブランチ」基準に変更**（#251）。旧実装はセッション cwd のブランチだけで deny を決めていたため、cwd が main のとき (1) **別リポジトリ**（dotfiles 等）のファイル編集、(2) **同一リポジトリの feature worktree** 配下への編集まで deny する偽陽性があった（逆に cwd が feature のときは sh の早期 return で main worktree 内ファイルへの編集が素通り）。新判定フロー: 対象ファイルを canonicalize（新規ファイルは最近接の既存祖先ディレクトリで解決）→ (a) フック cwd の `git rev-parse --git-common-dir` が解決不能 → fail-safe allow → (b) 対象ファイルの common dir が cwd 側と不一致（プロジェクトリポジトリ外）→ allow → (c) 一致だが**対象側 worktree** のブランチが main/master 以外（detached HEAD 含む）→ allow → (d) main/master → 既存 allow-list 照合 → deny。`main-branch-guard.sh` は入力読取り・`git`/`python3` 存在確認・fail-safe のみへ役割縮小し、ブランチ判定を含む全ロジックを `main_branch_guard.py` に集約。allow-list・フック登録方式・deny メッセージは不変。`tests/test_main_branch_guard.bats` はテストリポジトリを allow-list 外（`$HOME` 直下の mktemp ベース）へ移設し、偽陽性 2 モードの真の負例（AT-001/AT-002、修正前実装で red を確認済み）・対象ファイル基準の真陽性（AT-004）・fail-safe 回帰（AT-006、git/python3 不在は空ディレクトリ + 必要コマンドのみ symlink した stub PATH 方式）を追加（65 case）。`hooks/README.md` / `tests/README.md` を同期。

## [3.7.0] - 2026-06-10

### Changed

- **autopilot の人間ゲートを 2 点から 3 点に再配置 — 設計承認ゲートを新設**（#249）。ユーザーの期待フロー「設計まで壁打ち → 成果物レビュー → 承認後に ATDD」に合わせ、収束ループを **design phase**（`extracting-user-stories` → `writing-plan-and-tests`、anchor = 承認済み prd.md → `autopilot-prd.pin`）と **impl phase**（`running-atdd-cycle`、anchor = 設計承認時に凍結した prd.md + user-stories.md → `autopilot-design.pin`）に分割。design phase が near-green に収束したら autopilot は**停止して設計成果物（user-stories / plan / acceptance-tests）を人間に提示**し、明示承認（差し戻しコメントは evidence_ref 付き finding として design loop に再投入）を得てからのみ ATDD に入る。これは同時に #246 実装の構造矛盾の修正でもある: 旧実装は `prd.md + user-stories.md` をループ開始前に単一 pin（`autopilot-ac.pin`）しながら `extracting-user-stories` を自律ループ内で回していたため、US への修正が入った瞬間 `check_pin` が偽 `ac-drift` halt を起こした。pin はフェーズ開始前に人間が承認した成果物のみを対象とし、同一フェーズのループが編集し得る成果物は含めない（`acceptance-tests.md` は lifecycle marker が動くため pin せず、内容は AC→AT coverage gate が守る）。design phase で AT_STEP がループに混入したら throw する fail-closed を追加。差し戻し後の design phase 再実行では既存 pin を `check_pin` で照合して freeze を継続する（`pin_anchor` の上書き拒否で再実行が破綻しない）。`docs/methodology/autopilot-iron-law.md` の AL-1（3 ゲート固定）/ AL-2（フェーズ別 immutable anchor）を更新し、`tests/test_autopilot_skill.bats`（3 ゲート・2 段 pin・fail-closed の pin 追加）/ `tests/e2e/autopilot.bats`（F1 を 3 ゲート検証へ）/ README ×3 / `tests/README.md` を同期。flow skill 本体と `lib/autopilot_convergence.sh` は無変更。

## [3.6.0] - 2026-06-09

autopilot を **復活**（#246）。ただし旧 autopilot（Agent Teams orchestration、v3.0.0 で廃止）の逐語復活ではなく、**既存の 6-step flow skill をそのまま使う「半自動運転」モード**として再設計した。autopilot を atdd-kit 自身の 6-step フローで自己適用（dogfood）して実装し、その自前レビュー（reviewing-deliverables の多人格・並列・敵対的レビュー）の指摘を反映して満足オラクルと安全レールを **code-deep 化**した。

### Added

- **`autopilot` skill を新設 — autopilot orchestrator**（#246）。既存の flow skill（`extracting-user-stories` → `writing-plan-and-tests` → `running-atdd-cycle` → `reviewing-deliverables`）を順に呼び、人間ゲートを「最初（AC 承認）」と「最後（merge）」の2点に絞る半自動運転。中間を `generate → review → fix` で満足オラクル `AND(決定論 AT 緑, AC→AT カバレッジ緑, reviewer verdict = correct, 確認済み P0/P1 = 0)` まで自律反復する薄い orchestrator。**AT 緑はテストの exit code から取得（LLM 判定にしない, AL-3）**、**AC→AT カバレッジゲートを AT author と別コンテキストで実行（AL-2）**、オラクルは fail-safe（確認済み P0/P1 は evidence_ref 有無に関わらず block）。flow skill は恒久変更せず、役割が変わるのは autopilot モードのときのみ。`/atdd-kit:autopilot <issue>`（例 `autopilot 24`）で起動する。監査ログは slug 付き Issue ディレクトリ `docs/issues/<NNN>-<slug>/autopilot-log.jsonl` に毎 iteration 追記し、収束レールは exit code を JS 側で判定する（LLM 要約に委ねない）。**AL-2 の AC immutability は宣言でなく強制**：承認済み AC（prd.md + user-stories.md）の sha256 をループ開始時に pin（`pin_anchor`）し毎 iteration で `check_pin`、ドリフトしたら `ac-drift` で halt する（ループが自身のアンカーを書き換えられない）。Unit Test (`tests/test_autopilot_skill.bats`、28 case) + Skill E2E Test (`tests/e2e/autopilot.bats`、5 case) 同梱。
- **autopilot 専用 Iron Law を新設**（`docs/methodology/autopilot-iron-law.md`、AL-1〜6）。autopilot モードのときだけ標準 Iron Law（`rules/atdd-kit.md`）を上書きし、人間ゲート2点（AL-1）/ immutable AC アンカー（AL-2、標準 #2 の置換）/ 満足オラクル AND ゲート（AL-3、標準 #3 の強化）/ evidence_ref 必須・裏付けなき PASS の自動降格（AL-4）/ 非収束時 human escalation（AL-5）/ 1 収束サイクルで複数成果物（AL-6）を定める。標準 Iron Law との相反を「逸脱」でなく「許容」する設計判断を明文化。`rules/atdd-kit.md` に上書き参照の1行、`docs/methodology/README.md` に登録。
- **`lib/autopilot_convergence.sh`**: autopilot の収束安全レール（正規化 fingerprint の sameness-detector、stuck 検出、max-iterations、JSONL 監査ログ）。pure bash + coreutils（ゼロ依存）。`record_iteration` は入力を JSON エスケープ・検証し（全 C0 制御文字を畳み込み、不正・空・改行・引用符・バックスラッシュ fingerprint は非ゼロで拒否、先頭ゼロ iteration は base-10 正規化＝監査ログ破損とレール無効化を防止）、`fingerprint` は `LC_ALL=C` でロケール非依存、`check_stuck` は window 内の重複検出で A,B,A,B 振動も捕捉し非数値 window で halt、`check_max_iterations` は空/非数値引数で halt（fail-open を排除）。AL-2 強制用に `pin_anchor`（承認 AC の sha256 を一度だけ pin、上書き拒否）と `check_pin`（ドリフト/pin 欠如/空 fp で halt）を追加。`tests/test_autopilot_convergence.bats` で挙動検証（30 case、JSON-injection・C0 制御文字・空/改行/引用符/バックスラッシュ fp・振動・引数検証・AC pin/ドリフトの負例含む）。

### Changed

- **`reviewing-deliverables` の verdict を後方互換で構造化**（#246）。`AGG_SCHEMA` に `overall_correctness` と evidence_ref 付き `findings[]`（priority / confidence / file / line_range / detail、items は priority/evidence_ref を required）を追加し、autopilot がループ判定（P0/P1 ゲート）に使えるようにした。Aggregate は確認済み P0/P1 を drop せず、裏付けなき finding は `evidence_ref="unverified"` で保持する **fail-safe**（旧 fail-open の drop 指示を撤廃）。既存の `verdict` / `summary` / `byLens`（PASS/FAIL）と top-level required は維持し、**通常モードの挙動は不変**。`tests/test_reviewing_deliverables_skill.bats` に pin（後方互換 = autopilot フィールドが top-level required に入らないことを含む）。
- **`rules/atdd-kit.md` の autopilot 回帰ガードを反転**（#246, 旧 #187 を supersede）。#187 は autopilot を完全廃止し「rules に autopilot 言及なし」を回帰ガードしていたが、本リリースが governed mode として復活させるため、`tests/test_rules_workflow.bats` の AC3 を「autopilot-iron-law 参照の確認」へ反転。

## [3.5.0] - 2026-06-07

### Added
- `.github/workflows/skill-e2e-subscription.yml`: Skill E2E Test を self-hosted runner 上で **サブスク課金内のみ**（macOS Keychain のサブスク資格情報・API キー不使用）で実行する `workflow_dispatch` 限定ワークフロー。`skill-e2e-live.yml`（#208, 従量課金）のサブスク版正系。`scripts/run-skill-e2e.sh` の影響範囲算定を使用。(#243)
- `scripts/ci/skill-e2e-guard.sh`: サブスク限定 CI の Guard ロジック（課金リダイレクト env ブロックリスト ＋ main-ref 信頼境界）の**単一ソース**。ワークフローが委譲し、bats が**挙動検証**する（grep ではなく実行検証）。(#243)
- `tests/test_skill_e2e_guard.bats`: 上記 Guard の**挙動検証** Unit Test 8 case — 7 課金 env それぞれで非ゼロ終了 / 非 main ref・tag・空 ref の拒否 / clean env で 0。反転・gut を検知する。(#243)
- `tests/test_skill_e2e_subscription_workflow.bats`: ワークフローの構造 invariants 9 case（dispatch 限定 / 最小権限（write 昇格禁止）/ 専用ラベル / 入力 env 化 / SHA pin（40hex anchored）/ timeout / no-op / Guard スクリプトへの委譲）。(#243)
- `docs/testing-skills.md` (j) サブスク内 CI 実行: 課金方針（サブスクのみ・APIキー禁止・overflow OFF）、self-hosted runner 登録手順（リポジトリ単位 / ラベル `atdd-kit-e2e` / **`SessionCreate` を付けない**）、複数マシン同一ラベル運用、ハードニング、**accept-risk（write 権限＝信頼境界。main-ref は accidental 排除の safety rail）**、metered 版 `skill-e2e-live.yml` との関係。(#243)

## [3.4.0] - 2026-06-07

epic #179 の最後のサブステップ **C2（#197）** を完了。これで epic #179 の全サブ Issue がクローズされる。

### Added

- **skill-gate に並列衝突検出を追加**（#179 Step C2 / #197）。新スクリプト `scripts/check-issue-collision.sh --issue <N>` が全 git worktree を走査し、別 worktree が同一 Issue の成果物（`docs/issues/<N>/`、`docs/issues/<N>-<slug>/`）を in-progress で書いている（未コミット/未追跡の変更、または base からの差分コミット）場合に衝突を検出し、`Issue #<N> is already in-progress in worktree <path>` を emit して exit 1 する。`skills/skill-gate/SKILL.md` に Pre-check として配線。BATS `tests/test_skill_gate_collision.bats`（20 件）で検証。
  - パス一致は境界アンカー付き（`mydocs/issues/<N>/` 等の部分文字列で誤検出しない／`197` が `1970` に一致しない）で **false positive なし**。
  - committed-work 検出の base ref は worktree ごとに自動判定（`origin/HEAD` → `main`/`master`/`trunk`）。`--base` 明示も可。default branch が `main` 以外の利用先でも false-negative しない。
  - point-in-time の **best-effort / advisory** スキャン（同時開始 race は防げない旨を SKILL.md に明記）。peer worktree の git 失敗は警告を出す（無言の fail-open をしない）。

## [3.3.0] - 2026-06-07

### Changed

- **reviewing-deliverables: `documentation` lens を動的パネルの ALWAYS-include に常設化**（#241）。これまで documentation は Scout が拾う risk surface 依存で、doc 比率の高い変更では散文ドキュメント（README / CHANGELOG / `docs/`）の正確性・整合性・追従性がレビューの穴になっていた（PR #240 のレビューで顕在化）。documentation lens の focus は (a) **accuracy**（prose が実変更と一致）、(b) **consistency**（cross-doc 一貫性。例: `skills/README.md` が全 skill を列挙）、(c) **follow-through / sync**（DEVELOPMENT.md の不変条件を diff に対し検証 — top-level dir 変更時の同 PR README 更新、feature 変更の CHANGELOG エントリ + `plugin.json` version bump。必須の doc 更新漏れは severity major）。`tests/test_reviewing_deliverables_skill.bats` に常設を pin。

## [3.2.0] - 2026-06-07

epic #179 v1.0 の残ステップ（D3/D4 + B7/B8 + C1）を一括完了。これにより新フロー対象 **10 skill 全てに Unit Test + Skill E2E Test が揃い**、#179 DoD「全 10 skill にテストが実装され green」を満たした。(#240)

### Added

- **launching-preview skill を本実装**（skeleton → 実装、#179 Step B7 / #194）。on-demand のローカル preview 起動 skill。引数仕様を確定（PRD Open Question #4 解消）: `--port <n>` / `--no-open`、platform は `.claude/config.yml` から自動判定、ローカルのみ（グローバル URL なし）。Unit Test (`tests/test_launching_preview_skill.bats`) + Skill E2E Test (`tests/e2e/launching-preview.bats`) 同梱。
- **writing-design-doc skill を本実装**（skeleton → 実装、#179 Step B8 / #195）。on-demand・条件付きの design-doc 生成 skill。出力 `docs/issues/<NNN>/design-doc.md`、Ubl 2020 形式（Context / Goals / Non-Goals / Design / Trade-offs / Alternatives / Open Questions）。Unit Test + Skill E2E Test 同梱。
- **bug / debugging skill のテストを追加**（#179 Step C1 / #196）。`tests/test_bug_skill.bats` / `test_debugging_skill.bats`（Unit）、`tests/e2e/bug.bats` / `debugging.bats`（E2E）。
- **`tests/test_skill_test_coverage.bats`**: flow 対象 10 skill が Unit Test + Skill E2E Test の両方を持つことを機械検証（#179 DoD の最終証明、#196）。
- **CI に `skill-e2e-test` job を新設**（#179 Step G1 / #208）。`pr.yml` で `scripts/run-skill-e2e.sh --changed-files <PR の変更ファイル> --dry-run` を実行し、影響範囲の Skill E2E Test を解決・構造検証する。**実 `claude` は呼ばず（トークン消費ゼロ・`ANTHROPIC_API_KEY` secret 不要）**、`ci-gate` に統合、ログを artifact 化。実 claude を伴う live 実行は `skill-e2e-live.yml`（`workflow_dispatch` 手動・secret-gated、`headless-live.yml` と同方式）に分離。#222 の「証跡コメントはローカル必須・CI は補助検証」方針に整合。`tests/test_pr_workflow_skill_e2e.bats` で job 構造を検証。

### Changed

- **`scripts/impact_map.sh` の `--layer` トークンを `L4` → `skill-e2e` にリネーム**（#179 Step D3 / #200）。#222 確定語彙（Skill E2E Test / Unit Test / skill-e2e）に統一。`config/impact_rules.yml` の `l4:` キー → `skill-e2e:`、`scripts/README.md` / `tests/test_impact_map.bats` を追従。`grep -ri l4 scripts/ .github/` = 0。
- **docs の L4 表記を統一**（#179 Step D4 / #201）。`docs/guides/testing-skills.md` の "L4" 言及を `skill-e2e` / `Skill E2E Test` へ。`grep -r L4 docs/ --exclude-dir=issues` = 0。

### Fixed

- **bug / debugging skill に残っていた廃止済み `discover` skill への stale 参照を `defining-requirements` へ修正**（#179 Step C1 / #196）。v1.0 の canonical chain（bug → defining-requirements）と整合。#203（旧 phase-name skill 削除）の取りこぼし。

## [3.1.1] - 2026-06-07

### Removed

- GitHub Projects v2 ボード設定 tooling を廃止 (#238)。`scripts/setup-project.sh` / `scripts/verify-project.sh` / `tests/test_github_projects_setup.bats` を削除し、`docs/methodology/scrumban.md` の `## GitHub Project` 節を除去した。ボードは一度も実体化されておらず（Project URL は `<TBD>` のまま）、関連 Issue（#168 / #170 / #171 / #172）は全て CLOSED 済みのため、[3.0.0] で deferred としていたボード taxonomy の再設計は行わず廃止する。これはプラグイン本体機能ではなくメンテナ用 tooling のため SemVer 上は PATCH 相当。

### Changed

- `docs/methodology/scrumban.md`: `### Autopilot Label Correspondence` を `### Workflow Label Correspondence` にリネームし、autopilot / Kanban Board / `#168` への参照と deprecated ラベル行（`express-mode` / `ready-to-implement`）を除去。active なワークフローラベル表は維持。(#238)
- `tests/test_legacy_terms.bats`: `ready-to-implement` 検査から `docs/methodology/scrumban.md` 例外を撤去し厳格化（scrumban からラベル行を除去したため）。(#238)
- `docs/product/roadmap.md` / `docs/product/product-goal.md` / `docs/product/story-map.md`: 廃止した Kanban Board / Projects v2 sync (#170) への参照を更新。(#238)
- `tests/README.md`: 削除した `test_github_projects_setup.bats` の行を除去。(#238)

## [3.1.0] - 2026-06-07

### Changed
- `skills/reviewing-deliverables/SKILL.md`: Step 5 を **Workflow ツールベースの動的・並列・多人格・複数ラウンドレビュー**へ置換（#234）。従来の固定 6 reviewer subagent **直列**ロスター（`prd`/`us`/`plan`/`code`/`at`/`final-reviewer`、47 criteria）を廃し、埋め込み workflow script で **Scout → Generate → Review → Verify → Aggregate** の 5 phase を駆動。Scout が変更内容（種別・言語・規模・risk surface）を解析し、Generate が **reviewer パネルを動的生成**（常設: functional / clean-code / testability / advocate / skeptic、risk surface に応じて security・performance/load・usability 等を追加）。Review は `pipeline()` で並列、Verify は各 finding を 3 angle で adversarial に多数決検証して偽陽性を抑制、Aggregate が単一 **PASS/FAIL**（日本語）を出力。直列制約は #216 PRD OQ#1 が「後発 Issue で再検討」と先送りしたもので、Workflow tool が `agent()` の context 分離で cross-talk を構造的に解消するため解除。動作確認は AT で完結し manual/preview 非強制。Output language Japanese。(#234)
- `tests/test_reviewing_deliverables_skill.bats`: Unit Test を #234 の新機構に合わせて全面更新 — Workflow tool 駆動 / 5 phase / 動的パネル生成 / 並列実行 / adversarial 複数ラウンド検証 / 非機能 (security・performance・usability) + clean-code・testability + advocate・skeptic カバレッジ / 単一 PASS/FAIL / responsibility boundary / line budget (≤240) / output language / persona-less を検証。(#234)
- `tests/e2e/reviewing-deliverables.bats`: Skill E2E Test を #234 の User Story（F1 動的パネル, F2 並列, F3 非機能 risk-surface lens, F4 adversarial 検証, F5 AT 動作確認, C1 aggregate→PASS/FAIL）へ更新。(#234)

### Note
- 固定 reviewer agents（`agents/{prd,us,plan,code,at,final}-reviewer.md`）は本変更では削除せず温存（`tests/test_reviewer_subagents.bats` 等の対象）。動的生成レビューは prompt ベースで reviewer を起こすため固定 agent に依存しない。整理は別 Issue。(#234)
## [3.0.0] - 2026-06-06

v1.0 への確定リリース。autopilot/Agent Teams 機構・旧 phase-name skill・evals・priority タグを全廃し、ワークフローを canonical な 6-step ATDD フロー（defining-requirements → extracting-user-stories → writing-plan-and-tests → running-atdd-cycle → reviewing-deliverables → merging-and-deploying）に一本化した。Epic #179 の E フェーズ（#202-207）。

### BREAKING Changes

- **autopilot 機構を完全廃止** (#202)。以下が削除された:
  - コマンド `/atdd-kit:autopilot`, `/atdd-kit:auto-sweep`
  - Agent Teams オーケストレーション（main Claude = PO ロール）と `spawn_profiles` 設定
  - autopilot 用 6 エージェント `developer` / `qa` / `tester` / `reviewer` / `researcher` / `writer`
  - circuit breaker (`lib/circuit_breaker.sh`) と autonomy levels (`autonomy:0-3` ラベル)
  - **移行**: 各 Step は対応する skill を直接呼ぶ（`/atdd-kit:defining-requirements <issue>` 等）。skill-gate は v1.0 6-step フローへリルート。レビューは `reviewing-deliverables` が 6 reviewer subagent（`prd-reviewer` / `us-reviewer` / `plan-reviewer` / `code-reviewer` / `at-reviewer` / `final-reviewer`）を直列起動する。
- **旧 phase-name skill を削除** (#203): `discover` / `plan` / `atdd` / `verify` / `ship` / `issue` / `ideate` / `express` とコマンド `/atdd-kit:express`。
  - **移行**: `discover`→`defining-requirements` + `extracting-user-stories`、`plan`/`atdd`→`writing-plan-and-tests` + `running-atdd-cycle`、`verify`/`ship`→`reviewing-deliverables` + `merging-and-deploying`。設計探索は `writing-design-doc`（on-demand）へ。
- **evals システムを廃止** (#204): コマンド `/atdd-kit:auto-eval`、`evals/footprint/`、各 skill の `evals/`（`baseline.json` / `evals.json`）、`scripts/measure-footprint.sh` / `scripts/check-phase5-section.sh`。
- **priority タグ (`p1` / `p2` / `p3`) 機構を廃止** (#205)。session-start のタスク推薦は bugs > features > refactoring > research の種別順のみで行う。

### Removed

- 旧機構を参照していた形骸化 bats テストを多数削除（autopilot 系 22 本、旧 skill 系 14 本、evals 系 2 本ほか）。(#202-204)
- 廃止ドキュメント: `docs/guides/circuit-breaker.md`, `docs/guides/express-mode.md`, `docs/workflow/autonomy-levels.md`, `docs/tests/nl-profile-fixtures.md`（削除済み `spawn_profiles` / autopilot `--profile` 機構専用ドキュメント）。(#206)

### Changed

- `config/impact_rules.yml`: `l4` ターゲットを v1.0 skill セットへ更新（削除済み skill 名を除去）。(#206)
- `skills/skill-fix/SKILL.md` / `lib/skill_fix_dispatch.sh`: Issue 作成を `gh issue create`（`templates/issue/en/development.yml`）に、計画を `writing-plan-and-tests --skill-fix` にリルート。`<AUTOPILOT-GUARD>` → `<SKILL-FIX-GUARD>`。quality-gate / blocked-ac プロトコルは維持。(#206)
- Issue テンプレート（`templates/issue/` と `.github/ISSUE_TEMPLATE/`）の Skill Checklist を 6-step v1.0 フローへリルート。(#206)
- `skills/debugging/SKILL.md` / `skills/session-start/SKILL.md`: 削除済み skill / `config/spawn-profiles.yml` への参照を v1.0 skill / `.claude/config.yml` へ更新。(#206)
- ドキュメント整備 (#207): `README.md` / `README.ja.md`（autopilot / Agent Teams / 旧 skill table / 旧 mermaid を 6-step v1.0 フローへ置換）、`DEVELOPMENT.md` / `DEVELOPMENT.ja.md`（Repository Structure・eval 章 → Test Evidence 章）、`docs/` 配下の prose を v1.0 フローと整合。対象: `docs/README.md`, `docs/product/*`, `docs/guides/*`（`skill-status-spec.md` は skill-fix を唯一の emitter とする実態へ書き換え）, `docs/methodology/*`（`scrumban.md` の GitHub Project ボードセクションは deferred tooling として legacy 注記付きで温存）, `docs/specs/llm-us-ac-auto-reference.md`, `docs/workflow/*`, `commands/README.md` / `lib/README.md`。テスト整備: `tests/README.md` を実在 73 本へ更新、`tests/fixtures/skill-fix/issues.json` のサンプル skill 名を v1.0 へ。

### Notes

- GitHub Projects ボード設定 tooling（`scripts/setup-project.sh` / `scripts/verify-project.sh` / `docs/methodology/scrumban.md` の GitHub Project セクション）は旧 phase 名をボード taxonomy として保持している。これはプラグイン本体の機能ではなくメンテナ用 tooling のため、ボード taxonomy の再設計は別 Issue で扱う。

## [2.6.0] - 2026-06-06

### BREAKING Changes (inherited from 2.0.0 — still in effect)
- `--light` and `--heavy` flags removed (see [2.0.0] for full migration guide). Use `spawn_profiles.custom` in `.claude/config.yml` or `--profile="..."`. (#122)

### Fixed
- `skills/defining-requirements/SKILL.md`: 本文の Step 番号を canonical な 6-step フロー（`rules/atdd-kit.md` Workflow table）と整合。「Step 1+2」→「Step 1」、`extracting-user-stories`「Step 3」→「Step 2」、`writing-plan-and-tests`「Step 4」→「Step 3」、`running-atdd-cycle`「Step 5」→「Step 4」、`reviewing-deliverables`「Step 6」→「Step 5」、"PRD review happens at Step 6"→"Step 5"。#226 reviewer subagent CONCERN の follow-up。(#227)
- `agents/README.md`: reviewer criteria 数を source of truth（`agents/final-reviewer.md`）と整合。us-reviewer「10」→「7」structural criteria（#218 で削減済み）、final-reviewer「50 criteria total」→「47 criteria total」。(#231)
- `skills/README.md`: Skill List テーブルの v1.0 行を実装実態と整合。`defining-requirements` / `extracting-user-stories` を「v1.0 skeleton — not yet implemented」→「Implemented」（#221 / #226 マージ済み）、3 列目 step 番号を canonical（Step 1〜6）に修正。(#231)
- `tests/test_defining_requirements_skill.bats`: test 名「(Step 3 ownership)」→「(Step 2 ownership)」（`extracting-user-stories` は canonical で Step 2）。assertion は Downstream 文字列ベースのため挙動不変。(#231)
- `tests/test_weekly_maintenance_removal.bats`: AC1 の recursive grep に `--exclude-dir='worktrees'` を追加し、リポジトリ配下の git worktree（ファイルの入れ子コピー）への降下による false positive を防止。除外パターンも `^./X` → `^(\./)?X`（dot escape 付き）へ変更し GNU / BSD / ugrep いずれの prefix 挙動でも機能するよう移植性を改善。(#231)

### Removed
- **`tests/claude-code/` 配下を完全削除**: 旧 SAT 系ハーネス (`run-skill-tests.sh` / `samples/{fast,integration}-*.sh` 13 件 / `fixtures/` / `test-helpers.sh` / `analyze-token-usage.py` / `README.md`)。`scripts/run-skill-e2e.sh` + `tests/e2e/<skill>.bats` (#222) が完全代替。(#198 / #199 D1+D2 統合)
- **`tests/test_l4_*.bats` 5 件を削除**: `test_l4_samples` / `test_l4_test_helpers` / `test_l4_run_skill_tests` / `test_l4_analyze_token_usage` / `test_l4_docs`。廃止対象 `tests/claude-code/` を test 対象とする形骸化テスト。(#198 / #199)

### Changed
- **`tests/test_l4_lint_skill_descriptions.bats` → `tests/test_skill_description_lint.bats`**: rename。`scripts/lint_skill_descriptions.sh` を test 対象とする Unit Test で廃止対象に非依存のため中身ロジックは保持。(#198 / #199)
- `tests/README.md`: 「L4 Skill Tests (`tests/claude-code/`)」セクションを「Skill E2E Tests (`tests/e2e/`)」に置換。conventions と references の L4 言及も新語彙 (Unit Test / Skill E2E Test) に更新。(#198)
- `tests/test_skill_terminology_grep.bats`: 許容例外パスに `198-tests-claude-code-deprecation` を追加 (D1+D2 統合 Issue が旧用語の廃止を議論するため)。(#198)

### Added
- `skills/merging-and-deploying/SKILL.md`: v1.0 Step 6 implementation（flow terminus）。review PASS を前提に **merge → deploy → post-deploy regression** の順で ship。post-deploy regression は `tests/acceptance/` の `[regression]` AT を本番ビルドに対して re-run。PASS でない場合は Step 5/4 に差し戻して停止。Output language Japanese。Subagent/label/コード修正は out of scope。(#193)
- `tests/test_merging_and_deploying_skill.bats`: Unit Test (12 cases) — merge→deploy flow / post-deploy AT re-run (regression, `tests/acceptance/`) / merge 前提 (review PASS) / responsibility boundary / line budget / output language / persona-less を検証。(#193)
- `tests/e2e/merging-and-deploying.bats`: Skill E2E Test 3 `@test`（F1 flow order, F2 post-deploy AT re-run, F3 merge precondition）。(#193)
- `skills/reviewing-deliverables/SKILL.md`: v1.0 Step 5 implementation。Step 1-4 成果物 (PRD/US/Plan/Code/AT) を 6 reviewer subagent (`prd-reviewer`/`us-reviewer`/`plan-reviewer`/`code-reviewer`/`at-reviewer`/`final-reviewer`) で **直列レビュー**（#216 PRD OQ#1: context 分離）。5 specialist が計 **47 structural criteria**、`final-reviewer` が集約して単一 PASS/FAIL を出力。動作確認は AT で完結し manual/preview は強制しない。Output language Japanese。(#192)
- `tests/test_reviewing_deliverables_skill.bats`: Unit Test (16 cases) — 6 subagent roster / serial 実行 / AT 動作確認 (manual 非強制) / 47-criteria 整合 / responsibility boundary / line budget / output language / persona-less を検証。(#192)
- `tests/e2e/reviewing-deliverables.bats`: Skill E2E Test 4 `@test`（F1 subagent roster, F2 serial, F3 AT 動作確認, C1 final-reviewer aggregate→PASS/FAIL）。(#192)
- `skills/running-atdd-cycle/SKILL.md`: v1.0 Step 4 implementation。`plan.md` + `acceptance-tests.md` を読み **ATDD double loop**（outer AT loop + nested TDD inner loop）で実装を駆動。実行可能 AT は story 単位で `tests/acceptance/AT-<NNN>.*` に配置、lifecycle `draft → green → regression` を機構として駆動し RED 確認を必須化。C1-C5 ATDD 解釈（Concrete Examples / draft→green / TDD nest / story 単位・unit 単位 / External・Internal 2 feedback loop）を機構強制。Output language Japanese。(#191)
- `tests/test_running_atdd_cycle_skill.bats`: Unit Test (17 cases) — C1-C5 機構 (Concrete Examples + Given/When/Then / lifecycle + RED / TDD nest / story・unit 粒度 / 2 feedback loop) と responsibility boundary / line budget / output language / persona-less を検証。(#191)
- `tests/e2e/running-atdd-cycle.bats`: Skill E2E Test 4 `@test`（F1 input/output paths, F2 TDD inner loop nest, F3 AT lifecycle, C4 story 単位/unit 単位）。(#191)
- `skills/writing-plan-and-tests/SKILL.md`: v1.0 Step 3 implementation. Reads `docs/issues/<NNN>/user-stories.md`, builds a Plan (`docs/issues/<NNN>/plan.md`, 2-5 分粒度タスク + `verify:` ペア, Implementation/Testing/Finishing) と AT 方針 (`docs/issues/<NNN>/acceptance-tests.md`, lifecycle `[planned] → [draft] → [green] → [regression]`) を生成。`design-doc.md` は trade-off / alternatives がある時のみ生成（Ubl 2020）。Output language fixed to Japanese。Scope ends at planning artifacts（実行可能 AT と ATDD double loop は `running-atdd-cycle` #191）。Subagent invocation と `in-progress` label management は out of scope。plan のユーザー承認ゲートは持たず技術レビューは Step 5 に委譲（`workflow-overrides.md`）。(#190)
- `tests/test_writing_plan_and_tests_skill.bats`: Unit Test (27 cases) — responsibility boundary (input/output paths, template citations, upstream/downstream skill, subagent/label scope), line budget (≤200), plan granularity (2-5 min + verify), AT lifecycle, design-doc conditionality, output language, persona-less invariant (SKILL.md + 両 template), template structure を検証。(#190)
- `tests/e2e/writing-plan-and-tests.bats`: Skill E2E Test. 1 skill = 1 file / 4 `@test` (F1 input/output paths, F2 2-5 min grain + verify, F3 AT lifecycle, C1 conditional design-doc) で実 `claude` を `claude -p --max-turns 1` で呼び出して SKILL.md の挙動回復性を検証。(#190)
- `skills/extracting-user-stories/SKILL.md`: v1.0 Step 2 implementation. Reads `docs/issues/<NNN>/prd.md`, presents Story candidates in **one batch** under `## Functional Story` and `## Constraint Story` headings, and after explicit `ok` writes `docs/issues/<NNN>/user-stories.md`. Output language fixed to Japanese. Scope ends at the User Stories file (Plan + AT owned by `writing-plan-and-tests` #190). Subagent invocation and `in-progress` label management are explicitly out of scope. Persona / INVEST / Story Splitting / Example Mapping are unadopted (#216 / #218). (#189)
- `tests/e2e/extracting-user-stories.bats`: Skill E2E Test. 1 skill = 1 file / 4 `@test` (F1-F2 + C2-C3; C1 (≤200 行) は構造的不変項のため Unit Test に集約) で実 `claude` を `claude -p --max-turns 1` で呼び出して output path / 出力言語 / persona-less invariant / batch UX 指示の有無を検証。(#189)
- `tests/test_extracting_user_stories_skill.bats`: Unit Test (13 cases) — responsibility boundary (output path, upstream/downstream skill, subagent/label scope), line budget (≤200), batch UX, output language, persona-less invariant (SKILL.md + template), template structure を検証。(#189)
- `scripts/run-skill-e2e.sh`: Skill E2E Test runner with path-based impact mapping. `--changed-files` でファイル変更リストから影響範囲を path-based に算定 (`skills/<X>/` → `tests/e2e/<X>.bats`、`rules/templates/methodology/` → 全 E2E、`lib/scripts/` → 利用元 SKILL.md cite skill)、`--all`、`--dry-run`、`--log-dir` 対応。`tests/e2e/.logs/<run-id>.log` に run-id / git_sha / timestamp / targets / results / summary を出力。(#222)
- `tests/test_run_skill_e2e_impact.bats`: runner の path-based マッピングと log 必須フィールドを検証する Unit Test 10 case。(#222)
- `tests/test_skill_terminology_grep.bats`: legacy skill testing terminology (SAT / L1-L3 / Fast layer / Integration layer / BATS gate / Fast SAT / Integration SAT) が active source に残らないことを検証。(#222)
- `tests/e2e/`: Skill E2E Test 配置ディレクトリ。`.logs/` は gitignore 済み、`.gitkeep` でディレクトリ自体は管理。(#222)
- `tests/e2e/defining-requirements.bats`: Skill E2E Test の最初の実体。1 skill = 1 ファイル、1 User Story = 1 `@test` の構造で、実 claude を `claude -p --max-turns 1` で呼び出して PRD 6 section / upstream→downstream chain order / 出力 path を検証。`scripts/run-skill-e2e.sh --changed-files skills/defining-requirements/SKILL.md` で path-based 影響範囲算定 → 実 claude 実行 → ログ出力までを通しで実証。(#222)
- `docs/issues/222-skill-test-redesign/`: PRD / user-stories / plan / acceptance-tests。Step 2-3 は B2 (#189) / B3 (#190) skill 未実装のため手動代行。(#222)
- `skills/defining-requirements/SKILL.md`: v1.0 Step 1+2 implementation. 64-line orchestrator that walks the author through the 6 PRD sections (Problem / Why now / Outcome / What / Non-Goals / Open Questions) one question at a time, then writes `docs/issues/<NNN>/prd.md`. Scope ends at the PRD (User Story extraction is owned by `extracting-user-stories` #189). Subagent invocation and `in-progress` label management are explicitly out of scope. (#188)
- `tests/test_defining_requirements_skill.bats`: Unit Test (6 cases) — responsibility boundary (output path, downstream skill, subagent and label scope) and line budget (≤200). (#188)

### Changed
- `tests/test_v1_skill_skeletons.bats`: `running-atdd-cycle` / `reviewing-deliverables` / `merging-and-deploying` removed from the `SKELETON_SKILLS` array (B4-B6 implemented). (#191 / #192 / #193)
- `tests/test_v1_skill_skeletons.bats`: `writing-plan-and-tests` removed from the `SKELETON_SKILLS` array (B3 implemented). (#190)
- `tests/test_v1_skill_skeletons.bats`: `extracting-user-stories` removed from the `SKELETON_SKILLS` array (B2 implemented). (#189)
- **Renamed: skill testing terminology.** v1.0 で「SAT (Skill Acceptance Test) / L1 BATS gate / L2 Fast SAT / L3 Integration SAT / Fast layer / Integration layer」を全廃し **Unit Test (claude を呼ばない BATS) / Skill E2E Test (実 claude 起動)** の 2 層に統一。`docs/testing-skills.md` が新体系の単一の正典。CHANGELOG.md / `docs/testing-skills.md` の廃止宣言 / `docs/issues/222-*` / `docs/issues/179-*` には移行ガイドとして旧用語を保持。(#222)
- `docs/testing-skills.md`: 2 層体系 / 影響範囲算定ロジック / 証跡コメント規約（最新 1 件 update 運用ルール含む） / 1 skill = 1 E2E ファイル構造例で全面書き換え。(#222)
- `tests/test_defining_requirements_skill.bats`, `tests/claude-code/run-skill-tests.sh`, `tests/claude-code/samples/{fast,integration}-*.sh`: 内部コメントの「Fast layer / Integration layer / Skill Acceptance Test」表記を「Skill E2E Test (single-turn) / Skill E2E Test (fixture-based chain) / Skill E2E Test」に置換。ファイル名のリネームは別 PR。(#222)
- `tests/test_v1_skill_skeletons.bats`: Split `V1_SKILLS` into a skeleton-only `SKELETON_SKILLS` array. `defining-requirements` is removed from the skeleton list. Each future B PR (#189–#195) follows the same one-line removal. (#188)

### BREAKING Changes (v1.0 — Step E6)

- **Persona concept removed.** v1.0 (#218) drops the persona model entirely. User Stories use **persona-less Connextra** (`I want to <goal>, so that <reason>`). The following are removed: `docs/personas/` directory, `lib/persona_check.sh`, `docs/methodology/persona-guide.md`, `scripts/check-persona-check-order.sh`, `tests/test_persona_check.bats`, `tests/test_persona_guide.bats`, `agents/us-reviewer.md` criteria #2 (named persona) / #5 (INVEST) / #6 (persona traceability), `lib/spec_check.sh::spec_persona` subcommand, `docs/specs/TEMPLATE.md` persona frontmatter field, and persona-related sections in `docs/methodology/{us-ac-format,us-quality-standard,definition-of-ready,scrumban,atdd-guide}.md`. Applied projects with `docs/personas/` must migrate User Stories to the persona-less form (manual migration required). (#218)
- **Example Mapping not adopted.** Inherited #169 (旧 Phase C: Backlog Refinement evolution) machinery was never part of #179 v1.0 PRD's "採用する設計判断" table. Explicitly removed from sub-issue ACs (#188 / #189). (#216 / #218)
- **INVEST not adopted.** Same provenance as Example Mapping. `agents/us-reviewer.md` criterion #5, `docs/methodology/definition-of-ready.md` R5, and `docs/methodology/us-quality-standard.md` SHOULD references removed. (#216 / #218)
- **Story Splitting (US methodology) not adopted.** `docs/methodology/story-splitting.md` removed. The "Story Splitting" naming in #179 epic refers to **PR splitting** (about 26 sub-PRs), not US methodology splitting. (#216 / #218)

### Changed
- `agents/us-reviewer.md`: Reduced from 10 to 7 criteria after removing #2 (named persona), #5 (INVEST), #6 (persona traceability). Connextra form criterion #1 rewritten as `I want to <capability>, so that <outcome>` (persona-less). (#218)
- `agents/final-reviewer.md`: Total traceability references reduced from 50 to 47 to mirror the us-reviewer change. (#218)
- `agents/qa.md`, `agents/developer.md`: AC Review note "persona's `I want to`" generalized to "`I want to`". (#218)
- `templates/docs/issues/user-stories.md`: `[persona]` placeholder removed; functional and constraint stories use persona-less Connextra. (#218)
- `templates/issue/en/development.yml`: User Story placeholder rewritten as persona-less Connextra. (#218)
- `docs/methodology/us-quality-standard.md`: MUST-1 (Persona Reference) removed; MUST-2/3/4 renumbered to MUST-1/2/3. SHOULD examples rewritten to persona-less form. (#218)
- `docs/methodology/definition-of-ready.md`: R2 rewritten to persona-less Connextra; R5 (INVEST) and R6 (Story Splitting) removed; R7 renumbered to R5. (#218)
- `docs/methodology/us-ac-format.md`: persona frontmatter field removed from schema; field order reduced to `title / issue / status`; TBD Persona Rule section removed. (#218)
- `docs/methodology/scrumban.md`: persona / Hiro / Story Splitting / persona-guide references removed. (#218)
- `docs/methodology/atdd-guide.md`: User Story format rewritten as persona-less Connextra; MUST-1 reference removed; constraint story example rewritten without persona. (#218)
- `docs/methodology/README.md`: persona-guide.md / story-splitting.md rows removed. (#218)
- `docs/README.md`: `personas/` section removed; methodology table cleared of persona-guide / story-splitting rows. (#218)
- `docs/specs/TEMPLATE.md`, `docs/specs/README.md`, `docs/specs/us-ac-format.md`, `docs/specs/llm-us-ac-auto-reference.md`: persona frontmatter field and User Story persona placeholder removed. (#218)
- `docs/guides/spec-reference.md`: AC6 Fallback Matrix `tbd-persona` row removed; Order Invariant `persona check` precedence removed. (#218)
- `docs/workflow/skill-fix-flow.md`: discover SKILL.md row updated to mark persona auto-select as removed in #218. (#218)
- `skills/bug/SKILL.md`: spec-cite step text simplified to remove `tbd-persona` reference. (#218)
- `lib/spec_check.sh`: `spec_persona` subcommand and `tbd-persona` warn case removed. (#218)
- `tests/test_reviewer_subagents.bats`: AC2 us-reviewer category list reduced to `Connextra` + `制約 Story`; AC2 forbidden-category guard added; AC3 reviewer-specific criteria count (us-reviewer=7, others=10); AC4 traceability count reduced from 50 to 47 with role-specific N range. (#218)
- `tests/test_spec_check.bats`: `_make_spec` helper persona arg removed; `spec_persona` subcommand existence test replaced with removal verification. (#218)
- `tests/test_spec_reference.bats`: Group 1 atdd "persona check precedes spec check" test removed. (#218)
- `tests/test_us_ac_format.bats`: persona frontmatter assertions converted to negative guards. (#218)
- `tests/test_us_quality_standard.bats`: persona-related assertions converted to negative guards; MUST-4 references renumbered to MUST-3. (#218)
- `docs/issues/179-atdd-kit-v1-redesign/prd.md`: Step A0 PRD revision — explicitly marked **persona / Example Mapping / INVEST / Story Splitting (US methodology)** as **不採用 (not adopted)** in v1.0. User Story format changed to **persona-less Connextra** (`I want to <goal>, so that <reason>`). Resolved all 4 Open Questions: subagent review = serial execution, dogfood timing = after Step E5, post-deploy regression mechanism and launching-preview args are deferred to #193 / #194 discover phases. Added Step A0 and E6 (persona machinery removal) to the Step structure. (#216)
- `skills/discover/SKILL.md`, `skills/plan/SKILL.md`, `skills/atdd/SKILL.md`, `skills/verify/SKILL.md`, `skills/ship/SKILL.md`: Removed `<AUTOPILOT-GUARD>` blocks from all 5 skills. Standalone slash-command invocation (e.g. `/atdd-kit:discover 188`) now works without `--autopilot`. Autopilot-mode behavioral branches preserved. Precursor partial of #202. (#214)

### Removed
- `docs/personas/` directory (all files: README, TEMPLATE, hiro-solo-dev.md, rin-freeform-coder.md). (#218)
- `lib/persona_check.sh`, `scripts/check-persona-check-order.sh`. (#218)
- `docs/methodology/persona-guide.md`. (#218)
- `docs/methodology/story-splitting.md` (US methodology splitting concept dropped; #179 epic's "Story Splitting" refers to PR splitting). (#218)
- `tests/test_persona_check.bats`, `tests/test_persona_guide.bats`. (#218)

### Removed
- `tests/test_autopilot_guard_block.bats`: Obsolete after `<AUTOPILOT-GUARD>` blocks were removed from 5 skills. The test asserted GUARD block presence and STOP behavior which no longer exists. (#214)
- BATS tests asserting `<AUTOPILOT-GUARD>` presence in `discover`/`plan`/`atdd` SKILL.md files (`test_discover_dod_structure.bats`, `test_discover_autopilot_approval.bats`, `test_discover_skill_fix_bypass.bats`, `test_skill_fix_flag_scope.bats`) — obsolete after GUARD removal. (#214)

## [2.5.1] - 2026-05-11

### Changed
- `rules/atdd-kit.md`: Workflow section replaced with the v1.0 6-step table (Discovery & Definition / User Stories / Plan / ATDD / Review / Merge) listing the 6 new capability-name skills and `docs/issues/<NNN>/` deliverable paths. Added "1 Issue = 1 worktree = 1 Draft PR" to PRs section and "Open Draft PR on first commit/push" to Commits section. (#187)
- `CLAUDE.md`: Added Workflow overview section mirroring the 6-step table with concrete deliverable paths under `docs/issues/<NNN>/`; preserved existing DEVELOPMENT.md / CHANGELOG.md references. (#187)
- `DEVELOPMENT.md`, `DEVELOPMENT.ja.md`, `rules/README.md`: Always-loaded rules budget raised from 40 to 60 lines (v1.0 migration concession); each location notes the re-tighten target tied to Step E. (#187)

### Added
- `tests/test_rules_workflow.bats`: New BATS suite (11 @test functions) mechanically verifying AC1-AC5 of #187 — 6 step names + 6 skill names + ≤60 line budget (AC1), 5 grep checks on CLAUDE.md (AC2), case-insensitive autopilot absence (AC3), verbatim "1 Issue = 1 worktree = 1 Draft PR" (AC4), Draft PR + first/initial commit/push regex (AC5). (#187)

## [2.5.0] - 2026-05-11

### Added
- `skills/defining-requirements/SKILL.md`: v1.0 skeleton — Step 1+2 Discovery & Definition. HARD-GATE blocks execution until #179 Step B1 is implemented. (#185)
- `skills/extracting-user-stories/SKILL.md`: v1.0 skeleton — Step 3 User Story extraction. HARD-GATE blocks execution until #179 Step B2 is implemented. (#185)
- `skills/writing-plan-and-tests/SKILL.md`: v1.0 skeleton — Step 4 Plan + Acceptance Tests. HARD-GATE blocks execution until #179 Step B3 is implemented. (#185)
- `skills/running-atdd-cycle/SKILL.md`: v1.0 skeleton — Step 5 ATDD implementation cycle. HARD-GATE blocks execution until #179 Step B4 is implemented. (#185)
- `skills/reviewing-deliverables/SKILL.md`: v1.0 skeleton — Step 6 Review. HARD-GATE blocks execution until #179 Step B5 is implemented. (#185)
- `skills/merging-and-deploying/SKILL.md`: v1.0 skeleton — Step 7 Merge + Deploy. HARD-GATE blocks execution until #179 Step B6 is implemented. (#185)
- `skills/launching-preview/SKILL.md`: v1.0 skeleton — on-demand local preview. HARD-GATE blocks execution until #179 Step B7 is implemented. (#185)
- `skills/writing-design-doc/SKILL.md`: v1.0 skeleton — on-demand design document. HARD-GATE blocks execution until #179 Step B8 is implemented. (#185)
- `tests/test_v1_skill_skeletons.bats`: BATS smoke test (11 @test functions) verifying all 8 v1.0 skeleton skills for existence, frontmatter conformance, HARD-GATE, Integration section, and ≤50 line constraint. (#185)

### BREAKING Changes (inherited from 2.0.0 — still in effect)
- `--light` and `--heavy` flags removed (see [2.0.0] for full migration guide). Use `spawn_profiles.custom` in `.claude/config.yml` or `--profile="..."`. (#122)

### Removed
- `hooks/autopilot-worktree-guard.sh`, `hooks/autopilot_worktree_guard.py`, `hooks/eval-guard.sh` と対応テスト・設定エントリ: autopilot / evals 機構削除（#179 Step E1/E3）に先行して hook 安全網を除去。(#182)

### Fixed
- `hooks/main-branch-guard.sh` + `hooks/main_branch_guard.py` (new): allow-list for repo-external paths (`/tmp`, `/var/folders`, `/private/var/folders`, `/private/tmp`, `/dev/null`, `~/.claude/`, `~/.config/`) on `main`/`master`; deny message updated to skill-name-agnostic wording; BATS suite extended to 47 cases covering AC1–AC5. (#181)

### Added
- `agents/prd-reviewer.md`, `agents/us-reviewer.md`, `agents/plan-reviewer.md`, `agents/code-reviewer.md`, `agents/at-reviewer.md`: 5 specialist reviewer subagent definitions for the new 6-step ATDD flow (#179 Step A3). Each enumerates 10 verifiable criteria covering the Issue-specified categories (PRD: 問題定義の明確性 / Audience / Outcome 測定可能性 / Non-Goals / Open Questions; US: Connextra / INVEST / 制約 Story / persona traceability; Plan: 2-5 分粒度 / verification / 依存関係; Code: Robot Pattern / testplan 分離 / AT 対応; AT: domain language / AT lifecycle / coverage). Frontmatter = `{name, description, tools}` with `Read, Grep, Glob` only. (#186)
- `agents/final-reviewer.md`: Final aggregator reviewer that names the 5 specialists by basename, cross-references all 50 criteria (10 per specialist via `<role>-reviewer#N` references), and defines the unified PASS/FAIL aggregation rule (PASS iff all 5 upstream reviewers report PASS). (#186)
- `tests/test_reviewer_subagents.bats`: 19-test structural smoke test covering AC1-AC6 of #186 — frontmatter shape, tools allowlist, AC2 category substring coverage, exactly-10 numbered criteria with verb/`?` constraint, 50 distinct traceability references in final-reviewer, and `name = basename` discoverability. (#186)
- `docs/methodology/scrumban.md`: `## GitHub Project` section — Project URL (`<TBD>` placeholder, auto-replaced by `setup-project.sh` on first run), 7-field schema (6 custom fields + Iteration), Status↔autopilot label mapping table with intentional gap note for "Shaped (Pitch済)". (#168)
- `scripts/setup-project.sh`: idempotent CLI script for GitHub Projects v2 setup — project create guard, Status + 5 custom fields creation, all Open Issue bulk-add, bulk field-set (uses `--single-select-option-id` and GraphQL node ID for `--project-id`); auto-replaces `projects/<TBD>` placeholder in scrumban.md with the real project URL on first run. (#168)
- `scripts/verify-project.sh`: automated verification script for AC2 (item count + non-null field check) and AC5 (scrumban.md URL / field schema / mapping grep); also queries Iteration date ranges via GraphQL for AC4 evidence. (#168)
- `tests/test_github_projects_setup.bats`: 23-assertion BATS test suite covering AC1–AC5 for the setup scripts and scrumban.md GitHub Project section; includes placeholder/sed verification for AC5 URL handling. (#168)
- `tests/claude-code/samples/fast-atdd.sh`: fast L4 test verifying atdd skill meta-knowledge — 14-keyword `assert_contains` loop + 2-anchor `assert_order` (ready-to-go State Gate → verify transition). (#140)
- `tests/claude-code/fixtures/atdd-keywords.txt`: ordered keyword fixture for fast-atdd.sh. (#140)
- `tests/claude-code/samples/integration-atdd.sh`: integration L4 test verifying atdd headless invocation — `atdd-kit:atdd` tool_use, SKILL_STATUS declaration in skill-status fence, and State Gate `issue view --json labels` gh call. (#140)
- `tests/claude-code/fixtures/atdd-fixture-issue.md`: mock Issue fixture for atdd integration tests with approved ACs and plan strategy (no real GitHub Issue required). (#140)
- `tests/claude-code/samples/integration-atdd-chain.sh`: chain/triggering L4 test verifying atdd → verify auto-invocation via `skill_transcript_parser.sh` order assertion (atdd_count == 1, verify_count >= 1, verify_order > atdd_order). (#140)
- `tests/test_atdd_superpowers_discipline.bats`: BATS grep tests for atdd superpowers discipline — Rationalization table (`| Excuse | Reality |`), HARD-GATE single-block, Terminal-state clause. (#140)
- `tests/claude-code/test-helpers.sh`: `setup_gh_stub()` extended with optional `--labels "label1 label2"` flag — returns `[{"id":1,"name":"<label>"}]` in `issue view` response; default behavior (empty labels) unchanged for back-compat with all existing callers. (#140)

### Changed
- `agents/README.md`: Available Agents table extended with 6 new step-reviewer rows (prd/us/plan/code/at/final-reviewer). (#186)
- `tests/test_po_dev_qa.bats` `#45-AC5`: agent definition file count updated from 6 to 12 (6 role agents + 6 step-reviewer agents); intent comment notes that Step E5 (#206) will drop `agents/reviewer.md` and the count will become 11. (#186)
- `skills/atdd/SKILL.md`: `## State Gate` section wrapped with `<HARD-GATE>` block (mirroring discover); Rationalization table added (replaces "Red Flags", `| Excuse | Reality |` format); Terminal-state constraint clause added restricting post-atdd invocation to `atdd-kit:verify` only. (#140)
- `DEVELOPMENT.md` / `DEVELOPMENT.ja.md`: "Red Flags tables" → "Rationalization tables" concept name update (line 108). (#140)

- `tests/claude-code/samples/fast-discover.sh`: fast L4 test verifying discover skill meta-knowledge — 11-keyword `assert_contains` loop + 2-anchor `assert_order` (session-start → plan). (#138)
- `tests/claude-code/fixtures/discover-keywords.txt`: ordered keyword fixture for fast-discover.sh. (#138)
- `tests/claude-code/samples/integration-discover.sh`: integration L4 test verifying discover invocation and `SKILL_STATUS: COMPLETE` in skill-status fence via jsonl transcript. (#138)
- `tests/claude-code/fixtures/discover-fixture-issue.md`: mock Issue fixture for integration tests (no real GitHub Issue required). (#138)
- `tests/claude-code/samples/integration-discover-chain.sh`: chain/triggering L4 test verifying discover → plan auto-invocation via `skill_transcript_parser.sh` order assertion. (#138)
- `tests/test_discover_superpowers_discipline.bats`: BATS grep tests for discover superpowers discipline — Rationalization table, HARD-GATE single-block, Terminal-state clause. (#138)
- `tests/claude-code/test-helpers.sh`: `setup_gh_stub()` helper added — creates a self-contained fake `gh` binary under `$tmpdir/gh-stub/` that intercepts `issue view/edit/comment` calls and logs all invocations to `gh-calls-<test-slug>.log`. Exports `GH_STUB_DIR` and `GH_STUB_LOG_FILE` (avoids subshell export problem). (#138)
- `skills/discover/SKILL.md` Step 4: US traceability table format instruction — each AC must map to a User Story element (`I want to` or `so that`); exclusion list overview (project conventions → DoD, trivial consequence → consolidate/omit, implementation guard → Implementation note, future Story → Plan test strategy). (#156)
- `skills/discover/SKILL.md` Step 4.5: MUST-4 "US Traceability" blocking criterion with fail markers, rewrite suggestions, single-source reference to `docs/methodology/us-quality-standard.md`, autopilot parity note (same behavior as MUST-1/2/3), and retroactive non-application caveat. (#156)
- `docs/methodology/us-quality-standard.md`: `### MUST-4: US Traceability` section with rule, Why, exclusion category table, Pass/Fail examples, retroactive non-application note. (#156)
- `agents/developer.md` / `agents/qa.md`: `## AC Review` section appended (identical content) — guides agents to require US element mapping before proposing new ACs, classify excluded categories, and prefer Then-clause strengthening over new AC addition. (#156)
- `skills/discover/evals/evals.json`: A13 assertion added to `dev-feature` eval for MUST-4 execution verification. (#156)

### Changed
- `skills/discover/SKILL.md`: description rewritten to `Use when` form; Rationalization table added; Terminal-state constraint clause added restricting post-discover invocation to `atdd-kit:plan` only. (#138)

## [2.4.0] - 2026-04-22

### Added
- `tests/claude-code/samples/fast-plan-skill-keywords.sh`: L4 fast test that verifies `skills/plan/SKILL.md` contains required anchors (`HARD-GATE`, `AUTOPILOT-GUARD`, `State Gate`, `## Core Flow`, `### Step 1`–`### Step 6`) in ascending line-number order using `grep -n` comparison. (#139)
- `tests/claude-code/samples/integration-plan-minimal.sh`: L4 integration test (guarded by `RUN_INTEGRATION=1`) that invokes `claude -p` against the minimal-project fixture and verifies the jsonl transcript contains `## Implementation Plan` and `### Test Strategy` markers. Stub-mode safe (skips content assertions when `SKILL_TEST_CLAUDE_BIN` is set). (#139)

### Changed
- `skills/plan/SKILL.md`: Applied Option X superpowers discipline — (a) description rewritten to "Use when …" trigger form; (b) `<IRON-LAW>` block added after `<HARD-GATE>`; (c) Rationalization table (`| Excuse | Reality |`) added after Core Principles; (d) `## Terminal State` section added before `## Status Output`. Existing `<HARD-GATE>`, `<AUTOPILOT-GUARD>`, and `ready-for-plan-review` label transition preserved. (#139)

## [2.3.0] - 2026-04-22

### Added
- `tests/claude-code/test-helpers.sh`: fast-test harness with `run_claude`, `assert_contains`, `assert_order`, `assert_count`, `create_test_project`. Supports `SKILL_TEST_CLAUDE_BIN` override for stub-based BATS testing. (#134)
- `tests/claude-code/run-skill-tests.sh`: fast/integration runner with `--test <name>`, `--integration`, `--verbose` flags. Exit codes 0/1/3/130/143. Supports `SKILL_TEST_TMPDIR`, `SKILL_TEST_CLAUDE_BIN`, `SKILL_TEST_PYTHON3_BIN` env overrides. SIGINT/SIGTERM cleanup. (#134)
- `tests/claude-code/analyze-token-usage.py`: per-agent token/cost breakdown from `claude -p` jsonl transcripts. Model-price map at script top; unknown models report N/A. Handles empty/malformed/non-UTF-8/missing files. (#134)
- `scripts/lint_skill_descriptions.sh`: scans `skills/*/SKILL.md` for description anti-patterns (step-chain keywords, length > 200 chars, dash-separator lists). WARN-only mode (exit 0). (#134)
- `tests/claude-code/samples/`: 4 sample tests — fast PASS (`fast-skill-description-lint.sh`), fast FAIL (`fast-intentional-fail.sh`), integration PASS (`integration-discover-minimal.sh`), integration FAIL (`integration-intentional-fail.sh`). (#134)
- `tests/claude-code/fixtures/minimal-project/`: minimal fixture project (`README.md` + `.claude/CLAUDE.md` stub) for integration tests. (#134)
- `docs/testing-skills.md`: L4 methodology — fast vs integration layers, jsonl analysis and pricing map update procedure, cost baseline (fast ≈ $0.10 / integration ≈ $5), adding new tests, linter WARN→FAIL escalation criteria. (#134)
- `tests/claude-code/README.md`: invocation prerequisites, env vars, GH_TOKEN hygiene, SIGINT/SIGTERM contract, exit codes, CI guard (`RUN_INTEGRATION=1`). (#134)
- `tests/fixtures/claude-code/`: BATS fixtures — `transcripts/` (valid/empty/malformed/non-utf8 jsonl), `lint_skill_descriptions/` (good/bad SKILL.md). (#134)
- `tests/test_l4_lint_skill_descriptions.bats`, `tests/test_l4_test_helpers.bats`, `tests/test_l4_analyze_token_usage.bats`, `tests/test_l4_run_skill_tests.bats`, `tests/test_l4_samples.bats`, `tests/test_l4_docs.bats`: BATS coverage for all AC1-AC6. (#134)
- `scripts/bats_runner.sh`: impact-scoped BATS runner. `--all` runs all 111 BATS files under `tests/` and `addons/*/tests/`; `--impact --base <ref>` delegates to `impact_map.sh` to run only affected tests, with automatic full-run fallback for unmatched changed files. Exits 0 with `no affected BATS` when diff is empty (AC5). Invalid base ref exits non-zero with error message (AC6). (#136)
- `scripts/check_bats_covers.sh`: validator that scans the first 5 lines of every BATS file for a non-empty `# @covers: <path-or-glob>` annotation. Exits 0 with `OK: N files` on success, non-zero with violation list on failure. (#136)
- `# @covers:` annotations added to all 111 BATS files (`tests/*.bats` + `addons/ios/tests/*.bats`). Annotation values follow `impact_rules.yml` token conventions for compatibility with both `scan_covers()` (glob-match) and `resolve_path_rules()` (substring-match) in `impact_map.sh`. (#136)
- `tests/test_check_bats_covers.bats`, `tests/test_bats_runner.bats`: BATS test files covering AC1-AC6. (#136)
- `tests/fixtures/impact/`: fixture files for validator and runner tests (valid/missing/empty_covers BATS + mock_impact_rules.yml). (#136)

### BREAKING Changes (inherited from 2.0.0 — still in effect)
- `--light` and `--heavy` flags removed (see [2.0.0] for full migration guide). Use `spawn_profiles.custom` in `.claude/config.yml` or `--profile="..."`. (#122)

## [2.2.0] - 2026-04-22

### Added
- `scripts/impact_map.sh`: maps git diff to affected tests via path rules (`config/impact_rules.yml`) and inline `@covers` metadata. Supports `--base <ref>`, `--layer {L4|BATS}`, `--all`, and `--config <path>`. Unmatched files trigger fallback to full scan with stderr diagnostics. Zero external dependencies (pure bash). (#135)
- `config/impact_rules.yml`: central path glob → L4/BATS test mapping for 7 path categories (skills, lib, hooks, agents, .claude-plugin, scripts, docs). (#135)
- `config/README.md`: schema reference for `impact_rules.yml` and extension policy. (#135)
- `docs/guides/testing-skills.md`: impact scope concept, `@covers` format definition, supported bash fnmatch subset, fallback behavior, and performance target. (#135)
- `tests/test_impact_map.bats`: 33 BATS cases covering AC1–AC8. (#135)

## [2.1.0] - 2026-04-21

### Added
- `skills/skill-fix/SKILL.md`: new skill for reporting atdd-kit skill defects during an active session without interrupting current work. Triggers via explicit `/atdd-kit:skill-fix` or implicit detection (skill name + intent verb). Runs 3-question interview, duplicate check, and dispatches a background subagent (`isolation: worktree`, `run_in_background: true`) that creates a new Issue and drives it to `ready-to-go` using the `--skill-fix` bypass on discover. (#119)
- `commands/skill-fix.md`: explicit slash command entry for skill-fix flow. (#119)
- `lib/skill_fix_dispatch.sh`: shell functions for dispatch, inflight registry (AC7), env scrubbing (AC8), completion check (AC6), and cleanup (AC9). (#119)
- `docs/workflow/skill-fix-flow.md`: workflow reference, Spike Results, #116 coexistence note, and audit marker regex. (#119)
- `templates/workflow/blocked_ac_comment.md`: template for `blocked-ac` blocker comments with `$phase`, `$failed_gate`, `$reason` placeholders. (#119)
- `tests/test_skill_fix_structure.bats`, `tests/test_skill_fix_dispatch.bats`, `tests/test_skill_fix_isolation.bats`, `tests/test_skill_fix_skill_md.bats`, `tests/test_skill_fix_beta_dispatch.bats`, `tests/test_skill_fix_env_contract.bats`, `tests/test_skill_fix_flag_scope.bats`, `tests/test_skill_fix_blocked_ac.bats`, `tests/test_skill_fix_audit_marker.bats`, `tests/test_discover_skill_fix_bypass.bats`: 10 bats test files covering AC1-AC10. (#119)
- `tests/fixtures/skill-fix/`: fixtures for dummy_skill_pass (GREEN scenario), dummy_skill_fail (RED scenario), inflight_registry_sample.json (AC7), issues.json (AC3 4-class). (#119)
- `skills/skill-fix/evals/evals.json` + `baseline.json`: 10 eval cases (trigger/interview/duplicate/dispatch), initial pass_rate 1.0 baseline. (#119)
- `blocked-ac` GitHub label (`#B60205`): AC quality gate failed under skill-fix. (#119)

### Changed
- `skills/discover/SKILL.md`: AUTOPILOT-GUARD and HARD-GATE extended to accept `--skill-fix` flag in addition to `--autopilot`. **HARD-GATE contract change**: discover skill に `--skill-fix` flag を追加。skill-fix subagent 経由の inline plan mode をサポート（HARD-GATE 契約変更）。Step 7 adds `--skill-fix` mode (user approval skipped, quality gates retained). Persona auto-select condition updated to `(--autopilot OR --skill-fix) AND valid_persona_count == 0`. `plan` SKILL.md remains unchanged — HARD-GATE fully maintained (see AC10). (#119)
- `commands/setup-github.md`: `blocked-ac` label added to the standard label set for new projects (prevents drift). (#119)

### HARD-GATE Compensation (discover --skill-fix)
1. Scope: discover only, plan HARD-GATE unchanged (AC10)
2. Audit trail: `<!-- skill-fix-audit: invoked via --skill-fix bypass from parent-issue #N at <ISO-8601> -->` in every skill-fix-created Issue
3. Quality gates retained: MUST-1/2/3 + UX U1-U5 + Interruption I1-I4 execute under `--skill-fix`
4. BLOCKED termination: gate FAIL → `blocked-ac` label, no `ready-to-go`
5. CHANGELOG: this entry

### BREAKING Changes (inherited from 2.0.0 — still in effect)
- `--light` and `--heavy` flags removed (see [2.0.0] for full migration guide). Use `spawn_profiles.custom` in `.claude/config.yml` or `--profile="..."`. (#122)

---

### Added (Japanese / 日本語)
- `skills/skill-fix/SKILL.md`: セッション中に atdd-kit skill の不具合を発見した際、対応中 issue を中断せず background subagent で `ready-to-go` まで自動起票するフロー。明示コマンド `/atdd-kit:skill-fix` と暗黙起動（skill 名 × 意向動詞）の 2 パターン。3 問 interview → duplicate check → subagent dispatch（`isolation: worktree` + `run_in_background: true`）。(#119)
- `commands/skill-fix.md`, `lib/skill_fix_dispatch.sh`, `docs/workflow/skill-fix-flow.md`, `templates/workflow/blocked_ac_comment.md`: 関連ファイル一式。(#119)
- 10 本の bats テスト（AC1-AC10 カバレッジ）。(#119)
- `blocked-ac` GitHub ラベル（`#B60205`）。(#119)

### Changed (Japanese / 日本語)
- `skills/discover/SKILL.md`: AUTOPILOT-GUARD / HARD-GATE 例外 / Step 7 の 3 箇所に `--skill-fix` 分岐を追加。**HARD-GATE 契約変更**: discover skill に `--skill-fix` flag を追加。skill-fix subagent 経由の inline plan mode をサポート。`plan` SKILL.md は変更なし（AC10 で CI 固定）。(#119)

## [2.0.1] - 2026-04-21

### Fixed
- `autopilot-worktree-guard`: hook now auto-detects worktree boundary from stdin `cwd` when `ATDD_AUTOPILOT_WORKTREE` env var is unset, fixing the silent no-op caused by Claude Code's Bash tool not persisting shell state between invocations (fixes #116). The env var remains supported as an explicit override (precedence: env > cwd-detection > no-op); existing env-set behaviour is fully backward-compatible (patch bump). Non-autopilot session overhead increases by ~25ms per tool call (Python startup; negligible vs. 5s timeout). (#116)

### Changed
- `.claude/config.yml`: activate `spawn_profiles.custom` — five roles (`developer` / `qa` / `tester` / `researcher` / `writer`) pinned to `sonnet` and `reviewer` pinned to `opus` for deeper review quality. Flagless `/atdd-kit:autopilot` runs on this repo now use this matrix. `--profile="..."` overrides are unaffected. (#128)

## [2.0.0] - 2026-04-20

### BREAKING Changes
- Autopilot spawn profile UX simplified from 3 paths (`--light` / `--heavy` / `--profile=NL`) to 2 paths: **default** (flagless) and `--profile="NL"`. Passing `--light` or `--heavy` now halts with `Unknown flag: --light (removed in BREAKING change; use --profile="..." instead. supported: --profile)` (substitute `--heavy` as appropriate). Replace preset usage by defining `spawn_profiles.custom` in `.claude/config.yml` for sticky defaults, and/or `--profile="..."` for one-off overrides. (#122)
- Configuration files merged into a single source of truth: the plugin-side `config/spawn-profiles.yml` and the project-side `.claude/workflow-config.yml` are gone. All spawn profile + platform settings now live in **`.claude/config.yml`**. `skills/session-start` auto-migrates existing projects on the next session (write-then-delete, idempotent); new projects get `.claude/config.yml` with a `spawn_profiles.custom` placeholder template. (#122)
- Positional NL after the issue number is no longer a supported invocation path. Use `--profile="..."` exclusively for NL profile overrides. (#122)
- `Profile Confirmation Gate` now fires **only** when `--profile` is supplied; flagless runs (including those that auto-apply `spawn_profiles.custom`) skip the gate. (#122)

### Added
- `lib/spec_check.sh`: 7 subcommands (`derive_slug`, `spec_exists`, `read_acs`, `spec_status`, `spec_persona`, `get_spec_load_message`, `get_spec_warn_message`) — single source of truth for spec file detection and slug derivation, mirroring the `lib/persona_check.sh` dispatcher pattern. `GH_CMD_OVERRIDE` and `SPEC_SLUG_OVERRIDE` env vars enable JA titles and testability. (#70)
- `rules/atdd-kit.md`: Iron Law 4 mandating atdd/verify/bug to load `docs/specs/<slug>.md` via `lib/spec_check.sh` before implementation or AC judgement. File stays at the 40-line cap. (#70)
- `skills/atdd/SKILL.md` "Spec Load (after State Gate PASS, before first AC)": persona-check → spec-check ordering; emits `Loaded docs/specs/<slug>.md (AC count: N)`. (#70)
- `skills/verify/SKILL.md` "Spec Authority Check": status tiebreak (approved/implemented → spec wins; draft/deprecated → Issue comments win with `[spec-warn]` prefix). (#70)
- `skills/bug/SKILL.md` "Spec Citation in Root Cause Classification": spec present → cite governing AC; absent → Classification A with `no spec found for <area>`. (#70)
- `docs/methodology/us-ac-format.md`: "Slug Derivation Rule" (1 Issue = 1 spec, EN-only + JA override), "Spec ↔ Issue Divergence Matrix" (5 patterns + status tiebreak) with cross-link to Rename Run-Book. (#70)
- `docs/guides/spec-reference.md`: full reference for the AC6 fallback matrix and the shared Spec Reference flow across atdd/verify/bug. (#70)
- `docs/specs/llm-us-ac-auto-reference.md`: self-dogfooded spec for #70 itself (AC7). (#70)
- `skills/{atdd,verify,bug}/evals/evals.json`: new spec-reference behavioral evals — atdd +4 (spec-load + 3 fallback variants), verify +8 (3 tiebreak + 5 drift matrix), bug +2 (classification-cites-spec / reports-missing). (#70)
- `tests/test_spec_check.bats` (15 @test) and `tests/test_spec_reference.bats` (22 @test): structural coverage of helper exports, slug rule, rules invariant, Divergence Matrix, and EN-only reference convention. (#70)
- `evals/footprint/spec-reference.yml` + `evals/footprint/baseline.json` update: new 3-SKILL footprint checkpoint (covers bug SKILL.md which is not on the autopilot path); autopilot delta +496 ≤ +500 token budget. (#70)
- `config/spawn-profiles.yml`: single source of truth for autopilot spawn profiles. `profiles.light.*` maps every sub-agent role to `sonnet`; `profiles.heavy.*` maps every sub-agent role to `opus`. (#109)
- `commands/autopilot.md` Phase 0 Argument Parsing sub-heading: parses `--light` / `--heavy` / `--profile=<text>` / `--profile <text>` / trailing positional NL. Position-independent. Halts before Phase 0.9 on unknown flag, conflicting preset flags, utility-mode misuse, search-mode NL violation, preset+NL mixing, or double NL sources. (#109)
- `commands/autopilot.md` Profile Confirmation Gate (fires before Phase 0.9 whenever a profile flag is supplied): prints the 6-role resolved matrix and confirms via AskUserQuestion, with a text-input `Reply with 1 (apply) or 2 (cancel).` fallback. No Team / worktree is created until the user approves. Main Claude (orchestrator) is not listed because its model is never overridden by these flags. (#109)
- `commands/autopilot.md` Agent spawn model resolution rule: each spawn site in AC Review Round, Phase 3 (Developer / Tester / Researcher / Writer), and Phase 4 (Reviewer) references the resolved matrix for the `model` parameter passed to the Agent tool. When no flag is supplied, the parameter is omitted so sub-agents inherit their session default. Mid-phase resume spawns pick up the current invocation's profile. (#109)
- `commands/autopilot.md` NL Resolution Examples block (marked with `<!-- nl-example start/end -->`): documents three representative per-role resolutions for positional NL, `--profile=` delimiter, and space-delimiter forms. (#109)
- `docs/tests/nl-profile-fixtures.md`: 10 manual-verify fixtures pinning expected resolved matrices for preset flags, positional NL, and `--profile` variants. PR merge DoD references these fixtures for human smoke-test evidence. (#109)
- `tests/test_spawn_profiles_config.bats`, `tests/test_autopilot_profile_parsing.bats`, `tests/test_autopilot_profile_flags.bats`, `tests/test_autopilot_nl_profile.bats`, `tests/test_autopilot_profile_main_claude_isolation.bats`: 61 drift-detect cases covering AC1–AC20 including code-fence-aware main-Claude isolation (AC3) and nl-example-aware single-source-of-truth (AC8). (#109)

### Scope Note — effort control not supported (#109)
`effortLevel` is **not** controlled by any profile flag in this release. Investigation during plan (#109) revealed that the Claude Code Agent tool schema does not expose an `effortLevel` parameter per-spawn; only `model` is overridable. Accordingly, `--light` / `--heavy` override the spawn `model` only (`sonnet` / `opus`), and NL profile grammar rejects any effort-dimension tokens with the `Effort control is not supported in this release.` error. Follow-up work to add effort control will be filed as a separate Issue once the Agent tool gains the parameter.

### Model version note (#109)
`model: opus` resolves to whichever Opus revision the Claude Code session is configured to run. The enum is not version-pinned; spawn-side Opus may therefore differ from main Claude's Opus revision at run time. This is deliberate — the profile matrix is intentionally decoupled from specific model revisions.

## [1.23.0] - 2026-04-20

### Added
- `scripts/test-skills-headless.sh`: integration runner for skill-chain tests. Supports `--replay <transcript> <scenario>` (deterministic, zero-token) and live mode (`claude -p --output-format stream-json --include-partial-messages --no-session-persistence`). Env overrides `HEADLESS_CLAUDE_BIN` / `HEADLESS_TEMP_DIR` for testability. SIGINT/SIGTERM terminates the subprocess and cleans up the transcript tempdir. (#72)
- `lib/skill_transcript_parser.sh`: jq-based parser extracting `type=tool_use && name=Skill` events from stream-json into a JSON array of `{name, args, order}`. Strict schema validation: missing `input.skill`, malformed JSON per line, and non-UTF-8 input all fail with `exit 2` (`parse_error`). Subagent-invoked tool_use (`parent_tool_use_id != null`) is filtered out. (#72)
- `lib/skill_assertion.sh`: match engine with `--mode subsequence|strict`, `--expected`, `--forbidden`, `--observed` JSON array flags. Subsequence allows intermediate skills; strict requires exact equality; forbidden hits FAIL regardless of mode. Exit codes: `0` PASS, `1` FAIL, `3` infra. (#72)
- `lib/scenario_loader.sh`: validates scenario spec JSON (version/name/prompt/expected_skills/forbidden_skills/match_mode/timeout/model/fixture) and emits normalized output. Schema violations -> `exit 3`. (#72)
- `tests/fixtures/headless/`: Group-A synthetic fixtures for happy/fail/malformed/schema paths, Group-B real-session fixture `skill-gate-discover.happy.jsonl` (144 lines, Haiku recording, sanitized host paths), plus scenario JSONs for each. (#72)
- `tests/test_skill_transcript_parser.bats` (17 cases), `tests/test_skill_assertion.bats` (17 cases), `tests/test_headless_runner.bats` (13 cases -- flags / SIGINT / live stub / tempdir retention), `tests/test_headless_exit_codes.bats` (12-case matrix across all exit code categories), `tests/test_pr_workflow_headless.bats` (10 cases verifying CI integration). All run in the new `headless-replay` PR job and do not invoke `claude`. (#72)
- `.github/workflows/pr.yml`: new `headless` paths-filter output and `headless-replay` job. Filter scope is narrow (skills/**, headless test own files, workflow YAMLs) to avoid flaky CI from unrelated edits; `hooks/`, `agents/`, `commands/` intentionally excluded in MVP. `ci-gate` now depends on `headless-replay`. (#72)
- `.github/workflows/headless-live.yml`: workflow_dispatch-only live runner. Requires `ANTHROPIC_API_KEY` secret; installs Claude Code CLI; accepts scenario path and model override inputs; uploads transcript artifact on failure. Never triggers on `pull_request` or `push`. (#72)
- `docs/guides/headless-skill-testing.md`: usage guide, regression coverage matrix, scenario spec schema, recording + sanitize procedure, engineered-prompt rationale for the skill-gate -> discover fixture, and budget notes. (#72)
- `DEVELOPMENT.md` + `DEVELOPMENT.ja.md`: "Skill rename = semver-breaking" policy under Versioning. Renaming or removing a shipped skill id breaks pinned scenario fixtures and requires a major bump + fixture re-recording + CHANGELOG `BREAKING CHANGE:` entry. (#72)

## [1.22.0] - 2026-04-18

### Added
- `hooks/autopilot-worktree-guard.sh` + `hooks/autopilot_worktree_guard.py`: PreToolUse hook enforcing that autopilot sessions cannot Edit/Write/MultiEdit/NotebookEdit or Bash-mutate files outside the active worktree. Gated by `ATDD_AUTOPILOT_WORKTREE` env var — no-op for normal (non-autopilot) sessions. Allow-list: `/tmp`, `/var/folders`, `/private/var/folders`, `/private/tmp`, `/dev/null`, and `<W>/.git`. Bash tokenization uses `shlex` (quoted literals and `2>&1` are not misdetected). Blocks exit 2 with `worktree=<W>\nviolating=<path>` on stderr. (#111)
- `hooks/hooks.json`: PreToolUse matchers extended — `Edit|Write|MultiEdit|NotebookEdit` now chains the new guard after `main-branch-guard.sh`, and a new `Bash` matcher invokes the guard. (#111)
- `commands/autopilot.md` Phase 0.9 Step 4: autopilot sessions must export `ATDD_AUTOPILOT_WORKTREE=$(realpath <worktree>)` immediately after `EnterWorktree`. (#111)
- `tests/test_autopilot_worktree_guard.bats`: 46 cases covering AC1-AC6 including Bash-parsing edges (quoted `>`, `2>&1`, `>|`, `&>`, `&>>`, `;` separator, `$()` outer redirect, `~` expansion, heredoc outer redirect, symlink escape, chained `&&`, pipe `|`, `/dev/null`). (#111)
- `tests/test_autopilot_phase09_env_export.bats`: drift-resistant assertion on the `commands/autopilot.md` Phase 0.9 section containing `ATDD_AUTOPILOT_WORKTREE`, `export`, and `realpath` tokens (AC1 regression guard). (#111)
- `hooks/README.md`: section documenting the new hook's behavior, allow-list, block contract, and Known Limitations (mirrors CHANGELOG). (#111)

### Known Limitations (intentional deferrals, #111)
- heredoc file targets (`cat <<EOF > /etc/x`) — not detected; deferred.
- Nested subshell mutations (`$(cmd > path)`) — only outer is inspected.
- `eval "cmd > path"` / `bash -c "cmd > path"` — command strings are opaque to the guard.
- `exec >path` redirects — not detected.
- Interpreter-level file IO (`python -c "open('/p','w')..."`) — target is a Python string literal, unreachable for shlex.
- All of the above are partly mitigated by the `/tmp` allow-list and by Edit/Write/MultiEdit/NotebookEdit being covered separately.
- Requires `python3` in `$PATH` (used for JSON parsing + shlex tokenization). Standard on macOS and CI; unavailability falls back to no-op.

## [1.21.1] - 2026-04-17

### Added
- `docs/personas/hiro-solo-dev.md`: Primary persona for atdd-kit itself — a solo developer running atdd-kit on personal projects. Grounded in the repository's actual single-maintainer commit pattern, project-scope Quick Start, and autopilot's PO-solo design. (#110)
- `docs/personas/rin-freeform-coder.md`: Negative persona — a freeform coder who rejects Issue-driven / AC-first process. Documents the scope boundary so future design decisions do not dilute guardrails under "freeform" pressure. (#110)

### Changed
- `docs/personas/README.md`: Convention table extended with `hiro-solo-dev.md` (Primary) and `rin-freeform-coder.md` (Negative) entries. (#110)
- `docs/methodology/persona-guide.md`: "Creating a Persona Before Running Autopilot" section appended with an "Example: atdd-kit's Own Persona Library" subsection linking to the two persona files above. (#110)

## [1.21.0] - 2026-04-17

### Added
- `commands/autopilot.md`: Phase 5 を `### development / bug / documentation / refactoring` と `### research` の二段 H3 に分割。research タスクは PR verify/merge をスキップし、deliverable 分類 → Issue 起票/コメント → クロージングコメント → 元 Issue クローズ → label 削除 → ExitWorktree/TeamDelete へルーティングされる。(#104)
- `commands/autopilot.md`: Agent Composition Table 直下に Phase 5 note 追加（research は PR verify/merge スキップを明示）。(#104)
- `commands/autopilot.md`: research H3 に classification heuristic 追加（`new_issue` / `existing_comment` / `no_action`、迷ったら `existing_comment` 優先）。(#104)
- `tests/test_autopilot_research_phase5.bats`: AC1-AC9 全件の BATS テスト 30 ケース。(#104)

### Changed
- `tests/test_autopilot_review_gate.bats`: sed 範囲パターンを H2 限定に修正（H3 挿入後も Phase 5 範囲が正しく抽出されるよう対応）。(#104)
- `evals/footprint/baseline.json`: autopilot checkpoint baseline を再測定（commands/autopilot.md +15.7%、plan R2 で想定済み）。(#104)

## [1.20.0] - 2026-04-17

### Changed
- `agents/{developer,qa,tester,reviewer,researcher,writer}.md`: removed pinned `model: sonnet` and `effort: high` frontmatter fields. Agents now inherit model and effort from session-level Claude Code settings (`/model`, `/effort`), allowing users to select Opus 4.7 or other models without editing plugin files. (#105)
- `agents/README.md`: removed `Model` and `Effort` columns from Agent table; removed `model` row from Frontmatter Reference; added session-inheritance note.

### Added
- `tests/test_issue_105_frontmatter_session_inheritance.bats`: regression guard (4 tests) verifying no pinned model/effort fields and README session-inheritance documentation. (#105)

## [1.19.0] - 2026-04-16

### Fixed
- `skills/discover/SKILL.md`: Step 7 autopilot mode now outputs `skill-status` block only — explicitly excludes draft AC listings, UX check results, Interruption check results, and Discussion Summary from terminal output. (#101)
- `skills/discover/SKILL.md`: Bug Flow Step 5 now has independent autopilot/standalone mode branches instead of implicit reference to development flow Step 7. (#101)
- `commands/autopilot.md`: Phase 1 now explicitly states Phase 1 is not complete until AC Review Round agents have been spawned; receiving SKILL_STATUS: COMPLETE from discover alone does not complete Phase 1. (#101)

### Added
- `tests/test_autopilot_phase1_transition.bats`: 14 BATS tests covering AC1 (discover output control), AC2 (Phase 1 completion condition), and AC3 (immediate transition regression). (#101)

## [1.18.0] - 2026-04-16

### Added
- `skills/discover/SKILL.md`: Step 3 persona lookup and bootstrap flow — lists available personas from `docs/personas/` (excluding README.md/TEMPLATE.md) and presents them as AskUserQuestion options; if no personas exist, prompts user to create one following `docs/personas/TEMPLATE.md` format and saves to `docs/personas/<name>.md` (D6 documentation artifact exception). (#69)
- `skills/discover/SKILL.md`: Step 4.5 US/AC Quality Validation gate (development flow only) — validates MUST-1 (named persona reference), MUST-2 (≥3 ACs), and MUST-3 (independently verifiable Then clauses) with blocking enforcement and max-2-revision escalation; checks SHOULD-1 through SHOULD-5 and anti-pattern categories with individual ID-tagged non-blocking advisory. (#69)
- `skills/discover/SKILL.md`: Step 8 spec file creation (standalone mode only) — creates `docs/specs/<kebab-slug>.md` per `docs/methodology/us-ac-format.md` format with `status: approved` frontmatter after Issue comment posting (D6 documentation artifact exception). (#69)
- `skills/discover/evals/evals.json`: 8 new eval cases (id 6-13) covering persona listing, persona bootstrap, MUST-1/2/3 individual violation blocking, SHOULD advisory non-blocking reporting, spec file creation in standalone mode, and spec file skip in autopilot mode. (#69)

### Changed
- `skills/discover/SKILL.md`: D6 principle updated to explicitly list documentation artifact exceptions (`docs/personas/` and `docs/specs/` only). (#69)
- `skills/discover/SKILL.md`: Mandatory Checklist updated to include Step 3a persona selection, Step 4.5 quality validation, SHOULD advisory, D6 exception guard, and spec file creation items. (#69)
- `skills/discover/evals/evals.json`: id:0 (dev-feature) updated — `files` fixture adds `docs/personas/kenji-analyst.md`, assertion A2 extended to require named persona reference from `docs/personas/`. (#69)
- `docs/methodology/atdd-guide.md`: User Story section adds MUST-1 cross-reference to `us-quality-standard.md`; AC Rules section adds MUST-3 independent verifiability link. (#69)

## [1.17.0] - 2026-04-16

### Added
- `docs/methodology/us-quality-standard.md`: New User Story quality standard document with MUST/SHOULD/Anti-pattern/LLM guidelines sections. MUST criteria enforce existing format rules (persona reference, 3+ AC count, independent verifiability). SHOULD criteria apply QUS-derived quality goals (well-formed, atomic, minimal, problem-oriented, unambiguous). Anti-pattern reference covers 3 smell categories with 9 bad examples and suggested rewrites. LLM guidelines scope overview with defer note linking to Issue #69. (#68)
- `docs/methodology/README.md`: New directory index listing all methodology documents with one-line descriptions. (#68)
- `tests/test_us_quality_standard.bats`: 29 BATS tests covering all 6 ACs and language policy for the new quality standard. (#68)

## [1.16.1] - 2026-04-16

### Fixed
- `commands/autopilot.md`: Phase 5 Step 6 の ExitWorktree 呼び出し前に `git switch worktree-autopilot-{issue_number}` を追加。worktree の HEAD が feature ブランチに移動した状態でも ExitWorktree が `discard_changes: true` なしで完了できるよう修正。(#97)
- `tests/test_worktree_isolation.bats`: Phase 5 内で `git switch worktree-autopilot-` パターンが ExitWorktree より前に出現することを機械検証するテスト 2 件を追加。(#97)

## [1.16.0] - 2026-04-16

### Added
- `skills/express/SKILL.md`: New Express skill providing a fast path for trivial, low-risk changes (typo fixes, `.gitignore` additions, one-line comments). Bypasses discover/plan/Three Amigos/review while maintaining Issue-driven development, CI gate, version bump, and CHANGELOG requirements. Requires explicit user approval and rationale before execution. (#94)
- `commands/express.md`: New `/atdd-kit:express <issue>` command that delegates to the Express skill. (#94)
- `docs/guides/express-mode.md`: OK/NG applicability criteria for Express mode with concrete examples, governance table, and escalation guidance. (#94)
- `commands/setup-github.md`: Added `express-mode` label (color `5319E7`) to the repository label setup. Label count updated 13 → 14. (#94)

### Changed
- `skills/README.md`: Added Express skill entry and Express path documentation in Workflow Chain section. (#94)
- `commands/README.md`: Added Express command entry. (#94)
- `tests/test_skill_structure.bats`: Added `express` to `ALL_SKILLS` list. (#94)

## [1.15.1] - 2026-04-16

### Fixed
- `skills/atdd/SKILL.md`: Workflow Step 2 の曖昧な "Create branch: `feat/<issue-number>-<slug>`" を明示的な `git switch -c feat/<issue-number>-<slug>` コマンドに置き換え。refspec rewriting 禁止の WARNING を追加。autopilot Phase 5 の `ExitWorktree` が `discard_changes: true` なしに完了できるよう root cause を修正。(#90)

## [1.15.0] - 2026-04-15

### Added
- `scripts/measure-footprint.sh`: New script for static context/token footprint measurement. Supports `measure`, `--check`, and `--update` operations with JSON output and regression detection (+10% bytes OR +500 tokens threshold). (#76)
- `evals/footprint/session-start.yml`, `evals/footprint/autopilot.yml`: Checkpoint definitions for high-frequency entry points. (#76)
- `evals/footprint/baseline.json`: Initial baseline for session-start and autopilot checkpoints. (#76)
- `evals/footprint/README.md`: Schema documentation distinguishing footprint eval from behavioral pass_rate eval. (#76)
- `tests/test_footprint_eval.bats`: 48 BATS tests covering all 7 groups (happy path / math / lifecycle / threshold / dynamic / errors / E2E) + B1 guard. (#76)
- `.github/workflows/pr.yml`: `evals/**` added to `config` paths-filter so footprint CI runs on checkpoint/baseline changes. (#76)

## [1.14.1] - 2026-04-15

### Changed
- `.gitignore`: Added `.claude/cb-state.json` to prevent accidentally committing circuit breaker runtime state files. (#92)

## [1.14.0] - 2026-04-15

### Added
- `lib/circuit_breaker.sh`: Three-state circuit breaker (CLOSED/HALF\_OPEN/OPEN) for autopilot infinite-loop prevention. Tracks `no_progress` (threshold 3) and repeated error fingerprints (threshold 5 consecutive). State persisted to `.claude/cb-state.json` (cwd-relative, worktree-scoped). No external dependencies (pure bash). (#56)
- `lib/README.md`: Directory README for the new `lib/` directory. (#56)
- `docs/guides/circuit-breaker.md`: Full specification — states, thresholds, subcommand reference, trigger events, fingerprint convention, and reset procedure. (#56)
- `tests/test_circuit_breaker.bats`: Unit tests for AC1–AC8 (37 cases). (#56)
- `tests/test_autopilot_cb_integration.bats`: Integration tests verifying CB check insertion in `commands/autopilot.md` at all 3 iteration entry points (AC9, 8 cases). (#56)
- `commands/autopilot.md`: Circuit Breaker Check blockquotes at Plan Review Round, Phase 3, and Phase 4 entry points. Circuit Breaker Integration section with trigger event table and fingerprint convention. (#56)
- `hooks/bash-output-normalizer.sh`: New PostToolUse hook that normalizes Bash tool output — JSON minify, 3+ consecutive blank line collapse to 2, trailing whitespace removal per line. Reduces token consumption from gh/Bash tool outputs. (#85)
- `hooks/hooks.json`: PostToolUse section added with Bash-only matcher and 10s timeout, distributing `bash-output-normalizer.sh` via plugin mechanism. (#85)
- `scripts/measure-token-reduction.sh`: New script for measuring token reduction between before/after log files using byte-count proxy. (#85)
- `fixtures/token-reduction/`: Fixed mock log fixtures for reproducible AC4b measurement (baseline/ and after/ directories). (#85)
- `docs/guides/token-reduction-results.md`: Token reduction measurement results: AC1 25.8%, AC2 75.3%, AC3 23.9% — all exceed baseline targets. (#85)

### Changed
- `skills/session-start/SKILL.md`: Phase 1-B `gh pr view` call removes unused `mergeStateStatus` field, reducing fetched data by ~3%. (#85)
- `commands/autopilot.md`: Phase 5 merges separate `--json statusCheckRollup` and `--json mergeable` calls into one `--json statusCheckRollup,mergeable` call. Phase 2, Plan Review Round, and Phase 3 SendMessage/spawn instructions updated to use reference-based context (Issue number + comment reference) instead of full-text injection. (#85)

## [1.13.2] - 2026-04-15

### Added
- `docs/specs/` directory with `README.md` and `TEMPLATE.md` for persisting User Story + Acceptance Criteria spec files beyond Issue closure. (#66)
- `docs/methodology/us-ac-format.md`: US/AC spec file format definition (frontmatter schema, status transitions, filename convention, TBD persona rule, rename run-book). (#66)
- `docs/specs/us-ac-format.md`: self-referencing sample spec for the format introduced in #66. (#66)
- `tests/test_us_ac_format.bats`: structural bats tests for docs/specs/ and format compliance. (#66)

## [1.13.1] - 2026-04-15

### Fixed
- `commands/autopilot.md`: Phase 1 Step 4「PO derives draft ACs through Stakeholder dialogue」を削除し、`SKILL_STATUS: COMPLETE` 受信時の即時 AC Review Round 遷移と中間ユーザーメッセージ禁止を明示。autopilot が discover → AC Review Round 間で不要な停止をするバグを修正。(#83)

## [1.13.0] - 2026-04-15

### Changed
- `scripts/check-plugin-version.sh`: UPDATED output changed from raw CHANGELOG diff to 5-line structured summary (`UPDATED`, `<old>`, `<new>`, `VERSIONS: <N>`, `BREAKING: <M>`). Eliminates large CHANGELOG dumps from session-start context. (#75)
- `skills/session-start/SKILL.md`: Phase 1-E updated to parse VERSIONS/BREAKING counts from new 5-line output. Phase 3 report template updated to show concise `v<old> → v<new> (N versions, M breaking changes). See CHANGELOG.md for details.` format. (#75)
- `tests/test_check_plugin_version.bats`: AC1-AC5 tests added for structured summary format; legacy CHANGELOG diff inclusion test removed. (#75)
- `tests/test_session_start_version.bats`: AC6 tests added verifying SKILL.md Phase 1-E and Phase 3 reflect new output protocol. (#75)

## [1.12.1] - 2026-04-15

### Added
- `rules/atdd-kit.md`: EN/JAバリアント存在時のEN優先読み取りルールを追加。`*.ja.md`/`*-ja.yml`はLLMが編集・同期時のみ読む。(#77)
- `skills/issue/SKILL.md`, `skills/bug/SKILL.md`: ENテンプレートのみを使用する旨と`-ja.yml`バリアントは人間のGitHub Web UI用である旨の注記を追加。(#77)
- `tests/test_i18n_language_resolution.bats`: EN優先読み取りルールの存在を検証するテストを追加。(#77)
- `tests/test_bilingual_templates.bats`: SKILL.mdのEN-only注記と-ja.yml除外を検証するテストを追加。(#77)

## [1.12.0] - 2026-04-15

### Added
- `docs/methodology/test-mapping.md`: new AC-to-test-layer mapping guide for the plan skill. Documents 1 AC = 1 Outer Loop cycle rule, Testing Quadrants (Q1-Q4), Double-Loop TDD Mermaid diagram, AC wording → test layer decision table, and usage guide for plan Step 3. (#67)

### Changed
- `docs/methodology/atdd-guide.md`: Double-Loop TDD section updated with cross-reference to test-mapping.md and inline AC correspondence annotation. (#67)
- `docs/README.md`: test-mapping.md entry added to methodology/ table. (#67)

## [1.13.0] - 2026-04-15

### Added
- `docs/methodology/persona-guide.md`: Comprehensive persona guide covering Cooper's Goal-Directed Design, Elastic User Problem, persona format (Name, Role, Goals, Context, Quote), Primary/Secondary/Negative types, creation process, anti-patterns, and discover skill reference method. (#65)
- `docs/personas/TEMPLATE.md`: Blank persona template matching the format defined in persona-guide.md. (#65)
- `docs/personas/README.md`: Directory index with purpose, template usage, and one-file-per-persona convention. (#65)
- `tests/test_persona_guide.bats`: Static verification tests for all persona guide ACs (AC1-AC7). (#65)

### Changed
- `docs/README.md`: Added `personas/` category section following existing format. (#65)

### Removed
- `agents/po.md` deleted — the PO agent definition was a redundant metadata shell (1-line system_prompt + tools list). main Claude already fulfills the PO role directly in autopilot, so the separate agent definition was misleading. All references updated to reflect main Claude as the orchestrator. (#45)

### Changed (#45)
- `commands/autopilot.md`: frontmatter description updated from "PO-led" to "Autopilot end-to-end workflow"; po.md file path references removed from Prerequisites, Phase 0.9, and Session Initialization; "main Claude acts as PO directly" added.
- `agents/developer.md`: "report to PO" → "report to team-lead (the autopilot orchestrator — main Claude)"
- `agents/qa.md`: "Escalate to PO" → "Escalate to team-lead (team-lead is the autopilot orchestrator — main Claude)"
- `agents/README.md`: po.md row removed from Available Agents table; Via Autopilot and Standalone sections updated.
- `README.md`, `README.ja.md`: "PO agent" → "main Claude as orchestrator"; "Seven agents" → "Six agents"; Agent Composition Table PO column → "main Claude"; Mermaid diagram PO node updated.
- `docs/workflow-detail.md`, `docs/getting-started.md`, `commands/README.md`, `skills/README.md`: PO references updated to reflect main Claude as orchestrator.

### Added
- `hooks/main-branch-guard.sh`: PreToolUse hook that denies Edit/Write/MultiEdit/NotebookEdit on `main`/`master` branches. Distributed via `hooks/hooks.json` so all atdd-kit projects receive it automatically. Fail-safe: non-git directories, detached HEAD, and git unavailability all pass through with `{}`. (#38)

### Removed (BREAKING CHANGE)
- **Decision Trail / Decision Record system fully abolished (#42).** The `docs/decisions/` directory, every auto-generated agent deliverable file (`ac-review-*.md`, `impl-strategy-*.md`, `plan-review-*.md`, `test-strategy-*.md`, `pr-review-reviewer-*.md`, `research-*.md`, `draft-acs.md`, `unified-plan.md`, etc.), and the `skills/record` skill are removed. This is a **reversal of #13 / #25** — the `record` skill introduced in 1.6.0 and the `ship` Step 11 chain-to-record are no longer part of the workflow.
- `skills/record/SKILL.md` deleted
- `skills/ship/SKILL.md`: Step 11 (Chain to Decision Record) removed
- `commands/autopilot.md`: Phase 0.9 `mkdir -p docs/decisions` removed; all agent `write results to docs/decisions/...` directives replaced with `SendMessage` reply / Issue-PR comment channels
- `docs/workflow-detail.md`: Decision Trail section replaced with Output Channels section
- `docs/README.md`: `decisions/` subdirectory entry removed
- Tests: `tests/test_decision_record.bats` deleted; Decision Trail assertions (#165-AC3, #165-AC4, #180-AC2) removed from `tests/test_autopilot_agent_teams_setup.bats`

### Changed (#50)
- `commands/autopilot.md`: translate all Japanese content to English (20 occurrences) — DEVELOPMENT.md language policy compliance (#50)
- `skills/plan/SKILL.md`: translate all Japanese content to English (6 occurrences) — DEVELOPMENT.md language policy compliance (#50)
- `skills/discover/SKILL.md`: translate Japanese example to English (1 occurrence) — DEVELOPMENT.md language policy compliance (#50)
- `skills/skill-gate/SKILL.md`: translate Japanese keyword examples to English (2 occurrences) — DEVELOPMENT.md language policy compliance (#50)
- `skills/bug/SKILL.md`: translate Japanese trigger keywords to English (1 occurrence) — DEVELOPMENT.md language policy compliance (#50)

### Changed (#42)
- `skills/discover` and `skills/plan`: `Discussion Summary` section is now described as "remains in the Issue comment as the permanent record" rather than "consumed by the record skill"
- `skills/README.md`: workflow chain diagram updated to end at `ship` (no trailing `record`)
- autopilot / workflow-detail: explicit **Output Channels** rule added — inter-agent handoffs flow via `SendMessage`, human-facing work logs flow via Issue / PR comments. Writing agent deliverables to `docs/decisions/` or any other repository path is prohibited. Curated knowledge graduates into existing docs only by explicit human decision.

### Rationale
The original Issue #42 was a one-off bug ("Phase 4 Reviewer Decision Trail file not committed"), but investigation showed the underlying mechanism was over-engineered: auto-generated files were not actually being read, the same information already existed in Issue / PR comments, and the write / commit responsibility was unclear across roles. Removing the mechanism eliminates the bug class entirely and aligns the workflow with where discussion already happens.

## [1.11.1] - 2026-04-15

### Removed
- `agents/po.md` deleted — the PO agent definition was a redundant metadata shell (1-line system_prompt + tools list). main Claude already fulfills the PO role directly in autopilot. (#45)

### Changed
- `commands/autopilot.md`: frontmatter description updated; po.md file path references removed from Prerequisites, Phase 0.9, and Session Initialization. (#45)
- `agents/developer.md`: "report to PO" → "report to team-lead (the autopilot orchestrator — main Claude)". (#45)
- `agents/qa.md`: "Escalate to PO" → "Escalate to team-lead (team-lead is the autopilot orchestrator — main Claude)". (#45)
- `agents/README.md`, `README.md`, `README.ja.md`, `docs/workflow-detail.md`, `docs/getting-started.md`, `commands/README.md`, `skills/README.md`: PO references updated; "Seven agents" → "Six agents"; Agent Composition Table PO → "main Claude". (#45)

## [1.11.0] - 2026-04-15

### Added
- `commands/autopilot.md`: Plan Review Round step 6 — clear/continue stop-point fires after `ready-to-go` label is set in the same session. Presents `AskUserQuestion` 2-option prompt (clear and end / continue to Phase 3). Clear selection prints resume guidance (`/atdd-kit:autopilot <N>`) and terminates autopilot. Continue proceeds to Phase 3 unchanged. Mid-phase resume (new session, `ready-to-go` already set) bypasses stop-point via Phase 0.5 determination. Other/unclassifiable response follows Autonomy Rules failure mode — report and STOP. (#54)
- `agents/po.md`: Added `AskUserQuestion` to PO `tools:` list to support the Plan approval stop-point. (#54)

## [1.10.0] - 2026-04-13

### Added
- docs: `skill-authoring-guide.md` — Dialogue UX design principles for skill authors (AskUserQuestion constraints, Recommended pattern, closed question guidelines) (#35)
- tests: `test_question_design_migration.bats` with 40 tests covering AC1-AC7 (#35)
- ideate: evals `baseline.json` with pass_rate 1.0 baseline for 4 eval scenarios (#35)
- issue: evals `baseline.json` with pass_rate 1.0 baseline for 5 eval scenarios (#35)
- bug: evals `baseline.json` with pass_rate 1.0 baseline for 2 eval scenarios (#35)

### Changed
- ideate: Step 0 (Brainstorm?), Step 2 approach selection, Step 3 approval — converted from inline text choices to AskUserQuestion + Recommended pattern (#35)
- issue: Priority confirmation — converted from inline text to AskUserQuestion + Recommended pattern (#35)
- bug: Fix Proposal approval — converted from inline arrow prompt to AskUserQuestion + Recommended pattern (#35)
- discover: Approach selection, DoD confirmation, User Story confirmation, AC approval, Root Cause confirmation, Docs DoD approval — converted to AskUserQuestion + Recommended pattern (#35)
- plan: Outer Loop test layer selection, Large Plans split decision — converted to AskUserQuestion + Recommended pattern (#35)
- ideate evals: added E1 assertion (Recommended pattern in approach selection) — total 10 assertions (#35)
- issue evals: added A4 assertion (Recommended in Priority confirmation) — total 13 assertions (#35)
- bug evals: added A3 assertion (Recommended in Fix Proposal) — total 5 assertions (#35)
- discover evals: added A10 assertion (Recommended in key decision points) — total 23 assertions (#35)
- plan evals: added A5 assertion (Recommended in Story Test layer selection) — total 10 assertions (#35)

## [1.9.0] - 2026-04-13

### Added
- plan: Agent Composition section added to plan deliverables — Step 4 derivation guidance, Step 6 template, and Step 5 Readiness Check row (#41)
- tests: `test_plan_agent_composition.bats` with 13 tests covering AC2-AC7 (#41)

### Changed
- autopilot: Variable-Count Agents now spawned directly from plan-approved Agent Composition — no additional user approval required at Phase 3/4 spawn time (#41)
- autopilot: Plan Review Round Developer instruction now includes Agent Composition review (count and focus concreteness) (#41)
- autopilot: Phase 0.9 mid-phase resume now validates plan comment exists before proceeding to Phase 3/4; reports error and STOPs if absent (#41)

## [1.8.0] - 2026-04-13

### Added
- discover: DoD (Definition of Done) derivation step (Step 2.5) added to Development, Bug, and Refactoring flows (#36)
- discover: DoD derivation step added to Documentation/Research flow (replaces Completion Criteria) (#36)
- discover: DoD section now appears at the top of all Issue comment templates across all task types (#36)
- discover: Refactoring flow requires a DoD item confirming externally observable behavior is unchanged (#36)
- tests: `test_discover_dod_structure.bats` with 26 tests covering AC1-AC9 (#36)

### Changed
- discover: "Completion Criteria" terminology replaced with "DoD (Definition of Done)" throughout all flows (#36)
- discover: Documentation/Research flow Step 3 renamed from "Define Completion Criteria" to "DoD Derivation" (#36)
- plan: Step 1 and description updated to read DoD + ACs from discover deliverables (#36)
- docs/issue-ready-flow.md: "completion criteria" references updated to "DoD" (#36)
- commands/autopilot.md: "completion criteria" reference updated to "DoD items" (#36)

## [1.7.0] - 2026-04-12

### Added
- 7-agent architecture: tester.md, reviewer.md, writer.md agents added alongside existing po, developer, qa, researcher (#34)
- Task-type-specific workflow branching in autopilot: development, bug, research, documentation, refactoring each have distinct agent compositions (#34)
- Agent Composition Table mapping task types to Phase 1/Phase 2 agent sets (#34)
- Variable-count agents (Reviewer, Researcher) with user approval flow (#34)
- AUTOPILOT-GUARD STOP mode for discover, plan, atdd, verify, ship skills — prevents direct invocation outside autopilot (#34)

### Changed
- `ready-to-implement` label renamed to `ready-to-go` across all skills, commands, docs, and templates (#34)
- `type:investigation` label renamed to `type:research` with corresponding template and flow updates (#34)
- investigation.yml Issue templates renamed to research.yml (en and ja) (#34)
- Phase 3/4 headings changed to "(task-type-specific)" reflecting multi-flow design (#34)

## [1.6.1] - 2026-04-12

### Fixed
- discover/plan/atdd: autopilot mode detection migrated from `<teammate-message>` context to `--autopilot` flag in ARGUMENTS, fixing PO direct Skill invocation not being recognized as autopilot mode (#3)
- autopilot.md: Phase 1 (discover) and Phase 3 (atdd) Skill calls now pass `--autopilot` flag in args (#3)

## [1.6.0] - 2026-04-12

### Added
- New `record` skill: generates Decision Record in `docs/decisions/YYYY-MM-DD-<topic>.md` after ship completes (#13)
- `ship` Step 11: chains to `record` skill after merge for automatic Decision Record generation (#13)
- `discover` deliverables template: `### Discussion Summary` section for recording approach exploration and rationale (#13)
- `plan` deliverables template: `### Discussion Summary` section for recording design decisions and trade-offs (#13)

## [1.5.1] - 2026-04-12

### Fixed
- pr-screenshot-table.sh: AWK code injection prevention — use `-v` option instead of shell expansion for file path (#26)
- pr-screenshot-table.sh: safe image_paths expansion — convert string concatenation to bash array, remove SC2086 disable (#26)
- pr-screenshot-table.sh: add PR number input validation with integer regex check (#26)
- .gitignore: add `*.local.*`, `*.secret`, `*.secrets` catch-all patterns (#26)
- eval-guard.sh: use three-dot diff (`origin/main...HEAD`) to detect only branch-introduced SKILL.md changes, preventing false positives when main advances (#22)
- eval-guard.sh: strengthen `git push` detection regex to avoid false positives from "git push" in command arguments (#22)

## [1.5.0] - 2026-04-12

### Changed
- sim-pool-guard.sh: redesign from fail-closed to fail-open — unlisted tools now ALLOW instead of DENY (#21)
- sim-pool-guard.sh: XcodeBuildMCP clone-required tools use `*_sim` pattern matching via `is_xcode_clone_required()` instead of explicit array (#21)
- sim-pool-guard.sh: rename `CLONE_REQUIRED_TOOLS` to `CLONE_REQUIRED_IOS_SIM` with updated ios-simulator tool names (#21)

### Added
- sim-pool-guard.sh: `DENY_TOOLS` array for golden image protection — `erase_sims` unconditionally denied (#21)
- sim-pool-guard.sh: `is_xcode_clone_required()` function for `*_sim` suffix pattern + `screenshot`, `snapshot_ui`, `session_set_defaults`, `session_use_defaults_profile` (#21)
- sim-pool-guard.sh: DENY check runs before session_id check — `erase_sims` blocked even without session (#21)

### Removed
- sim-pool-guard.sh: `READONLY_TOOLS` array — superseded by fail-open default (#21)

## [1.4.0] - 2026-04-12

### Changed
- `workflow-config.yml` simplified to flat `platform` field only — removed `project.name` wrapper (#17)
- session-start confirmation prompt now shows full addon inventory (MCP servers, hooks, deploy files, skills) before asking for confirmation (#17)

### Fixed
- Removed stale `screenshot_script` reference in ship skill (#17)
- Removed stale `review_agents` reference in review-guide (#17)

### Added
- Addon installation inventory section in getting-started.md listing all components each addon installs (#17)

## [1.3.0] - 2026-04-12

### Added
- ideate skill integrated into issue → discover workflow: post-Issue mode, skip option, Context Block handoff (#8)
- issue skill now chains to ideate instead of directly to discover (#8)
- Workflow documentation updated with ideate step in all flow diagrams and skill chain descriptions (#8)

## [1.2.1] - 2026-04-12

### Fixed
- sim-pool-guard.sh: add `build_sim`, `build_run_sim`, `test_sim` to `CLONE_REQUIRED_TOOLS` — previously denied by fail-closed guard (#1)

## [1.2.0] - 2026-04-12

### Added
- autopilot Phase 5: TeamDelete step to remove `autopilot-{issue_number}` team on task completion (#7)
- autopilot Phase 0.9: pre-resolve `TeamDelete` schema via ToolSearch (#7)

## [1.1.0] - 2026-04-11

### Added
- session-start Phase 1-G: auto-configure `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in `.claude/settings.local.json` every session (#2)
- autopilot Prerequisites Check: actionable error message when Agent Teams tools are unavailable (#2)

## [1.0.0] - 2026-04-10

### Added
- `addons/` directory with declarative addon manifest system (`addon.yml`) (#192)
- `addons/ios/` — self-contained iOS addon (scripts, CI fragment, tests, manifest) (#192)
- `agents/` directory with role definitions (po.md, developer.md, qa.md, researcher.md) (#192)
- `templates/ci/base.yml` — platform-agnostic base CI workflow (#192)
- `commands/setup-github.md` — GitHub templates and labels setup command (#192)
- `commands/setup-ci.md` — CI workflow composition command (#192)
- First-time auto-setup in session-start (auto-detects platform from project structure) (#192)

### Changed
- **BREAKING:** Plugin architecture redesigned — init skill abolished, template expansion abolished (#192)
- **BREAKING:** `workflow-config.yml` simplified to `platform` field only (removed: language, build, paths, autonomous_processes, skill_adapters, environment, design) (#192)
- **BREAKING:** LLM-facing files are English only — all SKILL.ja.md and docs/*.ja.md removed (#192)
- `scripts/ios/` moved to `addons/ios/scripts/` (#192)
- `tests/test_sim_*.bats` moved to `addons/ios/tests/` (#192)
- `commands/autopilot.md` — reads agent definitions from `agents/` instead of `autonomous_processes` in workflow-config.yml (#192)
- `skills/session-start/SKILL.md` — addon-aware file sync replaces hardcoded sync table (#192)
- `rules/atdd-kit.md` — language resolution section replaced with addons section (#192)

### Removed
- `skills/init/` — init skill abolished; replaced by session-start auto-setup (#192)
- `templates/*.tmpl` — pseudo-Handlebars template expansion abolished (#192)
- `docs/language-resolution.md`, `docs/i18n-strategy.md` — i18n simplified (#192)
- All `SKILL.ja.md` files (12 files) — English only for LLM-facing content (#192)
- All `docs/*.ja.md` files (7 files) — English only for LLM-facing docs (#192)
- `autonomous_processes` and `skill_adapters` from workflow-config.yml — moved to agents/ (#192)

