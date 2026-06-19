# PRD: flaky-test-fix 専用の軽量ルート（bugfix ルートの兄弟）

## Problem

#308 で確立した **bugfix 軽量ルート（`fixing-bugs`）** は「決定的に再現する欠陥」を前提に設計されている。`debugging` の再現工程は **1回ツールを動かせば赤が出る**ことを暗黙の前提にし、cause-agreement ゲートのアンカーも「単一の failing test（赤→緑）」を想定する。

しかし **flaky test（確率的に失敗するテスト）** はこの前提を満たさない:

- **再現が確率的** — 1回の実行では赤が出ないことがあり、「再現確認（firsthand 証拠）」が単発実行では成立しない。N回ループ / seed 固定 / 並列度・実行順の変動などの統計的再現手段が要る。
- **原因が非決定性カテゴリ** — タイミング依存・順序依存・共有状態・外部依存・リソースリーク等。`debugging` の Type A/B/C 分類はロジック欠陥向けで、非決定性の原因軸を直接は表現しない。
- **quarantine 判断が欠落** — flaky は「直すまで CI をブロックし続ける」か「一時隔離して他作業を止めない」かの運用判断を伴うが、bugfix ルートにその居場所がない。

結果として、flaky test を bugfix ルートに通すと「再現できないので診断に進めない」「単発赤テストをアンカーにできない」で詰まる。

## Why now

- **土台が今そろった** — #308 で bugfix 軽量ルート（`fixing-bugs` ＋ cause-agreement ゲート ＋ Type 分類 ＋ 再現2層配線）が実装・マージ済み（#321）。#308 PRD が flaky を「診断/回帰の背骨を bugfix で先に確立してから載せる方が土台が安定する」として明示的に defer しており、その前提条件が満たされた**直後の今**が着手の正当なタイミング。
- **atdd-kit 自身に実需がある** — 影響度ベース並列ランナー（#324/#325）やキュー方式 full-autopilot（#318/#319）など並列・非決定実行の比重が増しており、テスト並列度・実行順依存に起因する flaky が今後構造的に増えやすい。flaky 対応ルートを今整備すれば以後の全 flaky 対応に効く。
- **defer の解消責務** — #308 が half-scope で User に明示確認して本 Issue に積んだ宿題であり、放置するとルーティング SoT（`route-eligibility.md`）に「bugfix はあるが flaky は未定義」の穴が残り続ける。

## Outcome

完了時に以下が達成されている:

- **flaky-test-fix 専用の軽量ルートが存在する** — bugfix ルートと同じ「既存スキル再利用のみ・新規メソドロジーなし」方針で、`確率的再現の確認 → 非決定性の原因分類 → 決定化する最小修正 → 反復検証で green 安定` の最短工程で回る。PRD / User Stories / Plan の作成はスキップする。
- **確率的再現が実ツール駆動で定義される** — 単発実行ではなく **N回反復実行（または seed/順序/並列度の変動）** で flaky を firsthand に確認し、「失敗率」を証拠として記録する工程が明示される。
- **cause-agreement ゲートが flaky 用にアンカーされる** — 中間 User ゲートのアンカーが「単一の赤テスト」ではなく **「非決定性の原因分類 ＋ 反復実行での失敗率（修正前 X% → 修正後 0%）」**。AL-1（中間ゲートを消さない）を維持する。
- **収束オラクルが反復ベース** — autopilot 収束判定 = **N回連続 green（決定化の確認）＋ 既存テスト非破壊**。単発 green では収束としない。
- **quarantine（隔離）判断がルートに組み込まれる** — 即時修正が困難な flaky を一時隔離（skip/quarantine マーク）して他作業をブロックしない判断ポイントが定義され、隔離した場合も追跡（再 dispatch / Issue 残置）される。
- **ルーティング SoT に flaky シグナルが追加される** — `route-eligibility.md` が flaky を判定し、明示コマンド（例 `/atdd-kit:flaky-fix` ないし既存 `/atdd-kit:autofix` への相乗り）で起動できる。

## What

スコープ内（flaky-test-fix ルートのみ。bugfix ルートは #308 で実装済み・再編集しない）:

1. **専用オーケストレーションスキルの新設**（仮称 `skills/fixing-flaky-tests`）。`fixing-bugs` と同じく **既存スキルを束ねるだけ**の薄いオーケストレータで、新規メソドロジー・ステップを足さない。チェーンは bugfix と同じ5スキル骨格 `bug → debugging → running-atdd-cycle → reviewing-deliverables → merging-and-deploying` を再利用し、`defining-requirements` / `extracting-user-stories` / `writing-plan-and-tests` をスキップ。forward-chain override も `fixing-bugs` と同じ方式で `bug` を無編集のまま迂回する。

2. **確率的再現工程の配線（flaky 特化の2層）** — `fixing-bugs` の「再現2層」を flaky 用に差し替える:
   - **2a. 確率的再現の確認** — 単発ではなく **N回反復実行 / seed・実行順・並列度の変動** で flaky を firsthand 確認し、**失敗率**を記録（platform-aware: other=bats/スクリプトのループ実行、web=Playwright CLI 反復、iOS=Xcode/simulator MCP 反復、いずれも外部ツール参照）。
   - **2b. 反復で観測可能な failing アンカー** — 確認した非決定性を「反復実行で一定確率赤になる」実行可能アンカーに符号化（修正後は N回連続緑で決定化を確認）。

3. **非決定性の原因分類**（`debugging` の Type 分類を flaky 軸で運用）— タイミング/順序依存/共有状態/外部依存/リソースリーク等の非決定性カテゴリで根本原因を特定。`debugging` 本体は無編集で、分類の **flaky 向け運用ガイダンスはオーケストレータ側に置く**（重複ゼロ）。

4. **cause-agreement ゲートの flaky 用アンカー** — 中間ゲートのアンカー = 「非決定性分類 ＋ 失敗率（前→後）」。`debugging` Step 5 の `Proceed to fix?` 確認を流用。

5. **quarantine（隔離）判断ポイント** — 即時決定化が困難な場合に一時隔離（skip/quarantine マーク）して他作業をブロックしない判断と、その追跡（Issue 残置 / 再 dispatch）をルートに組み込む。

6. **ルーティング拡張** — `route-eligibility.md` に flaky シグナル（ラベル `type:flaky` 等＋キーワード `flaky` / `不安定` / `間欠的に失敗` / `intermittent`）を追加し、明示コマンドを併設。低確信時は #305 ワンタップで User 確認。

7. **autopilot 対象化** — 収束オラクル = `N回連続 green ＋ 既存テスト非破壊`。User gate は最小（原因合意＋マージ）。

## Non-Goals

- **既存 `bug` / `debugging` / `running-atdd-cycle` / `reviewing-deliverables` / `merging-and-deploying` の本質的書き換え** — 再利用のみ。flaky 特化の追補はすべて新オーケストレータ側に置く（#308 と同じ重複ゼロ方針）。
- **`fixing-bugs`（bugfix ルート）の再設計** — 本 Issue は flaky 専用ルートの新設であり、bugfix ルートは無編集の兄弟ルートとして残す。
- **新規メソドロジー・診断アルゴリズムの発明** — 非決定性の原因分類も反復再現も既存 `debugging` / 既存テストランナーの再利用で賄い、新しい理論は足さない。
- **flaky の自動検出・常時監視システム** — CI ログから flaky を自動採掘して Issue 化する仕組みは対象外（本ルートは「flaky と分かった Issue を直す」工程に限定）。次 Issue 候補。
- **テストランナー / 並列ランナー（#324/#325）の改修** — 反復実行は既存ランナーの呼び出しで賄い、ランナー自体は変更しない。
- **マージの自動化** — マージは常に User gate（AL-1）を維持。flaky ルートでも自動マージしない。

## Open Questions

- 新オーケストレーションスキルの正式名称（`fixing-flaky-tests` / `flaky-fix` / `defixing-flaky` 等）— plan で確定。
- 起動口を **新コマンド `/atdd-kit:flaky-fix`** にするか、既存 **`/atdd-kit:autofix` に相乗り**（サブモード）させるか — plan で確定。
- **反復再現の回数 N と判定基準** — 再現確認の試行回数、収束オラクルの「N回連続 green」の N、失敗率のしきい値（何%以上を flaky 確定とするか）— plan で確定。
- **platform: other（atdd-kit 自身を含む bats プロジェクト）** での反復実行の具体手段（bats のループ / seed 注入 / 実行順シャッフルのどこまでを必須とするか）— plan で確定。
- **非決定性の原因カテゴリの確定セット** — タイミング/順序/共有状態/外部依存/リソースリーク等、`debugging` の Type A/B/C にどうマッピングするか（Type C 配下のサブ軸にするか別軸を足すか）— plan で確定。
- **quarantine の具体的マーク手段と追跡** — skip マークの付け方（bats の skip / タグ）、隔離後の Issue 残置 vs 再 dispatch の運用 — plan で確定。
- **ルーティングしきい値** — flaky と通常 bug の境界、誤判定時の User 確認フロー — plan で確定。
