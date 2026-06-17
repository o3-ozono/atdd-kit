# User Stories: Draft PR 作成時に in-progress 付与 ＋ full-autopilot dispatch の GitHub-state プリフィルタ

## Functional Story

<!-- 機能要求を persona 抜き Connextra 形式で記述する。1 ストーリー = 1 ユーザーゴール。 -->

### F1: Draft PR 作成時の in-progress 自動付与（What ①）

**I want to** Draft PR が作られた時点で、PR body の `Closes #<N>` または branch 名プレフィックス `<N>-...` から解決したリンク Issue へ PostToolUse hook が `in-progress` ラベルを自動付与する,
**so that** discover を経ず fast-batch / autopilot で実装に進んだ経路でも、Draft PR が存在する Issue には必ず `in-progress` が付き、GitHub state が「着手済みか」の真実源として機能する.

### F2: full-autopilot dispatch の GitHub-state プリフィルタ（What ②）

**I want to** full-autopilot の dispatch 候補列挙が、open PR を持つ Issue / `in-progress` ラベルを持つ Issue を select 対象から冪等に除外する（GitHub 問い合わせは呼び出し側＝`full-autopilot-run.sh` か env 注入可能なフックとして実装し、`cmd_select` 自体は lease-store 合成の純粋ロジックのまま据え置く）,
**so that** 揮発 lease がクラッシュ復帰で消えても同一 Issue を二重 dispatch せず、無駄な headless worker 起動とトークン空費を防げる.

### F3: Draft PR 放棄（close/merge）時の in-progress 除去（What ③）

**I want to** Draft PR が merge されず close された時点（`gh pr close`）に、付与と同じ Issue 番号解決ロジックを共有する同一 hook 機構がリンク Issue から `in-progress` を除去する（merge 経路も対称性のため冪等に除去してよく、既に label が無い場合は no-op）,
**so that** 放棄された Issue からラベルが除去され、付与と除去の対称ライフサイクルでラベルが実態に追従する.

## Constraint Story (Non-Functional)

<!-- 非機能要求（NFR）を Story 形式で表現する（Pichler 2013）。 -->

### C1: cmd_select の純粋性維持（既存 env 注入パターン踏襲）

**I want to** dispatch プリフィルタの追加が `cmd_select` の純粋性を壊さず、GitHub 問い合わせを呼び出し側または env 注入可能なフックに隔離する（既存の env 注入パターンを踏襲する）,
**so that** `cmd_select` が副作用なくテスト可能なまま保たれ、プリフィルタ部分も注入で差し替えてテストできる.

### C2: 冪等で対称なライフサイクル（クラッシュ復帰耐性）

**I want to** 付与・除去・dispatch 除外のいずれも冪等（二重付与・既消去 label の再除去・再 dispatch 試行が害なく no-op になる）で、揮発 lease の crash-recovery を跨いでも GitHub state が真実源として一貫する,
**so that** dispatcher のクラッシュや経路の重複を跨いでも二重 dispatch せず、ラベル状態が壊れない.

### C3: hook アーキテクチャ準拠（skill 非編集）

**I want to** 付与・除去メカニズムが既存 hook 群（#316 branch-lease-guard 等）と同じ PostToolUse hook アーキテクチャで実装され、skill 群は未編集のまま skill-gate を概念上の owner に保つ,
**so that** ラベル管理の責務境界（skill-gate がラベルの owner）を崩さず、既存 hook 流儀との一貫性が保たれる.
