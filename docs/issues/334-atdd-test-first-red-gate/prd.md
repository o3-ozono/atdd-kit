# PRD: ATDD の test-first（AT red 先行）を構造的に担保する

## Problem

ATDD の中核である test-first（AT を red にしてから実装で green にする）が、atdd-kit のフロー上で構造的に担保されていない。

**現状:**

- `running-atdd-cycle` の impl phase は gen サブエージェント（LLM）任せで、red 先行を機械的に検証するガードが無い。
- autopilot の AT gate（AL-3）は「最終的に green か」だけを exit code で見る。red を一度も踏まずに green でも検出できない。
- impl は 1 コミットに test と実装が混在しうるため、コミット履歴からは red→green の順序を検証できない。
- autopilot のライフサイクルは「near-green を Gate③（マージ）に渡す」で終端し、Gate③後のユーザー実機フィードバックで新しい振る舞い（新AC）が判明した場合の正規ルートが未定義。

**それによって何が困るか:**

- AT が「実装の事後追認」になりうる。実際に stockbot-jp ダッシュボード刷新の autopilot 実走（観測日 2026-06-18）の impl phase transcript で、機能 F1（マーケット時刻ヘッダ）が `実装 → test → pytest` の順で **red を一度も踏んでいない**（test-first 違反）一方、F2〜F5 は遵守、という混在が確認された。同一セッション内でも守る/守らないがブレる。
- Gate③後フィードバックの正規ルートが無いため、オーケストレータ（メインループ）が autopilot の外で実装を先行させ AT を後付けする逸脱が起きた。「効率（session limit / トークン / 速さ）を理由に正道を飛ばす」誘惑がこれを後押しした。

## Why now

- autopilot / full-autopilot が無人運転フェーズに入り（#318/#319/#329/#331/#335）、人間の目視が減る分、test-first の機械的担保が無いと「green だが事後追認の AT」が無検出で量産されるリスクが構造的に拡大している。
- 直近の実走（stockbot-jp）で実害（test-first 違反の transcript）が観測され、根本原因が「エージェント自律任せ」「ライフサイクルの終端設計」「明文ルールの不在」の3点に特定できた。設計が機械的ガードに踏み込める機が熟した。

## Outcome

完了時、以下が機械的・規範的に担保されている:

- **A（red ゲート / Hard）**: 新規 AT 追加時、実装着手前に当該 AT を実行し **red（非0 exit）を deterministic に記録しなければ impl phase が前進・収束できない**。red 証跡が無い限り satisfaction oracle は満たされない。test コミットと impl コミットの分離を必須化し、`red→green` の粒度をコミット履歴から機械検証できる。AL-3（green ゲート）と対称の deterministic gate として成立する。
- **B（Gate③後ルート / 規模で使い分け）**: autopilot ライフサイクルに「Gate③後フィードバックで新ACが生じたときの正規ルート」が明記される。**小規模（設計アンカー不変・少数AC）は同一Issue内の design 差し戻し、大規模（設計アンカー変更を伴う・まとまった新機能）は新Issue**、という分岐基準が methodology / autopilot-iron-law に明文化される。
- **C（横断ルール）**: 「効率（session limit / トークン / 速さ）は test-first 逸脱の理由にしない」が Iron Law / rules に明記される。

測定可能な合否:

- `running-atdd-cycle`（または AL-3 の対）に red 先行を機械検証する手順/ガードが存在し、red 証跡なしでは収束しないことがテストで担保される。
- autopilot ライフサイクルの「Gate③後フィードバック→新ACの正規ルート」が分岐基準つきで文書化される。
- 「効率は test-first 逸脱の理由にしない」が Iron Law / rules に文言として存在する。

## What

A/B/C の3点を本Issueに統合して対応する（同一の根「test-first が守られない」に帰着するため）。

- **A. 決定的 red ゲート（Hard）**
  - 新規 AT について、実装前に当該 AT 単体を実行し red（非0 exit）を記録する deterministic gate を導入。
  - red 証跡を satisfaction oracle の必須条件に組み込む（AL-3 green ゲートの対）。
  - test コミットと impl コミットの分離を必須化し、コミット履歴から `red→green` 粒度を機械検証可能にする。
  - `running-atdd-cycle` の手順と、autopilot のオーケストレーション（AL-3 周辺）に配線する。
- **B. Gate③後フィードバックの正規ルート（規模で使い分け）**
  - autopilot-iron-law / autopilot-overview 等の methodology に、Gate③後の新ACを「直接実装しない」ことと、規模による分岐（小=design 差し戻し / 大=新Issue）の判断基準を明文化。
- **C. 効率は逸脱理由にしない（横断ルール）**
  - Iron Law（`docs/methodology/autopilot-iron-law.md`）/ `rules/atdd-kit.md` に「効率を理由に test-first を飛ばさない」旨を追記。

## Non-Goals

- **red ゲートの soft 運用（記録要求＋レビュー指摘止まり）** — Hard（決定的ブロック）を採用したため、soft 版は実装しない（機械的担保が本Issueの目的の核であり、警告止まりでは根本解決にならない）。
- **Gate③後ルートを「常に新Issue」または「常に design 差し戻し」に一本化すること** — 規模で使い分ける方針のため、片方への一本化はしない。
- **既存の green ゲート（AL-3）/ coverage ゲート（AL-2）のロジック変更** — red ゲートは対として追加する。既存ゲートの判定そのものは変更しない。
- **過去にマージ済みの AT の遡及的 red 検証** — 本Issue以降に追加される新規 AT を対象とする。

## Open Questions

設計フェーズ（writing-plan-and-tests）で詰める論点。要件レベルでは A=Hard / B=規模分岐 / C=明文化 で確定済み。

- red 証跡の記録媒体: autopilot-log.jsonl への red 記録行か、コミット分離（test コミットの存在＋当時の red exit）か、両方か。
- 「新規 AT」の判定方法: acceptance-tests.md の AC 差分から導出するか、AT ファイルの追加検出か。
- B の分岐基準の具体的閾値（「設計アンカー変更を伴うか」を一次基準とするか、AC 数の閾値も併用するか）。
- C の文言を Iron Law と rules のどちらに正典として置き、もう一方から参照するか。
