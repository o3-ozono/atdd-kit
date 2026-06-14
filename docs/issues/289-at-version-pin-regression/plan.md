# Plan: 恒久実行される acceptance AT のバージョン完全一致ピンを将来耐性のある検証へ置換する

<!-- 2-5 分粒度のタスク行と verification 行を交互に配置する（superpowers writing-plans 形式）。
     各タスクは単一の操作に限定し、verification で完了条件を即確認できる粒度にする。 -->

## 設計方針（共通）

「将来耐性のあるバージョン検証」は次の不変条件で表現する（PRD What 1・2）:

- **履歴事実（append-only・将来も不変）**: CHANGELOG に当該版の `## [X.Y.Z]` リリース見出しが存在すること。一度マージされたリリース見出しは追記専用で消えないため、将来の bump で壊れない。
- **整合事実（bump 追従）**: plugin.json の `version` が CHANGELOG の **最新リリース見出し**と一致すること。最新リリース見出し = `## [Unreleased]` を除いた先頭の `## [X.Y.Z]`。bump のたびに CHANGELOG 先頭にも新見出しが入り plugin.json も更新されるため、両者は常に一致し続ける。

この「最新リリース見出しを取得する」ロジックは AT-284 AT-010 と AT-271 AT-005 の双方で必要になるため、bats ヘルパー関数として一度だけ定義し共有する（重複ロジックを避ける）。

## Implementation

- [ ] CHANGELOG から最新リリース見出しのバージョンを抽出するヘルパー関数を用意する（`## [Unreleased]` をスキップし、先頭の `## [X.Y.Z]` から `X.Y.Z` を取り出す）。AT-271.bats と AT-284.bats が共有できる場所（共有ヘルパーが既にあればそこ、なければ各ファイル内の重複しない実装）に置く
- [ ] verify: 関数に現在の CHANGELOG.md を渡すと `3.14.2`（= plugin.json の現 version）が返り、`Unreleased` を拾わないことを手元で確認する

- [ ] `tests/acceptance/AT-284.bats` L186-188 の `@test "AT-010: plugin.json version is 3.14.0"` を書き換える。(a) `grep -q '^## \[3.14.0\]' CHANGELOG.md`（#284 が当該版へ bump した履歴事実）と (b) plugin.json version == CHANGELOG 最新リリース見出し、の 2 アサーションにする。テスト名から完全一致値 `3.14.0` の含意を外す（例: `AT-010: plugin.json version matches CHANGELOG latest release & 3.14.0 history exists`）
- [ ] verify: 書き換え後の AT-284.bats を単体実行（`bats tests/acceptance/AT-284.bats`）して当該テストが green になることを確認する

- [ ] `tests/acceptance/AT-271.bats` の version 完全一致ブロック（`[[ "$version" == "3.12.0" ]]`、現状 L293 付近）を「version == CHANGELOG 最新リリース見出し」へ置換する。同テスト内の `[3.12.0]` 見出し存在検証と `### Removed` 存在検証は #271 のリリース規律の履歴事実として**そのまま残す**。あわせて、当該 `@test` 名（現状 `AT-005: CHANGELOG has [3.12.0] with Removed section and plugin.json version is 3.12.0`、L274 付近）から `version is 3.12.0` の含意を外し、最新リリース見出し整合を表す名へ改める（AT-284 タスクのテスト名修正と同じ理由＝完全一致値が消えた後にテスト名が虚偽にならないようにする）
- [ ] verify: 書き換え後の AT-271.bats を単体実行（`bats tests/acceptance/AT-271.bats`）して AT-005 相当テストが green になり、テスト名に `3.12.0` の version 完全一致含意が残っていないことを確認する

## Testing

- [ ] AT-271 AT-006（全 suite 再帰実行、L301-324）は構造を変更しない。上記 2 件の修正により連鎖的に green 化することを確認する
- [ ] verify: `bats tests/acceptance/AT-271.bats` で AT-006 が green（= 配下の AT-284.bats 含む全 suite が fail 0 件）になることを確認する

- [ ] post-merge regression 相当の全 acceptance suite を実行する
- [ ] verify: `bats tests/acceptance/` が fail 0 件で完走する（#277 検出時の 3 件 red がすべて解消されている）

- [ ] 将来耐性の確認（回帰しない証拠）: 一時的に plugin.json version を疑似的な次版（例: `3.14.3`）へ、CHANGELOG 先頭に対応見出しを追加した状態でも対象 AT が green を保つことを確認し、確認後に元へ戻す（commit はしない）
- [ ] verify: 疑似 bump 状態で `bats tests/acceptance/AT-271.bats tests/acceptance/AT-284.bats` が green、戻した後も green であることを確認する

## Finishing

- [ ] 再発防止ガイダンス（PRD What 4）を明文化する。`skills/writing-plan-and-tests/SKILL.md`（AT spec 作成ステップ＝ Step 3 付近）と `skills/running-atdd-cycle/SKILL.md`（`[regression]` を確立する箇所＝ C2 / lifecycle 付近）に「`[regression]` として恒久実行される AT には、バージョン等の時点依存値を完全一致でピンしない（履歴事実＋最新リリース見出しとの整合で書く）」を追記する
- [ ] verify: 両 SKILL.md に当該ガイダンス文が存在することを grep で確認する（`grep -n '時点依存' skills/writing-plan-and-tests/SKILL.md skills/running-atdd-cycle/SKILL.md`）

- [ ] DEVELOPMENT.md のルール（versioning / i18n / 言語ポリシー）に反していないか、CHANGELOG.md への本 Issue エントリ追記が必要かを確認する
- [ ] verify: CHANGELOG.md の `## [Unreleased]` に本修正のエントリ（Fixed/Changed）が追加され、DEVELOPMENT.md のルールと矛盾しない

- [ ] ドキュメント整合性チェック
- [ ] verify: plan.md / acceptance-tests.md・対象 AT ファイル・両 SKILL.md・CHANGELOG が相互に整合している
