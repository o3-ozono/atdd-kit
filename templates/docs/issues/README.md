# docs/issues/ Artifact Templates

> **注意:** このディレクトリは GitHub Issue テンプレートではありません。`docs/issues/NNN/` に配置する artifact（PRD・User Stories・Plan・Acceptance Tests・Design Doc）のテンプレートです。GitHub Issue テンプレートは [`templates/issue/`](../issue/) を参照してください。

## テンプレート一覧

| ファイル | 用途 |
|---------|------|
| `prd.md` | PRD（Problem / Why now / Outcome / What / Non-Goals / Open Questions） |
| `user-stories.md` | User Stories（persona 抜き Connextra 形式 + Pichler 制約 Story） |
| `plan.md` | Plan（2-5 分粒度タスク + verification 交互配置） |
| `acceptance-tests.md` | Acceptance Tests（lifecycle: planned → draft → green → regression） |
| `design-doc.md` | Design Doc（Context / Goals / Proposal / Alternatives / Trade-offs / Risks） — **optional** |

## 使い方

新しい Issue `NNN` を開始するときに、必要なテンプレートを `docs/issues/NNN/` にコピーします。

```bash
cp templates/docs/issues/prd.md docs/issues/NNN/prd.md
cp templates/docs/issues/user-stories.md docs/issues/NNN/user-stories.md
cp templates/docs/issues/plan.md docs/issues/NNN/plan.md
cp templates/docs/issues/acceptance-tests.md docs/issues/NNN/acceptance-tests.md
# optional: trade-off / alternatives がある場合のみ
cp templates/docs/issues/design-doc.md docs/issues/NNN/design-doc.md
```

`NNN` は Issue 番号に置き換えてください（例: `docs/issues/184/prd.md`）。

## 各テンプレートの概要

### prd.md
PRD（Product Requirements Document）テンプレート。`## Problem` から `## Open Questions` までの 6 セクションに記入ガイドコメントが付いています。

### user-stories.md
User Story テンプレート。**persona 抜き Connextra** 形式（`I want to [goal], so that [reason].`）と Pichler 2013 形式の制約 Story（NFR を Story 形式で表現）の 2 種類を含みます。persona フィールドは v1.0 (#216 / #218) で廃止されました。

### plan.md
実装計画テンプレート。2-5 分粒度のタスク行（`- [ ] <task>`）と verification 行（`- [ ] verify: <condition>`）を交互に配置する superpowers writing-plans 形式です。

### acceptance-tests.md
Acceptance Test テンプレート。AT lifecycle（`[planned]` → `[draft]` → `[green]` → `[regression]`）の状態マーカーをチェックボックス形式で付与できます。

### design-doc.md（任意）
設計ドキュメントテンプレート。trade-off や alternatives の検討がある場合にのみ使用します。`## Context` から `## Risks` までの 7 セクション構成です。
