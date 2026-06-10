# Acceptance Tests: autopilot 収束ループのプロンプト欠陥3点修正（#252）

<!-- AT lifecycle: planned → draft → green → regression。skill 実装の AT は
     Unit Test（tests/test_*.bats, claude 非起動の構造検証）で検証する。
     skill-fix inline mode: アンカーは Issue #252 本文の受け入れ条件チェックリスト。 -->

## AC 対応表（トレーサビリティ / MUST-3）

| Issue #252 受け入れ条件 | AT |
|------------------------|----|
| AC1: FAIL 行の fingerprint が blocking findings 実テキストの sha256 になる（定数 `2aed7ea6...` が二度と記録されない） | AT-001, AT-002 |
| AC2: design phase のレビューが「プロダクションコード不在/実行可能 AT 不在」を findings として返さない | AT-003 |
| AC3: extracting-user-stories ステップのレビューが plan.md / acceptance-tests.md への findings を返さない | AT-004 |
| AC4: gen エージェントのプロンプトに前回レビューの findings 本文が含まれる | AT-005 |
| AC5: BATS — プレースホルダ文字列の fingerprint がログに現れないことを検証するテストの追加 | AT-006 |

## AT-001: 監査プロンプトからプレースホルダ排除（AC1）

- [x] [green] AT-001: SKILL.md にプレースホルダのハッシュ指示が存在しない
  - Given: `skills/autopilot/SKILL.md`
  - When: 読む（Unit: grep）
  - Then: 文字列 `<the blocking findings text, verbatim>` および `Run EXACTLY` によるプレースホルダ直接 `printf | fingerprint` 指示が存在しない

## AT-002: findings payload の埋め込みハッシュ手順（AC1）

- [x] [green] AT-002: audit プロンプトが findings 実テキストをハッシュする手順を持つ
  - Given: `skills/autopilot/SKILL.md` の `audit:${step}` プロンプト
  - When: 読む（Unit: grep）
  - Then: blocking findings の JSON が `BEGIN-PAYLOAD` / `END-PAYLOAD` マーカー付きでプロンプトに埋め込まれ（`JSON.stringify(blocking)` 等の変数展開）、quoted heredoc で一時ファイルへ書いてから `fingerprint` に渡す手順が指示されている

## AT-003: design phase の review スコープ（AC2）

- [x] [green] AT-003: review プロンプトが design phase で計画成果物のみをスコープにする
  - Given: `skills/autopilot/SKILL.md` の `review:${step}` プロンプト（design phase 経路）
  - When: 読む（Unit: grep）
  - Then: 計画成果物のみをレビュー対象とし、プロダクションコード不在・実行可能 AT 不在を findings にしない旨のスコープ節がプロンプトに連結される

## AT-004: step 単位の review スコープ（AC3）

- [x] [green] AT-004: extracting-user-stories ステップのレビューが当該ステップ成果物に限定される
  - Given: `skills/autopilot/SKILL.md` のスコープヘルパー（step 別分岐）
  - When: 読む（Unit: grep）
  - Then: `extracting-user-stories` ステップでは prd.md ↔ user-stories.md の整合のみをスコープとし、plan.md / acceptance-tests.md への findings を返さない指示がある

## AT-005: gen プロンプトへの findings 伝達（AC4）

- [x] [green] AT-005: iteration 2 以降の gen プロンプトに前回 findings 本文が含まれる
  - Given: `skills/autopilot/SKILL.md` の `gen:${step}` プロンプト
  - When: 読む（Unit: grep）
  - Then: 前イテレーションの `verdict.findings` を JSON で埋め込む条件分岐が存在し（iteration 1 は従来文言を維持）、findings 本文なしの「fix them verbatim」単独指示が iteration 2 以降の経路に残っていない

## AT-006: placeholder fingerprint の回帰 pin（AC5）

- [x] [green] AT-006: BATS がプレースホルダ定数 fingerprint の再発を防ぐ
  - Given: 追加された BATS テスト（tests/test_autopilot_convergence.bats または新規ファイル）
  - When: `bats` 実行（Unit）
  - Then: テストが `printf '%s' "<the blocking findings text, verbatim>" | fingerprint` = `2aed7ea6d4c79d81da29da31fe975d762c64b1e15c211769880c3c6a92ccce2a` を再計算で確認した上で、その入力文字列が SKILL.md に存在しないことを assert し、green である

<!-- 実装開始後は [planned] → [draft] に変更する -->
<!-- テストが通過したら [draft] → [green] に変更する -->
<!-- リグレッション対象になったら [green] → [regression] に変更する -->

## ライフサイクル例

| 状態 | 意味 |
|------|------|
| [planned] | テスト設計済み・未実装 |
| [draft] | 実装中・まだ通過していない |
| [green] | テスト通過済み |
| [regression] | リグレッション対象として継続監視中 |
