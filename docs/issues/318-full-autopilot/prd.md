# PRD: full-autopilot — キュー方式で複数 issue を並列・無人で merge まで回す

## Problem

autopilot の運用実態は「最初の壁打ち（要件固め）だけ人間がやり、以降はほぼノールック承認」に収束している。つまり人間の関与は各 issue の冒頭に集中し、実装〜レビュー〜merge は実質 Claude に委ねられている。

それにもかかわらず現状は **1 セッション＝1 issue を手動で起動し、終わるまで張り付く** 運用のため、以下の損失が出ている:

- **逐次の遅さ** — 複数 issue を捌くとき、人間が1本ずつ起動し完了を待ってから次を起動する。並列に回せる工程が直列化している。
- **継ぎ目ごとの再起動コスト** — 1 issue 完了のたびに人間が「次に何をやるか」を判断し、手で次の autopilot を起動している。要件が固まっている issue が複数あっても、数珠つなぎに自動消化されない。
- **merge の張り付き** — autopilot が merge まで担うため、完全無人で複数 PR を並列に統合する経路がない。

## Why now

- autopilot を atdd-kit 自身で多重セッション dogfood する運用が定着し（[[project_autopilot_dogfood_277]] で 7 度フル実走）、「最初だけ壁打ち・あとはノールック承認」というスタイルが安定的に再現されている。この実績が full-autopilot の前提（人間関与を issue 冒頭に集約できる）を裏付けた。
- 並列化に必要な排他制御の土台が `#316`（branch-lease guard, sim-pool 型 PreToolUse フック）で構築中。lease 機構を容量・キー違いで流用すれば、issue-lease / merge-lease を低コストで足せる下地が揃う。
- 並列セッションの衝突リスクが現実の頻度になっており（`#316` の動機）、無人並列を安全に回す仕組みを今整える価値が高い。

## Outcome

1. **人間の関与が issue 冒頭（壁打ち）に閉じる**。要件を `ready-to-go` まで固めた issue をキューに積めば、実装〜レビュー〜merge〜post-merge regression まで無人で完了する。
2. **複数 issue が並列に進む**。並列度 K をパラメータとし、K=1 で純粋な数珠つなぎ、K>1 で並列消化。同一スキルが両モードを兼ねる。
3. **キューが空になるまで数珠つなぎに自動消化される**。worker slot が空いたら、人間の再起動なしにキューから次の issue を取って着手する。
4. **merge が単一の直列ロールで安全に統合される**。並列 worker が同時完了しても main は壊れない（rebase 後フル再ゲートを必ず通す）。
5. **失敗時も完全には止まらない**。rebase 衝突 / 再ゲート fail は自動差し戻しでリトライし、閾値超で初めて human にエスカレーションする。

## What

2軸に分解して設計する。**軸B（数珠つなぎ）が full-autopilot 本体**、**軸A（並列）はその worker を多重起動する土台**。

```
[人間] 壁打ち → ready-to-go な issue を N 個キューに積む
                        │
                        ▼
        ┌──────── dispatcher（軸A） ────────┐
        │ 空き worktree slot に issue を割当       │
        │ （issue-lease + branch-lease で排他）    │
        └──────────────┬──────────────┘
        ▼              ▼              ▼
   autopilot       autopilot       autopilot   ← 並列 worker（上限 K）
   (issue 1)       (issue 2)       (issue 3)    ← 「単体 green な PR」まで作って exit
        │              │              │
        └──── merge coordinator（容量1で直列化）────┘
                        ▼
        rebase→ゲート再実行→merge→post-merge regression
        ▼
   slot が空いたらキューから次を取る（軸B）
```

1. **`full-autopilot` スキル新設** — dispatcher（issue 割当）＋ 数珠つなぎループ。中身は既存 autopilot を呼ぶだけにし、autopilot 本体には手を入れない（疎結合）。**各 worker は独立した headless プロセス（`claude -p "/atdd-kit:autopilot <issue>"` を `run_in_background`）として起動する**（検証済み・下記）。worker が内部で Workflow を回しても、各 worker が top-level プロセスのため Workflow 入れ子制約に当たらない。dispatcher は起動 → 完了通知待ち → 結果回収 → 次を起動 / coordinator へ、を担う。
   - **多重化方式の技術検証（実証済み, 2026-06-17）**: headless `claude -p` が Workflow ツールを起動し完了結果を回収できることを確認（`{"value":"PONG"}` 返却）。`-p` でも background Workflow の完了を待って exit する。ログは3層で回収可能 —（a）`--output-format json` の stdout（`result`/`session_id`/`is_error`/`total_cost_usd`/`usage`/`terminal_reason`）、（b）`--session-id` 指定で確定する transcript `<munged-cwd>/<session-id>.jsonl`、（c）入れ子 Workflow の `<session-dir>/subagents/workflows/wf_*/`（agent 単位 jsonl ＋ journal）。`total_cost_usd` で worker 単位のコスト追跡も可能。実装注意: 起動時 `< /dev/null` で stdin をリダイレクト（3秒ストール回避）、本番は `--permission-mode` ＋ `--allowed-tools` で gate を絞る。
2. **キュー = キュー方式**。人間が壁打ちで `ready-to-go` まで固めた issue だけを消化対象とする。backlog からの自動選定・要件自動生成はしない（暴走防止）。
3. **autopilot に hand-off モードを追加** — full-autopilot から呼ぶときだけ有効化するフラグ。autopilot の3 User gate（①要件 ②設計 ③merge, AL-1）を次のように畳む:
   - ① 要件承認 → キュー方式で**事前承認済み**（`ready-to-go` の前提）。
   - ② 設計承認 → **自動承認（ブロックしない）**。設計ループ（generate→review→fix）と in-loop reviewer による near-green 収束は維持し、人間サインオフ待ちのみ外す。autopilot が既に人間レビューを reviewer-oracle で代替しているのと同じ思想。人間は Draft PR の設計成果物を見て差し戻す override 権を保持。
   - ③ merge → **merge coordinator** が引き取る（autopilot は元々 merge しない）。
   結果として DoD は「merged PR」→「`merge-ready`（単体 green・Draft 外し・ラベル付与）まで」。通常起動（非 full-autopilot）の3 gate と DoD は不変。
4. **merge coordinator（容量1の直列ロール）** — `merge-ready` を FIFO/優先度で1件ずつ drain。各 PR について `rebase onto 最新 main → ゲート再実行（AT＋verdict）→ merge → post-merge regression`。**rebase 後は毎回フル再ゲート**（green alone / broken together を確実に殺す）。
5. **失敗ハンドリング = 自動差し戻し → 閾値超で human** — coordinator が rebase 衝突 / 再ゲート fail を踏んだら新 autopilot イテレーションへ自動差し戻し。N 回失敗で初めて human にフラグ。
6. **lease 機構の流用（`#316` 由来）**:

   | lease | 容量 | キー | 用途 | 状態 |
   |-------|------|------|------|------|
   | branch-lease | K | branch | worker の worktree/branch 排他 | `#316` で構築中 |
   | issue-lease | issue 単位 | issue 番号 | 同じ issue を2本が拾わない | 本 Issue で拡張 |
   | merge-lease | 1 | `main-merge` | 統合の直列化 | coordinator が握る |

7. **epic 分割（想定）** — 規模的にサブ Issue 化する: (a) autopilot hand-off モード / (b) dispatcher＋issue-queue / (c) merge coordinator / (d) issue-lease・merge-lease 拡張。分割の確定は plan で行う。

## Non-Goals

- **backlog からの issue 自動選定・要件自動生成** — キュー方式の核心的安全弁。間違った issue を勝手に作って実装し始めるリスクを排除するため、消化対象は人間が `ready-to-go` まで固めたものに限定する。
- **autopilot の判断ロジック本体の改変** — hand-off モード追加以外は autopilot に手を入れない。疎結合を維持し、full-autopilot は autopilot を呼ぶオーケストレータに徹する。
- **複数マシン間の lease 共有** — `#316` 同様、同一マシン上の並行セッション衝突が対象。マシンを跨ぐ排他は対象外。
- **merge の軽量ゲート最適化** — 「main 差分が無関係なら再ゲートをスキップ」等の最適化は後回し。まずは安全側のフル再ゲート固定。

## Open Questions

- ~~**並列 worker の多重化手段**~~ — **RESOLVED（2026-06-17 検証）**: headless `claude -p` を `run_in_background` で K 本起動する方式に確定。Workflow 利用可・ログ3層回収可を実証（What 1 参照）。旧 atdd-kit の TeamCreate/spawn-profiles 構成は intra-issue 並列の参考。実窓制御（osascript/tmux）は結果回収不能のため不採用。
- **設計 gate ②の自動承認は AL-1 と整合させる必要** — hand-off モードは AL-1（gate を厳密に3つに固定）を full-autopilot 限定で上書きする。autopilot Iron Law にモード分岐を入れる形になるため、plan / design-doc で AL-1 への影響範囲と「通常起動では不変」の担保方法を詰める（C3 疎結合との緊張点）。
- **キューの実体** — GitHub ラベル（`ready-to-go`）を queue とみなすか、専用ファイル／store を持つか。優先度の与え方も含めて plan で詰める。
- **merge coordinator の常駐形態** — dispatcher の merge-drain ループとして同居させるか、独立プロセスにするか。
- **エスカレーション閾値 N の既定値** と、human フラグの通知経路（Issue コメント / 通知）。
- **`#316` への依存順序** — issue-lease / merge-lease は `#316` の branch-lease 機構が merge されていることが前提。本 Issue の着手タイミングを `#316` merge 後に揃えるか、設計だけ先行させるか。
- **epic サブ分割の粒度** — 上記 (a)〜(d) の単位で良いか、依存順序をどう引くか。
