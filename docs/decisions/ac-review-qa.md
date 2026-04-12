# AC Review: QA Perspective

Issue #21: fix: sim-pool-guard.sh の allowlist を現行 XcodeBuildMCP / ios-simulator ツール名に同期する

Design Decision: fail-closed から fail-open へ再設計。CLONE_REQUIRED（sim 操作ツール）と DENY（ゴールデンイメージ破壊リスク）のみ明示列挙。それ以外は即時 ALLOW。

## Overall Testability Assessment

**高い。** 既存の BATS テストスイート（10 ファイル、70+ テスト）が成熟しており、mock xcrun / run_guard ヘルパー / jq アサーションの確立済みパターンで全 AC をテスト可能。fail-open への転換は根本的な変更だが、テスト観点では「判定分岐の反転」であり、既存テストの大半は書き直しが必要になるものの、テストパターン自体は再利用できる。

## Per-AC Feedback

### AC1: Fail-open default — unlisted tools get immediate ALLOW

**Testability:** 高。`run_guard` に未登録ツール名を渡して `permissionDecision == "allow"` を検証するだけ。

**Feedback:**

1. **Given 節の例示ツールが不十分** — `mcp__XcodeBuildMCP__build_device` と `mcp__XcodeBuildMCP__swift_package_test` の 2 つだけでは、境界パターンを見逃す。以下のカテゴリもテストに含めるべき:
   - `mcp__XcodeBuildMCP__list_schemes`（現行 READONLY — fail-open では READONLY_TOOLS 配列自体が廃止されるので、このツールも「未登録」扱いで ALLOW になるのか？）
   - `mcp__xcode__*`（addon.yml に xcode MCP もあるが、matcher が `mcp__XcodeBuildMCP__.*` と `mcp__ios-simulator__.*` のみ。xcode MCP は guard に到達するのか？）
   - `mcp__apple-docs__*`（同上）

2. **READONLY_TOOLS 配列の扱いが不明確** — AC5 で `READONLY_TOOLS removal` と書かれているが、AC1 の Given 節は「CLONE_REQUIRED_TOOLS にも DENY_TOOLS にもない」としか言っていない。現行の READONLY_TOOLS に含まれる 14 ツールが fail-open 後にどうルーティングされるかを AC1 の Then で明示すべき。

3. **Recommendation:** Given を以下に修正:
   > Given: CLONE_REQUIRED_TOOLS にも DENY_TOOLS にも含まれないツール名（例: `mcp__XcodeBuildMCP__build_device`, `mcp__XcodeBuildMCP__list_schemes`, `mcp__ios-simulator__some_new_tool`）

### AC2: CLONE_REQUIRED — XcodeBuildMCP sim tools (37 tools)

**Testability:** 中。動作自体はテスト可能だが、「37 ツール」の正確性を検証するのが困難。

**Feedback:**

1. **37 ツールの列挙が必須** — AC2 はカテゴリ名と合計数（`*_sim` 12 ツール、UI interaction 9 ツール等）で記述されているが、実装者がどのツールを含めるべきか判断できない。テスト側も「37 ツールが CLONE_REQUIRED に含まれている」ことを検証するには、具体的な列挙が必要。
   - **Recommendation:** AC2 に付録として 37 ツールの全リストを添付するか、少なくとも各カテゴリの先頭 + 末尾ツールを明示する。

2. **XcodeBuildMCP の全ツール一覧はどこで取得するか？** — 現行スクリプトの CLONE_REQUIRED には XcodeBuildMCP ツールが `build`, `build_sim`, `build_run_sim`, `test`, `test_sim`, `run`, `session_set_defaults`, `session_use_defaults_profile` の 8 つしかない。37 に増やすということは 29 ツールの追加だが、XcodeBuildMCP の最新ツール一覧のソースが AC に記載されていない。
   - **Recommendation:** AC に「ツール一覧は `npx xcodebuildmcp@latest mcp --list-tools` から取得」等のソース情報を記載する。

3. **session_set_defaults ガイダンス DENY の挙動** — 現行ロジックでは CLONE_REQUIRED の XcodeBuildMCP ツールは初回呼び出し時に DENY + `session_set_defaults` 案内を返す。37 ツール全てがこの挙動になるのか？それとも一部ツール（debug 系など）は session_set_defaults 不要で即 ALLOW にすべきか？
   - Then 節に「session_set_defaults 実行前は DENY with guidance、実行後は ALLOW」を明示すべき。

4. **テスト戦略:** 37 ツール全ての動的テストは非現実的。推奨:
   - 静的検証: `CLONE_REQUIRED_TOOLS` 配列に 37 エントリが含まれることを `wc -l` で検証
   - 境界テスト: 各カテゴリから 1 ツールずつ選んで動的テスト（6-7 テスト）
   - 全列挙テスト: 配列内容をソートして期待値と比較する単一テスト

### AC3: CLONE_REQUIRED — ios-simulator tools (11 tools)

**Testability:** 高。現行テストがこのパターンを既にカバーしている。

**Feedback:**

1. **「all 11 except `get_booted_sim_id` and `stop_recording`」の問題** — 現行スクリプトでは `mcp__ios-simulator__get_booted_simulators`（`get_booted_sim_id` ではない）と `mcp__ios-simulator__stop_recording` が READONLY。ツール名が AC と現行コードで異なる。
   - `get_booted_sim_id` は `get_booted_simulators` の誤りか、それとも ios-simulator MCP が名称変更したのか？ fail-open 設計では READONLY_TOOLS が廃止されるので、この 2 ツールは「未登録 → 即 ALLOW」になるはず。AC3 で除外を明示するなら正確なツール名が必要。

2. **UDID injection の挙動が Then に含まれている — 良い。** ただし:
   - 既存の UDID がツール入力に含まれていた場合の挙動は？ 現行の `jq '. + {udid: $udid}'` は上書きする。意図的か？

3. **11 ツールの列挙も必要** — AC2 と同じ理由。

### AC4: DENY — erase_sims

**Testability:** 高。単一ツール名の DENY テストは最も単純なパターン。

**Feedback:**

1. **DENY メッセージの内容を Then に含めるべき** — 「golden image protection reason message」だけでは曖昧。具体的なメッセージ文字列の一部（例: `"Golden image"` または `"erase"` を含む）を指定すべき。

2. **erase_sims 以外の破壊的ツールは？** — XcodeBuildMCP に他に破壊的なツール（例: `delete_sim`, `reset_sim`）が存在しないか確認が必要。ios-simulator 側の `erase_simulator` は現行 CLONE_REQUIRED に含まれているが、fail-open 後も CLONE_REQUIRED に残るのか、それとも DENY にすべきか？
   - **Recommendation:** `erase_simulator`（ios-simulator 側）の分類を AC で明示する。現行コードでは CLONE_REQUIRED だが、クローン上での erase は安全なので CLONE_REQUIRED で正しいはず。AC4 の scope を「erase_sims のみが DENY」と明確にする。

3. **将来の DENY ツール追加** — fail-open 設計では DENY リストが安全弁。DENY_TOOLS 配列の拡張ガイドライン（どんな基準でツールを DENY に分類するか）をコメントまたはドキュメントに記載すべき。これは AC の scope 外だが、レビューコメントとして記録する。

### AC5: READONLY_TOOLS removal and set -u safety

**Testability:** 高。`set -u` でのエラーは guard 実行時に即座に検出される。

**Feedback:**

1. **READONLY_TOOLS 配列の参照箇所の洗い出しが必要** — 現行コードでは:
   - L34-49: `READONLY_TOOLS` 配列定義
   - L388: `in_array "$tool_name" "${READONLY_TOOLS[@]}"` — `set -u` 下で配列が未定義なら `unbound variable` エラー
   - 既存テスト `test_sim_failclosed_guard.bats` AC3.15: `grep -q 'READONLY_TOOLS=' "$GUARD"` — 配列の存在を検証

2. **テスト方法:**
   - 全ツール名（CLONE_REQUIRED、DENY、未登録）で guard を実行し、exit code が 0 であること（`set -u` エラーなし）
   - 既存テスト AC3.15 は READONLY_TOOLS 存在を前提にしているので、削除後に FAIL する — AC7 で対応必要

3. **PERSIST_CHECK_TOOLS の扱い** — READONLY_TOOLS は削除するが、PERSIST_CHECK_TOOLS は残すのか？ AC5 では READONLY_TOOLS のみ言及。PERSIST_CHECK_TOOLS は fail-open 後も必要（persist:true ブロック）なので残すべき。AC5 の scope を「READONLY_TOOLS のみ削除」と明示すべき。

4. **Recommendation:** Then 節を以下に修正:
   > Then: READONLY_TOOLS 配列への参照がスクリプト内に存在せず、`set -u` アクティブ下で全ルーティングパス（CLONE_REQUIRED、DENY、未登録ツール）が `unbound variable` エラーなく動作する

### AC6: persist:true block maintained

**Testability:** 高。既存 `test_sim_persist_block.bats` がそのままカバー。

**Feedback:**

1. **既存テストで十分** — `test_sim_persist_block.bats` の 10 テスト（AC4.1-AC4.10）は persist:true のブロックを包括的に検証している。fail-open への変更で persist チェックのロジック位置が変わる可能性があるが、テスト自体は「入力 → 出力」検証なので変更不要のはず。

2. **persist チェックの実行順序** — 現行コードでは persist チェック（L394-396）が CLONE_REQUIRED ルーティング（L399-409）の前に実行される。fail-open 後もこの順序を維持するか？ CLONE_REQUIRED 内で persist チェックが先に走る現行ロジックは正しい。

3. **Recommendation:** AC としては十分。追加テスト不要。

### AC7: Existing BATS tests updated for fail-open

**Testability:** 高（AC 自体の検証は `bats addons/ios/tests/` の全パスで判定）。

**Feedback:**

1. **壊れるテストの特定が不十分** — AC7 は「全テスト PASS」としか言っていないが、どのテストが壊れるか事前に特定しておくべき。以下が影響を受ける:

   | テストファイル | 影響テスト | 理由 |
   |--------------|----------|------|
   | `test_sim_failclosed_guard.bats` | AC3.9, AC3.10, AC3.11 | 「未知ツール → DENY」が「未知ツール → ALLOW」に反転 |
   | `test_sim_failclosed_guard.bats` | AC3.15 | `READONLY_TOOLS=` の存在チェック — 配列削除で FAIL |
   | `test_sim_failclosed_guard.bats` | AC3.4-AC3.8 | READONLY ツールの ALLOW テスト — fail-open では同じ結果だが、テスト名/コメントが「readonly」を参照しており、意味が変わる |
   | `test_sim_clone_required_variants.bats` | AC2.1-AC2.3 | READONLY_TOOLS の存在チェック — 配列削除で FAIL |

2. **テスト名・コメントの更新** — `test_sim_failclosed_guard.bats` のファイル名自体が `failclosed` を含んでいる。fail-open への変更後はファイル名も `test_sim_failopen_guard.bats` に変更すべきか、既存テストを再構成すべきか、方針が必要。

3. **AC7 は「検証基準」であって「受入条件」ではない** — AC7 は「テストが全パスする」という検証手段を述べているが、受入条件としては「fail-open ルーティングのテストが存在し、全パスする」とすべき。

4. **Recommendation:** AC7 を以下に分割:
   - AC7a: fail-closed テスト（AC3.9-AC3.11）が fail-open テスト（未知ツール → ALLOW）に書き換えられている
   - AC7b: READONLY_TOOLS 参照テスト（AC3.15, AC2.1-AC2.3）が削除または更新されている
   - AC7c: `bats addons/ios/tests/` が全テスト PASS

## Coverage Gaps (Missing ACs)

### Gap 1: addon.yml matcher scope と guard の対応

**Priority: 高**

addon.yml の hooks matcher は `mcp__XcodeBuildMCP__.*` と `mcp__ios-simulator__.*` の 2 パターン。しかし addon.yml には `xcode` と `apple-docs` の MCP サーバーも定義されている。これらのツール呼び出しは guard に到達しないので問題ないが、AC で「guard が受け取るツール名の範囲」を明示すべき。

fail-open 設計では guard に到達した全ツールが ALLOW/CLONE_REQUIRED/DENY のいずれかに分類されるため、matcher の scope が安全境界になる。

**Recommendation:** addon.yml の matcher が変更されないことを前提条件として AC に記載する。

### Gap 2: 空 session_id の挙動

**Priority: 中**

現行コード（L382-385）では空 session_id で即 ALLOW（パススルー）。fail-open 後もこの挙動を維持するか？ 空 session_id でパススルーする場合、DENY ツール（erase_sims）もパススルーされてしまう。

**Current behavior:** `session_id == ""` → 即 ALLOW（DENY チェックをスキップ）

**Recommendation:** AC を追加:
> AC-new: 空 session_id の場合、DENY_TOOLS チェックは実行され、DENY 対象ツールは session_id の有無にかかわらず DENY される

または現行動作を維持するなら、その理由を AC のコメントに記載する。

### Gap 3: clone 作成失敗時の fail-open 挙動

**Priority: 中**

現行コードでは clone 作成失敗時に DENY（L235-237, L241-243）。fail-open 設計思想と矛盾しないか？ clone が必要なツールで clone が作れない場合、ALLOW してしまうとシミュレータなしで実行されてしまう。DENY が正しいが、AC で明示すべき。

**Recommendation:** AC2/AC3 の Then に以下を追加:
> clone 作成失敗時は DENY with reason message

### Gap 4: CLONE_REQUIRED + DENY の重複チェック

**Priority: 低**

同一ツールが CLONE_REQUIRED と DENY の両方に含まれた場合の動作は？ 現行コードの評価順序（CLONE_REQUIRED → DENY ではなく、READONLY → persist → CLONE_REQUIRED → DENY/unknown）では、CLONE_REQUIRED が先にマッチする。fail-open 後は CLONE_REQUIRED → DENY → default ALLOW になるが、重複時の優先順位を AC で明示すべき。

### Gap 5: DENY_TOOLS の将来拡張性

**Priority: 低**

AC4 は `erase_sims` のみを DENY にしているが、DENY_TOOLS を配列として定義するのか、case 文のハードコードにするのか、実装方針が AC に含まれていない。配列定義であれば AC2/AC3 と同じパターンで静的テスト可能。

## 37-Tool CLONE_REQUIRED List Assessment

AC2 は「37 ツール」と述べているが列挙がない。これは QA にとって以下の理由で問題:

1. **テスト作成不能** — 37 ツール全てが CLONE_REQUIRED に含まれることを検証するテストが書けない
2. **実装者の裁量範囲が広すぎる** — どのツールを含めるか実装者が判断する余地があると、AC の「37」という数字自体が検証不能
3. **XcodeBuildMCP のバージョン依存** — `xcodebuildmcp@latest` はバージョンアップでツールが増減する。AC が特定バージョンのツール一覧に基づいているなら、そのバージョンを明記すべき

**Recommendation:**
- AC2 にツール全リストを付録として添付する（37 ツール列挙）
- テストでは `CLONE_REQUIRED_TOOLS` の XcodeBuildMCP エントリ数を `== 37` でアサートし、加えて各カテゴリの代表ツールを名前で検証する
- XcodeBuildMCP のバージョン（または取得日）を AC に記載する

## Regression Risk Assessment

| 既存テストファイル | テスト数 | 影響度 | 必要なアクション |
|------------------|---------|-------|---------------|
| `test_sim_failclosed_guard.bats` | 17 | **高** | AC3.9-AC3.11（unknown → DENY）を反転、AC3.15（READONLY 存在チェック）削除、AC3.4-AC3.8 のコメント更新 |
| `test_sim_clone_required_variants.bats` | 12 | **中** | AC2.1-AC2.3（READONLY 非含有チェック）削除。AC1.1-AC1.3, AC3.1-AC4.3 は変更なし |
| `test_sim_auto_inject.bats` | 6 | **低** | CLONE_REQUIRED ルーティング変更なければ影響なし |
| `test_sim_ephemeral_clone.bats` | 7 | **低** | clone ライフサイクル変更なければ影響なし |
| `test_sim_golden_init.bats` | 7 | **低** | golden init ロジック変更なければ影響なし |
| `test_sim_golden_set_fallback.bats` | 13 | **低** | Device Set ロジック変更なければ影響なし |
| `test_sim_init_guidance.bats` | — | **要確認** | ファイル内容の読み取りが必要 |
| `test_sim_orphan_cleanup.bats` | 9 | **低** | cleanup ロジック変更なければ影響なし |
| `test_sim_persist_block.bats` | 10 | **低** | persist チェック維持であれば影響なし |
| `test_sim_pool_docs.bats` | 4 | **低** | ドキュメント参照テスト。SKILL.md 更新時のみ影響 |

## Summary

| AC | Testability | Verdict | Key Issues |
|----|------------|---------|------------|
| AC1 | 高 | **Needs refinement** | READONLY_TOOLS 廃止後の旧 READONLY ツールの扱いを明示すべき。例示ツールを増やすべき |
| AC2 | 中 | **Needs refinement** | 37 ツールの列挙が必須。session_set_defaults ガイダンス DENY の挙動を Then に明示すべき |
| AC3 | 高 | **Needs refinement** | `get_booted_sim_id` → `get_booted_simulators` のツール名不整合。11 ツールの列挙が必要 |
| AC4 | 高 | **Pass with minor** | DENY メッセージ内容を具体化。erase_simulator（ios-simulator 側）の扱いを明示 |
| AC5 | 高 | **Pass with minor** | PERSIST_CHECK_TOOLS は維持されることを明示。影響テストの特定が必要 |
| AC6 | 高 | **Pass** | 既存テストで十分にカバー |
| AC7 | 高 | **Needs refinement** | 壊れるテストの事前特定と、AC7a/7b/7c への分割を推奨 |

**Critical additions needed:**
1. 空 session_id + DENY ツールの挙動を定義する AC（Gap 2）
2. clone 作成失敗時の挙動を AC2/AC3 に明示（Gap 3）
3. AC2 の 37 ツール全リスト添付
4. AC3 のツール名不整合の修正（`get_booted_sim_id` vs `get_booted_simulators`）
