# Plan: bugfix 専用の軽量ルート（フル機能ルートと分離）

<!-- 2-5 分粒度のタスク行と verification 行を交互に配置する（superpowers writing-plans 形式）。
     各タスクは単一の操作に限定し、verification で完了条件を即確認できる粒度にする。 -->

方針: 新規メソドロジー・ステップ・スキルは増やさず、既存スキルの**再利用のみ**で構成する。
新設するのは (a) 軽量オーケストレーションスキル `skills/fixing-bugs/SKILL.md` 1 つ、
(b) `docs/methodology/route-eligibility.md`（ルーティング SoT）への bugfix ルート判定追記＋`skills/autopilot/SKILL.md` からの**参照**、(c) `commands/autofix.md` 明示コマンド、
(d) `docs/methodology/autopilot-iron-law.md` への bugfix オラクル特化条項（AL-3 の specialization）＋`skills/autopilot/SKILL.md` の bugfix 収束オラクル配線、のみ。`bug` / `debugging` / `running-atdd-cycle` /
`reviewing-deliverables` / `merging-and-deploying` は本質的書き換えをしない。

## AL-1 三ゲート不変条件との整合（設計ゲート代替の明示 / finding#1）

bugfix ルートは US/Plan/AT spec を作らないため、標準の**設計承認ゲート**（user-stories / plan / acceptance-tests を承認）が物理的にアンカーする成果物を持たない。だが AL-1 は「ATDD は設計承認ゲート前に開始しない／autopilot はいかなるゲートも黙って除去・自動化・迂回しない」を不変条件とする。これを**ゲート除去ではなく specialization** で満たす:

- **設計ゲートの代替アンカー = 「`debugging` Step 5 の根本原因分類（A/B/C・evidence 付き）＋ 失敗する再現テスト（赤）」**。`debugging` は既に Step 5 末で `Proceed to fix? [Yes / ...]` の人間確認を持つ（再利用）。bugfix ルートではこの**原因合意ゲート（cause-agreement gate）が設計承認ゲートの role を担い**、ATDD（最小修正）はこのゲート通過後にのみ開始する。
- これは AL-1 の**改訂を要する**（メソドロジー変更であり純粋再利用ではない）。`docs/methodology/autopilot-iron-law.md` に「bugfix ルートでは middle gate が design-approval から **cause-agreement（承認対象 = 根本原因分類＋失敗再現テスト）** へ specialize される。ゲート数は三のまま（除去・追加なし）」を明記する。代替アンカーは autopilot の immutable per-phase anchor（AL-2）として pin 可能な実体（再現テスト＋分類記録）を持つため、AL-2 の「人間承認済み immutable artifact に traceable」要件も満たす。
- 承認対象が空でない（再現テスト＋分類）ため、AL-1 の「ATDD never starts before that gate」は維持される。フル機能ルートの US/Plan/AT 承認を、bugfix では「原因合意（根本原因＋赤い再現テスト）」承認に置換するのが本 specialization の核心。
- **二文書整合（finding#2）**: 設計承認ゲートの詳細仕様は #305 が `docs/methodology/autopilot-iron-law.md`（AL-1 の不変条件本体）から `docs/methodology/autopilot-design-gate.md`（ゲートの提示契約・presentation contract）へ split out 済みである。bugfix の middle-gate specialization は **両文書に同時に**着地させ、片方だけに書いて他方を stale にしない。すなわち (a) `autopilot-iron-law.md` AL-1 に「bugfix では middle gate が design-approval → cause-agreement（承認対象 = 根本原因分類＋失敗再現テスト）に specialize、ゲート数は三のまま」を記述し、(b) `autopilot-design-gate.md` の presentation contract にも「bugfix ルートでは本ゲートが cause-agreement ゲートとして機能し、承認対象成果物が user-stories/plan/acceptance-tests ではなく『根本原因分類（A/B/C・evidence 付き）＋失敗再現テスト（赤）』である」旨を記述して、**両文書が bugfix の middle-gate 定義について一致する**ことを保証する。

## Implementation

### A. オーケストレーションスキル新設（US1: 軽量ルート / US-Constraint1: 再利用のみ）

> **`bug` の組込み forward chain との衝突解消（finding#1）**: 既存 `bug` スキルは末尾「Next Step」で `invoke the defining-requirements skill ...（the bug chain routes into Step 1 of the 6-step flow）`（`skills/bug/SKILL.md:92`）と forward chain を**ハードコード**しており、これは `defining-requirements` をスキップする bugfix ルートと直接衝突する。だが Non-Goal（prd.md:49 / plan.md:9-10）が `bug` の本質的書き換えを禁じるため、`bug` SKILL.md は編集しない。代わりに **override 機構を `fixing-bugs` 側に明記**して衝突を解消する: bugfix ルートでは**オーケストレーターである `fixing-bugs` が各スキルの Skill 呼び出しを明示的に駆動する**（orchestrator-driven invocation）。各被連鎖スキルの「Next Step」は**この文脈下では advisory（次工程の示唆）に過ぎず、forward chain の self-routing は `fixing-bugs` の連鎖定義が上書きする**。具体的には `bug` 完了後、`fixing-bugs` は `bug` の「Next Step」が指す `defining-requirements` を**呼ばず**、自らの連鎖定義に従って `debugging` を次に呼ぶ。これにより `bug` を一切編集せずに forward chain がインターセプトされる。AT-308-1b がこの override 機構（orchestrator-driven／被連鎖スキルの Next Step は advisory／`bug`→`debugging` の実配線）を pin し、ランタイムで非機能なルートが green AT と共存しないようにする。

- [ ] `skills/fixing-bugs/` ディレクトリを作成し、`SKILL.md` に YAML frontmatter（`name: fixing-bugs`、`description` は**トリガー条件のみ**＝ DEVELOPMENT.md「Skill Description Field Rules」遵守、ワークフロー要約禁止）を置く
- [ ] verify: `head` で frontmatter を確認し、`description` がワークフロー要約を含まず起動条件のみであること、`name` が `fixing-bugs` であることを目視確認

- [ ] `SKILL.md` 本文に Skill Chain を記述: `bug`（intake/Issue 化/トリアージ）→ `debugging`（Scientific Debugging で根本原因診断・分類 A/B/C）→ `running-atdd-cycle`（最小修正＋回帰テスト）→ `reviewing-deliverables` → `merging-and-deploying`。`defining-requirements` / `extracting-user-stories` / `writing-plan-and-tests` の 3 スキルは **スキップ**する旨と理由（Connextra US が定型化しバグの本質に直行できない）を明記
- [ ] verify: `grep` で本文に 5 連鎖スキル名すべてが順に出現し、スキップ対象 3 スキル名が「スキップ」文脈で出現することを確認

- [ ] `SKILL.md` に **forward-chain override 機構**（finding#1）を明記: bugfix ルートでは `fixing-bugs` がオーケストレーターとして各スキルの Skill 呼び出しを明示駆動し（orchestrator-driven invocation）、被連鎖スキルの「Next Step」（特に `bug` の `defining-requirements` への routing, `skills/bug/SKILL.md:92`）は**本ルート下では advisory に過ぎず `fixing-bugs` の連鎖定義が上書きする**こと、`bug` 完了後は `bug` の Next Step を辿らず `debugging` を次に呼ぶことを記述する。`bug`/`debugging` 等の SKILL.md は編集しない（Non-Goal 遵守）
- [ ] verify: `grep` で `fixing-bugs/SKILL.md` に override 機構（orchestrator-driven invocation／Next Step は advisory／`bug` 後は `debugging`）が記述され、`bug` の forward chain（`defining-requirements` への routing）が本ルートで上書きされる旨が存在すること、かつ `skills/bug/SKILL.md` 自体が未編集（`git diff --quiet skills/bug/SKILL.md`）であることを確認

- [ ] `SKILL.md` に Responsibility Boundary 表を追加し、本スキルが既存スキルを**束ねるだけ**で再現メソドロジー・診断ロジックを再定義しないこと（重複ゼロ）を明示
- [ ] verify: `grep` で「再利用」「重複」相当の境界記述が存在し、新規メソドロジー定義が本文に含まれないことを確認

### B. 再現工程の 2 層配線（US2: 実ツール駆動再現 → failing test 符号化）

> **外部スキル参照の明示（finding#2）**: `playwright-cli` / `verify` は**環境/グローバル提供の外部スキル**であり、atdd-kit が `skills/` 配下に所有するスキルではない（`ls skills/` に存在しない。`sim-pool` 等のみが atdd-kit 所有）。`fixing-bugs` はこれらを**外部スキル参照として呼ぶだけ**で、atdd-kit のローカルスキルファイル・`skills/README.md` 登録・BATS 構造テスト（DEVELOPMENT.md「Skill Changes Require Test Evidence」「Directory READMEs」）の対象**ではない**。`re-use only` 契約（PRD / US-Constraint1）は atdd-kit 内部スキルの不変条件であり、外部スキル参照には構造テスト期待を生成しない。iOS の Xcode/simulator MCP も同様に外部ツール（MCP）参照であり、`sim-pool` のみ atdd-kit 所有スキル。

- [ ] `SKILL.md` に「1a. 再現確認（経験的・ツール駆動）」ステップを追加。`.claude/config.yml` の `platform` を読み、web=`playwright-cli`/`verify`（**外部スキル**）、iOS=Xcode/simulator MCP（外部ツール）＋`sim-pool`（atdd-kit 所有）、other=CLI/スクリプト（bats 等）実行へ platform-aware に分岐する配線を記述。外部スキル/外部 MCP は参照のみ（atdd-kit 内部スキルとして新設・登録しない）旨を本文に明記
- [ ] verify: `grep` で 3 platform（web/iOS/other）それぞれに対応ツールが対応付けられた分岐記述が存在し、`playwright-cli`/`verify`/Xcode MCP が**外部参照**として（atdd-kit 所有スキルとしてではなく）記述されていることを確認

- [ ] `SKILL.md` に「1b. 失敗テストへの符号化」ステップを追加。確認できた再現を実行可能な failing test に落とし、autopilot オラクルのアンカー（赤→修正後に緑）にする旨を記述
- [ ] verify: `grep` で「failing test」「赤→緑」相当の符号化記述と、それがオラクルアンカーになる旨が存在することを確認

### C. #302 ルーティング拡張＋明示コマンド（US3: 自動判定＋ワンタップ＋明示起動）

> **配置の単一ソース化（finding#3）**: #302 ルーティングの正準ロジックは `docs/methodology/route-eligibility.md`（session-start がロードする SoT）に集約されており、`skills/autopilot/SKILL.md:27-32` の Express precheck は「**Auto-route is never performed**（advisory のみ）」と明記する advisory 層に過ぎない。bugfix ルート判定ロジックは **route-eligibility.md（SoT）側に追記**し、autopilot SKILL.md は既存 express-eligibility と同じく**参照するだけ**にする。判定ロジックを autopilot SKILL.md に置くと SoT と二重化し「no auto-route / advisory-only」設計と衝突するため禁止。
>
> **行バジェット制約（finding#1, priority-1 実行ブロッカー）**: `skills/autopilot/SKILL.md` は現在ちょうど 280/280 行で**ヘッドルームゼロ**であり、`tests/test_autopilot_skill.bats:131` が `≤ 280 lines` を pin、`tests/test_autopilot_skill.bats:727`（#305 finding #1: no 3rd raise）が split 後の再昇格禁止を pin する。DEVELOPMENT.md:59-61（SKILL.md Line-Budget Raises）により昇格は **2 回まで**で 240→260→280 と両回を消費済み、**3 回目の昇格は禁止**（#283/#305 の design-gate split はまさにこれを避けるために実施）。したがって本セクション C と次セクション D が autopilot SKILL.md に行を**純増させると `≤280` テストが最初の 1 行目で赤化し、pin の引き上げでは直せない**。そこで autopilot SKILL.md への編集は **各所 1 行のローダースタブ参照に限定し、配線の詳細本体は参照先ドキュメント（route-eligibility.md / autopilot-iron-law.md / autopilot-design-gate.md）側に置く**。SKILL.md には loader-stub 行しか増やさない。各セクションに `wc -l skills/autopilot/SKILL.md` ≤ 280 を明示 assert する verification 行を置く。

- [ ] `docs/methodology/route-eligibility.md` に **bugfix ルート判定信号**を追記（SoT）。Issue ラベル（`type:bug` 等）＋キーワード＋タスク内容から bugfix ルートを判定する Hybrid Determination（label + keyword + LLM、既存節を踏襲）と、低確信時の User 確認（#305 ワンタップ整合）を規定。既存の「Recommendation Only, No Auto-Routing」不変条件はそのまま適用（自動振り分けはしない）
- [ ] verify: `grep` で route-eligibility.md に bugfix ルート判定信号と低確信フォールバックが存在し、「No Auto-Routing」不変条件節が維持されていることを確認
- [ ] `skills/autopilot/SKILL.md` の Express precheck 節に、bugfix ルートも route-eligibility.md を**参照**して判定する旨を**ローダースタブ参照 1 行**で追記する（判定ロジック本体・分岐記述は SKILL.md に書かず route-eligibility.md 側に置く。advisory-only / auto-route なしを維持）。**3 回目の行バジェット昇格は禁止（finding#1）のため、純増は最大 1 行**。既存行のタイトニング（DEVELOPMENT.md「Tightening Guidelines」）で相殺し ≤280 を維持できれば望ましい
- [ ] verify: `wc -l skills/autopilot/SKILL.md` が **≤ 280**（finding#1: pin 引き上げ不可・loader-stub のみ）であり、`tests/test_autopilot_skill.bats` を編集前後で実行し（編集前 green → 編集後も green、≤280 line-budget テスト含む）、autopilot SKILL.md が route-eligibility.md を参照する pin（判定ロジック本体を持たない）が green

- [ ] `commands/autofix.md` を新設し、`/atdd-kit:autofix <issue>` で fixing-bugs ルートを明示起動できるようにする
- [ ] verify: `grep` で `commands/autofix.md` に `fixing-bugs` 呼び出しと issue 引数の記述が存在することを確認

### D. bugfix autopilot 収束オラクル（US4: 自律収束＋最小 User gate）

> **AL-3 coverage 項との整合（finding#5）**: 標準 autopilot の AND オラクル（`autopilot-iron-law.md` AL-3）は `done = AT green AND AC→AT coverage green AND reviewer overall_correctness=correct AND confirmed P0/P1=0`。bugfix ルートは US/Plan/AT spec を作らないため **AC セットが存在せず、「AC→AT coverage」項がカバー対象を持たない**。これを degraded な「tests pass」に落とさず、coverage ガードを保つために **AL-3 を specialize** する: bugfix ルートでは coverage 項の被覆対象を「承認済み AC」から「**原因合意ゲートで承認された失敗再現テスト（赤）**」に置換する。すなわち coverage gate = 「再現テストが実装され赤→修正後に緑になっていること（＝オラクルアンカーが実在し、修正がそれを緑化したこと）」を別コンテキストで確認する。これにより AL-2/AL-3 が要求する coverage ガード（自分の AT を自分で採点させない外部アンカー）の機能は保たれる。

- [ ] `docs/methodology/autopilot-iron-law.md` に **bugfix オラクル特化条項**を追記: 標準 AL-3 の `AC→AT coverage` 項を、bugfix ルートでは「原因合意ゲート承認済みの**失敗再現テスト被覆**（再現テスト赤→緑が実在し外部コンテキストで確認される）」に specialize する旨を明記（override ではなく specialization。標準ルートの AC→AT coverage はそのまま）
- [ ] verify: `grep` で autopilot-iron-law.md に bugfix の coverage 項 specialization（再現テスト被覆＝coverage ガードの代替アンカー）が記述され、標準 AL-3 の AND 構造（4 条件）が壊れていないことを確認

- [ ] **設計ゲート二文書整合（finding#2）**: `docs/methodology/autopilot-design-gate.md`（#305 が split out したゲート提示契約）にも bugfix の middle-gate specialization を追記し、`autopilot-iron-law.md` AL-1 と一致させる: bugfix ルートでは本ゲートが **cause-agreement ゲート**として機能し、承認対象成果物が user-stories/plan/acceptance-tests ではなく「根本原因分類（A/B/C・evidence 付き）＋失敗再現テスト（赤）」である旨を presentation contract に明記する（AL-1 の三ゲート不変条件はそのまま）
- [ ] verify: `grep` で `autopilot-design-gate.md` に bugfix の cause-agreement ゲート記述（承認対象 = 根本原因分類＋失敗再現テスト）が存在し、`autopilot-iron-law.md` の middle-gate specialization 記述と**矛盾しない**（両文書が同じ承認対象を指す）ことを目視確認
- [ ] bugfix 用収束オラクルの**配線本体**（`回帰テスト green ＋ 既存テスト非破壊（既存回帰なし）＋ 再現テスト赤→緑（= 特化 coverage アンカー）`、中間ゲート = 原因合意、終端 = マージ User gate / AL-1 維持、cause-agreement は設計承認ゲートの specialize であり除去ではない）は **`docs/methodology/autopilot-iron-law.md`（bugfix オラクル特化条項・上タスクで追記済み）側に記述**する。`skills/autopilot/SKILL.md` には **autopilot-iron-law.md の bugfix オラクル条項を参照するローダースタブ 1 行のみ**を追加する（**finding#1: SKILL.md は 280/280 でヘッドルームゼロ・3 回目の行バジェット昇格は禁止のため、配線詳細を SKILL.md に純増させない。loader-stub 行に留める**）
- [ ] verify: `wc -l skills/autopilot/SKILL.md` が **≤ 280**（finding#1）であり、`grep` で SKILL.md が autopilot-iron-law.md の bugfix オラクル条項を参照する loader-stub を持ち（配線詳細本体は SKILL.md に無い）、参照先の autopilot-iron-law.md にオラクル定義「回帰テスト green」「既存回帰なし」「再現テスト赤→緑」が揃い、中間ゲートが原因合意ゲート（設計承認の specialize）、マージが User gate（AL-1）であることを確認

### E. フル機能ルートへの昇格基準（US5: Type A 昇格）

- [ ] `skills/fixing-bugs/SKILL.md` に昇格基準を追加。`debugging` の Root Cause 分類が **Type A（AC Gap = 仕様/設計判断が必要）** の場合、bugfix 軽量ルートを離脱し既存の `debugging → defining-requirements` 連鎖を流用してフル機能ルートへ昇格する旨を記述
- [ ] verify: `grep` で「Type A」「昇格」「defining-requirements」が昇格分岐文脈で揃って出現することを確認

## Testing

- [ ] `skills/fixing-bugs/SKILL.md` 用の BATS 構造テスト `tests/test_fixing_bugs_skill.bats` を新設（DEVELOPMENT.md「Skill Changes Require Test Evidence」: skill 追加には BATS で構造 pin）。frontmatter・5 連鎖・スキップ 3 スキル・再現 2 層・昇格基準・**forward-chain override 機構（finding#1: orchestrator-driven invocation／Next Step は advisory／`bug` 後は `debugging`）**を pin
- [ ] verify: `bats tests/test_fixing_bugs_skill.bats` が green、かつ `git diff --quiet skills/bug/SKILL.md`（`bug` 未編集）が成立

- [ ] **二文書整合の cross-doc consistency pin（finding#2 / 配置・robustness は finding priority-3 で修正）**: `autopilot-iron-law.md` と `autopilot-design-gate.md` の双方に bugfix middle-gate specialization 記述が存在することを確認する pin は、**`tests/test_autopilot_skill.bats`（skill の構造スイート）に載せず、新設の `tests/acceptance/AT-308.bats` が own する**。理由（finding#2 priority-3 nit）: メソドロジー文書 2 つの prose レベル一致を skill の構造スイートで pin すると、日本語 prose 表現への grep でブリットルになり構造スイートを過負荷にする。pin は**安定した不変トークン**（リテラル `cause-agreement`）で行い、フル文一致では pin しない。すなわち AT-308.bats が「両ファイルが cause-agreement 承認対象フレーズを含む」ことを安定トークンで確認する
- [ ] verify: `grep -F 'cause-agreement'` で `autopilot-iron-law.md` と `autopilot-design-gate.md` の双方に安定トークンが存在し、両文書の承認対象（根本原因分類＋失敗再現テスト）が一致していること、かつこの cross-doc 整合 pin が `tests/test_autopilot_skill.bats` ではなく `tests/acceptance/AT-308.bats` に置かれていることを確認

- [ ] ルーティング/オラクル拡張の構造 pin を `tests/test_autopilot_skill.bats` に追加し、Acceptance Test `tests/acceptance/AT-308.bats` を新設する。**オラクルアンカーのスコープ明示（finding priority-3, 過剰主張防止）**: AT-308-* のほぼすべては SKILL.md / メソドロジー文書への静的 grep（text-presence）であり、bugfix の**赤→緑収束はオーケストレーションのランタイム特性で text-grep では exercise できない**。したがって AT-308.bats は再現テスト赤→緑を生む**配線（wiring）を pin する**のであって、AT-308.bats 自身が実際の fix ループを実行して赤→緑を観測するわけではない。再現テスト赤→緑のオラクル挙動そのものは **wiring pin ＋（out-of-band の）autopilot replay/fixture 経路**で検証される（no-runtime-suite プラグインで AT-302/AT-305 がドキュメント構造を pin するのと同じ方針）
- [ ] verify: `bats tests/test_autopilot_skill.bats tests/acceptance/AT-308.bats` が green、かつ既存 BATS スイート全体が非破壊（既存回帰なし）。AT-308.bats が「赤→緑を生む wiring の存在」を pin し、real fix loop の実行は AT が own しない（out-of-band replay 経路が own する）旨が AT に明記されていることを確認

## Finishing

- [ ] `skills/README.md` に `fixing-bugs` を追記、`commands/README.md` に `autofix` を追記、`CHANGELOG.md` の `[Unreleased]` に `### Added` エントリ追加、`.claude-plugin/plugin.json` を **minor** bump（新スキル追加 = minor。skill rename/remove ではないため major 不要）
- [ ] verify: `grep` で README 2 件・CHANGELOG・plugin.json の更新を確認し、`scripts/check-plugin-version.sh` 相当で version と CHANGELOG 最新見出しの整合を確認

- [ ] ドキュメント整合性チェック（`rules/atdd-kit.md` 60 行バジェット維持、`docs/workflow/` のルート分離記述整合）
- [ ] verify: `wc -l rules/atdd-kit.md` が 60 以下、関連ドキュメントが bugfix ルート追加と整合している

- [x] **half-scope の User 明示確認＋ flaky フォローアップ Issue 作成（finding#4）**: Issue #308 のタイトル/提案は bugfix AND flaky-test-fix の 2 ルートを謳うが、本 Issue は **bugfix ルートのみに scope を絞り flaky は次 Issue に defer** する（prd.md:31 / Non-Goal）。この**半スコープ（bugfix のみ／flaky は次 Issue）を設計承認（bugfix では原因合意 = cause-agreement）ゲートで User に明示提示**し、`enhancement` ラベル＋両ルートを約束するタイトルとの差分を User が明示確認できるようにする。flaky-test-fix ルートのフォローアップ Issue は **#322（flaky-test-fix 専用の軽量ルートを設ける）として実際に作成済み**（`gh issue create`）であり、本 plan からリンクする
- [x] verify: 設計承認ゲート提示文に「bugfix のみ／flaky は次 Issue」の half-scope 明示があること、flaky フォローアップ Issue（**#322**）が作成済み（番号付き）で本 plan から参照されていることを確認
