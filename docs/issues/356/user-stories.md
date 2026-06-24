# User Stories: pre-merge フェイルセーフゲートの契約再定義（--all 再帰化＋影響選択 e2e 配線）

## Functional Story

### FS1: `--all` の acceptance/ 再帰化（false-green を塞ぐ）

**I want to** `run-tests.sh --all` が `tests/acceptance/*.bats` を再帰収集して実行し、決定的に落ちる AT を FAIL として集約し非 0 を返す,
**so that** 必須 pre-merge ゲートが false-green を返さず、赤を見落としたままマージできない真のフェイルセーフになる.

### FS2: 影響選択 e2e の merge gate 配線

**I want to** merge gate が変更の影響を受ける skill の e2e のみを `run-skill-e2e.sh --changed-files <main 比 diff>` で実行する,
**so that** e2e による回帰検出を merge gate に組み込みつつ、無関係な e2e の無駄な `claude -p` 起動とコストを避けられる.

## Constraint Story (Non-Functional)

### CS1: `--all` と `--impact` の判定一致

**I want to** 同一リポジトリ状態で `--all`（必須側）と `--impact`（FALLBACK 時）の BATS 判定が一致している,
**so that** ゲート間で結果が食い違わず、どちらを使っても同じ防壁強度になる.

### CS2: e2e は影響選択に限定（コスト制約）

**I want to** e2e の実行が影響選択（impact mapping）に限定され、全件実行が merge gate に課されない,
**so that** フェイルセーフ強化とコスト/実行時間のバランスが保たれる.

### CS3: 文書と実装の整合

**I want to** 新しい契約に合わせて `AT-210f`（#324 acceptance-tests.md）・merging-and-deploying L72・`docs/methodology/test-execution-policy.md`・`collect_all_bats` のコードコメントが改訂されている,
**so that** 文書と実装の乖離（「e2e を含む」と書きながら未配線、「acceptance/ 除外」を承認）が解消され、後続の監査が成立する.

### CS4: 既存ロジック再利用・CI 不変（影響範囲最小化）

**I want to** `run-skill-e2e.sh` / `impact_map.sh` の影響マッピングロジックと CI（pr.yml）を変更せず、既存ロジックを再利用するだけに留める,
**so that** 変更の影響範囲が最小化され、既に acceptance/ を再帰カバーしている CI には手を入れない.
