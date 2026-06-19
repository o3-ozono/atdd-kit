# Plan: flaky-test-fix 専用の軽量ルート（bugfix ルートの兄弟）

<!-- 2-5 分粒度のタスク行と verification 行を交互に配置する（superpowers writing-plans 形式）。
     各タスクは単一の操作に限定し、verification で完了条件を即確認できる粒度にする。 -->

方針: #308 の `fixing-bugs`（bugfix ルート）と同じく **新規メソドロジー・ステップ・診断ロジックは増やさず、既存スキルの再利用のみ**で構成する。新設するのは (a) 軽量オーケストレーションスキル `skills/fixing-flaky-tests/SKILL.md` 1 つ、(b) `docs/methodology/route-eligibility.md`（ルーティング SoT）への flaky ルート判定追記、(c) 明示コマンド `commands/flaky-fix.md`、(d) `docs/methodology/autopilot-iron-law.md` ＋ `docs/methodology/autopilot-design-gate.md` への flaky 特化条項（cause-agreement ゲートの反復アンカー化＋反復ベース収束オラクル）、のみ。`bug` / `debugging` / `running-atdd-cycle` / `reviewing-deliverables` / `merging-and-deploying` / `fixing-bugs` は**本質的書き換えをしない**（無編集の兄弟ルート）。

## Open Question の確定（plan で確定すると PRD が指定した項目）

PRD Open Questions を本 plan で以下に確定する（実装はこの確定値に従う）:

1. **正式スキル名 = `fixing-flaky-tests`**。理由: 兄弟ルート `fixing-bugs` と命名規約（動名詞 + 対象）を揃え、`skills/` 一覧での並びと description トリガーの一貫性を保つ。
2. **起動口 = 新コマンド `/atdd-kit:flaky-fix`**（`commands/flaky-fix.md` 新設）。理由: flaky は bugfix と判定信号・原因軸・収束オラクルが異なるため、`autofix` 相乗りサブモードにすると `commands/autofix.md`（bugfix 専用・本 Issue で無編集）と route-eligibility の判定が二重化する。独立コマンドにして route-eligibility.md（SoT）の flaky シグナルから一意に起動する。
3. **反復回数 N と判定基準** — 本 plan は **N を固定値に exact-pin せず「設定可能な反復回数（既定の下限あり）」として定義**する（#289 の point-in-time pin 回避と同じ規律: 数値リテラルを AT で完全一致 pin しない）。確定する規約は次の不変条件のみ:
   - **再現確認**: 反復実行で **1 回以上赤が観測される**ことを firsthand 証拠とし、**失敗率（赤回数 / 試行回数）を記録**する。単発実行を再現確認としない。
   - **収束オラクル**: **N 回連続 green（決定化の確認）＋ 既存テスト非破壊**。単発 green を収束としない。N と失敗率しきい値は実行時パラメータ（platform / テスト特性で調整可能）であり、AT は「反復ベースであること」「単発を収束としないこと」という不変条件を pin する（具体的 N の数値は pin しない）。
4. **platform: other（bats 等）の反復手段** — 既存テストランナーの**ループ実行**（同一テストの反復起動）を必須とし、seed 注入 / 実行順シャッフルは **flaky 種別に応じた任意の追加手段**（順序依存が疑われる場合に実行順変動、共有状態が疑われる場合に並列度変動）として記述する。ランナー自体は改修しない（Non-Goal）。
5. **非決定性の原因カテゴリと `debugging` Type へのマッピング** — 新しい Type 軸は足さず、`debugging` の既存 Type 分類を **flaky 軸で運用**する。非決定性カテゴリ（タイミング依存 / 順序依存 / 共有状態 / 外部依存 / リソースリーク）は **Type C（Logic Error 系）配下の運用サブ軸**として扱い、分類の flaky 向け運用ガイダンスは**オーケストレータ側**（`fixing-flaky-tests/SKILL.md`）に置く（`debugging` 本体は無編集・重複ゼロ）。Type A（AC Gap）に該当する場合はフル機能ルートへ昇格（bugfix と同じ）。
6. **quarantine のマーク手段と追跡** — 即時決定化が困難な flaky を**一時隔離マーク**（platform-aware: other=bats `skip`／タグ、web=Playwright `test.fixme`/skip、iOS=`XCTSkip` 等、いずれも外部ランナー機能参照）で隔離し、**隔離は追跡（Issue 残置 / 再 dispatch）が必須**で放置しないことをルートに組み込む。隔離手段の atdd-kit ローカル実装は作らない（外部ランナー機能参照のみ）。
7. **ルーティングしきい値** — flaky と通常 bug の境界は route-eligibility.md（SoT）に flaky シグナル（ラベル `type:flaky` ＋キーワード `flaky`/`不安定`/`間欠的に失敗`/`intermittent`）として定義し、低確信時は #305 ワンタップ User 確認（既存 fallback 節を踏襲）。誤判定時は User が override（既存「Recommendation Only / No Auto-Routing」不変条件）。

## AL-1 三ゲート不変条件との整合（cause-agreement の flaky アンカー化 / 兄弟ルート整合）

flaky ルートも US/Plan/AT spec を作らないため、標準の**設計承認ゲート**がアンカーする成果物を持たない。bugfix と同じく **ゲート除去ではなく specialization** で AL-1 を満たすが、flaky では**アンカーの中身が「単一の赤テスト」ではない**点が bugfix との差分:

- **cause-agreement ゲートの flaky アンカー = 「非決定性の原因分類（`debugging` Type を flaky 軸で運用）＋ 反復実行での失敗率（修正前 X% → 修正後 0%）」**。bugfix の「Type 分類＋単一失敗再現テスト（赤）」を、flaky では「Type 分類（非決定性カテゴリ）＋反復で観測可能な failing アンカー＋失敗率」に置換する。`debugging` Step 5 の `Proceed to fix?` 確認を流用（無編集）。
- 承認対象が空でない（分類＋失敗率を伴う反復アンカー）ため、AL-1 の「ATDD は中間ゲート前に開始しない」が維持される。ゲート数は三のまま（除去・追加なし）。
- **二文書整合**: `autopilot-iron-law.md`（AL-1 本体）と `autopilot-design-gate.md`（提示契約）の **両方に同時に** flaky の middle-gate specialization を着地させ、片方だけに書いて他方を stale にしない。両文書が flaky の middle-gate を **cause-agreement（承認対象 = 非決定性分類＋失敗率）** と一致して定義することを保証する。

## Implementation

### A. オーケストレーションスキル新設（FS-1: 専用ルート起動 / CS-2: 再利用のみ・無編集）

> **`bug` の組込み forward chain との衝突解消（兄弟ルート整合）**: 既存 `bug` スキルは末尾「Next Step」で `defining-requirements` への routing を**ハードコード**しており、`defining-requirements` をスキップする flaky ルートと衝突する。Non-Goal が `bug` の本質的書き換えを禁じるため、`bug` は編集しない。`fixing-bugs` と**同一の override 機構**を `fixing-flaky-tests` 側に置く: flaky ルートでは**オーケストレーターである `fixing-flaky-tests` が各スキルの Skill 呼び出しを明示駆動する**（orchestrator-driven invocation）。被連鎖スキルの「Next Step」は本ルート下では advisory に過ぎず、`fixing-flaky-tests` の連鎖定義が上書きする。`bug` 完了後は `bug` の Next Step（`defining-requirements`）を辿らず `debugging` を次に呼ぶ。

- [ ] `skills/fixing-flaky-tests/` ディレクトリを作成し、`SKILL.md` に YAML frontmatter（`name: fixing-flaky-tests`、`description` は**トリガー条件のみ**＝ DEVELOPMENT.md「Skill Description Field Rules」遵守、ワークフロー要約禁止）を置く
- [ ] verify: `head` で frontmatter を確認し、`description` がワークフロー要約を含まず起動条件（flaky / 不安定 / intermittent / `/atdd-kit:flaky-fix`）のみであること、`name` が `fixing-flaky-tests` であることを目視確認

- [ ] `SKILL.md` 本文に Skill Chain を記述: `bug`（intake/Issue 化/トリアージ）→ `debugging`（非決定性の原因分類）→ `running-atdd-cycle`（決定化する最小修正＋反復回帰）→ `reviewing-deliverables` → `merging-and-deploying`。`defining-requirements` / `extracting-user-stories` / `writing-plan-and-tests` の 3 スキルは **スキップ**する旨と理由を明記（bugfix と同じ 5 連鎖骨格の再利用）
- [ ] verify: `grep` で本文に 5 連鎖スキル名すべてが順に出現し、スキップ対象 3 スキル名が「スキップ」文脈で出現することを確認

- [ ] `SKILL.md` に **forward-chain override 機構**を明記（`fixing-bugs` と同方式）: flaky ルートでは `fixing-flaky-tests` がオーケストレーターとして各スキルの Skill 呼び出しを明示駆動し、被連鎖スキルの「Next Step」（特に `bug` の `defining-requirements` への routing）は**本ルート下では advisory に過ぎず `fixing-flaky-tests` の連鎖定義が上書きする**こと、`bug` 完了後は `debugging` を次に呼ぶことを記述。`bug`/`debugging` 等の SKILL.md は編集しない
- [ ] verify: `grep` で `fixing-flaky-tests/SKILL.md` に override 機構（orchestrator-driven invocation／Next Step は advisory／`bug` 後は `debugging`）が記述され、`git diff --quiet skills/bug/SKILL.md` で `bug` が未編集であることを確認

- [ ] `SKILL.md` に Responsibility Boundary 表を追加し、本スキルが既存スキル（`bug`/`debugging`/`running-atdd-cycle`/`reviewing-deliverables`/`merging-and-deploying`）と兄弟ルート `fixing-bugs` を**束ねるだけ**で再現メソドロジー・診断ロジックを再定義しないこと（重複ゼロ・既存スキル無編集）を明示
- [ ] verify: `grep` で「再利用」「重複」「無編集」相当の境界記述が存在し、新規メソドロジー定義が本文に含まれないこと、`git diff --quiet skills/fixing-bugs/SKILL.md` で bugfix ルートが未編集であることを確認

### B. 確率的再現工程の flaky 特化 2 層配線（FS-2: 確率的再現確認 / FS-3: 反復で観測可能な failing アンカー）

> **外部ツール参照の明示（兄弟ルート整合）**: `playwright-cli` / `verify`（web）、Xcode/simulator MCP（iOS）は**環境/グローバル提供の外部スキル/外部 MCP**であり atdd-kit が `skills/` 配下に所有しない。flaky ルートはこれらを**外部参照として反復実行に用いるだけ**で、atdd-kit ローカルスキルファイル・`skills/README.md` 登録・BATS 構造テストの対象ではない（`sim-pool` のみ atdd-kit 所有）。反復実行の手段（ループ / seed / 順序・並列度変動）も既存ランナーの呼び出しで賄い、ランナー自体は改修しない（Non-Goal）。

- [ ] `SKILL.md` に「2a. 確率的再現の確認（経験的・反復ツール駆動）」ステップを追加。単発ではなく **N 回反復実行 / seed・実行順・並列度の変動**で flaky を firsthand 確認し**失敗率を記録**する旨を、`.claude/config.yml` の `platform` を読んで platform-aware に分岐（other=bats/スクリプトのループ実行、web=`playwright-cli` 反復、iOS=Xcode/simulator MCP 反復、いずれも外部ツール参照）して記述。N は固定数値リテラルで pin せず**設定可能（既定の下限あり）**とし、再現確認の不変条件は「反復で 1 回以上赤を観測＋失敗率記録（単発を再現確認としない）」と明記
- [ ] verify: `grep` で 3 platform（other/web/iOS）それぞれに反復実行手段が対応付けられた分岐記述が存在し、「失敗率」「反復」「単発（を再現確認としない）」相当が記述され、外部ツールが**外部参照**として（atdd-kit 所有スキルとしてではなく）記述されていることを確認

- [ ] `SKILL.md` に「2b. 反復で観測可能な failing アンカーへの符号化」ステップを追加。確認した非決定性を「**反復実行で一定確率赤になる**」実行可能アンカーに符号化し、修正後は **N 回連続緑で決定化を確認**する旨（収束オラクルのアンカー）を記述。N は固定数値で pin しない
- [ ] verify: `grep` で「反復実行で一定確率赤」「N 回連続緑」「決定化」相当の符号化記述と、それが収束オラクルのアンカーになる旨が存在することを確認

### C. 非決定性の原因分類（FS-4: `debugging` Type を flaky 軸で運用）

- [ ] `SKILL.md` に**非決定性の原因分類**を追加。タイミング依存 / 順序依存 / 共有状態 / 外部依存 / リソースリーク の非決定性カテゴリを `debugging` の既存 Type 分類（特に Type C 配下の運用サブ軸）として運用する旨を記述。`debugging` 本体は無編集で、flaky 向け運用ガイダンスは**オーケストレータ側に置く**（重複ゼロ）。Type A（AC Gap）はフル機能ルートへ昇格（bugfix と同じ）
- [ ] verify: `grep` で 5 非決定性カテゴリ（タイミング/順序/共有状態/外部依存/リソースリーク）が `debugging` Type 運用文脈で揃って出現し、`debugging` SKILL.md が未編集（`git diff --quiet skills/debugging/SKILL.md`）であることを確認

### D. cause-agreement ゲートの flaky 用反復アンカー＋二文書整合（FS-5 / CS-3）

- [ ] `docs/methodology/autopilot-iron-law.md` に **flaky の middle-gate specialization 条項**を追記: flaky ルートでは middle gate が cause-agreement ゲートとして機能し、承認対象が「**非決定性の原因分類＋反復実行での失敗率（修正前 X% → 修正後 0%）**」である旨（bugfix の「単一失敗再現テスト」アンカーに対する flaky 差分＝反復アンカー＋失敗率）を明記。ゲート数は三のまま（除去・追加なし）。AL-3 の coverage 項は flaky では「**反復で観測可能な failing アンカーの被覆（反復赤→ N 回連続緑が外部コンテキストで確認される）**」に specialize（標準ルートの AC→AT coverage はそのまま）
- [ ] verify: `grep` で autopilot-iron-law.md に flaky の cause-agreement specialization（承認対象 = 非決定性分類＋失敗率）と coverage 項の反復アンカー specialization が記述され、AL-1 の三ゲート構造・AL-3 の AND 構造が壊れていないことを確認

- [ ] `docs/methodology/autopilot-design-gate.md` の presentation contract にも **flaky の cause-agreement ゲート**を追記し、`autopilot-iron-law.md` と一致させる: flaky ルートでは本ゲートが cause-agreement ゲートとして機能し、承認対象が user-stories/plan/acceptance-tests ではなく「非決定性の原因分類＋反復失敗率（前→後）」である旨を記述。両文書が flaky の middle-gate 定義について一致する（片方着地で他方 stale にしない）
- [ ] verify: `grep -F 'cause-agreement'` が `autopilot-iron-law.md` と `autopilot-design-gate.md` の双方に hit し、両文書の flaky 承認対象（非決定性分類＋失敗率）が一致していることを確認

### E. quarantine（隔離）判断ポイント（FS-6: 一時隔離＋追跡）

- [ ] `skills/fixing-flaky-tests/SKILL.md` に **quarantine 判断ポイント**を追加。即時決定化が困難な flaky を一時隔離マーク（platform-aware: other=bats `skip`/タグ、web=Playwright skip/`fixme`、iOS=`XCTSkip` 等、いずれも**外部ランナー機能参照**）して他作業をブロックしない判断と、**隔離は追跡（Issue 残置 / 再 dispatch）が必須**で放置しない旨を記述。隔離手段の atdd-kit ローカル実装は作らない
- [ ] verify: `grep` で quarantine（隔離）判断と 3 platform の隔離マーク手段（外部ランナー機能参照）、隔離後の追跡（Issue 残置 / 再 dispatch）が記述されていることを確認

### F. ルーティング拡張＋明示コマンド（FS-7: flaky シグナル判定＋ワンタップ＋明示起動）

> **配置の単一ソース化（兄弟ルート整合）**: ルーティングの正準ロジックは `docs/methodology/route-eligibility.md`（session-start がロードする SoT）に集約する。flaky 判定も **SoT 側に追記**し、autopilot SKILL.md は参照のみ。
>
> **行バジェット制約（priority-1 実行ブロッカー）**: `skills/autopilot/SKILL.md` は現在 **279/280 行でヘッドルーム 1 行**（`tests/test_autopilot_skill.bats:131` が `≤ 280 lines` を pin、`:718` 周辺が loader-stub split 後の**3 回目昇格禁止**を pin）。DEVELOPMENT.md「SKILL.md Line-Budget Raises」により昇格は 2 回まで（240→260→280 で消費済み）で **3 回目は禁止**。したがって autopilot SKILL.md への flaky 配線は**純増を最大 1 行（loader-stub 参照）に限定**し、詳細本体は参照先ドキュメント（route-eligibility.md / autopilot-iron-law.md）側に置く。各セクションで `wc -l skills/autopilot/SKILL.md` ≤ 280 を assert する。

- [ ] `docs/methodology/route-eligibility.md` に **flaky ルート判定信号**を追記（SoT）。ラベル `type:flaky` ＋キーワード（`flaky` / `不安定` / `間欠的に失敗` / `intermittent`）＋タスク内容（確率的に失敗するテストの決定化）から flaky ルートを判定する Hybrid Determination（既存節を踏襲）と、低確信時の #305 ワンタップ User 確認を規定。既存「Recommendation Only, No Auto-Routing」不変条件はそのまま適用。flaky と bugfix の境界（flaky = 非決定的に失敗 / bugfix = 決定的に再現する欠陥）を明示
- [ ] verify: `grep` で route-eligibility.md に flaky ルート判定信号（`type:flaky`＋4 キーワード）と低確信フォールバック、flaky/bugfix 境界が存在し、「No Auto-Routing」不変条件節が維持されていることを確認

- [ ] `skills/autopilot/SKILL.md` に flaky ルートも route-eligibility.md を**参照**して判定する旨を**ローダースタブ参照 1 行**で追記（判定ロジック本体は SKILL.md に書かず SoT 側。advisory-only / auto-route なしを維持）。**3 回目の行バジェット昇格は禁止のため純増は最大 1 行**。既存行のタイトニングで相殺し ≤280 を維持できれば望ましい
- [ ] verify: `wc -l skills/autopilot/SKILL.md` が **≤ 280**（pin 引き上げ不可・loader-stub のみ）であり、`tests/test_autopilot_skill.bats` を編集前後で実行（編集前 green → 編集後も green、≤280 line-budget テスト含む）、autopilot SKILL.md が route-eligibility.md を参照する（判定ロジック本体を持たない）ことを確認

- [ ] `commands/flaky-fix.md` を新設し、`/atdd-kit:flaky-fix <issue>` で `fixing-flaky-tests` ルートを明示起動できるようにする
- [ ] verify: `grep` で `commands/flaky-fix.md` に `fixing-flaky-tests` 呼び出しと issue 引数の記述が存在することを確認

### G. flaky autopilot 反復ベース収束オラクル（CS-1: 反復オラクル / CS-3: マージ User gate）

> **反復オラクルの配置（行バジェット整合）**: 収束オラクルの**配線本体**（`N 回連続 green ＋ 既存テスト非破壊（既存回帰なし）＋ 反復 failing アンカー赤→ N 回連続緑`、単発 green を収束としない、中間ゲート = cause-agreement、終端 = マージ User gate / AL-1）は **`docs/methodology/autopilot-iron-law.md`（flaky 特化条項・D で追記）側に記述**する。`skills/autopilot/SKILL.md` には**参照ローダースタブ 1 行のみ**を追加（行バジェット ≤280 厳守）。

- [ ] `docs/methodology/autopilot-iron-law.md` の flaky 特化条項（D で追記）に **反復ベース収束オラクル**を明記: `done` = 「**N 回連続 green（決定化の確認）＋ 既存テスト非破壊**」であり、**単発 green を収束としない**。中間ゲート = cause-agreement（非決定性分類＋失敗率）、終端 = マージ User gate（AL-1 維持・自動マージしない）。N は固定数値で pin せず「N 回連続」の不変条件で記述
- [ ] verify: `grep` で autopilot-iron-law.md の flaky オラクルに「N 回連続 green」「既存テスト非破壊」「単発 green を収束としない」「マージ User gate（AL-1）」が揃い、coverage アンカーが反復 failing アンカーに特化していることを確認

- [ ] `skills/autopilot/SKILL.md` に autopilot-iron-law.md の flaky オラクル条項を参照する**ローダースタブ 1 行**を追加（配線詳細本体は SKILL.md に純増させない）
- [ ] verify: `wc -l skills/autopilot/SKILL.md` が **≤ 280** であり、`grep` で SKILL.md が autopilot-iron-law.md の flaky オラクル条項を参照する loader-stub を持つ（配線詳細本体は SKILL.md に無い）ことを確認

### H. フル機能ルートへの昇格基準（FS-4 補: Type A 昇格）

- [ ] `skills/fixing-flaky-tests/SKILL.md` に昇格基準を追加。`debugging` の Root Cause 分類が **Type A（AC Gap = 仕様/設計判断が必要）** の場合、flaky 軽量ルートを離脱し既存 `debugging → defining-requirements` 連鎖を流用してフル機能ルートへ昇格する旨を記述（bugfix と同じ）
- [ ] verify: `grep` で「Type A」「昇格」「defining-requirements」が昇格分岐文脈で揃って出現することを確認

## Testing

- [ ] `skills/fixing-flaky-tests/SKILL.md` 用の BATS 構造テスト `tests/test_fixing_flaky_tests_skill.bats` を新設（DEVELOPMENT.md「Skill Changes Require Test Evidence」）。frontmatter・5 連鎖・スキップ 3 スキル・確率的再現 2 層（失敗率＋反復アンカー）・非決定性 5 カテゴリ・quarantine 判断・昇格基準・**forward-chain override 機構**を pin
- [ ] verify: `bats tests/test_fixing_flaky_tests_skill.bats` が green、かつ `git diff --quiet skills/bug/SKILL.md skills/debugging/SKILL.md skills/fixing-bugs/SKILL.md`（既存スキル・兄弟ルート未編集）が成立

- [ ] **二文書整合の cross-doc consistency pin**: `autopilot-iron-law.md` と `autopilot-design-gate.md` の双方に flaky middle-gate specialization（cause-agreement）記述が存在することを確認する pin を、**`tests/test_autopilot_skill.bats`（skill 構造スイート）に載せず、新設の `tests/acceptance/AT-322.bats` が own** する。pin は**安定不変トークン**（リテラル `cause-agreement` ＋ flaky 文脈）で行い、日本語 prose のフル文一致では pin しない（#308 と同じ robustness 方針）
- [ ] verify: `grep -F 'cause-agreement'` で `autopilot-iron-law.md` と `autopilot-design-gate.md` の双方に安定トークンが存在し、この cross-doc 整合 pin が `tests/acceptance/AT-322.bats` に置かれていることを確認

- [ ] ルーティング/反復オラクル拡張の構造 pin を `tests/test_autopilot_skill.bats` に追加し、Acceptance Test `tests/acceptance/AT-322.bats` を新設する。**オラクルアンカーのスコープ明示（過剰主張防止）**: AT-322-* のほぼすべては SKILL.md / メソドロジー文書への静的 grep（text-presence）であり、flaky の**反復赤→ N 回連続緑の収束はオーケストレーションのランタイム特性で text-grep では exercise できない**。AT-322.bats は反復オラクルを生む**配線（wiring）を pin** するのであって、AT 自身が実際の反復 fix ループを実行して赤→緑を観測するわけではない（#308 AT-308 と同じ no-runtime-suite 方針。実挙動は wiring pin ＋ out-of-band の autopilot replay/fixture 経路で検証）
- [ ] verify: `bats tests/test_autopilot_skill.bats tests/acceptance/AT-322.bats` が green、かつ既存 BATS スイート全体が非破壊（既存回帰なし）。AT-322.bats が「反復赤→緑を生む wiring の存在」を pin し real loop は own しない旨が AT に明記されていることを確認

## Finishing

- [ ] `skills/README.md` に `fixing-flaky-tests` を追記、`commands/README.md` に `flaky-fix` を追記、`CHANGELOG.md` の `[Unreleased]` に `### Added` エントリ追加、`.claude-plugin/plugin.json` を **minor** bump（新スキル追加 = minor。skill rename/remove ではないため major 不要）
- [ ] verify: `grep` で README 2 件・CHANGELOG・plugin.json の更新を確認し、`scripts/check-plugin-version.sh` 相当で version と CHANGELOG 最新見出しの整合を確認

- [ ] ドキュメント整合性チェック（`rules/atdd-kit.md` 60 行バジェット維持、`docs/methodology/route-eligibility.md` の bugfix/flaky 兄弟ルート記述整合、`docs/workflow/` のルート分離記述整合）
- [ ] verify: `wc -l rules/atdd-kit.md` が 60 以下、関連ドキュメントが flaky ルート追加と整合している
