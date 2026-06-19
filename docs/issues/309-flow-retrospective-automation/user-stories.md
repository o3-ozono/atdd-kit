# User Stories: atdd-kit 開発フロー完了時の自動振り返り（メトリクス + フィードバック抽出）

## Functional Story

<!-- 機能要求を persona 抜き Connextra 形式で記述する。1 ストーリー = 1 ユーザーゴール。 -->

### FS-1: 完了トリガーで振り返りを自動起動

**I want to** Issue 完了時（`merging-and-deploying` 末尾の merge gate 通過後）に振り返りを既定 ON・軽量で自動実行し、express 経路はスキップする,
**so that** 振り返りを人手で起動し忘れることなく、軽量 Issue にも余計なコストをかけずに毎回の振り返りが残る.

### FS-2: 対話量メトリクスの集計

**I want to** ユーザー ⇄ assistant のやりとり回数（ターン数）をフェーズ別内訳付きで集計する,
**so that** どのフェーズで対話が膨らんだかを定量的に把握できる.

### FS-3: トークンコストの集計（harness 値一次ソース）

**I want to** 使用トークン量（input / output / 合計）を harness 提供値（Workflow `subagent_tokens` / headless `total_cost_usd` / `autopilot-log.jsonl`）を一次ソースとして、autopilot は subagent を含む総量で集計する,
**so that** 1 Issue あたりの実コストを確実な経路で把握し、コスト管理の基礎データにできる.

### FS-4: 前回比較（コード量正規化込み）

**I want to** 直近マージ PR を比較対象として、トークン量を diff 行数で正規化した前回比を出力し、docs 主体 vs code 主体の差は注記で補う,
**so that** 単純なトークン差ではなく成果規模あたりのコスト傾向で前回と公平に比較できる.

### FS-5: 摩擦点（ユーザー指摘箇所）の抽出

**I want to** ユーザーから指摘・差し戻しが入った箇所を、autopilot の gate rejection / `rejectionFindings` / `implSeedFindings` の構造化データを起点に抽出し、どのゲート（requirements / design / merge）で発生したかを示す（手動 flow は best-effort）,
**so that** どのステップ／ゲートで摩擦が起きたかを機械的に把握し、改善対象を特定できる.

### FS-6: atdd-kit 改善候補（skill-fix 候補）のサマリ列挙

**I want to** 振り返りで挙がった atdd-kit へのフィードバック点（skill-fix 起票候補・ガイダンス不足・偽 halt 等）をレポートにサマリ列挙する（自動起票はしない）,
**so that** No Auto-Routing 哲学を保ちつつ、skill-fix へつなぐ改善ループの起点を残せる.

### FS-7: レポート出力と横断ログ・全チャネル同期

**I want to** 振り返りレポートを `docs/issues/<NNN>-*/retrospective.md`（Issue ローカル）に生成し、前回比較用の横断集計 JSONL に追記したうえで、ターミナル・Issue／PR コメントに同内容を出す,
**so that** Issue 単位で振り返りを残しつつ前回比較を横断ログで可能にし、どのチャネルで見ても同じ振り返り内容を参照できる.

## Constraint Story (Non-Functional)

<!-- 非機能要求（NFR）を Story 形式で表現する（Pichler 2013）。 -->

### CS-1: 軽量性（既定 ON でも開発フローを阻害しない）

**I want to** 振り返り処理が merge gate 後に軽量に実行され、既定 ON であっても完了フローを目立って重くしない,
**so that** 全 Issue で自動実行しても開発体験を損なわず、振り返りが負担にならない.

### CS-2: トークン計測は harness 近似で許容

**I want to** トークン量の集計を harness 提供値ベースの近似で済ませ、完全精密計測を要求しない（#312 feasibility と同根）,
**so that** 計測の厳密化に過剰投資せず、実用十分な精度で前回比較とコスト把握を成立させられる.
