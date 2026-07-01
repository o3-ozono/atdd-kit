# Acceptance Tests: impact_map / addon deploy の堅牢化（#323 レビュー由来の非ブロッキング所見対応）

<!-- AT lifecycle: planned → draft → green → regression
     各エントリには状態マーカー [planned] / [draft] / [green] / [regression] を付与する。
     状態は実装の進行に合わせて更新する。
     [regression] AT は将来の全ブランチで恒久実行されるため、point-in-time 値
     （現在の plugin version・日付・行数）を exact-pin せず invariant を assert する。 -->

## AT-347-1: `parse_impact_rules` の診断可能なエラー化（US-1 / カテゴリ 1）

- [ ] [planned] AT-347-1a: 末尾空白付き glob が trim されて fnmatch 一致する
  - Given: `- path: src/**  `（末尾空白付き）と対応 `skill-e2e:` を持つ `impact_rules.yml` fixture、および `src/app/main.ts` の差分
  - When: `impact_map.sh --config <fixture> --platform web --base <ref> --layer skill-e2e` を実行する
  - Then: glob が末尾空白なしで格納され rule が一致し、FALLBACK ではなく該当 skill-e2e 識別子が出力される

- [ ] [planned] AT-347-1b: 末尾空白付き `rules:` キーが正しくセクション開始として解釈される
  - Given: `rules: `（末尾空白付き）行を持つ有効 rule 入り `impact_rules.yml` fixture
  - When: `impact_map.sh --config <fixture> --all --layer skill-e2e` を実行する
  - Then: `missing 'rules:' section` エラーにならず rule が取り込まれ exit 0 になる

- [ ] [planned] AT-347-1c: 誤インデント（4-space / tab）がインデント規約に言及する診断エラーになる
  - Given: `rules:` 配下の `- path:` が 4-space（または tab）でインデントされた `impact_rules.yml` fixture
  - When: `impact_map.sh --config <fixture> --all --layer skill-e2e` を実行する
  - Then: 非ゼロ終了し、stderr のメッセージにインデント規約（2-space 期待）への言及が含まれ、真に空の rules ブロックと区別できる（`no rules entries found` のみの区別不能エラーにならない）

## AT-347-2: `--base` 入力の fail-closed 検証（CS-1 / カテゴリ 2）

- [ ] [planned] AT-347-2a: `-` 始まりの `--base` は fail-closed で弾かれる
  - Given: 有効な `impact_rules.yml`
  - When: `impact_map.sh --base -Spattern --layer skill-e2e`（pickaxe 相当の短オプション）を実行する
  - Then: 非ゼロ終了し、stderr に不正 base を示すメッセージが出て、空 diff での exit 0（CI バイパス相当）にならず、`git diff` に短オプションが渡らない

- [ ] [planned] AT-347-2b: `--output=/path` 相当の敵対的 base で任意ファイル truncate が起きない
  - Given: 監視対象の既存ファイルと有効な `impact_rules.yml`
  - When: `impact_map.sh --base --output=<既存ファイル> --layer skill-e2e` を実行する
  - Then: 非ゼロ終了し、当該ファイルが truncate（内容消失）されない

## AT-347-3: `setup-web` / `setup-ios` 再実行時の config 上書き保護（US-2 / カテゴリ 3）

- [ ] [planned] AT-347-3a: `setup-web.md` に既存 config 検出と上書き警告・保持が記載されている
  - Given: `commands/setup-web.md`
  - When: ドキュメントを読む
  - Then: 既存 `config/impact_rules.yml` 検出時に上書き警告を出し既存ファイルを保持（推奨動作）する手順が記載されている

- [ ] [planned] AT-347-3b: `setup-ios.md` に同等の保護手順が記載されている
  - Given: `commands/setup-ios.md`
  - When: ドキュメントを読む
  - Then: 既存 config 検出・上書き警告・保持の手順が記載され、iOS 必須カスタマイズの消失防止が明記されている

## AT-347-4: addon.yml スキーマへの冪等保護フィールド予約（US-3 / カテゴリ 3）

- [ ] [planned] AT-347-4a: web / ios addon.yml に予約フィールドが定義されている
  - Given: `addons/web/addon.yml` と `addons/ios/addon.yml`
  - When: 各ファイルを読む
  - Then: `deploy` エントリ文脈に `if_not_exists` と `merge_strategy` が予約フィールドとして存在する

- [ ] [planned] AT-347-4b: addon.yml Schema 表に予約フィールドが文書化されている
  - Given: `addons/README.md` の addon.yml Schema 表
  - When: 表を読む
  - Then: `if_not_exists` / `merge_strategy` の行が存在し、予約（将来実装委譲）である旨が読み取れる

## AT-347-5: FALLBACK 検出手順・addon ドキュメントの整備（US-4 / カテゴリ 4）

- [ ] [planned] AT-347-5a: `setup-web.md` に FALLBACK 検出手順の3要素が記載されている
  - Given: `commands/setup-web.md`
  - When: ドキュメントを読む
  - Then: stderr 保持・`grep FALLBACK`・常時フォールバック時の CI fail ステップの3要素が含まれる

- [ ] [planned] AT-347-5b: `addons/README.md` に Required / Optional 区分がある
  - Given: `addons/README.md`
  - When: スキーマ表（または addon 一覧）を読む
  - Then: Required / Optional を区分する列が存在する

- [ ] [planned] AT-347-5c: `addons/web/README.md` が存在し他 addon README と同水準である
  - Given: `addons/` 配下
  - When: ファイル一覧を確認する
  - Then: `addons/web/README.md` が存在し、web addon の deploy 内容・使い方を記述している（他 addon README が存在するのに web だけ欠落する非対称が解消されている）

- [ ] [planned] AT-347-5d: `scripts/README.md` に4スクリプト説明と `--layer` platform 制約がある
  - Given: `scripts/README.md`
  - When: ドキュメントを読む
  - Then: `bats_runner.sh` / `check_bats_covers.sh` / `run-skill-e2e.sh` / `test-skills-headless.sh` の説明と `--layer` の platform 制約が記載されている

- [ ] [planned] AT-347-5e: `DEVELOPMENT.md` に `mcp_servers` の Zero Dependencies carve-out がある
  - Given: `DEVELOPMENT.md`
  - When: Zero Dependencies 節を読む
  - Then: addon.yml `mcp_servers` は user-project 宣言であり Zero Dependencies 規則の対象外である旨の carve-out が含まれる

## AT-347-6: 重複実装の統合と AT の厳格化（US-5 / カテゴリ 5）

- [ ] [planned] AT-347-6a: `select_web` / `select_ios` が `select_path_rules_only` に統合されている
  - Given: `scripts/impact_map.sh`
  - When: 関数定義を確認する
  - Then: `select_path_rules_only` が定義され、`select_web` / `select_ios` の重複関数本体が存在しない（両プラットフォームが同一関数を呼ぶ）

- [ ] [planned] AT-347-6b: 統合後も web / ios 分類結果が不変である（回帰）
  - Given: web glob 一致差分と ios glob 一致差分、それぞれの `impact_rules.yml`
  - When: `--platform web` / `--platform ios` で `impact_map.sh` を実行する
  - Then: 統合前と同一の識別子集合を返す（挙動不変）

- [ ] [planned] AT-347-6c: `AT-323-004b` が `--impact` 必須に厳格化されている
  - Given: 強化後の `AT-323-004b`
  - When: `merging-and-deploying/SKILL.md` が `--base` のみ言及し `--impact` を含まない状態で AT を走らせる
  - Then: AT-323-004b が fail する（`--base` 単独では pass せず、`--impact` の存在を要求する）

- [ ] [planned] AT-347-6d: `AT-323-001b` / `AT-323-001c` が content assert に強化されている
  - Given: 強化後の `AT-323-001b` / `AT-323-001c`
  - When: web / ios の差分で `impact_map.sh` を実行する
  - Then: 出力が非空であるだけでなく、期待する web / iOS 識別子文字列を含むことを assert する（無関係な非空出力では fail する）

- [ ] [planned] AT-347-6e: 変更した SKILL.md の BATS 証跡が記録されている
  - Given: `DEVELOPMENT.md` の「Skill Changes Require Test Evidence」節
  - When: 節を読む
  - Then: 本 PR で変更した各 SKILL.md に対する BATS 証跡が記録され、参照される証跡テストが green である

## ライフサイクル例

| 状態 | 意味 |
|------|------|
| [planned] | テスト設計済み・未実装 |
| [draft] | 実装中・まだ通過していない |
| [green] | テスト通過済み |
| [regression] | リグレッション対象として継続監視中 |
