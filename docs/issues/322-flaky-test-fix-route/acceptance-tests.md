# Acceptance Tests: flaky-test-fix 専用の軽量ルート（bugfix ルートの兄弟）

<!-- AT lifecycle: planned → draft → green → regression
     各エントリには状態マーカー [planned] / [draft] / [green] / [regression] を付与する。
     状態は実装の進行に合わせて更新する。
     注意（#289）: [regression] になる AT は将来の全ブランチで永続実行されるため、
     その時点限りの値（現行 plugin version / 日付 / 行数 / 反復回数 N の具体値）を
     完全一致ピンしてはならない。不変条件（invariant）を assert する。 -->

## AT-322-1: 軽量ルートは PRD/US/Plan をスキップして既存スキルを連鎖する（FS-1 / CS-2）

- [ ] [planned] AT-322-1: `fixing-flaky-tests` オーケストレーションスキルが、フル機能 3 スキルをスキップして flaky 5 連鎖を構成する
  - Given: `skills/fixing-flaky-tests/SKILL.md` が存在する
  - When: SKILL.md 本文を読む
  - Then: `bug` → `debugging` → `running-atdd-cycle` → `reviewing-deliverables` → `merging-and-deploying` の 5 スキルが連鎖として記述され、かつ `defining-requirements` / `extracting-user-stories` / `writing-plan-and-tests` の 3 スキルが「スキップ」文脈で記述されている（不変: 連鎖構成そのもの。特定行番号には依存しない）

## AT-322-1b: `bug` の組込み forward chain が `fixing-flaky-tests` の連鎖定義で上書きされる（兄弟ルート整合）

- [ ] [planned] AT-322-1b: flaky ルートで `bug` を実行しても、`bug` の「Next Step」がハードコードする `defining-requirements` への routing が `fixing-flaky-tests` のオーケストレーションで上書きされ、ルートがランタイムで機能する
  - Given: `skills/fixing-flaky-tests/SKILL.md` の forward-chain override 記述と未編集の `skills/bug/SKILL.md`
  - When: `fixing-flaky-tests/SKILL.md` の override 機構記述を読み、`skills/bug/SKILL.md` の編集有無を確認する
  - Then: `fixing-flaky-tests/SKILL.md` に (a) オーケストレーターが各スキルの Skill 呼び出しを明示駆動する（orchestrator-driven invocation）、(b) 被連鎖スキルの「Next Step」は本ルート下では advisory に過ぎず `fixing-flaky-tests` の連鎖定義が上書きする、(c) `bug` 完了後は `bug` の Next Step（`defining-requirements`）を辿らず `debugging` を次に呼ぶ、の 3 点が記述されており、かつ `skills/bug/SKILL.md` が未編集である（`git diff --quiet skills/bug/SKILL.md`）（不変: `bug` を書き換えずに forward chain がインターセプトされる override 機構の実体が pin される）

## AT-322-2: description はトリガー条件のみ（DEVELOPMENT.md 準拠 / CS-2）

- [ ] [planned] AT-322-2: `fixing-flaky-tests` の YAML `description` がワークフロー要約を含まずトリガー条件のみである
  - Given: `skills/fixing-flaky-tests/SKILL.md` の frontmatter
  - When: `name` / `description` を抽出する
  - Then: `name` == `fixing-flaky-tests`、`description` は起動条件（flaky / 不安定 / intermittent / `/atdd-kit:flaky-fix`）のみで「creates ... then ...」のような工程列挙を含まない（不変: Skill Description Field Rules 遵守）

## AT-322-3: 確率的再現の確認が platform-aware に反復実ツールへ配線され失敗率を記録する（FS-2 / 2a）

- [ ] [planned] AT-322-3: 確率的再現確認ステップが `.claude/config.yml` の `platform` に応じて反復実ツールに分岐し、失敗率を記録し、単発を再現確認としない
  - Given: `skills/fixing-flaky-tests/SKILL.md` の確率的再現確認ステップ
  - When: 本文を読む
  - Then: other → bats/スクリプトのループ実行、web → `playwright-cli` 反復、iOS → Xcode/simulator MCP 反復 の 3 分岐が明示され、N 回反復 / seed・実行順・並列度の変動で flaky を firsthand 確認し**失敗率を記録**する旨と「単発実行を再現確認としない」旨が記述され、外部ツール（`playwright-cli`/Xcode MCP）が**外部参照**として（atdd-kit 所有スキルとしてではなく）記述されている（不変: 3 platform × 反復手段＋失敗率記録＋単発否定。反復回数 N の具体値は pin しない）

## AT-322-4: 反復で観測可能な failing アンカーに符号化され収束オラクルのアンカーになる（FS-3 / 2b）

- [ ] [planned] AT-322-4: 確認した非決定性が「反復実行で一定確率赤になる」failing アンカーに符号化され、修正後は N 回連続緑で決定化を確認する収束オラクルのアンカーになる
  - Given: `skills/fixing-flaky-tests/SKILL.md` の符号化ステップ
  - When: 本文を読む
  - Then: 「反復実行で一定確率赤」になるアンカーへの符号化と、「修正後に N 回連続緑で決定化を確認」がオラクルアンカーとして記述されている（不変: 反復赤→ N 回連続緑のアンカー関係。N の具体値は pin しない）

## AT-322-5: 非決定性の原因分類が `debugging` Type を flaky 軸で運用する（FS-4）

- [ ] [planned] AT-322-5: タイミング/順序/共有状態/外部依存/リソースリークの非決定性カテゴリが `debugging` の既存 Type 分類の flaky 運用としてオーケストレータ側に記述され、`debugging` 本体は無編集である
  - Given: `skills/fixing-flaky-tests/SKILL.md` の非決定性分類記述と `skills/debugging/SKILL.md`
  - When: 両者を読む
  - Then: 5 非決定性カテゴリ（タイミング依存/順序依存/共有状態/外部依存/リソースリーク）が `debugging` の Type 分類（Type C 配下の運用サブ軸）として flaky 軸で運用される旨がオーケストレータ側に記述され、新しい Type 軸を `debugging` に足していない（`git diff --quiet skills/debugging/SKILL.md`）（不変: 既存 Type の flaky 運用・重複ゼロ・`debugging` 無編集）

## AT-322-6: cause-agreement ゲートが flaky 用に「非決定性分類＋反復失敗率」へアンカーされ二文書整合する（FS-5 / 兄弟ルート整合）

- [ ] [planned] AT-322-6: flaky ルートの middle gate が cause-agreement へ specialize され、承認対象が「非決定性の原因分類＋反復失敗率（修正前 X% → 修正後 0%）」で、`autopilot-iron-law.md` と `autopilot-design-gate.md` の両文書が一致する
  - Given: `docs/methodology/autopilot-iron-law.md`（AL-1）、`docs/methodology/autopilot-design-gate.md`（提示契約）、`skills/fixing-flaky-tests/SKILL.md` のゲート記述
  - When: 三者を読む
  - Then: autopilot-iron-law.md に「flaky ルートでは middle gate が design-approval から cause-agreement（承認対象 = 非決定性の原因分類＋反復失敗率）へ specialize、ゲート数は三のまま」が明記され、**かつ `autopilot-design-gate.md` の presentation contract にも flaky ルートで本ゲートが cause-agreement として機能し承認対象が「非決定性分類＋反復失敗率」である旨が記述され、両文書が一致している（片方着地で他方 stale でない）**。さらに `fixing-flaky-tests` SKILL.md で ATDD（決定化する最小修正）が cause-agreement ゲート通過後にのみ開始する旨が記述されている（不変: 設計承認ゲートは除去されず cause-agreement に置換され、承認対象が空でない実体＝分類＋失敗率を持つため AL-1「ATDD never starts before that gate」が維持され、specialization が両文書で整合する）
  - **二文書整合 pin の配置・robustness**: 両文書一致を確認する cross-doc consistency pin は `tests/test_autopilot_skill.bats`（skill 構造スイート）ではなく **`tests/acceptance/AT-322.bats` が own** し、日本語 prose のフル文一致ではなく**安定不変トークン `cause-agreement`** のリテラル grep（`grep -F 'cause-agreement'` が両ファイルに hit）で pin する（#308 と同じ robustness 方針）

## AT-322-7: quarantine（隔離）判断と追跡がルートに組み込まれる（FS-6）

- [ ] [planned] AT-322-7: 即時決定化が困難な flaky を一時隔離（platform-aware な隔離マーク）して他作業をブロックせず、隔離後も追跡（Issue 残置 / 再 dispatch）する判断ポイントがルートに記述されている
  - Given: `skills/fixing-flaky-tests/SKILL.md` の quarantine 判断ポイント
  - When: 本文を読む
  - Then: 一時隔離マーク（other=bats `skip`/タグ、web=Playwright skip/`fixme`、iOS=`XCTSkip` 等の外部ランナー機能参照）で他作業をブロックしない判断と、隔離後の追跡（Issue 残置 / 再 dispatch）が必須で放置しない旨が記述され、隔離手段の atdd-kit ローカル実装を作らない（外部参照のみ）（不変: 隔離判断＋追跡の組込み・外部参照のみ）

## AT-322-8: flaky ルート判定は route-eligibility.md（SoT）に集約され autopilot は参照のみ（FS-7）

- [ ] [planned] AT-322-8: ラベル `type:flaky` ＋キーワードからの flaky ルート判定が `docs/methodology/route-eligibility.md`（SoT）に定義され、低確信時は #305 ワンタップ User 確認と整合し、autopilot は判定ロジック本体を持たず参照する
  - Given: `docs/methodology/route-eligibility.md` と `skills/autopilot/SKILL.md`
  - When: 両者を読む
  - Then: route-eligibility.md に flaky ルート判定信号（ラベル `type:flaky` ＋キーワード `flaky`/`不安定`/`間欠的に失敗`/`intermittent`＋タスク内容）と flaky/bugfix 境界、低確信時の User 確認（#305 ワンタップ整合）が定義され、「Recommendation Only / No Auto-Routing」不変条件が維持され、autopilot SKILL.md は判定ロジック本体を重複させず route-eligibility.md を**参照**している（不変: 判定ロジックは SoT に単一定義・autopilot は参照のみ・auto-route なし）

## AT-322-9: 明示コマンド `/atdd-kit:flaky-fix` で flaky ルートを起動できる（FS-7）

- [ ] [planned] AT-322-9: `commands/flaky-fix.md` が `fixing-flaky-tests` ルートを issue 引数付きで明示起動する
  - Given: `commands/flaky-fix.md` が存在する
  - When: 内容を読む
  - Then: `<issue>` 引数を受け取り `fixing-flaky-tests` ルートを起動する記述がある（不変: コマンド → ルートの結線）

## AT-322-10: flaky autopilot 収束オラクルが反復ベースで単発 green を収束とせずマージは User gate（CS-1 / CS-3）

- [ ] [planned] AT-322-10: flaky 用収束オラクルが「N 回連続 green（決定化）＋ 既存テスト非破壊」で定義され、単発 green を収束とせず、AL-3 coverage 項が反復 failing アンカー被覆に specialize され、マージは User gate（AL-1）を維持する
  - Given: `docs/methodology/autopilot-iron-law.md` の flaky 特化条項と `skills/autopilot/SKILL.md` の参照
  - When: 両者を読む
  - Then: autopilot-iron-law.md の flaky オラクルに「N 回連続 green（決定化の確認）」「既存テスト非破壊（既存回帰なし）」「単発 green を収束としない」が揃い、AL-3 の `AC→AT coverage` 項が flaky では「反復で観測可能な failing アンカー被覆（反復赤→ N 回連続緑が外部コンテキストで確認される）」に **specialize**（override ではなく標準ルートの coverage はそのまま）され、coverage ガードが「tests pass」へ degrade しておらず、マージが常に User gate（Iron Law AL-1・自動マージしない）である。`skills/autopilot/SKILL.md` は flaky オラクル条項を **loader-stub 1 行で参照**し配線本体を重複させず、`wc -l skills/autopilot/SKILL.md` が **≤ 280**（3 回目の行バジェット昇格禁止）である（不変: 反復ベースオラクル＋単発否定＋coverage の反復アンカー特化＋AL-3 AND 構造非破壊＋マージ User gate＋行バジェット ≤280）
  - **スコープ注記（過剰主張防止）**: 本 AT は反復赤→ N 回連続緑を生む**配線（wiring）の存在**を静的に pin するのであって、AT-322.bats 自身が実際の反復 fix ループを実行して赤→緑のランタイム挙動を観測するわけではない。収束オラクル挙動はオーケストレーションのランタイム特性で text-grep では exercise できないため、その挙動は **wiring pin ＋（out-of-band の）autopilot replay/fixture 経路**で検証される（#308 AT-308 と同じ no-runtime-suite 方針）

## AT-322-11: Type A 根本原因はフル機能ルートへ昇格する（FS-4 補）

- [ ] [planned] AT-322-11: `debugging` の Root Cause 分類が Type A（AC Gap）の場合、flaky 軽量ルートを離脱し `defining-requirements` 起点のフル機能ルートへ昇格する
  - Given: `skills/fixing-flaky-tests/SKILL.md` の昇格基準
  - When: 本文を読む
  - Then: Type A（AC Gap = 仕様/設計判断が必要）で `debugging → defining-requirements` 連鎖を流用してフル機能ルートへ昇格する旨が記述されている（不変: Type A → 昇格 → defining-requirements の結線）

## AT-322-12: 既存スキル・兄弟ルートが無編集で再利用される（CS-2）

- [ ] [planned] AT-322-12: flaky 特化の追補がすべて `fixing-flaky-tests` 側に置かれ、`bug`/`debugging`/`running-atdd-cycle`/`reviewing-deliverables`/`merging-and-deploying` と `fixing-bugs`（bugfix ルート）が無編集で再利用される
  - Given: 既存スキル群と兄弟ルート `fixing-bugs` の SKILL.md
  - When: 本 Issue ブランチでの編集有無を確認する
  - Then: `git diff --quiet skills/bug/SKILL.md skills/debugging/SKILL.md skills/running-atdd-cycle/SKILL.md skills/reviewing-deliverables/SKILL.md skills/merging-and-deploying/SKILL.md skills/fixing-bugs/SKILL.md` が成立する（不変: 重複ゼロ・既存スキル/兄弟ルート無編集。flaky 特化は新オーケストレータ側のみ）

## AT-322-13: バージョン整合は不変条件で守る（リリース回帰ガード / #289）

- [ ] [planned] AT-322-13: 新スキル追加に伴う version/CHANGELOG 整合が、点ではなく不変条件で守られる
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
