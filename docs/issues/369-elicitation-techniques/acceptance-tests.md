# Acceptance Tests: docs/methodology — 要件抽出の技法カタログ（Pre-mortem / Job Story / One question at a time / Out-of-scope question）を一次情報付きで新設

<!-- AT lifecycle: planned → draft → green → regression
     各エントリには状態マーカー [planned] / [draft] / [green] / [regression] を付与する。
     状態は実装の進行に合わせて更新する。 -->

## AT-1: 4 技法の一次情報付きカタログ（FS-1）

- [ ] [planned] AT-369-1: 4 技法 doc が一次情報付きで存在する
  - Given: 実装完了後の `docs/methodology/elicitation-techniques/` ディレクトリ
  - When: `pre-mortem.md` / `job-story.md` / `one-question-at-a-time.md` / `out-of-scope-question.md` の各ファイルを確認する
  - Then: 4 ファイルが全て存在し、各々の `## 一次情報` 節に著者・出典・発行年（Klein 2007 / Klement 2013 / Krug 2010 / Patton 2014）が記載されている

## AT-2: 各技法ドキュメントの統一フィールド（FS-2）

- [ ] [planned] AT-369-2: 各技法 doc が統一 5 フィールドを備える
  - Given: 4 技法 doc
  - When: 各 doc の見出しを走査する
  - Then: すべての技法 doc に `## 目的` `## 問いの型` `## 適用先マッピング` `## 一次情報` `## 例` の 5 見出しが漏れなく存在する

## AT-3: 共通原則の独立ドキュメント（FS-3）

- [ ] [planned] AT-369-3: 共通原則が独立 doc として存在し各技法から参照される
  - Given: 実装完了後のカタログ
  - When: `common-principles.md` と各技法 doc のリンクを確認する
  - Then: `common-principles.md` が存在し 3 共通原則（キャッチボール / 責務を侵さない / 対話ログ）が記載され、かつ 4 技法 doc すべてから `common-principles.md` への相対リンクが張られている

## AT-4: SKILL.md からのマッピング参照（FS-4）

- [ ] [planned] AT-369-4: SKILL.md はマッピング参照のみを持ち詳細は doc に委ねる
  - Given: 追記後の `defining-requirements/SKILL.md` と `batch-discovery/SKILL.md`
  - When: 各 SKILL.md 内のカタログ参照と行数を確認する
  - Then: 両 SKILL.md に `docs/methodology/elicitation-techniques/` への相対リンクが存在し、`defining-requirements/SKILL.md` は 200 行以下の line budget pin 内に収まり、技法の詳細手順・一次情報・例が SKILL.md 本文に転記されていない

## AT-5: 一次情報への忠実性（CS-1）

- [ ] [planned] AT-369-5: 原典記述と独自整理の境界が判別できる
  - Given: 4 技法 doc と `common-principles.md`
  - When: 独自解釈を加えた箇所のマーカーを確認する
  - Then: `common-principles.md` の 3 原則すべてに `[独自整理]` マーカーが付与され、技法 doc で独自解釈を加えた箇所には `[独自]` が明示されている（原典忠実な記述にはマーカーが不要）

## AT-6: 構造検証の自動ピン（CS-2）

- [ ] [planned] AT-369-6: 構造検証 BATS がカタログのファイル欠落・フィールド抜けを検出する
  - Given: `tests/test_elicitation_techniques_docs.bats`
  - When: `bats tests/test_elicitation_techniques_docs.bats` を実行する
  - Then: 4 技法 doc + `common-principles.md` + `README.md` の存在、各技法 doc の統一 5 フィールド見出しの存在、両 SKILL.md からカタログへのリンク存在を検証する全ケースが green になる

## AT-7: バージョン・CHANGELOG 規約準拠（CS-3）

- [ ] [planned] [regression] AT-369-7: version と CHANGELOG が規約通り一貫する
  - Given: マージ後の `.claude-plugin/plugin.json` と `CHANGELOG.md`
  - When: plugin.json の version 値と CHANGELOG.md の最上位リリース見出しを突き合わせる
  - Then: plugin.json の version が CHANGELOG.md 最上位リリース見出しのバージョンと一致する（不変条件を検証する。特定バージョン文字列を直接ピンしない — #289 リグレッション永久赤化の回避）

## ライフサイクル例

| 状態 | 意味 |
|------|------|
| [planned] | テスト設計済み・未実装 |
| [draft] | 実装中・まだ通過していない |
| [green] | テスト通過済み |
| [regression] | リグレッション対象として継続監視中 |
