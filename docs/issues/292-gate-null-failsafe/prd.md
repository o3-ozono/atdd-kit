# PRD — autopilot Workflow の `agent()` null フェイルセーフ化（#292）

## 背景・問題

autopilot の Workflow スクリプト（`skills/autopilot/SKILL.md`）は、各 `agent()` 呼び出しの戻り値を null ガードせずに参照している。

ツール仕様上 `agent()` は次の場合に `null` を返す:

- ユーザーが途中でサブエージェントをスキップした
- terminal API エラー（モデルアクセス不可・プロバイダ側 transient 障害など）でサブエージェントが死亡した

別プロジェクト Issue #24 の impl phase 実走（2026-06-13）で、at-gate ステップのサブエージェントがセッションモデル（`claude-fable-5`）への terminal API エラーで死亡し、`agent()` が `null` を返した。スクリプトが `at.exitCode` を null ガードなしに参照したため、**workflow プロセス全体が `null is not an object (evaluating 'at.exitCode')` でクラッシュ**した。

```
Error: null is not an object (evaluating 'at.exitCode')
    at <anonymous> (workflow.js:123:19)
[at-gate:running-atdd-cycle] failed: There's an issue with the selected model (claude-fable-5).
```

## 根本原因

戻り値を参照する `agent()` 呼び出しが null ガードを欠く。スクリプトを精査すると、戻り値を参照する箇所は 5 つ（`gen` は戻り値未使用のため安全）。いずれも null で同一クラスのクラッシュを起こす。

| # | 呼び出し | 参照箇所 | null 時の現状 |
|---|---------|---------|-------------|
| 1 | `freeze:anchor` | `frozen.pinned` / `frozen.logLines` | クラッシュ |
| 2 | `review` | `verdict.findings` / `verdict.overall_correctness` | クラッシュ |
| 3 | `at-gate` | `at.exitCode` / `at.green` | クラッシュ（報告事象） |
| 4 | `coverage` | `cov.uncovered` / `cov.allCovered` | クラッシュ（報告事象の同系統） |
| 5 | `audit` / `rails` | `rec.recordOk` / `r.acDriftExit` 他 | クラッシュ |

## 影響

- 一時的なモデルアクセス障害（プロバイダ側 transient エラー、モデル切替の過渡期など）で、収束途中の run が**監査記録もされず・`COMPLETED_WITH_DEBT` にもならず**異常終了する＝フェイルセーフでない。
- `resumeFromRunId` で復旧は可能だが、ガードがあれば「その iteration を gate 未通過扱いにしてループ継続」でき、transient 障害が run 全体のクラッシュにならず収束ループ内で自然にリトライされる。

## スコープ（壁打ちで (B) 包括 に決定）

戻り値を参照する **5 箇所すべて**を null フェイルセーフ化する。各呼び出しの意味に応じた fail-safe セマンティクスを与える:

| # | 呼び出し | null 時のセマンティクス | 理由 |
|---|---------|----------------------|------|
| 1 | `freeze:anchor` | **フェイルクローズ** — `COMPLETED_WITH_DEBT`（step: `freeze`, reason: `freeze-error`） | anchor が確定できないまま走らせると AL-2 が崩れる |
| 2 | `review` | 「未収束」扱いでループ継続（`overall_correctness` 不一致＝not converged、findings 無し） | review の transient 死亡で run を落とさない。`check_max_iterations` が上限担保 |
| 3 | `at-gate` | gate 未通過（`atGreen = false`）でループ継続 | Issue 対処案どおり。transient リトライ |
| 4 | `coverage` | gate 未通過（`coverageOk = false`, `uncovered = []`）でループ継続 | 同上 |
| 5a | `audit` (`rec`) | **フェイルクローズ** — `COMPLETED_WITH_DEBT`（reason: `record-error`） | 監査記録（AL-4）が確定しないなら継続不可。既存の `recordOk!==true` 経路に null も合流させる |
| 5b | `rails` (`r`) | **フェイルクローズ** — halt（`COMPLETED_WITH_DEBT`、reason: `rails-error`） | レール判定を計算できないなら安全側で halt |

不変条件:「null は決して fail-open（収束/PASS とみなす）にしない」。ループ継続するケース（②③④）も `check_max_iterations` が無限ループを防ぐ。

### 非スコープ

- `agent()` のリトライ機構そのものの実装（ツール側責務）。
- gen 呼び出しの戻り値利用（現状未使用・変更不要）。
- gate のセマンティクス・オラクル論理の変更（null 経路の追加のみ）。

## Outcome（受け入れ基準の方向性）

- AC1: at-gate の `agent()` が null を返しても workflow はクラッシュせず、当該 iteration を「AT gate 未通過」として扱いループを継続する。
- AC2: coverage の `agent()` が null を返しても workflow はクラッシュせず、当該 iteration を「coverage gate 未通過」として扱いループを継続する。
- AC3: review (`verdict`) の `agent()` が null を返しても workflow はクラッシュせず、当該 iteration を「未収束」として扱いループを継続する。
- AC4: freeze (`frozen`) の `agent()` が null を返した場合、workflow はクラッシュせず `COMPLETED_WITH_DEBT`（reason 系: `freeze-error`）で安全に終了する。
- AC5: audit (`rec`) の `agent()` が null を返した場合、workflow はクラッシュせず `COMPLETED_WITH_DEBT`（reason: `record-error`）で安全に終了する。
- AC6: rails (`r`) の `agent()` が null を返した場合、workflow はクラッシュせず halt（`COMPLETED_WITH_DEBT`）で安全に終了する。
- AC7: いずれの null 経路も「収束済み / PASS」と誤判定しない（fail-open しない）。
- AC8: 変更は `skills/autopilot/SKILL.md` の Workflow スクリプトに反映され、`tests/test_autopilot_skill.bats` に null フェイルセーフの構造アサーションが追加され、既存 BATS スイートが green を維持する。
- AC9: SKILL.md は行バジェット（280 行）以内に収まる（in-line ガード中心で行数増を最小化）。

## 制約・参照

- `skills/autopilot/SKILL.md` への変更 ＝ DEVELOPMENT.md「Skill Changes Require Test Evidence」適用（BATS を変更前後で実行・green 維持）。
- SKILL.md 行バジェットは 280 行（既に 277 行・2 回引き上げ済みのため**第 3 回引き上げ不可**。超過時はローダ分割が必要 — 回避するため in-line 改変で行数増を抑える）。
- feature PR には version bump + CHANGELOG 更新が必須（DEVELOPMENT.md Versioning）。
- 関連: #288（同 #24 系セッションで遭遇した別系統の harness 欠陥 — log-integrity / findings 運搬）。
