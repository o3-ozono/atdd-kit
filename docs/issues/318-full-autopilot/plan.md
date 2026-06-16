# Plan: full-autopilot — キュー方式で複数 issue を並列・無人で merge まで回す

> **本 Issue は #318 一本で一括実装する**（サブ Issue 分割なし・単一 Draft PR #319）。下記の (a)〜(d) は**実装順序の単位**であり、別 Issue ではない。依存 DAG に従って同一ブランチ上で順に green 化する。

## Epic 分解と依存 DAG

```
#316 (merged: branch-lease guard, hooks/branch-lease-guard.sh)
   │
   ├──> (d) lease 拡張: issue-lease + merge-lease        … 基盤・依存なし
   │        ├──────────────> (b) dispatcher + issue-queue   … (a)(d) 依存
   │        └──────────────> (c) merge coordinator          … (d) 依存
   │
   └──  (a) autopilot hand-off モード                    … lease 非依存
            └──────────────> (b) dispatcher + issue-queue
```

| サブ | タイトル | 依存 | 成果物の核 |
|------|---------|------|-----------|
| (a) | autopilot hand-off モード | なし | autopilot に full-autopilot 限定フラグ。3 gate を畳む（②自動承認・③merge せず手放す）。AL-1 のモード分岐。 |
| (d) | lease 拡張（issue-lease / merge-lease） | なし（#316 基盤） | #316 の lease 機構を容量・キー違いで拡張。issue 単位排他 ＋ `main-merge` 容量1。 |
| (c) | merge coordinator | (d) | `merge-ready` を容量1で直列 drain：rebase→フル再ゲート→merge→post-merge regression。自動差し戻し→閾値 N で human。 |
| (b) | dispatcher + issue-queue（`full-autopilot` skill） | (a)(d) | キュー読取（`ready-to-go`）→ issue-lease 取得 → headless worker 起動 → 完了監視 → 次へ / coordinator へ。 |

**ロールアウト順**: (a)・(d) を先行（相互独立・並行可）→ (c)（merge-lease 上に）→ (b)（hand-off worker ＋ issue-lease を束ねる）→ epic 統合 E2E。

## Implementation

### サブ (a) autopilot hand-off モード
- [ ] autopilot skill に full-autopilot 限定フラグ（例 `--hand-off` / 内部 args）を追加し、Gate ②（設計承認）を自動承認・Gate ③（merge）を `merge-ready` 手放しに切り替える
- [ ] verify: 通常起動は3 gate のまま（AT-318-A2 invariant green）、hand-off 起動は設計 gate でブロックせず near-green 収束後に Draft 外し＋`merge-ready` ラベル付与で exit（AT-318-A1）
- [ ] `docs/methodology/autopilot-iron-law.md` に full-autopilot モードでの AL-1 上書き（gate を①事前承認＋②自動＋③coordinator へ）を明記
- [ ] verify: 通常モードの AL-1（厳密3 gate）記述が不変であることを doc 整合チェックで確認

### サブ (d) lease 拡張
- [ ] `hooks/branch-lease-guard.sh` の lease 機構を共有して issue-lease（キー=issue 番号）を実装（issue claim の二重取り防止）
- [ ] verify: 同一 issue を2セッションが claim → 後発がブロック（フック単体テスト、#316 と同型）
- [ ] merge-lease（キー=`main-merge`・容量1）を実装。取得は coordinator が握る
- [ ] verify: 2 worker が同時 merge 試行 → 容量1で後発が待機/ブロック（フック単体テスト）＋ TTL stale 掃除（#316 同型）
- [ ] verify: `ATDD_BRANCH_LEASE_FORCE` 相当の override が各 lease で機能

### サブ (c) merge coordinator
- [ ] `merge-ready` ラベル PR を FIFO/優先度で1件 drain するループを実装（merge-lease 保持下）
- [ ] verify: `rebase onto 最新 main → フル再ゲート（AT＋verdict）→ merge → post-merge regression` が1本通る（AT-318-C1）
- [ ] rebase 衝突 / 再ゲート fail → 新 autopilot イテレーションへ自動差し戻し、失敗カウンタ加算
- [ ] verify: 意図的に衝突させた PR が差し戻され、N 回失敗で human フラグ（Issue コメント）に到達（AT-318-C2 / F7）
- [ ] verify: 並列 merge-ready 2本を逐次統合し main が壊れない（broken-together 防止、AT-318-C3 / C1-story）

### サブ (b) dispatcher + issue-queue（`full-autopilot` skill 新設）
- [ ] `skills/full-autopilot/SKILL.md` を新設：キュー（`ready-to-go` ラベル）読取 → issue-lease 取得 → headless `claude -p "/atdd-kit:autopilot <issue> --hand-off"` を `run_in_background`（`< /dev/null`）で起動
- [ ] verify: 1 issue が headless worker で near-green→`merge-ready` まで無人到達（stdout json の `is_error:false` ＋ ラベル確認、AT-318-B1）
- [ ] 並列度 K のパラメータ化と slot 管理（空き slot にキューから割当）
- [ ] verify: K=2 でキュー2 issue が同時進行し、互いの worktree/branch を破壊しない（lease 排他、AT-318-B2 / F2）
- [ ] worker 完了監視（完了通知＋stdout json）→ slot 解放 → キューから次を取得（数珠つなぎ）
- [ ] verify: キュー3 issue・K=2 で人間の再起動なしに全消化（AT-318-B3 / F3）
- [ ] worker 結果のログ回収（3層: stdout json / transcript / 入れ子 Workflow agent jsonl）を監査ログに集約
- [ ] verify: 各 worker の `session_id`・`total_cost_usd`・terminal_reason が dispatcher 側ログに残る

## Testing

- [ ] epic 統合 E2E：キュー2 issue・K=2 で `dispatch → 並列 hand-off worker → 各 merge-ready → coordinator 逐次 merge → 次の取得` まで無人で1周
- [ ] verify: 2 issue が main に直列 merge され、post-merge regression green、人間関与は壁打ち（キュー投入）のみ（AT-318-E1）
- [ ] 各実装単位 (a)〜(d) が Unit（bats フック / skill）+ 必要箇所 E2E を持つ（#316 の skill テスト規律踏襲）
- [ ] verify: `reviewing-deliverables`（Step 5 / R1-R6）が #318 全体で PASS

## Finishing
- [ ] CHANGELOG.md 更新（Keep a Changelog、feature PR ごと）
- [ ] verify: epic 完了時に full-autopilot の使い方が `docs/` に追記され、autopilot skill 本文との責務境界が整合
- [ ] ドキュメント整合性チェック（autopilot-iron-law / hooks/README / rules）
- [ ] verify: 通常 autopilot の不変条件（3 gate・merge しない）が全 doc で保持されている
