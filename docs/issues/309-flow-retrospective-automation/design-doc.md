<!-- このファイルは trade-off または alternatives の検討がある場合にのみ使用します -->

# Design Doc: フロー完了時の自動振り返りの実装方式

## Context

PRD / User Stories で「何を集めるか」（5 メトリクス・前回比・摩擦点・skill-fix 候補）と論点 1〜6 は確定済み。PRD:34 は **実装方式（集計スクリプトの配置・テンプレート）と一次ソースの実経路を design phase で確定する** と明記しており、本ドキュメントがその確定を担う。残る設計判断は **(a) トークン / 対話量 / 摩擦点の実読み取り経路（どのファイルのどのフィールド）**、**(b) 集計ロジックの配置**、**(c) 横断ログの schema**、**(d) express スキップの実機構**。Issue 完了のたびに既定 ON で走るため、軽量性（CS-1）・近似許容（CS-2）・テスト可能性が同時に要求される。

### 一次ソースの実経路（design 確定 — 前回レビュー finding #1/#2/#3 を解消）

User Stories が挙げる名前（`subagent_tokens` / `autopilot-log.jsonl`）はラベルであり、実測すると次のとおり読み取り経路として成立しないものがある。design phase で **実在する経路に確定する**:

- **`autopilot-log.jsonl` はトークンを持たない**。実スキーマは `{iteration, step, verdict, fingerprint, timestamp}`（全 `docs/issues/*/autopilot-log.jsonl` で実測、#299 で `timestamp` 追加）。→ **トークンの一次ソースから除外**。本ファイルは摩擦点の補助シグナル（`verdict:"FAIL"` の step 出現）としてのみ read-only 参照する。
- **`subagent_tokens` は repo 内に存在しない**（`grep -r` ヒット 0）。Workflow の対話セッションがトークン総量を機械可読に書き出す経路は現状ない。→ **対話（非 headless）セッションのトークンは取得不能ゾーン**として best-effort（注記のみ）に確定する。
- **token / cost の唯一の確定読み取り経路は headless `claude -p` の 3 層ログ**（#318 prd:51 で技術検証済み）:
  - (a) `--output-format json` の **stdout JSON**: `total_cost_usd` / `usage`（input/output トークン）/ `session_id` / `terminal_reason`。full-autopilot はこれを `<worker-out>.json` にリダイレクト保存する（full-autopilot/SKILL.md:49）。→ **これがトークン / コストの primary**。
  - (b) `--session-id` 指定で確定する **transcript `<munged-cwd>/<session-id>.jsonl`**。対話量（ターン数）とフェーズ別内訳の primary 読み取り元（下記）。
  - (c) 入れ子 Workflow `<session-dir>/subagents/workflows/wf_*/`（agent 単位 jsonl）。autopilot の subagent 総量を含めるための補助。
- **対話量（FS-2 / AT-309-3）の「セッション記録」を確定**: transcript `<munged-cwd>/<session-id>.jsonl`（経路 b）。ターン数 = transcript 内の `type:"user"` / `type:"assistant"` レコード数。**フェーズ別内訳** = autopilot は同 Issue の `autopilot-log.jsonl` の `step` 値でフェーズ境界を確定（read-only、機械判定可能）／手動 flow は transcript の skill 起動マーカーが無いケースがあるため best-effort（フェーズ境界を機械判定できないときは「内訳: best-effort（unknown）」と注記）。
- **摩擦点（FS-5 / AT-309-6）の永続化先を確定**: `rejectionFindings` / `implSeedFindings` は autopilot Workflow の **in-memory args** で、どのファイルにも永続化されない（`grep` で永続化先 0 件）。merge gate 通過後に走る retrospective は Workflow 終了済みのため args を参照**できない**。→ 摩擦点の primary 読み取り経路を **永続化されたシグナルに置換する**: ① `autopilot-log.jsonl` の `verdict:"FAIL"` step（read-only、どの step で否決が起きたか＝requirements / design / merge ゲートへマップ可能）、② GitHub の Issue / PR コメント（`gh issue view --comments` / `gh pr view --comments`、design ゲート差し戻し・merge ゲート引き継ぎは全チャネル同期規約でコメントに残る）。in-memory な `rejectionFindings` は**読み取り経路から外し**、その構造化等価物として上記永続シグナルを使う。手動 flow は構造化シグナルが薄いため best-effort。

トークン・摩擦点の一次ソース（autopilot-log.jsonl / headless `<worker-out>.json` / transcript jsonl / 入れ子 Workflow dir）は **orchestrator 所有のため read-only** で扱い、追記 / 編集 / commit は一切しない。

## Goals

- 決定的に検証できる集計ロジックを持つ（BATS で出力契約を pin できる）
- merge gate 後に軽量・既定 ON で走り、express ではスキップする
- 横断ログを前回比較に使える安定 schema で append-only に残す
- 全チャネル（ターミナル + Issue / PR）同期で同内容を提示する

### 軽量性（CS-1）の測定可能なしきい値（前回レビュー finding #5 を解消）

「目立って重くしない」を BATS で pin できる**客観基準**に落とす:

- **LLM 往復 0 回**: `scripts/retrospective.sh` は bash + `gh` + `jq` のみで完結し、内部で `claude` / LLM 呼び出しを一切起動しない。pin = スクリプト本文に `claude ` / `Workflow` / LLM 呼び出しトークンが grep ヒット 0。
- **read-only / 非対話**: 一次ソースは全て read-only 読み取りで、ユーザー入力待ち（プロンプト）を発生させない。pin = `read -p` / `AskUserQuestion` 等のブロッキング入力が本文に 0。
- **実行時間上限**: `scripts/retrospective.sh` 単体（ネットワーク待ち = `gh` 呼び出しを除いたローカル集計部）が CI 環境で **5 秒以内**に完了する。pin = BATS で `SECONDS` ベースの上限アサート（`gh` をスタブ / fixture 化した状態で計測）。
- これらを満たすことで「既定 ON でも完了フローを目立って重くしない」を非主観的に表明する。

## Non-Goals

- トークンの完全精密計測（harness 近似で許容・#312 と同根）
- skill-fix の自動起票（候補提示まで・No Auto-Routing）
- 手動 flow の指摘自動抽出（best-effort 注記で済ませる）

## Proposal

採用案: **集計ロジックは `scripts/retrospective.sh` に閉じ込め、`merging-and-deploying` 末尾は軽量フックとして呼び出し・提示に専念する。** 一次ソースは上記「一次ソースの実経路」で確定した実在ファイル / フィールドのみを read-only で読む。

```
merging-and-deploying（末尾ステップ＝完了点A）
  └─ scripts/retrospective.sh <issue> <pr>   # 手動 / autopilot はここを通る
       ├─ token / cost 読み取り（primary = headless <worker-out>.json の usage/total_cost_usd、
       │                          + 入れ子 Workflow dir で subagent 総量。経路欠落時 best-effort 注記）
       ├─ 対話量 読み取り（primary = transcript <munged-cwd>/<session-id>.jsonl の user/assistant
       │                    レコード数。フェーズ内訳 = autopilot-log.jsonl の step、手動は best-effort）
       ├─ 摩擦点 読み取り（primary = autopilot-log.jsonl の verdict:"FAIL" step + gh issue/pr comments。
       │                    in-memory な rejectionFindings は参照不能のため不採用。手動は best-effort）
       ├─ 前回比（直近マージ PR を gh で特定 / diff 行数で正規化）
       ├─ skill-fix 候補をサマリ列挙（自動起票なし）
       ├─ docs/issues/<NNN>-*/retrospective.md を生成（template から）
       └─ docs/retrospective-log.jsonl へ 1 行 append（安定キー schema）
     → ターミナル + Issue/PR コメントに同内容を出力（全チャネル同期）

express（完了点B = express/SKILL.md Step 5「CI Gate and Human Merge」）
  └─ merging-and-deploying を一切呼ばない（express/SKILL.md に呼び出し 0 件＝実測）
     ⇒ retrospective.sh への到達経路がそもそも無い＝構造的スキップ（下記「express スキップの実機構」）
```

### express スキップの実機構（前回レビュー finding #4 を解消）

express 経路は **`merging-and-deploying` を経由しない**（`skills/express/SKILL.md` 内に `merging-and-deploying` 参照 0 件、完了点は Step 5「CI Gate and Human Merge」で human merge）。したがって retrospective を `merging-and-deploying` 末尾フックに置く設計は、**express にとっては「フックに到達しない」こと自体がスキップ機構**である（merging-and-deploying 内に `if 非 express` 分岐を置く belt-and-suspenders は不要・むしろ誤解を招くため置かない）。express でスキップが漏れない根拠 = *retrospective の唯一の起動点が merging-and-deploying 末尾であり、express はそこを構造的に通過しない*。AT-309-2 はこの構造的不在を pin する（merging-and-deploying 末尾フックの存在 ＋ express/SKILL.md に retrospective 起動が無いこと、の両面）。

横断ログ schema（安定キー、append-only JSONL）:

```json
{"issue": 309, "pr": 999, "tokens": {"input": 0, "output": 0, "total": 0},
 "diff_lines": 0, "normalized_ratio": 0.0,
 "friction": {"requirements": 0, "design": 0, "merge": 0},
 "feedback_candidates": ["..."]}
```

## Alternatives Considered

- **A. 集計を skill prose にインライン化（bash スクリプトなし）** — 却下。決定的でなく BATS で出力契約を pin できない。既定 ON で毎回 LLM 集計が走り CS-1（軽量性）に反する。
- **B. 横断ログを CSV にする** — 却下。摩擦点（ゲート別）や skill-fix 候補（可変長配列）のネスト構造を表現しづらく、schema 拡張に弱い。JSONL の方が 1 行 1 レコードで append-only と前回比較に向く。
- **C. トリガーを autopilot 専用にする** — 却下。PRD の論点 6 で「既定 ON・手動 flow も対象（best-effort）」が確定済み。merging-and-deploying 末尾フックなら手動 / autopilot 両方を覆える。

## Trade-offs

- 得るもの: 決定的・テスト可能な集計、軽量な既定 ON、安定した前回比較ログ。
- 失うもの: 集計ロジックが bash に寄るため、複雑な自然言語的振り返り（定性洞察）は skill 側の提示レイヤに依存し、スクリプト単体では浅くなる。摩擦点・skill-fix 候補は構造化データのある autopilot で濃く、手動 flow では best-effort に留まる。

## Risks

- harness トークン値の取得経路が環境差で欠落するリスク → best-effort 注記で degrade（CS-2 で許容）。primary 経路は headless `<worker-out>.json` の `usage`/`total_cost_usd`（#318 で検証済み）であり、対話（非 headless）セッションは取得不能ゾーンとして注記のみ。値の有無両ケースを AT-309-4 で固定する。
- 摩擦点の in-memory args（`rejectionFindings`）が retrospective 実行時点で参照不能なリスク → 永続化シグナル（`autopilot-log.jsonl` の `verdict:"FAIL"` step + `gh` コメント）に置換済み。AT-309-6 はこの永続経路を pin する。
- 一次ソース（`autopilot-log.jsonl` / `<worker-out>.json` / transcript jsonl / 入れ子 Workflow dir）は orchestrator 所有。**読み取り専用**で扱い、追記 / 編集 / commit は行わない（振り返りの書き込み先は別ファイル `docs/retrospective-log.jsonl`）。
- 既定 ON が完了フローを重くするリスク → 集計は bash で完結させ LLM 往復 0（上記「軽量性の測定可能なしきい値」で pin）。
- foreign file 混入リスク → retrospective が読む一次ソースは本 Issue スコープ外の orchestrator 所有ファイルを含む。読み取りのみ・編集 / exclude 設定変更はしない。
