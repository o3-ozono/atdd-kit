# Plan: defining-requirements / prd テンプレを 4 要素構造へ再編し問題定義品質規律を導入

<!-- 2-5 分粒度のタスク行と verification 行を交互に配置する（superpowers writing-plans 形式）。
     各タスクは単一の操作に限定し、verification で完了条件を即確認できる粒度にする。 -->

## Implementation

### A. テンプレ再編（US-1 / US-3 / CS-2 → `templates/docs/issues/prd.md`）

- [ ] `templates/docs/issues/prd.md` の見出しを新 4 要素構造へ置換する（`## 1. 基礎項目` / `## 2. 問題定義と背景` / `## 3. ゴールと成功指標` / `## 4. 機能要件` + `## Open Questions` を存続）
- [ ] verify: 5 見出しが順に存在し、旧 6 節見出し（Problem / Why now / Outcome / What / Non-Goals）が単独見出しとして残っていない（Open Questions のみ存続）

- [ ] `## 1. 基礎項目` にプロダクト名 / ターゲット / 制約のプレースホルダーと品質規律ガイダンス（コメント）を記述する
- [ ] verify: 基礎項目節にスコープ境界・前提制約を先頭固定するガイダンスコメントが存在する

- [ ] `## 2. 問題定義と背景` に「事実」欄と「課題」欄を明示的に分離したプレースホルダーと、事実/課題分離の品質規律ガイダンスを記述する（Why now は「今やる背景」欄として統合）
- [ ] verify: 「事実」欄と「課題」欄が別々の小見出し（または明示ラベル）として存在し、両者を分けて書く旨のガイダンスがある

- [ ] `## 3. ゴールと成功指標` に観察可能・外部視点の記述規律（Inspired Ch.7 参照）ガイダンスを記述する
- [ ] verify: 内部完了条件（「〜を実装する」等）を禁じ観察可能なゴールを求めるガイダンスコメントが存在する

- [ ] `## 4. 機能要件` に Non-Goals を「スコープ外」欄として統合し、優先度列（#367 方法論）のプレースホルダーを追加する
- [ ] verify: 機能要件節に「スコープ外」欄と優先度列プレースホルダーが存在する

- [ ] `## Open Questions` に Resolved / Unresolved を明示するガイダンス（未解決のみ列挙・[独自]）を追加する
- [ ] verify: Open Questions 節に Resolved/Unresolved 状態管理ガイダンスコメントがある

### B. 品質規律・anti-pattern 集の埋め込み（US-1）

- [ ] テンプレ内コメントに品質規律 4 原則（事実と課題の分離 / 1 PRD=1 本質課題 / 観察可能なゴール / 下流からの還流）を記述する（Inspired 由来と [独自] を明示）
- [ ] verify: 4 原則すべてがテンプレ内コメントに出現し、[独自] マーカーが該当 2 原則（1 PRD=1 課題・下流還流）に付いている

- [ ] テンプレ内コメントに anti-pattern 集（事実/課題混在・複数課題同居・内部完了条件ゴール・観察不可能な成功指標）を記述する
- [ ] verify: 4 種の anti-pattern が anti-pattern/warning コメントとして存在する

### C. 旧新対応表の埋め込み（US-3 / CS-2）

- [ ] 旧 6 節 ↔ 新 4 要素の対応表をテンプレ内コメントに記述する（Open Question 1 の Gate① 承認: テンプレ内コメント推奨。実装時に両案を評価し適切な方を選ぶ）
- [ ] verify: 旧 6 節（Problem/Why now/Outcome/What/Non-Goals/Open Questions）と新 4 要素の対応が読み取れる表がテンプレ内に存在する

- [ ] 既存 `docs/issues/*/prd.md`（旧 6 節形式）を書き換えていないことを確認する
- [ ] verify: `git status` 上、既存 Issue の prd.md に変更差分がない（後方互換 = CS-2）

### D. スキル更新（US-2 → `skills/defining-requirements/SKILL.md`）

- [ ] SKILL.md の Flow を新 4 要素構造の対話順へ更新し、4 原則に対応する問いかけを Step 毎に組み込む（1 質問ずつ・AskUserQuestion ルールは維持）
- [ ] verify: Flow の各 Section 問いかけが基礎項目 / 問題定義（事実・課題分離）/ ゴール（観察可能）/ 機能要件（優先度）に対応し、「1 質問ずつ」規律の記述が残っている

- [ ] SKILL.md 冒頭の「6 PRD sections」記述を新 4 要素構造の説明へ更新する
- [ ] verify: SKILL.md に旧「6 sections」を前提とする誤導表現が残っていない

## Testing

- [ ] `tests/acceptance/AT-366.bats` を新規追加し、テンプレ構造（4 要素見出し存在・事実/課題欄分離・anti-pattern 警告・旧新対応表・4 原則）を検証する（CS-1）
- [ ] verify: `bats tests/acceptance/AT-366.bats` が green（`bats tests/acceptance/` 全体も緑）

- [ ] SKILL.md が新 4 要素の対話規律を含むことを検証する AT を追加する（US-2 の証跡）
- [ ] verify: 該当 AT が green

## Finishing

- [ ] `CHANGELOG.md` の `[Unreleased]` に本変更を追記し、`.claude-plugin/plugin.json` の version を minor bump する（DEVELOPMENT.md Versioning 準拠）
- [ ] verify: plugin.json の version が CHANGELOG の最上位リリース見出しと一致し、既存の version 整合 AT が green

- [ ] ドキュメント整合性チェック（DEVELOPMENT.md / rules / docs で「PRD は 6 節」を前提にする箇所がないか）
- [ ] verify: 関連ドキュメントが 4 要素構造と整合し、旧 6 節前提の残存記述がない
