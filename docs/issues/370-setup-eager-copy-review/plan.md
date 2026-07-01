# Plan: setup-* の eager-copy を「参照優先 + 使う時に不足検出してプロンプト」モデルへ見直す

<!-- 2-5 分粒度のタスク行と verification 行を交互に配置する（superpowers writing-plans 形式）。
     各タスクは単一の操作に限定し、verification で完了条件を即確認できる粒度にする。 -->

## 前提整理（本 Issue のスコープ確定事項）

- W-1/W-2 は **doc 成果物**（`docs/design/setup-eager-copy-inventory.md` / `docs/design/setup-on-demand-policy.md`）で、AT は doc の存在・必須章立て・分類基準の一貫性を pin する。
- W-3a（ラベル不足検出）は既存 setup-* を変更せず **追加**する低リスク項目。冪等性は `gh label create --force`（既存でも成功＝422 相当を吸収）で担保する。
- W-3b（hook 配線の plugin-global 寄せ）は現状 `hooks/hooks.json` が既に `${CLAUDE_PLUGIN_ROOT}` 参照で plugin-global に配線済み（setup-* は hook をコピーしない）。本 Issue は「plugin-global 常時有効」という不変条件を **doc 化・回帰 AT で pin** し、プロジェクト個別コピーへ退行しないことを保証する。実装の再発明はしない（Non-Goals: 破壊的移管の回避）。

## Implementation

### W-1: 仕分け一覧 doc（`docs/design/setup-eager-copy-inventory.md`）

- [ ] `docs/design/` に `setup-eager-copy-inventory.md` を新規作成し、setup-github / setup-ci / setup-discord / setup-ios / setup-web の各コマンドが「コピー or 生成する成果物」を実ファイル参照付きで洗い出す
- [ ] verify: 5 コマンドすべてが表に登場し、各成果物にソースパス（`templates/…` / `addons/…`）と配置先が記載されている

- [ ] 各成果物を Gate① 承認基準（「plugin インストール済み環境で Claude が参照経路を持つか」）で「参照で足りる（plugin-global 参照）」/「プロジェクトローカルに要る（ユーザー管理）」に二分類し、判定根拠列を埋める
- [ ] verify: 全アイテムに二分類のいずれかと判定根拠（1 行以上）が付与されている（未分類ゼロ）

- [ ] MCP config・webhook・ラベル定義など「書き込み/秘匿値/ユーザー管理」を含むものは「プロジェクトローカルに要る」側に固定し、Non-Goals（高リスク破壊移管の除外）と矛盾しないことを明記する
- [ ] verify: 「プロジェクトローカルに要る」列に discord webhook（秘匿値）と GitHub ラベル（書き込み対象）が含まれ、それらが本 Issue のオンデマンド移管対象外である旨が明記されている

### W-2: オンデマンド移管の設計方針 doc（`docs/design/setup-on-demand-policy.md`）

- [ ] `docs/design/setup-on-demand-policy.md` を新規作成し、移管対象ごとに「トリガー（どの skill・コマンド）/ 検出ロジック（何が不足しているか判定する方法）/ プロンプト方法（通知・自動修復・confirm 要求）」の 3 列を定義する
- [ ] verify: 少なくとも W-3a（ラベル不足検出）を含む移管対象が、トリガー・検出・プロンプトの 3 要素すべて埋まった行として存在する

- [ ] pre-flight check の標準パターン（起動時ガード：検出失敗はエラー終了ではなく「不足を通知 → confirm 後続行 / スキップ可能」）を明文化する
- [ ] verify: doc に「エラー終了しない・スキップ可能」を要件とする標準ガードパターン節が存在する

- [ ] 冪等性チェックリスト（「既に存在すれば何もしない / 差分のみ適用」「ラベル作成は既存を無視」「hook は plugin-global 常時有効で重複適用回避」）を doc に含める
- [ ] verify: 冪等性チェックリストが箇条書きで存在し、ラベル・hook の 2 経路の冪等化方法が各 1 項目以上含まれる

### W-3a: ラベル不足検出プロンプト（pre-flight check）

- [ ] `commands/setup-github.md` の 16 ラベル定義を正準ソースとして参照し、必須ラベル集合を `gh label list` と突き合わせて不足ラベル名を出力する検出スクリプト `scripts/check-required-labels.sh` を新規作成する（不足があっても非ゼロ終了せず＝通知のみ）
- [ ] verify: `bash scripts/check-required-labels.sh` が実行可能で、不足があれば不足ラベル名を列挙し、ラベル未取得（gh 不在/未認証）でもクラッシュせずスキップ扱いのメッセージを出す

- [ ] 検出後の修復経路として「confirm 後に `gh label create --force` で不足分のみ作成」する処理をスクリプトに追加する（`--force` により既存ラベルへの再作成が副作用ゼロ＝冪等）
- [ ] verify: スクリプトを 2 回連続実行しても 2 回目でエラー・重複作成が起きず、既存ラベルは変更されない

- [ ] ワークフロー skill（autopilot / full-autopilot）の起動節に、この pre-flight check を「起動時ガード（不足通知 → skip 可）」として呼び出す 1 節を追記する（W-2 の標準パターンに準拠）
- [ ] verify: `skills/autopilot/SKILL.md` または `skills/full-autopilot/SKILL.md` に check-required-labels の呼び出しと「不足は通知のみ・エラー終了しない」旨が記述されている

### W-3b: hook 配線の plugin-global 不変条件の固定

- [ ] `hooks/hooks.json` の全 hook command が `${CLAUDE_PLUGIN_ROOT}` 参照（plugin-global）であることを確認し、その不変条件を W-1/W-2 doc に「hook は setup-* に依存せず常時有効」として明記する
- [ ] verify: `hooks/hooks.json` の全 `command` に `${CLAUDE_PLUGIN_ROOT}` が含まれ、プロジェクトローカルパス（`.claude/hooks/` 等）への配線が存在しない

## Testing

- [ ] W-1/W-2 doc の存在と必須章立て（分類基準・冪等性チェックリスト・標準ガードパターン）を pin する BATS AT を `tests/` に追加する
- [ ] verify: 追加した BATS が green（doc 欠落・必須章欠落を検出できることを RED で確認済み）

- [ ] W-3a のラベル不足検出スクリプトの冪等性（2 回実行で副作用重複なし）と「不足は通知・非破壊」を検証する BATS AT を追加する
- [ ] verify: 追加した BATS が green

- [ ] W-3b の hook plugin-global 不変条件を pin する回帰 AT を追加する（不変条件を assert、点在値は pin しない）
- [ ] verify: 追加した BATS が green で、`${CLAUDE_PLUGIN_ROOT}` 不変条件のみを assert している（バージョン・行数など時点値を pin していない）

## Finishing

- [ ] `docs/` 配下のディレクトリ README / 索引を新規 doc 追加に合わせて更新する
- [ ] verify: 新規 doc がディレクトリ README / 索引から辿れる

- [ ] `CHANGELOG.md` に本 Issue のエントリ（Added: setup on-demand inventory/policy doc + label pre-flight check）を追加し、`.claude-plugin/plugin.json` の version を minor bump する（新スクリプト＋新 doc＋skill ガード追加＝minor）
- [ ] verify: CHANGELOG 最上段の release 見出しと plugin.json の version が一致する

- [ ] ドキュメント整合性チェック
- [ ] verify: 関連ドキュメント（inventory / policy / setup-* コマンド / hooks README）が変更内容と整合している
