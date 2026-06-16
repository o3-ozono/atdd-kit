# Acceptance Tests: session-start の Draft PR 接触を二層でブロック（branch-lease guard ＋ 推奨の非 Draft 限定）

<!-- AT lifecycle: planned → draft → green → regression
     各エントリには状態マーカー [green] / [draft] / [green] / [regression] を付与する。
     状態は実装の進行に合わせて更新する。
     注意: [regression] AT は将来のブランチで永続実行されるため、point-in-time 値
     （現在の plugin version / 今日の日付 / 行数）を exact-pin しない。不変条件を assert する。 -->

## AT-001: Draft PR を rebase 推奨・actionable task 化しない（FS-1 / Layer 1）

- [ ] [green] AT-001: session-start SKILL.md が Draft PR を read-only 表示に限定する
  - Given: session-start SKILL.md の Recommended Tasks / Step 2 セクション
  - When: 当該本文を検査する（BATS による文字列 pin）
  - Then: Draft PR が actionable task ではなく `🔒 別セッション作業中` の read-only 表示として扱われる旨が記載され、Draft ブランチへの `git checkout` / `git rebase` / `git push --force-with-lease` を提案しない旨が明記されている（不変条件: 文字列の存在を assert、行番号は pin しない）

## AT-002: CONFLICTING rebase 推奨を ready かつ @me に限定する（FS-2 / Layer 1）

- [ ] [green] AT-002: CONFLICTING rebase 推奨が非 Draft ＋ @me 限定として記述される
  - Given: session-start SKILL.md Step 2 の「Highest priority: `mergeable == CONFLICTING` → rebase」ルール
  - When: 当該ルール本文を検査する（BATS pin）
  - Then: rebase 推奨が「ready（非 Draft）かつ `@me`」の PR にのみ適用されると明記され、既存 #187（exclusion / type priority）と #302（route column / Step 3）の pin が引き続き green である

## AT-003: write-back 操作を hard block する（FS-3 / Layer 2）

- [ ] [green] AT-003: 別セッション保有 Draft ブランチへの write-back が deny される
  - Given: 共有 lease store に別 session_id 名義の fresh リースを持つブランチ B があり、B に open Draft PR が存在する（モック gh）
  - When: branch-lease-guard.sh に対し、B を対象とする `git push` / `gh pr edit` / `gh pr merge` / `gh pr ready` のいずれかを tool_input として流す
  - Then: フックが `permissionDecision: "deny"` JSON を返し非ゼロ相当で hard block し、deny 理由に別セッションが作業中である旨を含む

## AT-004: 非 write-back 操作と main を通過させる（FS-4 / Layer 2）

- [ ] [green] AT-004: checkout / switch / ローカル rebase / main 操作はブロックされない
  - Given: branch-lease-guard.sh と、別セッションが Draft ブランチ B を保有する lease store
  - When: (a) B に対する `git checkout` / `git switch` / `git rebase`（push 無し）、(b) main / master ブランチへの `git push` を流す
  - Then: いずれも allow（PreToolUse allow JSON, exit 0）になり、ガードは破壊的リモート操作（write-back）以外と main を一切ブロックしない

## AT-005: push 時にリースを自動取得する（FS-5 / Layer 2）

- [ ] [green] AT-005: 非 main ブランチ push でリース未取得なら自セッション名義で取得する
  - Given: 自セッション（session_id S）がリース未取得の非 main ブランチ F
  - When: F への `git push` を S として流す（F に別セッションの fresh リースは無い）
  - Then: allow され、lease store に branch=F・session_id=S・timestamp を持つ lease が生成される。別セッションの fresh リースが既にある場合は同じ push が deny される

## AT-006: override エスケープハッチを提供する（FS-6 / Layer 2）

- [ ] [green] AT-006: ATDD_BRANCH_LEASE_FORCE=1 で hard block を上書きできる
  - Given: AT-003 と同じ deny 条件（別セッション保有 Draft ブランチへの write-back）
  - When: `ATDD_BRANCH_LEASE_FORCE=1` を設定して同操作を流す
  - Then: hard block が上書きされ allow になる（袋小路を作らない）

## AT-007: 共有 lease store がクロスセッションで可視である（CS-1）

- [ ] [green] AT-007: lease が共有 store に branch キーで保存されクロスセッション参照できる
  - Given: `BRANCH_LEASE_DIR`（default `/tmp/claude-branch-leases/`）に session A が取得した branch B のリース
  - When: 異なる session_id C の呼び出しから同 lease store を参照する
  - Then: C が B のリース（session_id=A, timestamp）を読み取れる。リースは branch 名キー → {session_id, timestamp} 構造である（不変条件: store パスは env で上書き可能・テストは固定 default に依存しない）

## AT-008: stale リースが TTL ＋ orphan 掃除で期限切れになる（CS-2）

- [ ] [green] AT-008: TTL 超過リースはアクセス時に掃除されブロックを生まない
  - Given: `BRANCH_LEASE_TTL_LOCAL` を小さく設定し、timestamp が TTL を超過した別セッション名義のリースが branch B に存在する
  - When: B を対象とする write-back 操作をフックに流す
  - Then: stale リースがアクセス時 orphan 掃除で削除され、その操作は別セッションリースを理由にブロックされない（不変条件: TTL は env override で制御・テストは固定秒数に依存しない）

## AT-009: 単体テストと E2E と Layer 1 pin で挙動が固定される（CS-3）

- [ ] [green] AT-009: フック単体 ＋ E2E ＋ session-start BATS ＋ README が回帰保護を構成する
  - Given: 本 Issue の成果物（branch-lease-guard.sh、hooks.json 登録、テスト、hooks/README.md、tests/README.md）
  - When: 全テストスイートを実行する
  - Then: フック単体 BATS（lease 取得／別セッションブロック／override／TTL stale／非 write-back 通過／main 通過／fail-safe）と E2E が green、Layer 1 が session-start task-recommendation BATS で pin され、`hooks/README.md` が branch-lease-guard を反映し、かつ **`tests/README.md` が新規テストファイル（`test_branch_lease_guard.bats` と新規 E2E）の行を含む**（DEVELOPMENT.md L65 のディレクトリ README 不変条件。doc 同期漏れが回帰で検出される。不変条件: ファイル名文字列の存在を assert、行番号は pin しない）

## AT-010: バージョン整合が回帰として維持される（regression 不変条件）

- [ ] [green] AT-010: plugin.json の version が CHANGELOG 最上位 release 見出しと一致する
  - Given: `.claude-plugin/plugin.json` と `CHANGELOG.md`
  - When: バージョン整合チェックを実行する
  - Then: plugin.json の version が CHANGELOG の最上位 release 見出しと一致する（不変条件を assert。特定バージョン番号を exact-pin しない — #289 の教訓）

## ライフサイクル例

| 状態 | 意味 |
|------|------|
| [green] | テスト設計済み・未実装 |
| [draft] | 実装中・まだ通過していない |
| [green] | テスト通過済み |
| [regression] | リグレッション対象として継続監視中 |
