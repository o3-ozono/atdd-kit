# PRD — autopilot impl phase の Sonnet 指定を Workflow スクリプトに恒久反映

Issue: #311
関連: #259（モデル方針ベンチ）, #277（dogfood 継続ギャップ）, #297（直近の手修正実例）, #304（SKILL.md ローダ分割）

## 1. 背景・問題

モデル方針 #259 は「autopilot の **impl phase subagent（gen / review + 決定的ヘルパー）は Sonnet をデフォルト**（~1/4 コスト・同等品質）、design phase / orchestrator はセッションモデル維持」と定める。これは `skills/autopilot/SKILL.md` の**本文（Model assignment セクション）には記載済み**だが、**Workflow スクリプト本体には未反映**である。

スクリプト内の `agent()` 呼び出しには `model` opts が無いため、起動時はメインループ（セッションモデル＝Opus/Fable）を継承してしまう。結果、autopilot を実走するたびに**保存済みスクリプトを手修正**して `model: 'sonnet'` を注入する必要があり（#277 dogfood 以降の継続ギャップ、#297 実走でも再発）、方針とコードが乖離している。

## 2. ゴール

Workflow スクリプトに静的な Sonnet デフォルトを恒久反映し、autopilot 実走時にスクリプト手修正を不要にする。impl phase のループ内 subagent はスクリプト記述だけで Sonnet を使い、design phase / orchestrator はセッションモデルを維持する。

## 3. スコープ

### In scope
1. `const PHASE = A.phase` 直後に **`const MODEL = PHASE === 'impl' ? 'sonnet' : undefined`** を追加（1 行）。
2. impl phase でループする **6 つの `agent()` 呼び出し**（`gen` / `review` / `at-gate` / `coverage` / `audit` / `rails`）の opts に **`model: MODEL`** をインライン付与。
3. `freeze:anchor`（両 phase で走るオーケストレーション glue）は対象外 — MODEL 未付与でセッションモデル継承。
4. AT: `tests/test_autopilot_skill.bats` に string-pin（`PHASE === 'impl' ? 'sonnet'` の存在、6 箇所の `model: MODEL` 付与）と line budget（≤ 280）維持の検証を追加。

### Out of scope
- #259 の**エスカレーション**（Sonnet → セッションモデル one-way 昇格）の実装。本 Issue は静的デフォルト注入のみ。
- SKILL.md ローダ stub 分割（#304）。本変更は budget 内（下記）に収まるため不要。

## 4. 受け入れ基準（AC）

- **AC1**: SKILL.md の Workflow スクリプトに `const MODEL = PHASE === 'impl' ? 'sonnet' : undefined` 相当の定義が存在する。
- **AC2**: impl phase ループ内の 6 つの `agent()` 呼び出し（gen / review / at-gate / coverage / audit / rails）すべての opts に `model: MODEL` が付与されている。
- **AC3**: `freeze:anchor` の opts には `model` が付与されていない（design phase でセッションモデルを継承する）。
- **AC4**: SKILL.md の総行数が **280 行以下**を維持する（line budget pin、3 回目の raise 禁止）。
- **AC5**: 上記を検証する AT が `tests/test_autopilot_skill.bats` に追加され、緑になる。

## 5. 制約

- **行数バジェット**: SKILL.md は現 279 行・pin `≤ 280`。MODEL 定数 +1 行、6 箇所はインライン追記（純増 0 行）で**純増 +1 行 → 280/280** に収める。**3 回目の raise は禁止**（DEVELOPMENT.md）。
- i18n / language policy は DEVELOPMENT.md に従う。

## 6. 実現可能性の事前検証（確認済み）

- SKILL.md = 279 行、6 つの impl agent() 呼び出しを行番号で特定済み（203/205/210/217/235/242）。
- インライン追記で **280/280** に収まることを確認済み（budget 内・split 不要）。
