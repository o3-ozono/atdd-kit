# Acceptance Tests: full-autopilot の使い勝手再設計（真因0-4 一括）

<!-- AT lifecycle: planned → draft → green → regression
     各エントリには状態マーカー [planned] / [draft] / [green] / [regression] を付与する。
     状態は実装の進行に合わせて running-atdd-cycle が更新する（本スキルは [planned] のみ）。
     [regression] 化する AT は、時点固定値（version 数値・日付・行数）を直接 pin せず invariant を assert する。 -->

## AT-329-0: Issue テンプレートが意図シードに軽量化されている（US-0 / 真因0）

- [x] [green] AT-329-0a: development.yml で AC/サブタスク/完了条件/User Story が optional
  - Given: `templates/issue/{ja,en}/development.yml` が存在する
  - When: 各テンプレートの `acceptance-criteria` / `subtasks` / `completion-criteria` / `user-story` フィールドの `validations.required` を調べる
  - Then: いずれのフィールドも `required: true` を持たない（任意入力）

- [x] [green] AT-329-0b: 意図3点フィールドは required（フィールドマッピング確定）
  - Given: `templates/issue/{ja,en}/development.yml` が存在する
  - When: 痛み=`summary` / 望む結果=`outcome` / スコープ境界=`scope-boundary` の各フィールド id の `validations.required` を調べる
  - Then: `summary` / `outcome` / `scope-boundary` の3フィールドが `required: true` を持ち、かつ required なフィールドはこの意図3点のみ（`user-story` は optional に降格済み）

- [x] [green] AT-329-0c: always-sync 経路が壊れていない
  - Given: development.yml を軽量化した状態
  - When: `tests/test_template_sync.bats` と `tests/test_bilingual_templates.bats` を実行する
  - Then: 両 bats が green（`.github/ISSUE_TEMPLATE/` 同期と ja/en 構造対応が保たれる）

## AT-329-1: queue が動的に再評価される（US-1 / 真因1）

- [x] [green] AT-329-1a: 走行中に追加された ready-to-go を現セッションが拾う
  - Given: `FA_QUEUE_CMD` を stub し、初回は issue A のみ、空きスロット充填時の再呼び出しで A+B を返すよう設定する
  - When: 並列度 K で `run()` を実行し A 完了後に空きスロットが生じる
  - Then: 起動時に存在しなかった issue B も同一セッションで `launch` される（起動時1回 freeze ではない）

- [x] [green] AT-329-1b: 同一 issue を二重起動しない
  - Given: `FA_QUEUE_CMD` の再評価が in-flight / 完了済みの issue を含めて返す stub
  - When: `run()` が空きスロット充填のたびに queue を再評価する
  - Then: 既に lease 保持 / in-flight / 完了済みの issue は再 `launch` されない（dedup される）

## AT-329-2: 起動時に通知先が確認される（US-2 / 真因2）

- [x] [green] AT-329-2a: 通知先未設定なら起動時に警告
  - Given: `FA_NOTIFY_CMD` が未設定
  - When: `run()` を起動する
  - Then: ログに「通知先未設定」警告が1回出力され、本体は停止しない

- [x] [green] AT-329-2b: 通知先設定済みなら確認ログ
  - Given: `FA_NOTIFY_CMD` が設定済み
  - When: `run()` を起動する
  - Then: ログに通知先確認の1行が出力される

## AT-329-3: merge-ready が GitHub ラベルで二重確認される（US-3 / 真因3 — produce ＋ consume を対で検証）

<!-- レビュー finding #1 反映: consume（照合）だけを stub green にすると、本番でラベルを誰も produce せず
     __default_result が常時 failed（fail-closed）になる欠陥を AT が見逃す。produce 側（ラベル定義 ＋
     hand-off 成功時の付与記述）も構造 pin で assert し、produce が欠落したら AT が red になるようにする。 -->

- [x] [green] AT-329-3a: (consume) ラベル不在なら failed に倒れる
  - Given: worker stdout が `is_error:false` だが、`gh issue view` stub が `merge-ready` ラベル不在を返す
  - When: `__default_result <issue>` を評価する
  - Then: 出力は `failed`（自己申告だけでは merge-ready にしない）

- [x] [green] AT-329-3b: (consume) 自己申告＋ラベル両立で merge-ready
  - Given: worker stdout が `is_error:false` かつ `gh issue view` stub が `merge-ready` ラベル存在を返す
  - When: `__default_result <issue>` を評価する
  - Then: 出力は `merge-ready`

- [x] [green] AT-329-3c: (produce) システムが merge-ready ラベルを実際に生成する
  - Given: `commands/setup-github.md` と `skills/autopilot/SKILL.md`
  - When: ラベル定義列挙と hand-off gate③ の記述を検査する
  - Then: `commands/setup-github.md` のラベル列挙に `merge-ready` が定義され、かつ `skills/autopilot/SKILL.md` に hand-off 成功時へ対象 Issue に `merge-ready` ラベルを付与する経路が記述されている（produce 半分が欠落＝consume 側 stub の偽 green を防ぐ外部アンカー）

## AT-329-4: skill-gate が route-eligibility を必須チェックする（US-4 / 真因4）

- [x] [green] AT-329-4a: 必須チェックと override が記述されている
  - Given: `skills/skill-gate/SKILL.md`
  - When: 内容を検査する
  - Then: route-eligibility（`docs/methodology/route-eligibility.md`）の必須チェック手順と、不適合モード抑止、override 手段の記述が存在する

## AT-329-5: full-autopilot SKILL.md が DoR 整合（US-5 / doc 整合）

- [x] [green] AT-329-5a: ready-to-go 前提が正典 DoR に一致
  - Given: `skills/full-autopilot/SKILL.md` と `docs/methodology/definition-of-ready.md`
  - When: SKILL.md の `ready-to-go` 前提記述を検査する
  - Then: 「ready-to-go = DoR ＋ plan review PASS」を反映し、「PRD が承認済み」という DoR とズレた記述が残っていない

## AT-329-CS1: 受け入れテスト整備とリポジトリ整合（CS-1）

- [x] [green] AT-329-CS1a: 全 bats スイートが green
  - Given: US-0〜US-5 の変更と各 AT bats が実装済み
  - When: `bats tests/`（および該当時 `bats addons/*/tests/`）を実行する
  - Then: 全テストが green（回帰なし）

- [x] [regression] AT-329-CS1b: version と CHANGELOG の invariant
  - Given: 機能 PR としてバージョン bump と CHANGELOG 追記を行った状態
  - When: `.claude-plugin/plugin.json` の version と CHANGELOG 最上位リリース見出しを比較する
  - Then: 両者が一致する（時点固定値を pin せず「version == 最上位リリース見出し」という invariant を assert）

## ライフサイクル例

| 状態 | 意味 |
|------|------|
| [planned] | テスト設計済み・未実装 |
| [draft] | 実装中・まだ通過していない |
| [green] | テスト通過済み |
| [regression] | リグレッション対象として継続監視中 |
