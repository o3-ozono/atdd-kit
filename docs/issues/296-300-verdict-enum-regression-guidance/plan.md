# Plan: VERDICT_SCHEMA enum 制約化 ＋ regression ピン禁止ガイダンス補完・changelog ヘルパー集約

対象 Issue: #296（autopilot review verdict の enum 制約化）/ #300（#289 follow-up）

<!-- 2-5 分粒度のタスク行と verification 行を交互に配置する（superpowers writing-plans 形式）。
     各タスクは単一の操作に限定し、verification で完了条件を即確認できる粒度にする。 -->

## Implementation

### #296 — VERDICT_SCHEMA.overall_correctness を enum 制約化（AC-296-1, AC-296-2）

- [ ] `skills/autopilot/SKILL.md` の `VERDICT_SCHEMA` 内 `overall_correctness: { type: 'string' }`（line 146 付近）を `overall_correctness: { type: 'string', enum: ['correct', 'incorrect'] }` に変更する。末尾コメント `// correct | incorrect` は維持する
- [ ] verify: `grep -n "enum: \['correct', 'incorrect'\]" skills/autopilot/SKILL.md` が `overall_correctness` 行にヒットする
- [ ] oracle の厳密一致判定（line 224 `verdict.overall_correctness === 'correct'`）と整合することを確認する。enum 値 `'correct'` がそのまま厳密一致を通すため判定ロジックは無改修で破綻しない
- [ ] verify: `grep -n "overall_correctness === 'correct'" skills/autopilot/SKILL.md` が line 78 / 224 で従来どおりヒットし、判定式が変更されていない

### #300-1 — running-atdd-cycle に時点依存ピン禁止ガイダンスを追加（AC-300-1, AC-300-2）

- [ ] `skills/running-atdd-cycle/SKILL.md` の C2 バレット（`[regression]` 確立箇所, line 41）末尾に、時点依存ピン禁止ガイダンスを 1 文追記する。文言は `writing-plan-and-tests/SKILL.md` line 40 の既存記述（`[regression]` AT は version/date/line-count 等の時点依存値を完全一致でピンせず invariant を assert する＝履歴事実＋整合事実の 2 アサーション、#289）と整合させる
- [ ] verify: `grep -nE "時点依存|完全一致|不変|invariant|#289" skills/running-atdd-cycle/SKILL.md` が C2 付近にヒットし、`writing-plan-and-tests/SKILL.md` の既存ガイダンスと用語（完全一致でピンしない／履歴事実＋整合事実／#289）が揃う

### #300-2 — changelog_latest_release ヘルパーへ集約（AC-300-3, AC-300-4）

- [ ] `tests/acceptance/helpers/changelog.bash` を新規作成し、`changelog_latest_release <changelog_path>` 関数を定義する。`## [Unreleased]` をスキップし、先頭の `## [X.Y.Z]` 見出しから `X.Y.Z` を取り出して echo する（既存インライン `grep -oE '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' | head -1 | tr -d '#[] '` と等価。`[Unreleased]` は数値 X.Y.Z 正規表現に一致しないため自然にスキップされる）
- [ ] verify: `bash -c 'source tests/acceptance/helpers/changelog.bash; changelog_latest_release CHANGELOG.md'` が現行 plugin.json version と一致する文字列を出力する
- [ ] `tests/acceptance/AT-271.bats`（AT-005, line 297）のインライン抽出 `top=$(grep -oE ... | tr -d '#[] ')` を、ヘルパー読み込み ＋ `top=$(changelog_latest_release "${repo_root}/CHANGELOG.md")` へ置換する。ヘルパーは当該テスト or setup で `source` し、`${repo_root}` 解決を維持する
- [ ] verify: `grep -n "changelog_latest_release" tests/acceptance/AT-271.bats` がヒットし、`grep -nF "grep -oE '^## \[" tests/acceptance/AT-271.bats` がヒットしない（インライン重複が残っていない）
- [ ] `tests/acceptance/AT-284.bats`（AT-010, line 190）のインライン抽出を同様に `changelog_latest_release CHANGELOG.md`（相対 CWD）へ置換する。AT-284 は CWD 相対のため引数も相対パスで渡す
- [ ] verify: `grep -n "changelog_latest_release" tests/acceptance/AT-284.bats` がヒットし、`grep -nF "grep -oE '^## \[" tests/acceptance/AT-284.bats` がヒットしない

## Testing

- [ ] `bats tests/acceptance/` を実行し fail 0 件を確認する（helper 置換後も AT-271/AT-284 を含め全 green）
- [ ] verify: `bats tests/acceptance/` の出力が `0 failures` で終わる
- [ ] 疑似 version bump（plugin.json version を一時的に上げ、CHANGELOG 先頭見出しも同値にする）で AT-271/AT-284 が red 化しないことを確認し、変更を元に戻す
- [ ] verify: 疑似 bump 中も AT-005/AT-010 が green（invariant が version 値に依存せず見出し一致で判定される）であり、確認後に plugin.json/CHANGELOG が元値へ復元されている
- [ ] `bats tests/` を実行し、autopilot SKILL.md の構造 pin（`test_autopilot_skill.bats` 等の行バジェット・schema 構造アサーション）が green を維持することを確認する
- [ ] verify: `bats tests/` が `0 failures`

## Finishing

- [ ] `.claude-plugin/plugin.json` の version を SemVer minor で bump し、`CHANGELOG.md` に本変更の `### Changed`/`### Added` エントリ（Keep a Changelog 形式）を追加する（DEVELOPMENT.md リリース規約）
- [ ] verify: `changelog_latest_release CHANGELOG.md` の出力が新 plugin.json version と一致する（AC-COM-2 ＝ AT-005/AT-010 invariant が green）
- [ ] `tests/acceptance/helpers/` 新設に伴い `tests/README.md` を更新する（helpers ディレクトリの記述追加。DEVELOPMENT.md Directory READMEs ルール）
- [ ] verify: `grep -n "helpers" tests/README.md` がヒットする
- [ ] ドキュメント整合性チェック
- [ ] verify: 関連ドキュメント（CHANGELOG / tests README）が変更内容と整合している
