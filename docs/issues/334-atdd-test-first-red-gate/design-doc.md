# Design Doc: 決定的 red ゲートの証跡媒体と oracle 配線

本Issueは方向性（A=Hard / B=規模分岐 / C=明文化）が要件で確定済みだが、red ゲートを **deterministic** に成立させる具体手段には複数の選択肢があり非自明なトレードオフを含む。ここに決定と却下理由を記録する（PRD Open Questions の解決）。

## 決定 1: red 証跡の記録媒体

**論点**: 「新規 AT が実装着手前に red だった」をどの deterministic な信号で担保するか。

| 案 | 内容 | 利点 | 欠点 |
|----|------|------|------|
| 案A: commit 分離のみ | test コミットが impl コミットより祖先であることだけを検証 | 追加の記録媒体不要 | コミット順序は「red を踏んだ」ことを保証しない。test コミット時点で AT が緑だった可能性を排除できない（事後追認を検出できない） |
| 案B: red.jsonl 記録のみ | red exit を専用ログに記録、コミット順序は問わない | red exit を直接捕捉 | 記録のみではエージェントが impl 後に red ログを後付け捏造しうる（時系列の外部アンカーが無い） |
| **案C（採用）: commit 分離 ＋ 記録の両方** | test コミット先行 **かつ** test コミット時点の red exit 証跡の両方を要求 | コミット履歴（改竄困難な時系列アンカー）と exit code（red の実体）の双方で担保。AL-3 green ゲート（exit code 由来）と完全対称 | 実装がやや複雑（2信号の AND） |

**決定: 案C。** red ゲートの目的は「事後追認 AT の無検出量産を機械的に防ぐ」ことであり、単一信号は片方の捏造経路を残す。コミット分離（時系列の外部アンカー、AL-2 の pin と同じ思想）と red exit（AL-3 と同じ exit-code 由来）の AND で、LLM の自律判断を一切介さず deterministic に成立する。記録媒体は orchestrator 所有の `autopilot-log.jsonl` とは分離し、`red.jsonl`（または `step=red` 行）として `record_iteration` の fail-closed 規約を踏襲する。

## 決定 2: oracle への配線（既存ゲートを壊さない）

**論点**: redObserved を既存 satisfaction oracle にどう足すか。

- **採用**: 既存 `AND(atGreen, coverageOk, overall_correctness, P0/P1==0)` に `redObserved` を **AND 項として追加**（5項化）。impl phase のみ発火。
- **却下**: atGreen / coverageOk のロジック変更（PRD Non-Goal）。red ゲートは green ゲート（AL-3）の **対** として **追加** するのみで、既存判定そのものは不変。
- fail-safe: redObserved が取得不能・破損のときは false（収束不可）。AL-5 と整合し fail-open しない。

## 決定 3: B の分岐一次基準

**論点**: Gate③後の新ACを「小=design 差し戻し / 大=新Issue」に振り分ける一次基準。

- **採用**: 「**設計アンカー（pin）変更を伴うか**」を一次基準とする。アンカー不変で吸収できる少数ACは同一Issue内 design 差し戻し、アンカー変更を伴うまとまった新機能は新Issue。
- **却下**: AC 数の数値閾値を一次基準にする案。閾値は恣意的で陳腐化しやすく、AL-2（immutable anchor）の概念と直交しない。AC 数は補助的目安に留める。

## 決定 4: C の正典配置

- **採用**: 正典は `docs/methodology/autopilot-iron-law.md`。`rules/atdd-kit.md`（60行バジェット・毎ターン読込）からは1行で参照する。
- **理由**: 毎ターン読込の rules を肥大させず、詳細は methodology に集約する既存方針（DEVELOPMENT.md「Always-Loaded Rules Budget」）に従う。
