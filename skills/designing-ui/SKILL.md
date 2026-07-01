---
name: designing-ui
description: "Use when a feature has UI/UX to design — after PRD approval, drive UI requirements, information architecture, wireframes, visual policy, and implementation handoff through pull-style dialogue."
---

## Session Start Check (required)

If `session-start` has not run in this session, run `/atdd-kit:session-start` first.

# Designing UI Skill — UI/UX 設計フロー

`defining-requirements` で PRD が承認された後、機能要件を画面へ落とし込む UI/UX 設計工程を駆動する。5 フェーズ（UI 要件確認 → 情報設計 → ワイヤーフレーム → ビジュアル方針 → 実装連携）を**引き出し型（pull）**の対話で順に進め、各フェーズの成果物を書く。

**Scope は UI 設計成果物に限る。** コード実装・Acceptance Test 実装・Plan 作成は担わない。技術アーキテクチャのトレードオフ記録は `writing-design-doc` が担う。

## Trigger

- **Explicit:** `claude skill atdd-kit:designing-ui <issue-number>`
- **Keyword-detected (confirm before invoking):** ユーザーメッセージが UI/UX 設計意図を示すとき（例: "UI 設計", "ワイヤー", "画面設計", "情報設計"）、開始前に `Run designing-ui skill on <issue>? Y/n` と確認する。

## Input

- Issue number
- `docs/issues/<NNN>/prd.md`（承認済み PRD。機能要件の出発点）

## 中核思想

- **何を出すか（概念・コンテンツ）はプロダクト側（PRD）が決める。** このスキルは問いで引き出すだけで、勝手に補わない。
- **どう見せるか（実装の作法）は対象プラットフォームの規約に従う。** iOS/macOS は HIG、Android は Material Design、Web は Baseline。既存の Design system があれば再利用する。
- **独自判断は `[独自]` と明示する。** 規約に根拠がない意思決定は、規約からの逸脱だと分かるようにマークする。
- **アクセシビリティ（WAI-ARIA / WCAG 2.2 / JIS Z 8520）はフェーズ横断の哲学である。** 後付けの監査項目ではなく、ワイヤーフェーズから組み込む。

## 5 フェーズ（引き出し型・順次進行）

各フェーズは一問一答の pull 対話で進める。作り手の頭の中にある設計判断を、問いを立てて引き出す。

| # | フェーズ | 成果物 | 主な問い |
|---|----------|--------|----------|
| 1 | UI 要件確認 | `docs/issues/<NNN>/ui-requirements.md` | 各機能要件はどの画面に対応するか？ |
| 2 | 情報設計 | `docs/issues/<NNN>/information-architecture.md` | 画面の単位・階層・遷移は？（ワイヤー着手前に画面単位を確定する） |
| 3 | ワイヤーフレーム | `docs/issues/<NNN>/wireframes.md` | 骨格・配置・遷移は？（装飾を含めない。アクセシビリティをここから組み込む） |
| 4 | ビジュアル方針 | `docs/issues/<NNN>/visual-policy.md` | プラットフォーム / Design system の選択根拠（HIG / Material Design / Baseline 参照）は？ |
| 5 | 実装連携 | `docs/issues/<NNN>/implementation-handoff.md` | コンポーネント・トークン・アクセシビリティ注記の handoff 粒度は？ |

## Flow

1. **UI 要件確認。** PRD の機能要件を1件ずつ確認し、対応する画面を問いで引き出す。`ui-requirements.md` に機能要件↔画面の対応表を書く。
2. **情報設計。** 画面の単位・階層・遷移を確定する。**画面の単位はここで確定し、ワイヤーに進む前に固める。** `information-architecture.md` に書く。
3. **ワイヤーフレーム。** 骨格・配置・画面遷移を ASCII / Mermaid 等で記述する。**装飾（色・フォント・余白）はこのフェーズに含めない。** アクセシビリティ（WAI-ARIA ロール等）をここから組み込む。`wireframes.md` に書く。
4. **ビジュアル方針。** 対象プラットフォームの作法（HIG / Material Design / Baseline）と Design system 選択の根拠を記録する。独自判断は `[独自]` と明示する。`visual-policy.md` に書く。
5. **実装連携。** コンポーネント・トークン・WCAG 2.2 達成基準・JIS Z 8520 注記を含む handoff メモを書く。`implementation-handoff.md` に書く。

## Output

| フェーズ | Artifact |
|----------|----------|
| UI 要件確認 | `docs/issues/<NNN>/ui-requirements.md` |
| 情報設計 | `docs/issues/<NNN>/information-architecture.md` |
| ワイヤーフレーム | `docs/issues/<NNN>/wireframes.md` |
| ビジュアル方針 | `docs/issues/<NNN>/visual-policy.md` |
| 実装連携 | `docs/issues/<NNN>/implementation-handoff.md` |

**Output language: Japanese (fixed).**

## Responsibility Boundary

| Concern | Owner |
|---------|-------|
| 画面設計の工程駆動（UI 要件〜実装連携） | **designing-ui**（このスキル） |
| 技術アーキテクチャのトレードオフ記録 | `writing-design-doc` |
| コード実装・Acceptance Test 実装・Plan 作成 | このスキルは担わない — `writing-plan-and-tests` / `running-atdd-cycle` |
| PRD → 機能要件 | `defining-requirements` |

このスキルは UI 設計成果物のみを生成する。コード実装・Acceptance Test（AT）実装・Plan の作成は担わない。

## Integration

- **Upstream:** `defining-requirements`（承認済み PRD を入力とする）
- **Downstream:** `writing-plan-and-tests`（UI 設計成果物を Plan + AT 作成の入力として渡す）
