# PRD — autopilot / express 経路判定ルーティングステップ（#302）

## 背景・問題

Issue に着手する際の実行経路（`/atdd-kit:autopilot` フル ATDD 収束 か `/atdd-kit:express` ドキュメント級省略経路 か）の選択は、現状ユーザーの明示指定・判断に委ねられ、**タスク内容から適切な経路を判定するステップが存在しない**。

- **express**: 明示 `/atdd-kit:express <issue>` 起動 + APPROVAL-GATE（OK 基準提示→Y/n）+ scope-overflow abort + CI ゲート。NG 基準（新機能・挙動変更・CI/hooks・依存追加・セキュリティ）あり。
- **autopilot**: 明示起動 or キーワード検出（確認付き）。経路トリアージ無し。

### 既存のギャップ
- express は「risky を express でやる」誤りを NG 基準＋scope-overflow abort で**部分カバー済み**。
- 逆の「**doc-grade を autopilot でやる（過剰プロセス・高コスト）**」を防ぐ仕組みが無い。
- **Issue 選択時点での経路ヒント**が無い（どの Issue がどちらに向くか可視化されない）。

## スコープ（壁打ちで合意）

経路判定を **推奨レイヤ**として追加する。核となる設計判断（壁打ち確定）:

| 論点 | 決定 |
|------|------|
| Q1 置き場所 | **(a) session-start の Recommended Tasks に「推奨経路」列を追加**（Issue 選択時のヒント）**のみ**を本 Issue のスコープとする。**(b) autopilot 冒頭プリチェックは descope**（後述 budget 制約のため分割を伴う follow-up Issue #304 へ委譲） |
| Q2 判定主体 | **ハイブリッド** — Issue title/body/labels への LLM 判断を主とし、決定的ガードレール（labels・キーワード）を併用 |
| Q3 拘束力 | **推奨のみ（auto-route しない）**。express は AT/review を省くため誤自動ルートは危険。ユーザーが最終選択を保持 |
| Q4 既存トリガ整合 | express の明示起動 + APPROVAL-GATE + scope-overflow + CI を**温存**。推奨レイヤを足すだけでゲートは置換しない |

### 判定ヒューリスティック（Q2 詳細）
- **express 適格信号**: 変更が docs/README/typo/コメント/gitignore/version-bump のみで挙動変更なし（express OK 基準と一致）。
- **autopilot 信号**: コード/挙動変更・新機能・CI/hooks・依存追加・セキュリティ（express NG 基準と一致）。
- **曖昧時は安全側（autopilot=フルフロー）にフォールバック**（express の "when in doubt, full flow" と一致）。
- Issue 選択時点では diff が無いため、file-pattern より Issue テキスト＋labels 依拠。

## 重要制約 — autopilot SKILL.md 行バジェット（→ Q1b を descope）

`skills/autopilot/SKILL.md` は **279 / 上限 280 行**。DEVELOPMENT.md により**行バジェット引き上げは累計 2 回まで（240→260→280 で消化済み）＝第 3 回引き上げ不可**。Q1(b) の autopilot 冒頭プリチェックを SKILL.md 本文に足すと 280 行を超過し、ローダ分割（stub + `docs/methodology/` 詳細）が必須となる。これはサブタスク級の作業量で、本 Issue のコア価値（経路の可視化・誤経路抑制）とは独立。

**決定（ユーザー承認）: Q1(b) を本 Issue から descope し、autopilot SKILL.md には触れない。** 直接 `/autopilot <issue>` 起動時の express 適格プリチェックは、SKILL.md ローダ分割とセットで **follow-up Issue #304** に委譲する。本 Issue は session-start 推奨（Q1a）のみに集中する。

session-start 側（Q1a）は SKILL.md 行バジェット pin が無く、`tests/test_session_start_task_recommendation.bats` という追加先もあるため制約なし。

## Outcome（受け入れ基準の方向性）

- AC1: session-start の Recommended Tasks 出力に、各推奨 Issue の「推奨経路（autopilot / express）」が表示される。
- AC2: 推奨経路の判定がハイブリッド（決定的ガードレール: labels/キーワード + LLM 判断）で行われ、express 適格信号・autopilot 信号が定義どおりに分類される。
- AC3: 判定が曖昧な Issue は安全側（autopilot＝フルフロー）にフォールバックする。
- AC4: 推奨のみで auto-route しない（不変条件）。ユーザーが最終的に経路を選択する。
- AC5: express の既存トリガ（明示起動 + APPROVAL-GATE + scope-overflow + CI ゲート）は変更されない。
- AC6: skill 変更につき `tests/test_session_start_task_recommendation.bats` に推奨経路の構造アサーションを追加し、既存スイートが green を維持する（autopilot SKILL.md は本 Issue では変更しない）。
- AC7: version bump + CHANGELOG 更新（DEVELOPMENT.md Versioning）。

### 非スコープ
- **autopilot 冒頭プリチェック（Q1b）と autopilot SKILL.md ローダ分割** — follow-up Issue #304 に委譲。本 Issue では autopilot SKILL.md を変更しない。
- express 自体の OK/NG 基準・APPROVAL-GATE・scope-overflow ロジックの変更。
- 経路の自動実行（auto-route）。
- diff ベース判定（着手前の Issue 選択時点では diff が存在しないため）。

## 制約・参照

- `skills/session-start/SKILL.md`（Recommended Tasks / Task Recommendation Rules）, `skills/autopilot/SKILL.md`（Trigger）, `skills/express/SKILL.md`（OK/NG 基準）。
- skill 変更 = DEVELOPMENT.md「Skill Changes Require Test Evidence」適用。
- autopilot SKILL.md 行バジェット 280 行・第 3 回引き上げ不可。
- 派生元: #292 autopilot 実走中にユーザー提起。
