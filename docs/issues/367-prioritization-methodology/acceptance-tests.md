# Acceptance Tests: 機能優先度の方法論 doc を新設（#367）

<!-- AT lifecycle: planned → draft → green → regression
     各エントリには状態マーカー [planned] / [draft] / [green] / [regression] を付与する。
     状態は実装の進行に合わせて更新する。
     verify: 行は実行/検証方法を示す。回帰対象は point-in-time 値を exact-pin しない。 -->

## AT-367-1: prioritization.md が新設され位置づけが明示される（US-1 / CS-1）

- [ ] [planned] AT-367-1: 方法論 doc が存在し MoSCoW(DSDM) 一次情報 + `[独自]` 派生の位置づけを持つ
  - Given: リポジトリに `docs/methodology/prioritization.md` が存在する
  - When: ファイル冒頭の位置づけ記述を検査する
  - Then: `MoSCoW` と `DSDM` と `[独自]` の 3 語がすべて含まれる
  - verify: `[ -f docs/methodology/prioritization.md ]` かつ `grep -q 'MoSCoW' && grep -q 'DSDM' && grep -q '独自'` が真

## AT-367-2: 5 段階の定義テーブルが完全である（US-1）

- [ ] [planned] AT-367-2: 5 段階（MUST/SHOULD/WANT/次回以降/破棄）が定義テーブルに揃う
  - Given: `prioritization.md` に「5 段階」相当のセクションがある
  - When: 定義テーブルのラベル行を検査する
  - Then: `MUST` `SHOULD` `WANT` `次回以降` `破棄` の 5 ラベルがすべて出現する
  - verify: 5 ラベルそれぞれについて `grep -q` が真（1 語でも欠ければ fail）

## AT-367-3: 効きと工数の 2 軸が分離定義される（US-2）

- [ ] [planned] AT-367-3: 効き（本質課題への解決力）と工数（実装コスト）が独立軸として定義される
  - Given: `prioritization.md` に「2 軸判定」相当のセクションがある
  - When: 軸の定義とマッピング表を検査する
  - Then: 「効き」「工数」の両語が含まれ、効き×工数→推奨ラベルの統合マッピング表が存在する
  - verify: `grep -q '効き' && grep -q '工数'` が真、かつマッピング表行（例: `| 高 |`）が存在する

## AT-367-4: anti-pattern セクションが工数混入誤用を明記する（US-2 / US-3）

- [ ] [planned] AT-367-4: anti-pattern に「工数を効きに混ぜる」誤用が記述される
  - Given: `prioritization.md` に anti-pattern 相当のセクションがある
  - When: anti-pattern 記述を検査する
  - Then: 「anti-pattern」見出しと「効くけど大変だから WANT」相当の誤用記述が含まれる
  - verify: `grep -qi 'anti-pattern'` かつ `grep -q '効くけど大変だから WANT'` が真

## AT-367-5: 破棄の扱い（テーブル内保存・ゾンビ復活防止）が規定される（US-3）

- [ ] [planned] AT-367-5: 破棄要件を削除せず理由付きで残す運用が明記される
  - Given: `prioritization.md` に「破棄の扱い」相当のセクションがある
  - When: 破棄運用の記述を検査する
  - Then: 「破棄」見出しと「ゾンビ復活」相当（再提案時の判断根拠参照）の記述が含まれる
  - verify: `grep -q '破棄'` かつ `grep -q 'ゾンビ復活'` が真

## AT-367-6: defining-requirements から prioritization.md への参照接続がある（US-4）

- [ ] [planned] AT-367-6: 機能要件パートから優先度 doc への参照指示が SKILL.md に存在する
  - Given: `skills/defining-requirements/SKILL.md`
  - When: doc 参照の追記を検査する
  - Then: `docs/methodology/prioritization.md` への参照が 1 箇所以上存在する（実装ロジックは変更されていない）
  - verify: `grep -q 'docs/methodology/prioritization.md' skills/defining-requirements/SKILL.md` が真

## AT-367-7: BATS 構造検証ピンが green で必須セクションを守る（CS-2）

- [ ] [planned] AT-367-7: prioritization.md の骨格セクション欠落を CI で検出できる
  - Given: `tests/test_prioritization_doc.bats` が存在する
  - When: BATS スイートを実行する
  - Then: 5 段階テーブル・2 軸・anti-pattern・破棄の扱い・`[独自]` マーカー・参照接続の各ピンが green になる
  - verify: `bats tests/test_prioritization_doc.bats` が全 pass

## AT-367-8: BATS ピンが point-in-time 値を exact-pin しない（CS-2 回帰安全性）

- [ ] [planned] AT-367-8: 構造ピンはバージョン・行数・日付を literal 固定しない
  - Given: `tests/test_prioritization_doc.bats`
  - When: ピンの assert 内容を検査する
  - Then: 数値バージョン・行数・日付の literal 比較が存在せず、セクション見出し・キーワードの不変条件のみを assert する
  - verify: `test_prioritization_doc.bats` 内にバージョン番号/行数/日付の literal 比較が無い（レビューで確認）

## AT-367-9: Versioning ルール準拠（CHANGELOG + version bump 整合）（CS-3）

- [ ] [regression] AT-367-9: plugin.json version が CHANGELOG 先頭リリース見出しと一致する
  - Given: `.claude-plugin/plugin.json` と `CHANGELOG.md`
  - When: plugin version と CHANGELOG の最上位リリース見出しを比較する
  - Then: 両者が一致する（特定バージョン値を exact-pin せず「一致」の不変条件を assert）
  - verify: `scripts/check-plugin-version.sh` 相当が pass（version==topmost CHANGELOG release heading）

## ライフサイクル例

| 状態 | 意味 |
|------|------|
| [planned] | テスト設計済み・未実装 |
| [draft] | 実装中・まだ通過していない |
| [green] | テスト通過済み |
| [regression] | リグレッション対象として継続監視中 |
