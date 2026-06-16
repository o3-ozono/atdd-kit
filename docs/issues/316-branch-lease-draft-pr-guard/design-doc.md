# Design Doc: branch-lease guard の lease store・TTL・無効化方針

本 Issue（#316）の Plan は、PRD の Open Questions が plan / design-doc に明示的に委ねた 3 つの設計判断に依存する。本ドキュメントはその決定と根拠・代替案・トレードオフを記録する。

## 決定 1: lease store は共有ストア `/tmp/claude-branch-leases/`（session-local ではない）

### 文脈

PRD「What §2」は lease 記録を `.claude/branch-lease.json`（**セッションローカル**・gitignore）と表現している。一方 PRD「Outcome §4」と User Stories「CS-1」は **共有 lease store**（クロスセッションで可視。`/tmp/claude-branch-leases/`、branch 名キー → {session_id, timestamp}）を要求している。同一 PRD 内で表現が割れているが、Outcome / CS-1 が上位（不変条件レベル）の要求である。

### 決定

**共有 lease store を採用する。** default パス `/tmp/claude-branch-leases/`、branch 名キーのファイルに `{session_id, timestamp}` を保存。`BRANCH_LEASE_DIR` env で上書き可能（テストはこの env で固定 default に依存しない）。

### 根拠

- 本機能の核は「**別セッションが**保有するブランチを各セッションが参照してブロックする」こと（FS-3 / FS-5 / CS-1）。session-local store では他セッションのリースが見えず、排他制御が成立しない。
- 既存 `sim-pool` も共有ディレクトリ（`/tmp/claude-sim-sessions` 系）方式でクロスセッション排他を実現済み。型を踏襲できる。

### 代替案とトレードオフ

- **session-local `.claude/branch-lease.json`（PRD What §2 の字面）**: クロスセッション可視性が無く CS-1 を満たせない。却下。
- **git config / リモート共有**: PRD Non-Goals が「複数マシン間のリモート共有は対象外」と明記。同一マシン上の並行セッションのみが対象なので、ローカル共有ディレクトリで十分。

## 決定 2: TTL のデフォルトと env override

### 文脈

PRD Open Questions: 「TTL のデフォルト値（sim-pool は local 2h / CI 40min）」を plan で詰める。不変条件: stale リースが他セッションを恒久ブロックしてはならない（CS-2）。

### 決定

**sim-pool と同値をデフォルトにする**: local 2h（7200s）/ CI 40min（2400s）。env override を sim-pool の `SIM_TTL_LOCAL` / `SIM_TTL_CI` 相当（例 `BRANCH_LEASE_TTL_LOCAL` / `BRANCH_LEASE_TTL_CI`）で用意。CI は `GITHUB_ACTIONS` 検出で CI 値に切替。アクセス時 orphan 掃除で TTL 超過リースを削除。

### 根拠

- 「正規の作業セッションの寿命」という意味的単位が sim-pool と同じ（1 セッションの作業時間）。別々の値にする積極的理由が無く、運用者が覚える定数を増やさない。
- アクセス時掃除（sim-pool の `cleanup_stale_clones` 型）により、デーモン無しで stale を必ず期限切れにできる（CS-2 の不変条件を満たす）。

### トレードオフ

- TTL を長くしすぎると stale リースが他セッションをブロックする時間が延びる。短くしすぎると正規セッションが作業途中でリースを失い得る。sim-pool の実績値（local 2h）は両者のバランス点として既に運用検証済み。

## 決定 3: PR merge / close 時のリース即時無効化はやらない（TTL に委ねる）

### 文脈

PRD Open Questions: 「PR が merge/close されたらリースを即時無効化するか否か」を委ねられている。

### 決定

**本 Issue では即時無効化を実装しない。** リースは TTL ＋アクセス時 orphan 掃除のみで期限切れにする。

### 根拠

- 不変条件「stale リースが他セッションを恒久ブロックしてはならない」は TTL で既に担保される。merge/close 即時無効化は追加の正確性ではなく「回復の速さ」の最適化にすぎない。
- 即時無効化には PR 状態変化を観測する追加経路（PostToolUse での `gh pr merge`/`close` 監視など）が要り、フックの責務とテスト面が膨らむ。最小実装の原則に反する。
- override エスケープハッチ（`ATDD_BRANCH_LEASE_FORCE=1`, FS-6）が、TTL 満了前に正当にリースを上書きしたいケースの逃げ道を提供する。

### トレードオフ

- merge 直後〜TTL 満了までの間、（自動取得した）リースが残るが、所有者は同一セッションであり通常は自分で上書きするか override する。恒久ブロックは生じないため許容。将来必要なら別 Issue で即時無効化を追加できる（後方互換）。

## skill-gate との責務境界（PRD Open Questions より）

- **skill-gate**: Issue 単位の並行セッション衝突・`in-progress` ラベル管理（プロセス層・ガイドライン）。
- **branch-lease guard（本 Issue）**: ブランチ単位の破壊的リモート操作（write-back）をツール層で hard block（強制）。
- 両者は層が異なり重複しない。branch-lease guard は `in-progress` ラベルを読み書きしない（session-start / skill-gate の責務を侵さない）。判定は「open Draft PR の存在 ＋ 共有 lease store」のみに基づく。
