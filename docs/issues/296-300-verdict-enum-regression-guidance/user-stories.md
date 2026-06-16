# User Stories: VERDICT_SCHEMA enum 制約化 ＋ regression ピン禁止ガイダンス補完・changelog ヘルパー集約

対象 Issue: #296（autopilot review verdict の enum 制約化）/ #300（#289 follow-up）

## Functional Story

<!-- #296 / AC-296-1, AC-296-2 -->
**I want to** autopilot の `VERDICT_SCHEMA.overall_correctness` を `enum: ['correct','incorrect']` に制約し、構造化出力ツール段で prose 混入を排除する,
**so that** review agent が `findings` の長文・XML 風タグを `overall_correctness` に流し込めなくなり、blocking ゼロなのに厳密一致が成立しない偽 stuck halt が構造的に発生しなくなる.

<!-- #300-1 / AC-300-1, AC-300-2 -->
**I want to** `running-atdd-cycle/SKILL.md` の `[regression]` 確立箇所に、時点依存値（バージョン等）を完全一致でピンせず「履歴事実（`## [X.Y.Z]` 見出し存在）＋ 整合事実（plugin.json version が CHANGELOG 最新リリース見出しと一致）」の 2 アサーションで表現する旨のガイダンスを、`writing-plan-and-tests/SKILL.md` の既存記述と整合する文言で追加する,
**so that** #289 で片側スキルにしか入らなかった再発防止ガイダンスが両スキルで揃い、regression AT の時点依存ピンによる脆さが繰り返されない.

<!-- #300-2 / AC-300-3, AC-300-4 -->
**I want to** `tests/acceptance/helpers/changelog.bash` に `changelog_latest_release <changelog_path>`（`## [Unreleased]` をスキップし先頭の `## [X.Y.Z]` から `X.Y.Z` を取り出す）を定義し、AT-271.bats（AT-005）と AT-284.bats（AT-010）のインライン抽出重複を呼び出しへ置換する,
**so that** CHANGELOG 最新リリース見出し抽出ロジックが 1 箇所に集約され、AT が増えても同ロジックが散在しない.

## Constraint Story (Non-Functional)

<!-- AC-COM-1 -->
**I want to** 上記変更後も `bats tests/acceptance/` が fail 0 件で green を維持し、疑似 version bump でも red 化しない,
**so that** regression セーフティネットが壊れず、enum 制約・ガイダンス追補・helper 集約がいずれも既存の不変条件を破らないことが保証される.

<!-- AC-COM-2 -->
**I want to** `.claude-plugin/plugin.json` の version bump と `CHANGELOG.md`（Keep a Changelog 形式）への本変更エントリ追加を伴う,
**so that** DEVELOPMENT.md のリリース規約に従い、変更が追跡可能なリリース単位として記録される.
