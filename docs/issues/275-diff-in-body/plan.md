# Plan — #275 Diff-in-body

## 変更スコープ

| ファイル | 変更 |
|---------|------|
| `skills/autopilot/SKILL.md` | Flow step 3 に Diff-in-body (mandatory) + key lines / key decision の操作的定義、step 5 にハンドオフ diff 必須化を追記。Dialog economy（#267, L47）に補完関係を明文化。行バジェットは #272 取り込みで 260/260 となったため 280 へ引き上げ（#254 の 240→260 と同じ前例） |
| `tests/test_autopilot_skill.bats` | 新規 7 @test: 境界 canary AT-000 + AT-001〜AT-005（AT-005 = #267/#275 調停句の両節 pin）+ 空配列 `rejectionFindings` の fail-closed 拒否 pin。極性を固定する anchored grep を使う |
| `tests/e2e/autopilot.bats` | ランタイム挙動検証: 再提示シナリオで LLM がゲートメッセージ本文に diff ハンク提示を回復することを実 `claude -p` で検証 |
| `docs/issues/275-diff-in-body/` | prd / user-stories / plan / acceptance-tests の 4 点セット |
| `CHANGELOG.md` + `.claude-plugin/plugin.json` | [3.12.1] エントリ + patch bump（DEVELOPMENT.md §Versioning。main の 3.12.0 取り込み後に採番） |
| `skills/README.md` / `tests/README.md` | 同一 PR で同期（DEVELOPMENT.md §Directory READMEs） |

## 設計判断

- **静的 pin + E2E の二層**: BATS pin は「要件文言の存在と極性」を、E2E（`tests/e2e/autopilot.bats`）は「LLM が文言からランタイム挙動を回復すること」を検証する。ゲートの実挙動そのもの（実セッションでの diff 提示）は本リポジトリのテスト境界外（実運用での乖離は skill-fix で還流）
- **#267 との関係は補完**: 成果物本体のチャネルは Draft PR diff のまま不変。インラインハンクは判断根拠（decision evidence）であり代替チャネルではない。これを Flow step 3 と Dialog economy の両節に明記して規則優先関係の曖昧さを排除
- **再提示の判別条件**: 再提示 = `rejectionFindings` 付きで再呼び出しされた run（#261）のゲート提示。それ以外は初回提示
