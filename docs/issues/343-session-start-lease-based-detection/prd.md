# PRD: session-start の「別セッション作業中」検出を branch-lease store ベースにする

## Problem

session-start が **他セッションで作業中の open PR をマージ/rebase 推奨してしまう事故が再発している**（直近: 2026-06-20、別セッション作業中の PR #332 を Priority 1「マージ推奨」に格上げ）。

根本原因は2層:

1. **検出設計のギャップ。** 「別セッションが作業中か」の検出が **Draft 状態 + `in-progress` ラベル**にしか依存していない（SKILL.md L186 / L211-223）。非 Draft 化（レビュー依頼済み）したまま反復中の PR は両方すり抜ける（`isDraft:false` / `labels:[]`）。Step 2.1 は CONFLICTING の非 Draft PR しか特別扱いせず、MERGEABLE な他セッション PR は素通りで「actionable」に見える。

2. **推薦デフォルトの誤り。** 「非 Draft = ready = 推薦」「green PR = マージしよう」という汎用的お節介が、マルチセッション規律（1 PR = 1 セッション所有）を上書きする。並列セッションでは全 PR が `@me` なので `@me + open` は推薦根拠として最弱。

決定的な事実（feasibility 実地探索で確定）: 作業所有の ground truth は **`hooks/branch-lease-guard.sh` が記録する `/tmp/claude-branch-leases/<branch>.json` = `{session_id, timestamp}`（TTL 付き）** にある。このフックはプラグインの PreToolUse（Bash matcher）として実稼働しており、インタラクティブ並列セッションを含めて branch 所有を記録している。session-start はこれを一切参照していない。

> 注: Issue 本文では参照先を `lib/lease-store.sh`（pool=issue）と推定していたが、feasibility で**誤りと判明**。`lib/lease-store.sh` は full-autopilot（dispatcher / merge coordinator）専用で、インタラクティブ作業では空（`/tmp/claude-leases` 未生成）。正しい store は branch-lease store。

## Why now

事故が「何度も」再発しており（ユーザー報告）、意志力では止まらないことが実証済み。並列セッション運用が常態化した今、構造で止めないと毎セッション同じ誤推薦が繰り返される。branch-lease store という ground truth が既に稼働しているため、検出をそこに繋ぎ替えるコストは小さく、機会コストだけが残っている。

## Outcome

完了時に達成されている状態:

- session-start は、**別セッションが fresh な branch-lease を保持している open PR を、Draft / 非 Draft を問わず read-only 表示のみ**にし、マージ・rebase・force-push を推薦しない。
- 「別セッション作業中」の判定が **branch-lease store ベース**（`/tmp/claude-branch-leases/<branch>.json` の fresh lease）になり、Draft 状態への依存をやめる。
- Step 2.1 の CONFLICTING rebase 推奨も、対象ブランチが別セッションの fresh lease を保持していないことを前提条件にする。
- 回帰防止の AT が「非 Draft・green・mergeable だが別セッションが lease 保持中の PR を推薦しない」ことを exit-code ベースで担保する。

## What

スコープ内:

- `skills/session-start/SKILL.md` の Previous Work / Task Recommendation Rules（Step 1-3）改訂:
  - branch-lease store（`/tmp/claude-branch-leases/<branch>.json`）の fresh lease を参照する検出ロジックを追加。
  - fresh lease を別セッションが保持する open PR は `🔒 別セッション作業中` として read-only 表示し、Recommended Tasks から除外。
  - Step 2.1（CONFLICTING rebase 推奨）に lease 未保持の前提条件を付与。
- branch-lease の freshness 判定は `hooks/branch-lease-guard.sh` の既存 TTL ロジック（`BRANCH_LEASE_TTL_LOCAL` 既定 7200s）を再利用し、二重定義しない。
- 回帰 AT（`tests/acceptance/AT-343.*`）。

## Non-Goals

- `hooks/branch-lease-guard.sh` / `lib/lease-store.sh` 本体の挙動変更 — 既存の store を読むだけ。書き込み・TTL・排他ロジックは触らない（変更点を最小化し回帰リスクを抑える）。
- full-autopilot / dispatcher / merge coordinator 側の lease 運用変更 — 別系統（pool=issue/merge）であり本件と独立。
- 他 skill の推薦ロジック変更 — 事故は session-start に閉じている。
- branch-lease store が空/未稼働環境でのフォールバック新設 — fail-safe は「lease 情報が無ければ従来どおり（ただし Outcome の read-only 既定は維持）」で足り、新機構は作らない。

## Open Questions

- **session 同定の方式（design phase で決定）。** session-start は通常 `main` 上・feature branch 未接触の状態で走るため、その時点の fresh branch-lease は定義上すべて「別セッションのもの」と扱える（自分の session_id を知る必要がない）案 A が有力。対して、自セッション ID と突き合わせて精密判定する案 B は session_id の取り回し（フックが stdin で受ける `.session_id` を session-start から参照する経路）が必要。トレードオフ（単純・堅牢 vs 精密）を design gate で確定する。
- AT で branch-lease store の状態をどう用意・隔離するか（`BRANCH_LEASE_DIR` を一時ディレクトリに差し替える等）は plan で具体化する。
