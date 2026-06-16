# User Stories: session-start の Draft PR 接触を二層でブロック（branch-lease guard ＋ 推奨の非 Draft 限定）

## Functional Story

<!-- 機能要求を persona 抜き Connextra 形式で記述する。1 ストーリー = 1 ユーザーゴール。 -->

### FS-1: session-start が Draft PR を rebase 推奨・actionable task 化しない（Layer 1）

**I want to** session-start の Recommended Tasks が Draft PR ブランチを rebase 推奨や actionable task の対象にせず、read-only の「🔒 別セッション作業中」としてのみ表示する,
**so that** 別セッションが作業中の Draft PR ブランチに対して `git checkout` / `git rebase` / `git push --force-with-lease` を提案されず、force-push 衝突の起点を踏まないで済む.

### FS-2: CONFLICTING rebase 推奨を ready かつ @me の PR に限定する（Layer 1）

**I want to** session-start Step 2.1 の `mergeable == CONFLICTING` に対する rebase 推奨を、**ready（非 Draft）かつ `@me`** の PR にのみ適用する,
**so that** rebase が安全に自セッション所有の非 Draft PR だけで提案され、EXCLUDE_SET を素通りして他セッションの Draft PR を巻き込むことがない.

### FS-3: write-back 操作を branch-lease guard フックでインターセプトし hard block する（Layer 2）

**I want to** 新設 PreToolUse（Bash matcher）フックが git/gh の write-back 操作（`git push` / `git push --force*` / `gh pr edit` / `gh pr merge` / `gh pr ready` 等リモート影響操作）をパースし、対象ブランチに open Draft PR があり、かつ自セッションがリースを保有していない場合に `permissionDecision: "deny"` JSON（exit 0 ＋ deny JSON。本リポジトリの PreToolUse deny 機構は exit 0 で表現し、exit 非ゼロは hook 実行エラー扱いになる）で hard block する,
**so that** ガイドライン頼りで漏れていた他セッション Draft PR への破壊的操作が、ツール層で確実に止められる.

### FS-4: 非 write-back 操作と main ブランチは通過させる（Layer 2）

**I want to** `git checkout` / `git switch` / ローカル `git rebase` 等の非 write-back 操作と、main ブランチへの操作を branch-lease guard が一切ブロックしない,
**so that** リモートに影響しない通常作業や main 上の作業が誤って妨げられず、ガードの対象が破壊的なリモート操作だけに絞られる.

### FS-5: push 時にリースを自動取得する（Layer 2）

**I want to** フックが非 main ブランチへの `git push` 時にリース未取得なら自セッション名義でリースを自動取得し、別セッションの fresh リースが存在する場合はブロックする,
**so that** スキル改修なしに hook 自己完結でリースが運用され、自セッションの正当な push は通り、他セッションの作業中ブランチは保護される.

### FS-6: 意図的上書きの override エスケープハッチを提供する（Layer 2）

**I want to** 安全と判断したときに `ATDD_BRANCH_LEASE_FORCE=1` で hard block を意図的に上書きできる,
**so that** hard block であっても袋小路を作らず、運用者が責任を持って例外操作を実行できる.

## Constraint Story (Non-Functional)

<!-- 非機能要求（NFR）を Story 形式で表現する（Pichler 2013）。 -->

### CS-1: 共有 lease store がクロスセッションで可視である

**I want to** リースが共有の lease store（例 `/tmp/claude-branch-leases/`、branch 名キー → {session_id, timestamp}）に置かれ、同一マシン上の並行セッションから可視である,
**so that** 別セッションが保有するリースを各セッションが参照でき、ブランチ単位の排他制御が成立する.

### CS-2: stale リースが TTL ＋ orphan 掃除で必ず期限切れになる

**I want to** リースが sim-pool と同様に TTL ＋アクセス時 orphan 掃除（`SIM_TTL_LOCAL` 相当の env override を備える）で stale 化したものは期限切れになる,
**so that** stale リースが他セッションを恒久的にブロックすることがなく、放置されたリースが袋小路を生まない.

### CS-3: フック単体テストと E2E で挙動が pin される

**I want to** branch-lease guard の挙動（リース取得／別セッションブロック／override／TTL stale／非 write-back 通過／main 通過）がフック単体テスト ＋ E2E で、Layer 1 の挙動が session-start task-recommendation BATS スイートで pin され、`hooks/README.md` が追従している,
**so that** sim-pool と同等の回帰保護が掛かり、二層ガードの退行が検出可能な状態で維持される.
