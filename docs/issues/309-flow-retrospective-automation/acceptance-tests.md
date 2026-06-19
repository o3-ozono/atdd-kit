# Acceptance Tests: フロー完了時の自動振り返り（メトリクス + フィードバック抽出）

<!-- AT lifecycle: planned → draft → green → regression
     各エントリには状態マーカー [planned] / [draft] / [green] / [regression] を付与する。
     状態は実装の進行に合わせて更新する。 -->

## AT-309-1: 完了トリガーで振り返りを自動起動（FS-1 / CS-1）

- [x] [regression] AT-309-1: 非 express の Issue 完了時に振り返りが既定 ON で軽量に起動する
  - Given: merge gate を通過済みで express 経路ではない Issue
  - When: `merging-and-deploying` の末尾ステップに到達する
  - Then: 振り返り処理が既定 ON で自動起動する。軽量性は以下の客観基準で表明する（主観表現を排し測定可能化、design「軽量性の測定可能なしきい値」に対応）:
    - `scripts/retrospective.sh` 本文に `claude ` / `Workflow` 等の LLM 呼び出しが grep ヒット 0（LLM 往復 0 回）
    - `read -p` / `AskUserQuestion` 等のブロッキング入力が本文に 0（非対話）
    - `gh` をスタブ化した状態でローカル集計部が 5 秒以内に完了する（BATS で `SECONDS` 上限アサート）

## AT-309-2: express 経路ではスキップ（FS-1）

- [x] [regression] AT-309-2: express 経路の完了では振り返りが起動しない（構造的スキップ）
  - Given: express 経路で完了した Issue（完了点 = `express/SKILL.md` Step 5「CI Gate and Human Merge」）
  - When: 完了処理に到達する
  - Then: 振り返りは起動せず、レポートも横断ログ追記も発生しない。スキップ機構は「express が retrospective の唯一の起動点を構造的に通過しない」ことで成立し、これを両面で pin する:
    - retrospective の起動点が `merging-and-deploying` 末尾ステップにのみ存在する
    - `skills/express/SKILL.md` に `merging-and-deploying` 参照・retrospective 起動が 0 件（express は merging-and-deploying を経由しない＝実測）
    - これにより `merging-and-deploying` 内の `if 非 express` 分岐に依存せずスキップが成立する（誤認識防止）

## AT-309-3: 対話量メトリクスの集計（FS-2）

- [x] [regression] AT-309-3: ターン数がフェーズ別内訳付きで集計される
  - Given: 完了した Issue のセッション記録 = transcript `<munged-cwd>/<session-id>.jsonl`（#318 prd:51 で確定した実経路）。autopilot の場合は同 Issue の `autopilot-log.jsonl`（read-only）がフェーズ境界シグナルとして併存する
  - When: 振り返りが対話量を集計する
  - Then: ターン数 = transcript 内の `type:"user"` / `type:"assistant"` レコード数として出力される。フェーズ別内訳は autopilot では `autopilot-log.jsonl` の `step` 値でフェーズ境界を機械判定して内訳行を出す。手動 flow で境界を機械判定できない場合は「内訳: best-effort（unknown）」と注記する（実装非依存に固定された経路）

## AT-309-4: トークンコストの集計（harness 値一次ソース）（FS-3 / CS-2）

- [x] [regression] AT-309-4: harness 提供値を一次ソースにトークン量が出力され、欠落時は best-effort 注記が付く
  - Given: token / cost の確定一次ソースは headless `claude -p` の **stdout JSON（`<worker-out>.json` の `usage` = input/output、`total_cost_usd`）**であり、autopilot の subagent 総量は入れ子 Workflow dir `<session-dir>/subagents/workflows/wf_*/` で補う（#318 prd:51 / full-autopilot/SKILL.md:49 で確定）。`autopilot-log.jsonl` はトークンを持たないため一次ソースから除外（実スキーマ = `{iteration,step,verdict,fingerprint,timestamp}`）。対話（非 headless）セッションのトークンは取得経路が存在しない（`subagent_tokens` は repo にヒット 0）ため欠落ケースとなる
  - When: 振り返りがコストを集計する
  - Then: headless 経路の値がある場合は input / output / 合計が `usage` / `total_cost_usd` から出力され、autopilot は subagent（入れ子 Workflow dir）を含む総量になる。値が欠落する場合（対話セッション・ログ非存在）は best-effort 注記が出力される。一次ソースは全て read-only で読む

## AT-309-5: 前回比較（コード量正規化込み）（FS-4）

- [x] [regression] AT-309-5: 直近マージ PR を対象に diff 行数で正規化した前回比が出力される
  - Given: 直近にマージされた PR が存在し、横断ログ `docs/retrospective-log.jsonl` に前回レコードがある。前回比の分子（トークン量）は AT-309-4 で確定した headless 経路に依存し、欠落時は best-effort（前回比も「token 欠落につき best-effort」と注記）に degrade する
  - When: 振り返りが前回比を算出する
  - Then: トークン量を diff 行数（`gh` で直近マージ PR の diff 行数を取得）で正規化した比率が数値で出力され、docs 主体 vs code 主体の差が注記で補われる。token が取得不能な場合は比率を空にせず best-effort 注記を出す

## AT-309-6: 摩擦点（ユーザー指摘箇所）の抽出（FS-5）

- [x] [regression] AT-309-6: 永続化された gate rejection シグナルを起点に摩擦点がゲート別に分類される
  - Given: 摩擦点の primary シグナルは **永続化された経路**のみを使う —（a）`autopilot-log.jsonl` の `verdict:"FAIL"` step（read-only、どの step で否決が起きたか）、（b）`gh issue view --comments` / `gh pr view --comments`（design ゲート差し戻し・merge ゲート引き継ぎは全チャネル同期でコメントに残る）。in-memory な `rejectionFindings` / `implSeedFindings` は retrospective 実行時点で Workflow 終了済み・参照不能のため一次ソースから除外する（手動 flow は永続シグナルが薄く best-effort）
  - When: 振り返りが摩擦点を抽出する
  - Then: `verdict:"FAIL"` の step とコメントから、どのゲート（requirements / design / merge）で発生したかに分類されて出力され、手動 flow は best-effort 注記が付く。一次ソースは read-only で読む

## AT-309-7: atdd-kit 改善候補（skill-fix 候補）のサマリ列挙（FS-6）

- [x] [regression] AT-309-7: skill-fix 候補がサマリ列挙され、自動起票は行われない
  - Given: 振り返りで挙がった atdd-kit へのフィードバック点（skill-fix 起票候補・ガイダンス不足・偽 halt 等）
  - When: 振り返りが改善候補を出力する
  - Then: 候補がレポートにサマリ列挙され、skill-fix Issue の自動起票は一切実行されない（No Auto-Routing）

## AT-309-8: レポート出力と横断ログ・全チャネル同期（FS-7）

- [x] [regression] AT-309-8: retrospective.md 生成・横断 JSONL 追記・全チャネル同期が成立する
  - Given: 非 express の Issue が完了する
  - When: 振り返りが出力を行う
  - Then: `docs/issues/<NNN>-*/retrospective.md` が生成され、横断 JSONL に 1 行 = 1 オブジェクトの valid なレコードが append され、同内容がターミナルと Issue / PR コメントに出力される

## AT-309-9: バージョン整合（リグレッション不変条件）

- [x] [regression] AT-309-9: 機能 PR でバージョンと CHANGELOG が整合する
  - Given: 本機能を含む feature PR
  - When: バージョン整合をチェックする
  - Then: `.claude-plugin/plugin.json` の version が CHANGELOG の先頭リリース見出しと一致する（点 pin 禁止・不変条件で表明する）

## ライフサイクル例

| 状態 | 意味 |
|------|------|
| [planned] | テスト設計済み・未実装 |
| [draft] | 実装中・まだ通過していない |
| [green] | テスト通過済み |
| [regression] | リグレッション対象として継続監視中 |
