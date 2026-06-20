# PRD: acceptance test の「計画前 feasibility 実地探索」を正典フローとして確立する

## Problem

**現状**: atdd-kit の 6-step flow では、`writing-plan-and-tests`（Step 3）で acceptance test（AT）を `[planned]` として机上で計画し、実際に検証手段が成立するかは `running-atdd-cycle`（Step 4、実装フェーズ）に入って初めて確かめられる。AT は技術スタックに依存しない普遍ルールとして `docs/methodology/` に明文化されておらず、「どう実地検証するか」は暗黙知に留まっている。

**それによる痛み**: 計画した AT が実装フェーズで初めて「実は検証手段が無い／不安定（GUI 要素にアクセスできない・API が想定の契約を返さない・フローが再現しない）」と判明し、計画への手戻りが発生する。手戻りは Step 3 へ巻き戻るため、autopilot では design phase のやり直し（Gate ② 再承認）まで波及しコストが大きい。

## Why now

#329 の調査で full-autopilot の手戻りコストが使い勝手の主要因と判明しており、計画段階で feasibility を前倒し検証する原則は手戻り削減の効くレバーである。また AT の実地検証方針が暗黙知のままだと、addon（ios / web）が増えるほど各スタックで再発明が起き、方針のばらつきが拡大する。普遍ルールとして今のうちに正典化することで、以降の addon・skill 拡張がこの原則に乗れる。

## Outcome

完了時に達成されている状態:

- `docs/methodology/` 配下に AT feasibility の**正典ドキュメント**（ファイル名案: `acceptance-test-feasibility.md`）が存在し、以下を最低限含む:
  1. **普遍ルール** — 技術スタック非依存の「計画前 feasibility 実地探索」原則。GUI=実操作（Claude が UI を実際に操作）／非 GUI=実 API call の二分岐と、その判定基準。
  2. **フロー統合点** — 6-step flow のどこに差し込むか（AT を `[planned]` 確定にする前に feasibility プローブを通す）。
  3. **ユーザーゲート** — 実現可能ルートが見つからない／不安定なときに計画段階でユーザー判断を仰ぐゲート設計。
  4. **ツール抽象** — Playwright CLI / Xcode MCP / API client 等を「feasibility プローブ」という抽象で扱い、addon が具体手段を供給する形（特定ツールに密結合しない）。
  5. **autopilot との整合** — autopilot design phase の中で feasibility プローブをどう走らせ、Gate ②（設計承認）にどう反映するか。
- 既存 methodology doc（`atdd-guide.md` / `test-mapping.md` / `definition-of-ready.md` / `test-execution-policy.md` 等）と矛盾せず、相互参照が張られている。
- 外部調査（agentic E2E / self-verifying AC / browser・mobile UI agent / API 探索検証）の傾向・採用事例・落とし穴が doctrine の根拠として要約・引用されている。
- `reviewing-deliverables` のレビューを PASS する（doctrine の内部整合・既存正典との非矛盾）。

## What

スコープは **調査 → 方針確立** まで（実装は派生 Issue）。

1. **既存資産の棚卸し（前提調査）** — `docs/methodology/`、`skills/launching-preview` / `running-atdd-cycle` / `writing-plan-and-tests`、過去調査（`docs/issues/278-skill-e2e-model-sonnet/`、`docs/issues/222-skill-test-redesign/`）、addon（ios / web）の MCP・preview 構成を棚卸しし、doctrine の土台にする。
2. **外部調査（deep-research ハーネスで徹底調査）** — GitHub 上の類似スキル・エージェント方法論を deep-research ハーネス（fan-out web 検索・多源裏取り・レポート化）で大量に調査。agentic E2E test 計画 / self-verifying acceptance criteria / Playwright・browser-use 系エージェント / Xcode・モバイル UI 自動操作エージェント / API 探索→契約検証 を対象に、「計画前の feasibility 実地探索（エージェントが実際に操作してルート確定）」採用の有無・パターン・落とし穴を抽出する。
3. **正典ドキュメントの執筆** — 上記 Outcome の 5 セクションを満たす doctrine を `docs/methodology/` に置き、既存 doc との相互参照を張る。

## Non-Goals

- **各 addon への具体的な feasibility プローブ実装** — 本 Issue は方針確立まで。具体手段（Playwright CLI ラッパ・Xcode MCP プローブ等）の実装は派生 Issue。理由: 方針が固まる前に実装するとツール密結合の温床になる。
- **既存 AT の全面書き換え** — 既存 AT への遡及適用は対象外。理由: doctrine 確立とリグレッションリスクを分離する。
- **skill / flow への配線実装** — doctrine は統合点を*記述*するが、`writing-plan-and-tests` 等への実際のコード/手順配線は派生 Issue。理由: 方針承認前の配線は手戻りを生む。

## Open Questions

- feasibility プローブの統合点は `writing-plan-and-tests` の **前段** か **内部** か — 外部調査と既存フロー分析を踏まえ doctrine 内で推奨を提示し、Gate ②（設計承認）でユーザーが確定する（事前確定はしない）。
- 本 doctrine の AT（atdd-kit 自身の受け入れ条件）をどう構成するか — doc-only 成果物のため、必須セクションの存在・既存 doc との相互参照健全性を検証する構造テスト（bats）を `writing-plan-and-tests` で設計する。
