<!-- このファイルは trade-off または alternatives の検討がある場合にのみ使用します -->

# Design Doc: express skill の発動形態・skill-gate 統合・旧実装再利用の確定

## Context

PRD（`docs/issues/284-express-skill/prd.md`）の Open Questions は 3 つの設計判断を plan に委ねた:

1. **発動形態の詳細** — コマンド起動のみか、keyword 検出 + Y/n 確認付き「提案」まで許すか
2. **skill-gate 統合のメカニズム（AC8）** — skill-gate 側の SKILL.md を編集するか、express skill 側の宣言で済ませるか
3. **旧 PR #96 実装の再利用度合い** — 旧 express の構造をどこまで流用するか

いずれも競合する代替案を持つため、本ドキュメントで決定を記録する。

## Goals

- AC1〜AC9 を満たしつつ、PRD の設計原則（スピードと簡略性が最優先、人間の接点は発動承認と merge の 2 点のみ）を壊さない実装方式を確定する。

## Non-Goals

- express skill 本体の逐語的な手順設計（plan.md と Step 4 の実装が担う）
- フルフロー skill 群（6-step）の変更（PRD Non-Goals）

## Proposal

### D1: 発動形態 = コマンド起動のみ（keyword 検出なし）

`/atdd-kit:express <issue>` の明示起動だけを発動経路とする。`commands/express.md`（skill-fix 形式の薄いエントリ）+ `skills/express/SKILL.md` の 2 ファイル構成（旧 #96 と同型）。SKILL.md の `description` は "explicitly invoked" を明記し、keyword 検出による提案・自動発動は書かない。

### D2: skill-gate 統合 = skill-gate 側 SKILL.md の編集

`skills/skill-gate/SKILL.md` の「Pre-check: Issue Work Routing」に express 分岐を追加する: 明示的な `/atdd-kit:express <issue>` 発動は正規ルートとして認識し、defining-requirements への誘導を行わない。express は Issue 必須（AC3）のため Iron Law #1（No Code Without an Issue）はそのまま成立する。Parallel Collision Detection（`scripts/check-issue-collision.sh`）は express 開始時にも適用する。

### D3: 旧 PR #96 の再利用 = 骨格を流用し、v1.0 差分を 4 点適用

旧 `skills/express/SKILL.md`（入力検証 → 適用基準 + APPROVAL-GATE → 実装 → PR マーカー → CI HARD-GATE）の骨格と OK/NG 基準の内容を流用する。v1.0 差分:

| # | 旧 #96 | 本 Issue（v1.0） | 根拠 |
|---|--------|------------------|------|
| 1 | Step 10 で `gh pr merge --squash` を自動実行 | 自動 merge を撤去し、CI green 後は人間の merge に引き渡す | PRD Non-Goal「merge の自動化はしない」/ CS-1 |
| 2 | 適用基準は別ファイル `docs/guides/express-mode.md` | OK/NG 基準を SKILL.md に内蔵（1 ファイル完結） | CS-3 最小構成・間接参照の排除 |
| 3 | フォールバック先は `/atdd-kit:autopilot` | `/atdd-kit:defining-requirements <n>`（v1.0 の Step 1） | v1.0 体系整合 |
| 4 | `skill-status` フェンスブロックを出力 | 出力しない | v1.0 では skill-fix のみ必須（`docs/guides/skill-status-spec.md`） |

## Alternatives Considered

- **D1 代替: keyword 検出 + Y/n 確認付き提案も許す** — AC1 が禁止するのは独断開始のみで、確認付き提案は形式上許容範囲。しかし PRD Non-Goals が「keyword 検出による implicit 自動発動はしない」と明記しており、検出ロジック・確認ステップの追加は簡略性の原則にも反するため却下。
- **D2 代替: express skill 側の宣言のみで済ませる** — skill-gate は全ユーザメッセージで発火し、自身の SKILL.md のみを判定根拠とするため、未ロードの express 側宣言は参照されない。宣言だけでは AC8（ブロックしない）を構造的に保証できず却下。なお skill-gate はインフラ skill であり、PRD Non-Goals が凍結するのは 6-step フロー skill 群のみ。
- **D3 代替: ゼロから書き直す** — 旧実装は 1 度本番運用され（PR #129）、AC1〜AC7 は旧 #94 由来で骨格がそのまま対応する。書き直しは差分レビュー可能性を失うだけで利得がなく却下。
- **D3 代替: docs/guides/express-mode.md を復活させる** — 基準とフローが 2 ファイルに分かれ、参照切れ・更新漏れの面が増える。SKILL.md 200 行以内に収まる分量のため内蔵を選択し却下。

## Trade-offs

- **D1:** ユーザがコマンドを知らないと express を使えない（発見性の低下）。得るもの: AC1 違反リスクゼロと SKILL.md の単純さ。発見性は README / skill-gate の案内で補う。
- **D2:** skill-gate の編集はガバナンス機構への変更であり、誤った緩和は Iron Law を弱める。得るもの: AC8 の構造的保証。`tests/test_skill_gate_collision.bats` と `tests/test_express_skill.bats` の双方で分岐を固定し緩和を防ぐ。
- **D3-2（基準内蔵）:** 他プロジェクトのユーザ向け説明が SKILL.md 頼みになる。得るもの: 1 ファイル完結・参照切れゼロ。必要になれば後続 Issue で guide を分離できる（可逆）。

## Risks

- **skill-gate の express 分岐が広すぎる緩和になるリスク** — 「明示的 `/atdd-kit:express` 発動のみ」を分岐条件に固定し、BATS で keyword 起動を不在アサーションする。
- **express の運用で適用基準がなし崩しに広がるリスク** — AC9 の逸脱フォールバックと PR の `## Express Mode` 理由セクション（事後監査）で検知可能にする。
- **`express-mode` ラベル未整備のプロジェクトでの AC5 不成立リスク** — `commands/setup-github.md` にラベル作成を追加し、SKILL.md 側にも欠落時の `/atdd-kit:setup-github` 案内を置く。
