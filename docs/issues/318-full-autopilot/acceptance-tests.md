# Acceptance Tests: full-autopilot — キュー方式で複数 issue を並列・無人で merge まで回す

> Epic レベルの受け入れ基準。各 AT は対応する User Story を括弧で示す。executable な AT 化は各サブ Issue の Step 4（running-atdd-cycle）で行い、ここでは `[planned]` で設計のみ。
> **`[regression]` 不変条件は point-in-time 値を pin しない**（#289 教訓）— 「3 gate である」「merge しない」等の不変条件を assert する。

## AT-318-A: hand-off モード（サブ a）

- [x] [green] AT-318-A1: hand-off 起動は設計 gate でブロックせず merge-ready で手放す（F4） — `tests/acceptance/AT-318-A.bats`（doc-grade）
  - Given: PRD 承認済み（`ready-to-go`）の issue と `--hand-off` 指定
  - When: autopilot を headless で起動する
  - Then: 設計 gate で人間入力を待たず near-green まで収束し、Draft を外して `merge-ready` ラベルを付け、merge せずに exit する

- [x] [green] AT-318-A2: 通常起動の3 gate は不変（C3・regression 候補） — `tests/acceptance/AT-318-A.bats`。Iron Law §AL-1 / autopilot SKILL の invariant を pin
  - Given: `--hand-off` を**付けない**通常 autopilot 起動
  - When: フローを進める
  - Then: ①要件 ②設計 ③merge の3 User gate が従来どおり発火し、autopilot は merge しない（不変条件 assert・将来も維持）

## AT-318-D: lease 拡張（サブ d）

- [x] [green] AT-318-D1: issue-lease が同一 issue の二重 claim を防ぐ（C2） — `tests/acceptance/AT-318-D.bats` / unit `tests/test_lease_store.bats`
  - Given: issue #X を claim 済みのセッション A
  - When: セッション B が同じ #X を claim しようとする
  - Then: B はブロックされる（lease 保有者 A が表示）。A の lease は TTL stale で期限切れ可能

- [x] [green] AT-318-D2: merge-lease 容量1が同時 merge を直列化（C2） — `tests/acceptance/AT-318-D.bats` / unit `tests/test_lease_store.bats`
  - Given: `merge-ready` PR を merge しようとする2つの主体
  - When: 同時に merge-lease を取得しようとする
  - Then: 容量1で後発は待機/ブロック。override（FORCE 相当）で意図的上書きは可能

## AT-318-C: merge coordinator（サブ c）

- [x] [green] AT-318-C1: rebase 後フル再ゲートを通して merge する（F5） — `tests/acceptance/AT-318-C.bats` / unit `tests/test_merge_coordinator.bats`。順序 rebase→regate→merge→regression をモックで pin
  - Given: `merge-ready` な単体 green の PR、main は他 PR で前進済み
  - When: coordinator が drain する
  - Then: 最新 main へ rebase → フル再ゲート（AT＋verdict）→ merge → post-merge regression が順に通る

- [x] [green] AT-318-C2: 失敗は自動差し戻し、閾値 N で human エスカレーション（F6・F7） — `tests/acceptance/AT-318-C.bats` / unit `tests/test_merge_coordinator.bats`
  - Given: rebase 衝突 or 再ゲート fail を起こす PR
  - When: coordinator が drain する
  - Then: 新 autopilot イテレーションへ自動差し戻し。N 回失敗で初めて human にフラグ（Issue コメント）が立つ

- [ ] [planned] AT-318-C3: 並列生成 PR を統合しても main が壊れない（C1・broken-together 防止・regression 候補） — 構造的担保（再ゲートが必ず merge 前に走る順序）は AT-318-C1 で green。実 git の複数 PR 統合 E2E は epic 統合（AT-318-E1）で検証
  - Given: 単体 green な merge-ready PR が2本（互いに干渉し得る変更）
  - When: coordinator が逐次 drain する
  - Then: 各 PR が rebase＋再ゲートを経て統合され、merge 後の main で regression が green（不変条件: 単体 green の同時統合で main は壊れない）

## AT-318-B: dispatcher + issue-queue（サブ b）

- [ ] [planned] AT-318-B1: キューの issue を headless worker で merge-ready まで無人到達（F1） — dispatch/lease は AT-318-D / FAD で green。実 `claude -p --hand-off` worker のフル到達は live E2E で検証
  - Given: `ready-to-go` issue が1件キューにある
  - When: full-autopilot が dispatch する
  - Then: headless `claude -p ... --hand-off` worker が起動し、`is_error:false` で near-green→`merge-ready` に到達。人間入力は発生しない

- [x] [green] AT-318-B2: 並列度 K=2 で2 issue 同時進行・相互非破壊（F2・C2） — 排他保証は `tests/test_full_autopilot_dispatch.bats`(FAD-1/2) ＋ `tests/acceptance/AT-318-D.bats`(issue-lease) で green。実 headless 並列走行は live E2E
  - Given: `ready-to-go` issue が2件、K=2
  - When: full-autopilot が dispatch する
  - Then: 2 worker が別 worktree/branch で同時進行し、branch-lease / issue-lease により互いの作業を破壊しない

- [ ] [planned] AT-318-B3: slot が空けば再起動なしに次を消化（数珠つなぎ）（F3） — select ロジックは FAD で green。slot ループ＋完了監視のフル走行は live E2E
  - Given: `ready-to-go` issue が3件、K=2
  - When: full-autopilot を1回起動する
  - Then: 先行2件のいずれかが終わると人間の再起動なしに3件目が着手され、最終的に全件が `merge-ready`/merge に到達する

## AT-318-E: epic 統合（横断）

- [ ] [planned] AT-318-E1: 壁打ち以外無人で複数 issue が main に統合される（F1・F2・F3・F5） — 全 lib 単体 green。フル無人ループ（実 `claude -p` worker × coordinator）は live 実行で検証
  - Given: 人間がキューに2 issue を `ready-to-go` で投入（＝唯一の人間関与）、K=2
  - When: full-autopilot を起動する
  - Then: 並列 hand-off worker → 各 `merge-ready` → coordinator が逐次 rebase＋再ゲート＋merge → post-merge regression green。2 issue が main に直列統合され、起動後の人間入力はゼロ

- [x] [green] AT-318-E2: 暴走防止 — キュー外 issue に着手しない（C4・regression 候補） — `tests/acceptance/AT-318-E.bats`（doc-grade invariant）
  - Given: `ready-to-go` でない（PRD 未承認の）issue が backlog に存在
  - When: full-autopilot を起動する
  - Then: その issue には一切着手しない（消化対象は人間が固めた `ready-to-go` に限定。不変条件 assert）

## ライフサイクル例

| 状態 | 意味 |
|------|------|
| [planned] | テスト設計済み・未実装 |
| [draft] | 実装中・まだ通過していない |
| [green] | テスト通過済み |
| [regression] | リグレッション対象として継続監視中 |
