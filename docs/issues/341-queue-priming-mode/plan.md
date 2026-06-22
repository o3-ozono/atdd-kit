# Plan: batch-discovery — 壁打ちを最前倒し一括化し ready-to-go 準備を並列バックグラウンド自走させる

<!-- 2-5 分粒度のタスク行と verification 行を交互に配置する（superpowers writing-plans 形式）。
     各タスクは単一の操作に限定し、verification で完了条件を即確認できる粒度にする。 -->

> 設計判断（AskUserQuestion バッチ束ね方・覆りうる点の昇格基準・実装順序の記録先・収束オラクル）は
> `design-doc.md` を真実源とする。本 plan はそこで採択した案を実装タスクへ落とし込む。

## Implementation

### A. スキル骨格（FS-1 / 疎結合 C3）

- [ ] `skills/batch-discovery/` ディレクトリを作り `SKILL.md` の frontmatter（name / description）を追加する
- [ ] verify: `skills/batch-discovery/SKILL.md` が存在し、`name: batch-discovery` と「準備フェーズ専用・full-autopilot 本体を書き換えない」旨が description に含まれる

- [ ] `SKILL.md` に Trigger（明示 `/atdd-kit:batch-discovery <issue...>` ＋ keyword 確認）と Input（対象 Issue 群 / 並列度 K）を記述する
- [ ] verify: SKILL.md に explicit trigger 行と「auto-invoke しない（確認後起動）」の記述がある

- [ ] `SKILL.md` の Responsibility Boundary 表に「準備フェーズ＝batch-discovery / 消化＝full-autopilot へ手渡し」を明記する
- [ ] verify: boundary 表に batch-discovery と full-autopilot の責務分割行があり、本体非改変が読める

### B. 横断バッチ壁打ち（FS-2 / FS-3 / CS-1）

- [ ] `SKILL.md` Flow に「対象 Issue 群を全自律読み込み → Issue 本文・docs から導出可能な要件は自律ドラフト（質問しない）」のステップを記述する
- [ ] verify: Flow に「導出可能な要件は質問せず自律ドラフト」（Dialog economy #254 を N Issue 分に拡張）の記述がある

- [ ] `SKILL.md` Flow に「人間にしか決められない点（トレードオフ / 割り切り / スコープ取捨 / リスク許容度 / 合否基準）だけを抽出し全 Issue 横断で 1 バッチ提示」を記述する
- [ ] verify: Flow に抽出対象 5 種が列挙され、「全 Issue 横断 1 バッチ」と書かれている

- [ ] AskUserQuestion の 1 メッセージ最大 4 質問制約下での束ね方を design-doc 採択案どおりに SKILL.md へ記述する
- [ ] verify: SKILL.md の壁打ち提示方式が design-doc の Proposal と一致し、4 質問上限の扱いが明記されている

### C. 並列自走（FS-4 / FS-5 — 既存 lib 転用）

- [ ] `SKILL.md` Flow に「疑問解消済み Issue から `lib/full-autopilot-dispatch.sh select <K> <issue...>` で issue-lease を取りつつ dispatch」を記述する
- [ ] verify: Flow が `lib/full-autopilot-dispatch.sh` の `select` を呼ぶ経路を明記し、他セッション claim 済みスキップに言及する

- [ ] `SKILL.md` Flow に「worktree 隔離＋プラグイン設定播種（#329）で headless worker 起動」を記述する（`lib/full-autopilot-run.sh` の `__seed_worktree_settings` 転用）
- [ ] verify: Flow が worktree 播種を必須として記し、播種なしの `Unknown command` 即死リスクに言及する

- [ ] worker の準備ゴールを「PRD→US→plan+AT→reviewing-deliverables PASS→Draft PR→`ready-to-go`」と SKILL.md に記述する
- [ ] verify: Flow の worker ゴール列が PRD から ready-to-go まで全段を含む

- [ ] worker lease 解放を 3 経路（正常 / 失敗・timeout / TTL）で `lib/lease-store.sh release issue` 経由にすると SKILL.md に記述する
- [ ] verify: SKILL.md の lifecycle 節が 3 経路すべての release を記し、TTL を最終防衛とする

### D. 実装順序の記録による軽量順序制御（FS-6）

- [ ] design-doc 採択の記録先（manifest）形式を確定し SKILL.md に「keystone→後続の順序を共有真実源に記録し worker をその順で進める」を記述する
- [ ] verify: SKILL.md に順序記録の保存先と dispatcher がそれを読む経路が記され、design-doc と一致する

- [ ] Non-Goal として「フル barrier / 動的依存解決は採らない（軽量順序記録のみ）」を SKILL.md に明記する
- [ ] verify: SKILL.md の Non-Goals に barrier / 動的依存解決の除外が書かれている

### E. 選別ピックアップ式の最終承認ゲート（FS-7 / CS-2）

- [ ] `SKILL.md` Flow に「準備フェーズ（reviewer-oracle 含む）が検出した覆りうる点だけを選別提示 → 承認後 `ready-to-go` 付与」を記述する
- [ ] verify: Flow に「一括承認しない・覆りうる点のみ選別提示」と「覆りうる点ゼロなら最終承認スキップ」が書かれている

- [ ] 覆りうる点の昇格基準（finding 種別 / priority）を design-doc 採択どおり SKILL.md に記述する（デフォルト＝トレードオフ・意図的割り切り・スコープ取捨に該当する finding）
- [ ] verify: SKILL.md の昇格基準が design-doc と一致し、デフォルト基準が明記されている

- [ ] AL-1 三ゲート整合（Gate ①＝横断バッチ壁打ち 1 回 / Gate ②相当＝選別最終承認 最大 1 回 / Gate ③ merge は full-autopilot 側で不変）を SKILL.md に明文化する
- [ ] verify: SKILL.md が AL-1 の 3 ゲートと batch-discovery の人間ゲートの対応を記し、Gate ③ 不変を読める

## Testing

- [ ] `tests/acceptance/AT-341-skill-contract.bats` で「SKILL.md に Trigger / Input / boundary / 本体非改変」が含まれることを検証する
- [ ] verify: bats が green。`@covers: skills/batch-discovery/SKILL.md` を持つ

- [ ] `tests/acceptance/AT-341-dispatch-reuse.bats` で「batch-discovery が `lib/full-autopilot-dispatch.sh select` を呼んだとき K スロット分だけ issue-lease を取り busy issue をスキップする」を検証する
- [ ] verify: bats が green。既存 lib の select 経路を fixture で実行し選択件数を assert する

- [ ] `tests/acceptance/AT-341-ready-to-go-gate.bats` で「覆りうる点ゼロなら最終承認をスキップして ready-to-go へ進める / 覆りうる点ありなら承認前は ready-to-go を付与しない」を検証する
- [ ] verify: bats が green。承認分岐の 2 ケースを assert する

- [ ] `tests/acceptance/AT-341-gate-invariant.bats` で「SKILL.md が AL-1 三ゲートと整合し Gate ③ が full-autopilot 側で不変と明文化されている」ことを deterministic に検証する
- [ ] verify: bats が green。3 ゲート対応と Gate ③ 不変の不変条件を assert する

- [ ] 上記 4 本を含む acceptance スイートを bats で通す
- [ ] verify: AT-341-* すべてが green

## Finishing

- [ ] `CHANGELOG.md` の Unreleased に batch-discovery 追加を Keep a Changelog 形式で記す
- [ ] verify: CHANGELOG の Unreleased に #341 の追加エントリがある

- [ ] `rules/atdd-kit.md` / 関連 docs にスキル追加が反映され、AL-1 整合の参照が貼られているか確認する
- [ ] verify: ドキュメント整合性チェックが通り、batch-discovery が一覧／参照に載っている

- [ ] ドキュメント整合性チェック
- [ ] verify: 関連ドキュメントが変更内容と整合している
