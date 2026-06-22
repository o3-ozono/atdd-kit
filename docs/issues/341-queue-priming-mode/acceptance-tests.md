# Acceptance Tests: batch-discovery — 壁打ちを最前倒し一括化し ready-to-go 準備を並列バックグラウンド自走させる

<!-- AT lifecycle: planned → draft → green → regression
     各エントリには状態マーカー [planned] / [draft] / [green] / [regression] を付与する。
     状態は実装の進行に合わせて更新する。
     [regression] AT は将来の全ブランチで永続実行されるため、時点固定値（バージョン・日付・行数）を
     ピン留めせず不変条件を assert すること（#289）。 -->

## AT-341-A: 独立スキル batch-discovery として準備フェーズを起動できる（FS-1 / CS-2）

- [x] [regression] AT-341-A-1: SKILL.md が独立スキル契約（Trigger / Input / boundary / 本体非改変）を満たす
  - Given: リポジトリに `skills/batch-discovery/SKILL.md` が存在する
  - When: SKILL.md の frontmatter と本文を読む
  - Then: `name: batch-discovery` を持ち、明示 trigger `/atdd-kit:batch-discovery` と Input（対象 Issue 群 / 並列度 K）が記述され、Responsibility Boundary 表に「full-autopilot 本体を書き換えない（疎結合）」旨が含まれる（特定の行数・文言全文には依存しない）

- [x] [regression] AT-341-A-1-nit: SKILL.md worker 起動擬似コードに CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS=0 が含まれる（レビュー指摘 priority=3）
  - Given: `skills/batch-discovery/SKILL.md` が存在する
  - When: Phase 3 の worker 起動擬似コードを読む
  - Then: `CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS=0` が記載されており、headless worker の bg-wait 600s 上限を解除する必要性が読める（lib/full-autopilot-run.sh の __default_launch・CHANGELOG 4.0.0 と整合）

## AT-341-B: 横断バッチ壁打ちは人間判断点だけを 1 バッチで提示する（FS-2 / FS-3 / CS-1）

- [x] [regression] AT-341-B-1: 導出可能な要件は自律ドラフトし、人間判断点だけを全 Issue 横断 1 バッチで提示する
  - Given: 複数 Issue を対象に batch-discovery を起動する
  - When: SKILL.md の壁打ちフローを読む
  - Then: 「Issue 本文・docs から導出可能な要件は質問しない（自律ドラフト）」と「人間にしか決められない 5 種（トレードオフ / 割り切り / スコープ取捨 / リスク許容度 / 合否基準）だけを全 Issue 横断で 1 バッチ提示」が記述され、AskUserQuestion の 1 メッセージ最大 4 質問制約下での束ね方が明記されている

- [x] [regression] AT-341-B-2: 人間の対話回数が Issue 件数に依存しない定数回に保たれる
  - Given: N 件（N≥2）を投入する運用を想定する
  - When: SKILL.md の人間ゲート定義を読む
  - Then: 人間ゲートが「front-loaded 壁打ち 1 回 ＋ 必要時のみ最終承認 1 回」という Issue 件数に非依存な定数回として定義されている（件数比例の per-issue 壁打ちに戻らないことが読める）

## AT-341-C: 疑問解消済み Issue から既存 lib で並列自走する（FS-4 / FS-5）

- [x] [regression] AT-341-C-1: K スロット下で issue-lease を取りつつ busy Issue をスキップして dispatch する
  - Given: 対象 Issue 群のうち一部が他セッションで既に claim 済み（busy）であるリースストア状態
  - When: batch-discovery が `lib/full-autopilot-dispatch.sh select <K> <issue...>` を呼ぶ
  - Then: 空きスロット K 件分だけ issue-lease を取得できた Issue が選ばれ、busy Issue はスキップされる（選択件数が K 以下、busy は含まれない）

- [x] [regression] AT-341-C-2: worker は worktree 隔離＋プラグイン設定播種で起動される
  - Given: batch-discovery が選択済み Issue の worker を起動する手順
  - When: SKILL.md の worker 起動フローを読む
  - Then: worktree 隔離（1 issue = 1 worktree）と `.claude/settings.local.json` の播種（#329、`__seed_worktree_settings` 転用）が必須として記述され、播種なしの `Unknown command: /atdd-kit:autopilot` 即死リスクに言及している

- [x] [regression] AT-341-C-3: worker lease は 3 経路すべてで解放される
  - Given: worker が正常完了 / 失敗・timeout / dispatcher クラッシュ のいずれかになる
  - When: SKILL.md の worker lifecycle 節を読む
  - Then: 正常完了・失敗/timeout で `lib/lease-store.sh release issue` を即時実行し、クラッシュ時は lease の TTL が最終防衛として stale 掃除する、の 3 経路すべてが記述されている

## AT-341-D: 実装順序の記録による軽量順序制御（FS-6）

- [x] [regression] AT-341-D-1: keystone→後続の実装順序を共有真実源に記録しその順で worker を進める
  - Given: 依存関係のある Issue 群（keystone と後続）を投入する
  - When: SKILL.md の順序制御フローを読む
  - Then: 実装順序を共有真実源（manifest）に記録し dispatcher がそれを読んでその順で進める軽量方式が記述され、Non-Goals に「フル barrier / 動的依存解決は採らない」が明記されている

- [x] [regression] AT-341-D-1-nit: 複数バッチ run 並存時の manifest 名前衝突への対処が明示されている（レビュー指摘 priority=3）
  - Given: `skills/batch-discovery/SKILL.md` が存在する
  - When: Phase 4 の manifest パス定義を読む
  - Then: タイムスタンプが並行 batch run 間の一意性を保証することが明記されており、同秒衝突への対処（ランダムサフィックス等）またはコーラー指定パスによるオーバーライドについて言及がある（`docs/issues/batch-<timestamp>/manifest.json` パスに関する名前衝突防止策が読める）

## AT-341-E: 選別ピックアップ式の最終承認ゲートと AL-1 整合（FS-7 / CS-2）

- [x] [regression] AT-341-E-1: 覆りうる点だけを選別提示し、ゼロなら最終承認をスキップする
  - Given: 準備フェーズ（reviewer-oracle 含む）が finding を検出した状態
  - When: 最終承認ゲートのフローを評価する（覆りうる点あり / なしの 2 ケース）
  - Then: 覆りうる点（トレードオフ・意図的割り切り・スコープ取捨に該当する finding）が「あり」のときは承認前に `ready-to-go` を付与せず選別提示し、「なし（ゼロ）」のときは最終承認をスキップして `ready-to-go` へ進める（全成果物の一括承認は求めない）

- [x] [regression] AT-341-E-2: AL-1 三ゲート不変条件と整合し Gate ③（merge）は full-autopilot 側で不変
  - Given: SKILL.md と AL-1（autopilot-iron-law.md）を突き合わせる
  - When: batch-discovery の人間ゲート定義を読む
  - Then: Gate ①＝横断バッチ壁打ち 1 回（集約）、Gate ② 相当＝選別最終承認 最大 1 回（覆りうる点に絞って集約）、Gate ③＝merge は full-autopilot 側の責務として不変、という対応が明文化されている（AC 承認＝false-green の外部アンカーを撤廃していないことが読める）

## AT-341-F: deterministic な bats 受け入れテストで守られている（CS-3）

- [x] [regression] AT-341-F-1: batch-discovery の各変更が deterministic な bats AT で検証される
  - Given: 上記 AT-341-A〜E を bats として実装する
  - When: acceptance スイートを bats で実行する
  - Then: 各 AT bats が外部ネットワーク非依存・再現可能（deterministic）に green になり、AL-3 deterministic AT gate を満たす

## ライフサイクル例

| 状態 | 意味 |
|------|------|
| [planned] | テスト設計済み・未実装 |
| [draft] | 実装中・まだ通過していない |
| [green] | テスト通過済み |
| [regression] | リグレッション対象として継続監視中 |
