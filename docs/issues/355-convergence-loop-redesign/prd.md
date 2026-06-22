# PRD: autopilot 収束ループ＋review ラウンドの根本再設計 — done を堅牢に認識して止まる

> 統合: 本 #355 は #345「reviewing-deliverables の収束性改善（単一敵対レビュー → 多視点合議制 + 停止条件）」を集約する。#345 はクローズ済み、本 Issue を単一の真実源とする。

## Problem

**現状**: autopilot の収束ループは満足オラクル `AND(redObserved, atGreen, coverageOk, overall_correctness==correct, P0/P1==0)` の **全項が同時に真**になるまで `generate→review→fix` を回す。各 signal（review / 各 deterministic ゲート）は独立に veto 権を持ち、(a) **ゲート機構の自己検証失敗**（SHA 解決失敗・tooling 不全）と (b) **成果物そのものの未完成**（review findings / tests red）を区別しない。停止条件として機能するのは MAX_ITERATIONS（回数上限）のみ。

**困ること（同一根本の2つの顕在化）**:

1. **脆弱な deterministic ゲートによる veto（#341 で観測）**: red-gate（`lib/autopilot_convergence.sh` の `check_red_evidence`）が test/impl SHA を git log 考古学で解決しており、多イテレーションで false-negative 化。review が `correct`・findings ゼロ・AT 全 green（AT-341 49本 green、impact 104本 green/exit 0）でも `redObserved=false` がオラクルを veto し、8 イテレーション（約2時間）空転 → MAX_ITERATIONS halt。red.jsonl には赤観測記録が存在していた。
2. **review ラウンドが PASS に自然到達しない（#345 で観測）**: 敵対レビューは「常に何かを探す」性質ゆえ、前ラウンドの blocker を全解消しても別角度の新所見が湧き続け、設計判断の再掲・スコープ外指摘で FAIL が継続。停止条件がなく収束しない（stockbot-jp #7 で 4 ラウンド連続 FAIL、P0 数が 多→4→0→1 と振動、レビュー1回 ~6M トークン・~1時間）。

**共通の根本**: 収束ループに「done を堅牢に認識して止まる」機構がない。「review=correct かつ tests green かつ残るは機構問題のみ」という明白な done 状態を認識できず、単一の脆弱 signal の veto で空転する。

## Why now

#341（batch-discovery）の autopilot 実走で顕在化し、約2時間・大量トークンを空転で浪費した。autopilot / full-autopilot は本プロジェクトの自律実行基盤であり、収束しないループはすべての自律フローのコスト・信頼性・体験を直接毀損する。triggering instance（red-gate の SHA 考古学解決）は記録方法が変わらない限り今後の全 autopilot 実行で再発し続ける。

## Outcome

完了時に達成されている状態（3層）:

1. **収束ループ／オラクルの再設計（ループ層）**: 「成果物が未完成」と「ゲート機構が自己検証できない」を**別クラスの停止理由**として扱う。後者は MAX まで空転させず、`gate-unverifiable`（仮称）として**早期に distinct な escalation** で人間へ手放す。demonstrably done（review PASS ＋ tests green）が単一の脆弱 signal に veto されて空転しない。
2. **review ラウンドの再設計（レビュー層 — 旧 #345 を集約）**:
   - 多視点合議制: 独立した複数パネル（機能正当性 / 安全性 / 設計妥当性）を並列実行し、**N/3 以上が同一所見を blocker/major と判定した場合のみ採用**。単一レンズの単独判定は severity を一段下げる。
   - 収束／停止条件: ラウンドをまたいで所見を追跡し、(a) 新規 blocker/major がゼロ、または (b) 残存が「設計判断」「スコープ外」タグのみ、で **CONVERGED（条件付き PASS）**。最大ラウンド数の上限も設ける。
   - スコープガード: Scout が Issue の PRD/US から境界を抽出し、対象外ファイル/関心事の所見は `out-of-scope` として分離（FAIL 要因にせず follow-up 起票候補へ）。
   - 設計判断の明示的扱い: 実装側が docstring/ADR で「意図的トレードオフ」と宣言した点は、合議で「設計として不当」と判定されない限り再提出しない（解決済み/意図的を round 間で記憶）。
   - severity 較正の単一化: レンズ横断で同一所見をマージしてから 1 回だけ severity を付ける（レンズ別重複付与を排除）。
3. **red-gate の堅牢化（triggering instance の修正）**: SHA を git log 考古学で推測せず、`running-atdd-cycle` が red 観測時点で test/impl SHA を red.jsonl に直接記録し、gate はそれを読むだけにする。deterministic に `redObserved=true` を確定。

**測定可能な合否**: #341 / #345 の再現シナリオで、(a) demonstrably-done（review correct ＋ tests green）が単一の脆弱 signal に veto されて MAX 空転しない、(b) 機構の自己検証失敗が `gate-unverifiable` で早期 escalation される（MAX_ITERATIONS まで回さない）、(c) review ラウンドが「新規 blocker/major ゼロ」または「設計判断/スコープ外のみ残存」で有限ラウンド内に CONVERGED へ到達する。

**期待効果**: 収束性の確保（無限ラウンド・MAX 空転の回避）と収束時間・トークンコストの大幅削減／「実バグ」と「設計トレードオフ・スコープ外」の分離によるマージ判断の明確化／偽陽性抑制（合議）と再現性（deterministic ゲート）の両立。

## What（スコープ内）

- `lib/autopilot_convergence.sh` — `check_red_evidence` の SHA 解決を red.jsonl 直接記録ベースに変更。オラクル／停止条件のレール（機構失敗 vs 未完成の分類、`gate-unverifiable` 早期 escalation）。
- `skills/autopilot/SKILL.md` — オラクル定義・停止理由の分類・review ラウンド呼び出しの更新。
- `skills/reviewing-deliverables/SKILL.md` — 多視点合議制＋停止条件・スコープガード・設計判断記憶・severity 較正。
- `skills/running-atdd-cycle/SKILL.md` — red.jsonl への test/impl SHA 記録契約。

## Non-Goals

- **#334 が確立した red-first 方針そのもの** — 変更しない。red 観測の必須性（AT が impl 前に赤）は維持し、その**記録方法のみ**堅牢化する。
- **coverage-gate / atGreen の判定ロジック本体** — オラクルの構成要素としては残すが、これらの内部判定アルゴリズムは本 Issue の再設計対象外。
- **3ゲート（AL-1）の構造変更** — User gate の数・位置は変えない。停止理由の分類と escalation の早期化のみ。

## Open Questions

1. **スコープ分割**: 3 サブ変更（ループ層オラクル再設計／レビュー層合議制／red-gate 堅牢化）を 1 Issue・1 PR でまとめるか、triggering instance である red-gate 堅牢化（確実・低リスク）を先行分離するか。Issue 本文は全て in scope と明記しているが、本変更は **autopilot 自身を autopilot で改変する**自己改変であり、3層同時はレビュー・検証の難度とリスクが高い。
2. **合議パネル構成**: パネル数 N=3（機能正当性 / 安全性 / 設計妥当性）・採用閾値 2/3（majority）で確定してよいか。
3. **`gate-unverifiable` の名称と手放し挙動**: 機構自己検証失敗時（review correct ＋ tests green、残るは機構問題のみ）は auto-converge せず人間 escalation で確定してよいか（Issue は escalation 指定）。停止理由の正式名称は `gate-unverifiable` でよいか。
