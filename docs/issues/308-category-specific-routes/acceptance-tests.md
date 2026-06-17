# Acceptance Tests: bugfix 専用の軽量ルート（フル機能ルートと分離）

<!-- AT lifecycle: planned → draft → green → regression
     各エントリには状態マーカー [planned] / [draft] / [green] / [regression] を付与する。
     状態は実装の進行に合わせて更新する。
     注意（#289）: [regression] になる AT は将来の全ブランチで永続実行されるため、
     その時点限りの値（現行 plugin version / 日付 / 行数）を完全一致ピンしてはならない。
     不変条件（invariant）を assert する。 -->

## AT-308-1: 軽量ルートは PRD/US/Plan をスキップして既存スキルを連鎖する（US1 / US-Constraint1）

- [ ] [planned] AT-308-1: `fixing-bugs` オーケストレーションスキルが、フル機能 3 スキルをスキップして bugfix 5 連鎖を構成する
  - Given: `skills/fixing-bugs/SKILL.md` が存在する
  - When: SKILL.md 本文を読む
  - Then: `bug` → `debugging` → `running-atdd-cycle` → `reviewing-deliverables` → `merging-and-deploying` の 5 スキルが連鎖として記述され、かつ `defining-requirements` / `extracting-user-stories` / `writing-plan-and-tests` の 3 スキルが「スキップ」文脈で記述されている（不変: 連鎖構成そのもの。特定行番号には依存しない）

## AT-308-1b: `bug` の組込み forward chain が `fixing-bugs` の連鎖定義で上書きされる（finding#1）

- [ ] [planned] AT-308-1b: bugfix ルートで `bug` を実行しても、`bug` の「Next Step」がハードコードする `defining-requirements` への routing が `fixing-bugs` のオーケストレーションで上書きされ、ルートがランタイムで機能する
  - Given: `skills/fixing-bugs/SKILL.md` の forward-chain override 記述と未編集の `skills/bug/SKILL.md`
  - When: `fixing-bugs/SKILL.md` の override 機構記述を読み、`skills/bug/SKILL.md` の編集有無を確認する
  - Then: `fixing-bugs/SKILL.md` に (a) オーケストレーターが各スキルの Skill 呼び出しを明示駆動する（orchestrator-driven invocation）、(b) 被連鎖スキルの「Next Step」は本ルート下では advisory に過ぎず `fixing-bugs` の連鎖定義が上書きする、(c) `bug` 完了後は `bug` の Next Step（`defining-requirements`）を辿らず `debugging` を次に呼ぶ、の 3 点が記述されており、かつ `skills/bug/SKILL.md` が未編集である（`git diff --quiet skills/bug/SKILL.md`）（不変: `bug` を書き換えずに forward chain がインターセプトされる override 機構の実体が pin される。SKILL.md テキストが skip+5連鎖を述べるだけでなく、override 機構そのものを pin することで、非機能なルートが green AT と共存しない）

## AT-308-2: description はトリガー条件のみ（DEVELOPMENT.md 準拠 / US-Constraint1）

- [ ] [planned] AT-308-2: `fixing-bugs` の YAML `description` がワークフロー要約を含まずトリガー条件のみである
  - Given: `skills/fixing-bugs/SKILL.md` の frontmatter
  - When: `name` / `description` を抽出する
  - Then: `name` == `fixing-bugs`、`description` は起動条件のみで「creates ... then ...」のような工程列挙を含まない（不変: Skill Description Field Rules 遵守）

## AT-308-3: 再現確認が platform-aware に実ツールへ配線される（US2 1a）

- [ ] [planned] AT-308-3: 再現確認ステップが `.claude/config.yml` の `platform` に応じて実ツールに分岐し、外部スキル/外部 MCP は参照のみである
  - Given: `skills/fixing-bugs/SKILL.md` の再現確認ステップ
  - When: 本文を読む
  - Then: web → `playwright-cli`/`verify`、iOS → Xcode/simulator MCP（＋`sim-pool`）、other → CLI/スクリプト（bats 等）の 3 分岐が明示され、かつ `playwright-cli`/`verify`/Xcode MCP が**外部スキル/外部 MCP 参照**として（atdd-kit 所有スキルとしてではなく）記述されている（不変: 3 platform × 対応ツールのマッピング＋外部参照の区別。`playwright-cli`/`verify` の atdd-kit ローカルスキルファイル・`skills/README.md` 登録・BATS 構造テストは生成しない）

## AT-308-4: 再現は実行可能な failing test に符号化されオラクルアンカーになる（US2 1b）

- [ ] [planned] AT-308-4: 確認できた再現が failing test（赤→修正後に緑）として符号化され、autopilot 収束オラクルのアンカーになる
  - Given: `skills/fixing-bugs/SKILL.md` の符号化ステップ
  - When: 本文を読む
  - Then: 「再現 → 実行可能な failing test（赤）→ 修正後に緑」がオラクルのアンカーとして記述されている（不変: 赤→緑のアンカー関係）

## AT-308-5: bugfix ルート判定は route-eligibility.md（SoT）に集約され autopilot は参照のみ（US3 / finding#3）

- [ ] [planned] AT-308-5: ラベル＋キーワード＋タスク内容からの bugfix ルート判定が `docs/methodology/route-eligibility.md`（SoT）に定義され、低確信時は #305 ワンタップ承認と整合した User 確認に落ち、autopilot は判定ロジック本体を持たず参照する
  - Given: `docs/methodology/route-eligibility.md` と `skills/autopilot/SKILL.md` の Express precheck 節
  - When: 両者を読む
  - Then: route-eligibility.md に bugfix ルート判定の入力（`type:bug` 等のラベル＋キーワード＋タスク内容）と低確信時の User 確認分岐（#305 ワンタップ整合）が定義され、「Recommendation Only / No Auto-Routing」不変条件が維持され、autopilot SKILL.md は判定ロジック本体を重複させず route-eligibility.md を**参照**している（不変: 判定ロジックは SoT に単一定義・autopilot は参照のみ・auto-route なし）

## AT-308-6: 明示コマンド `/atdd-kit:autofix` で bugfix ルートを起動できる（US3）

- [ ] [planned] AT-308-6: `commands/autofix.md` が `fixing-bugs` ルートを issue 引数付きで明示起動する
  - Given: `commands/autofix.md` が存在する
  - When: 内容を読む
  - Then: `<issue>` 引数を受け取り `fixing-bugs` ルートを起動する記述がある（不変: コマンド → ルートの結線）

## AT-308-7: bugfix autopilot 収束オラクル＋AL-3 coverage 項の specialization（US4 / finding#5）

- [ ] [planned] AT-308-7: bugfix 用収束オラクルが「回帰テスト green ＋ 既存回帰なし（＋再現テスト赤→緑）」で定義され、AL-3 の `AC→AT coverage` 項が「失敗再現テスト被覆」に specialize され、マージは User gate（AL-1）を維持する
  - Given: `skills/autopilot/SKILL.md` の bugfix オラクル定義と `docs/methodology/autopilot-iron-law.md` の bugfix 特化条項
  - When: 両者を読む
  - Then: オラクルに「回帰テスト green」「既存テスト非破壊（既存回帰なし）」「再現テスト赤→緑」が揃い、autopilot-iron-law.md に AL-3 の `AC→AT coverage` 項が bugfix では「原因合意ゲート承認済みの失敗再現テスト被覆（赤→緑が外部コンテキストで確認される）」に **specialize**（override ではなく標準ルートの coverage はそのまま）される旨が記述され、coverage ガードが「tests pass」へ degrade していない（不変: オラクル 3 条件＋coverage アンカーが再現テストに特化＋AL-3 の AND 構造非破壊）。さらにマージが常に User gate（Iron Law AL-1）であることが記述されている
  - **スコープ注記（finding priority-3, 過剰主張防止）**: 本 AT は再現テスト赤→緑を生む**配線（wiring）の存在**を静的に pin するのであって、AT-308.bats 自身が実際の fix ループを実行して赤→緑のランタイム挙動を観測するわけではない。赤→緑の収束オラクル挙動はオーケストレーションのランタイム特性であり text-grep では exercise できないため、その挙動は **wiring pin ＋（out-of-band の）autopilot replay/fixture 経路**で検証される（AT-302/AT-305 がドキュメント構造を pin するのと同じ no-runtime-suite 方針）

## AT-308-7b: AL-1 三ゲート不変条件は cause-agreement ゲートで満たされる（finding#1）

- [ ] [planned] AT-308-7b: bugfix ルートが US/Plan/AT spec を作らない場合でも、設計承認ゲートが **cause-agreement（根本原因分類＋失敗再現テスト承認）** に specialize され、AL-1 の三ゲート不変条件（ATDD は中間ゲート前に開始しない／ゲートの除去・自動化・迂回なし）が満たされる
  - Given: `docs/methodology/autopilot-iron-law.md`（AL-1）、`docs/methodology/autopilot-design-gate.md`（#305 が split out したゲート提示契約）、`skills/fixing-bugs/SKILL.md` のゲート記述
  - When: 三者を読む
  - Then: autopilot-iron-law.md に「bugfix ルートでは middle gate が design-approval から cause-agreement（承認対象 = `debugging` Step 5 の根本原因分類＋失敗再現テスト）へ specialize される。ゲート数は三のまま（除去・追加なし）」が明記され、**かつ `autopilot-design-gate.md` の presentation contract にも bugfix ルートで本ゲートが cause-agreement ゲートとして機能し承認対象が「根本原因分類＋失敗再現テスト」である旨が記述され、両文書が bugfix の middle-gate 定義について一致している（片方に着地して他方が stale でない）**。さらに `fixing-bugs` SKILL.md で ATDD（最小修正）が cause-agreement ゲート通過後にのみ開始する旨が記述されている（不変: 設計承認ゲートは除去されず cause-agreement に置換され、承認対象が空でない実体＝再現テスト＋分類を持つため AL-1「ATDD never starts before that gate」が維持される。specialization が iron-law.md と design-gate.md の両文書で整合する）
  - **二文書整合 pin の配置・robustness（finding priority-3）**: 両文書一致を確認する cross-doc consistency pin は `tests/test_autopilot_skill.bats`（skill 構造スイート）ではなく **`tests/acceptance/AT-308.bats` が own** し、日本語 prose のフル文一致ではなく**安定不変トークン `cause-agreement`** のリテラル grep（`grep -F 'cause-agreement'` が両ファイルに hit）で pin する（メソドロジー文書 2 つの prose レベル一致を構造スイートで pin すると brittle なため）

## AT-308-8: Type A 根本原因はフル機能ルートへ昇格する（US5）

- [ ] [planned] AT-308-8: `debugging` の Root Cause 分類が Type A（AC Gap）の場合、bugfix 軽量ルートを離脱し `defining-requirements` 起点のフル機能ルートへ昇格する
  - Given: `skills/fixing-bugs/SKILL.md` の昇格基準
  - When: 本文を読む
  - Then: Type A（AC Gap = 仕様/設計判断が必要）で `debugging → defining-requirements` 連鎖を流用してフル機能ルートへ昇格する旨が記述されている（不変: Type A → 昇格 → defining-requirements の結線）

## AT-308-9: マージは bugfix ルートでも常に User gate を経由する（US-Constraint2）

- [ ] [planned] AT-308-9: bugfix ルートのマージステップが `merging-and-deploying` 経由で常に User gate（AL-1）を要求する
  - Given: `skills/fixing-bugs/SKILL.md` のマージステップ
  - When: 本文を読む
  - Then: マージが `merging-and-deploying` を経由し User gate（autopilot Iron Law AL-1）を必須とする（自動マージしない）旨が記述されている（不変: 軽量化してもマージ判断は人間に残る）

## AT-308-9b: half-scope が User に明示確認され flaky フォローアップ Issue が作成される（finding#4）

- [ ] [planned] AT-308-9b: Issue #308 が bugfix AND flaky の 2 ルートを謳うのに対し本 Issue は bugfix のみに scope を絞るため、設計承認（bugfix では原因合意）ゲートで half-scope が User に明示提示され、flaky フォローアップ Issue が実際に作成される
  - Given: `docs/issues/308-category-specific-routes/plan.md` の Finishing と設計承認ゲート提示
  - When: plan の half-scope ステップと作成済み Issue を確認する
  - Then: 設計承認ゲート提示文に「bugfix のみ／flaky は次 Issue」の half-scope 明示があり、flaky-test-fix ルートのフォローアップ Issue が作成済み（番号付き）で本 plan から参照されている（不変: 半スコープの User 明示確認＋フォローアップ Issue の実在。Issue ラベルが `enhancement` でタイトルが両ルートを約束する差分を User が確認できる）

## AT-308-10: バージョン整合は不変条件で守る（リリース回帰ガード / #289）

- [ ] [planned] AT-308-10: 新スキル追加に伴う version/CHANGELOG 整合が、点ではなく不変条件で守られる
  - Given: `.claude-plugin/plugin.json` と `CHANGELOG.md`
  - When: version と最新リリース見出しを照合する
  - Then: `plugin.json` の version が CHANGELOG の**最上位リリース見出し**と一致する（不変条件として assert。`== "3.x.y"` のような特定バージョン完全一致ピンは禁止 — #289 で post-merge 回帰が次の bump で永続赤化したため）

## ライフサイクル例

| 状態 | 意味 |
|------|------|
| [planned] | テスト設計済み・未実装 |
| [draft] | 実装中・まだ通過していない |
| [green] | テスト通過済み |
| [regression] | リグレッション対象として継続監視中 |
