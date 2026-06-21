# Design Doc: session-start の branch-lease ベース別セッション検出

Issue #343。PRD の Open Questions（session 同定方式）と plan が選んだ実装形態（ヘルパ抽出）の 2 つの非自明なトレードオフを確定する。

## 決定 1: session 同定方式 — 案A（その時点の fresh lease をすべて別セッション扱い）

### コンテキスト

検出には「その lease が自セッションのものか、別セッションのものか」の判定が要る。PRD Open Questions が 2 案を提示していた。

### 検討した代替案

| 案 | 内容 | 長所 | 短所 |
|----|------|------|------|
| **案A（採用）** | session-start 実行時点の fresh branch-lease は定義上すべて別セッションのものと扱う | 自 session_id の取り回し不要。最も単純・堅牢。実装・テストが最小 | session-start を feature branch 上で走らせ、かつ自分がその branch の lease を持っている特殊ケースで自 PR を「別セッション」と誤表示しうる |
| 案B | フックが stdin で受ける `.session_id` を session-start から参照し、自セッション lease を除外して精密判定 | 自 PR を誤って lock 表示しない | session-start に session_id を流す経路が新設で、フック以外から `.session_id` を安定取得する保証がない。複雑さに見合う実益が薄い |

### 決定と根拠

**案A を採用。** 根拠:

- session-start は Phase 0 の branch auto-return により**通常 `main` 上で走る**（feature branch にいても commit 0 件なら main へ自動復帰）。この通常経路では自分は feature branch の lease を持たず、fresh lease はすべて別セッションのものという前提が成立する。
- 案B の誤表示回避メリットは「ongoing work（自 branch 上に未マージ commit）」の稀なケースに限られ、そのケースでは Previous Work が別途自 PR を表示するため、二重表示の害は read-only 表示が 1 行増える程度で破壊的操作には繋がらない。事故（他セッション PR への破壊的操作）の構造的防止という本 Issue の目的に対し、案A は十分かつ過剰防御として安全側に倒れる。
- 「精密さ」より「単純・堅牢」が本件の価値関数に合致（誤検出＝過剰 lock は read-only 表示で安全、見逃し＝事故再発が許容できない非対称性）。

## 決定 2: 検出ロジックの配置 — 抽出ヘルパ `scripts/session-lease-scan.sh`

### コンテキスト

検出を (a) SKILL.md 本文の手順記述（プロンプト）だけで表現するか、(b) 実行可能なシェルヘルパに抽出するか。

### 検討した代替案

| 案 | 長所 | 短所 |
|----|------|------|
| **ヘルパ抽出（採用）** | Story 7 の exit-code ベース回帰が可能。fresh/encode/TTL をコードで一意に固定でき Story 4（二重定義禁止）を機械検証できる。フックの確立ロジックを流用できる | スクリプトファイルが 1 つ増える |
| SKILL.md プロンプトのみ | ファイル追加なし | 「非 Draft・green・mergeable でも推薦しない」という振る舞いを grep でしか検査できず、回帰 AT が構造文言の存在チェックに留まる。事故の ground truth（lease 状態）に対する振る舞いを担保できない |

### 決定と根拠

**ヘルパ抽出を採用。** 本 Issue の存在理由は「意志力では止まらない誤推薦を構造で止める」こと。構造的担保には実行可能で機械検証できる検出が不可欠で、プロンプトのみでは Story 2/7 の中核（非 Draft・green・mergeable でも除外）を回帰で固定できない。

### 二重定義の回避（Story 4）

ヘルパは `hooks/branch-lease-guard.sh` と**同じ env 名**（`BRANCH_LEASE_DIR` / `BRANCH_LEASE_TTL_LOCAL`）・**同じ freshness 式**（`now - timestamp <= ttl`）・**同じ encode 5 文字セット**（`%2F %2E %20 %23 %7E`）を採用する。共通ロジックの実体配置（フックの関数を source 再利用するか、定数のみ合わせて独立実装するか）は実装時に詳細化するが、いずれの場合も TTL 既定値（7200s）を独自に再定義せず、AT-007 がフックとの env 名一致を機械検証する。

## 意図的にフックと異なる点: Draft 非依存

`hooks/branch-lease-guard.sh` の deny 条件は「fresh 別セッション lease **かつ** open Draft PR」だが、本 Issue の中核は**非 Draft（レビュー依頼済み）PR のすり抜け**を塞ぐこと。よってヘルパは `has_open_draft_pr` を呼ばず「open PR かつ fresh 別セッション lease」だけで検出する。フック（Layer 2, write-back のハードブロック）と session-start（Layer 1, 推薦の抑制）で Draft 依存度が異なるのは設計上意図的であり、両者の役割分担（#316 の二層防御）と整合する。
