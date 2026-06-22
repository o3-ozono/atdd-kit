# User Stories: batch-discovery — 壁打ちを最前倒し一括化し ready-to-go 準備を並列バックグラウンド自走させる

## Functional Story

<!-- 機能要求を persona 抜き Connextra 形式で記述する。1 ストーリー = 1 ユーザーゴール。 -->

### FS-1: 独立スキル batch-discovery として準備フェーズを起動する

**I want to** 複数 Issue の ready-to-go 準備を、full-autopilot 本体を書き換えない独立スキル `batch-discovery` として起動できる,
**so that** 準備フェーズと消化フェーズ（full-autopilot）が疎結合に保たれ、最小の新規実装で複数 Issue 一括投入を運用できる.

### FS-2: 横断バッチ壁打ち（front-loaded・人間 1 回）

**I want to** 対象 Issue 群を全自律読み込みした上で、各 Issue から人間にしか決められない点（トレードオフ / 割り切り / スコープ取捨 / リスク許容度 / 合否基準）だけを抽出し、全 Issue 横断で 1 バッチにまとめて提示してもらい一度のセッションで全部答える,
**so that** 人間の壁打ち拘束時間が Issue 件数に比例せず front-loaded な定数回（理想は 1 回）に圧縮される.

### FS-3: Issue 本文・docs から導出可能な要件は自律ドラフトする

**I want to** Issue 本文や docs から導出可能な要件は人間に質問せず自律でドラフトされる,
**so that** 横断バッチ壁打ちで人間に提示される質問が「人間判断点のみ・最小」に絞られる（Dialog economy #254 を N Issue 分に拡張）.

### FS-4: 疑問が解消した Issue から並列に自走する

**I want to** 疑問が解消した Issue から順に worktree 隔離の headless worker を並列起動し、PRD→US→plan+AT→reviewing-deliverables PASS→Draft PR→`ready-to-go` まで自律で準備を進める,
**so that** 壁打ち解消後の ready-to-go 化が人間の関与なしにバックグラウンドで並列に完了し full-autopilot キューへ一貫して受け渡される.

### FS-5: full-autopilot 基盤の lib を準備フェーズへ転用する

**I want to** full-autopilot の dispatcher / lease-store / worktree 播種（#329）の lib を準備フェーズの並列 worker 起動に転用する,
**so that** 新規実装を最小化しつつ既存の隔離・排他制御基盤の信頼性をそのまま活用できる.

### FS-6: 実装順序の記録による軽量な順序制御

**I want to** 依存関係のある Issue 群（keystone→後続）について実装順序を共有真実源に記録し、worker をその順で進める,
**so that** フルな barrier / 動的依存解決を導入せずに依存順序を尊重した準備自走ができる.

### FS-7: 選別ピックアップ式の最終承認ゲート（人間・最大 1 回）

**I want to** 準備完了後、全成果物の一括承認ではなく、準備フェーズ（reviewer-oracle 含む）が検出した「ユーザーレビューで判断が覆りうる点（リスク / トレードオフ / 重要な割り切り）」だけを選別提示され、その点を承認してから `ready-to-go` が付与される,
**so that** 人間の最終承認も件数に依存しない最大 1 回に集約され、覆りうる点が無ければ最終承認自体をスキップできる.

## Constraint Story (Non-Functional)

<!-- 非機能要求（NFR）を Story 形式で表現する（Pichler 2013）。
     システムが満たすべき品質特性（性能・セキュリティ・信頼性等）を制約として記述する。 -->

### CS-1: 人間の対話回数が Issue 件数に依存せず定数回に圧縮される

**I want to** N 件投入しても人間の対話回数が Issue 件数に依存せず定数回（理想は front-loaded 壁打ち 1 回 ＋ 必要時のみ最終承認 1 回）に保たれている,
**so that** 複数 Issue 一括投入時の人間拘束時間が件数比例から定数へと外れ、本機能の主指標（合否基準）を満たす.

### CS-2: AL-1 三ゲート不変条件との整合が保たれ文書化される

**I want to** 準備フェーズの人間ゲートが「横断バッチ壁打ち 1 回（Gate ① 集約）＋ 選別最終承認 最大 1 回（Gate ② 相当を覆りうる点に絞って集約）」として AL-1（3 ゲート不変条件）と整合し、Gate ③（merge）が full-autopilot 側の責務として不変であることが明文化されている,
**so that** 壁打ちのバッチ化が false-green の外部アンカー（AC 承認）や三ゲート不変条件を損なわないことが保証・追跡できる.

### CS-3: 各変更が deterministic な bats 受け入れテストで守られている

**I want to** batch-discovery の各変更に bats 受け入れテストが追加されている,
**so that** AL-3 の deterministic AT gate を満たし、準備フェーズの振る舞いが再現可能に検証される.
