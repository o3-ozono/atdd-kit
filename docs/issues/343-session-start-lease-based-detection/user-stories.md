# User Stories: session-start の「別セッション作業中」検出を branch-lease store ベースにする

## Functional Story

<!-- PRD ## What / ## Outcome から導出。1 ストーリー = 1 ユーザーゴール。 -->

### Story 1: branch-lease store ベースの「別セッション作業中」検出

**I want to** session-start が、別セッションが fresh な branch-lease を保持している open PR を、Draft / 非 Draft を問わず branch-lease store（`/tmp/claude-branch-leases/<branch>.json` の fresh lease）を参照して検出できる,
**so that** 非 Draft 化（レビュー依頼済み）のまま反復中の PR が Draft 状態依存の検出をすり抜けて誤推薦される事故を防げる.

受け入れ基準（PRD の open question に対して中立）:
- 「別セッションが対象 branch の fresh lease を保持している」open PR が、Draft 状態や `in-progress` ラベルの有無に関係なく「別セッション作業中」として検出される。
- 検出根拠は branch-lease store の fresh lease であり、Draft 状態には依存しない。
- 「別セッション」の同定方式（PRD Open Questions の 案A: その時点の fresh lease をすべて別セッション扱い / 案B: 自セッション ID と突合）の選択に依存せず、別セッションが lease を保持している PR が検出される、という外形的振る舞いが成立する。

### Story 2: 別セッション作業中 PR の read-only 表示と推薦除外

**I want to** 別セッションが fresh lease を保持している open PR を `🔒 別セッション作業中` として read-only 表示し、マージ・rebase・force-push を推薦せず Recommended Tasks から除外できる,
**so that** 他セッションが所有する PR への破壊的操作（1 PR = 1 セッション所有規律の違反）を構造的に止められる.

受け入れ基準:
- 別セッションが fresh lease を保持している open PR は read-only 表示のみで、マージ / rebase / force-push のいずれも推薦されない。
- 当該 PR は Recommended Tasks から除外される。
- 非 Draft・green・mergeable であっても、上記が成立する（「非 Draft = ready = 推薦」「green = マージしよう」のデフォルトを上書きする）。

### Story 3: Step 2.1 CONFLICTING rebase 推奨への lease 未保持前提条件

**I want to** session-start の Step 2.1（CONFLICTING な PR への rebase 推奨）が、対象ブランチを別セッションが fresh lease で保持していないことを前提条件として満たすときのみ rebase を推奨できる,
**so that** 他セッションが作業中の CONFLICTING ブランチに対する rebase 推奨という横取りを防げる.

受け入れ基準:
- 対象ブランチを別セッションが fresh lease で保持している場合、Step 2.1 は rebase を推奨しない（read-only 表示に従う）。
- lease 未保持の CONFLICTING PR に対しては従来どおり rebase が推奨される。

## Constraint Story (Non-Functional)

<!-- PRD ## Outcome / ## What / ## Non-Goals から導出した NFR を Story 形式で表現（Pichler 2013）。 -->

### Story 4: freshness 判定ロジックの二重定義禁止（保守性・一貫性）

**I want to** branch-lease の freshness 判定が `hooks/branch-lease-guard.sh` の既存 TTL ロジック（`BRANCH_LEASE_TTL_LOCAL` 既定 7200s）を再利用し、session-start 側で TTL を二重定義しない状態,
**so that** TTL の定義が一箇所に保たれ、片側だけ変更されて検出と書き込みが食い違う回帰を防げる.

### Story 5: 既存 store 本体の挙動非変更（回帰リスク最小化）

**I want to** `hooks/branch-lease-guard.sh` / `lib/lease-store.sh` 本体の書き込み・TTL・排他ロジックを変更せず、既存の branch-lease store を読むだけで検出が成立する状態,
**so that** lease 書き込み系統や full-autopilot（pool=issue/merge）側の運用に副作用を出さず、変更点を最小化して回帰リスクを抑えられる.

### Story 6: lease store 空/未稼働時の fail-safe（信頼性）

**I want to** branch-lease store が空または未稼働の環境でも、新たなフォールバック機構を増やさずに従来どおり動作し、かつ Outcome の read-only 既定を維持する状態,
**so that** lease 情報が無い環境でも session-start が壊れず、保守すべき分岐が増えない.

### Story 7: 回帰の exit-code ベース担保（回帰防止）

**I want to** 「非 Draft・green・mergeable だが別セッションが lease を保持中の PR を推薦しない」ことを回帰 AT（`tests/acceptance/AT-343.*`）が exit-code ベースで担保している状態,
**so that** 同種の誤推薦事故が将来再発した場合に CI で機械的に検知できる.
