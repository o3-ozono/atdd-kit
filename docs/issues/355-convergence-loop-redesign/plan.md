# Plan: autopilot 収束ループの根本再設計 — 収束信号を客観ゲートに一本化

> 設計根拠は [research.md](research.md)。SKILL.md 編集は behavior-shaping code（DEVELOPMENT.md）— 各 SKILL/lib 変更は対応 BATS（`tests/test_*.bats`）を編集前後で実行し green を維持。
> red-first 原則（#334）・3ゲート（AL-1）・coverage/atGreen 内部判定は不変（C2）。

## Implementation

### A. reviewing-deliverables を standalone へ戻す（F2 / F7）

- [ ] `skills/reviewing-deliverables/SKILL.md` の #345 追加分（F3-F7: scope guard / 多視点合議 2/3 / round memory / severity dedup / CONVERGED 停止条件）を main の形に revert する（`git checkout main -- skills/reviewing-deliverables/SKILL.md`）
- [ ] verify: `git diff main -- skills/reviewing-deliverables/SKILL.md` が空（main と一致）

### B. autopilot オラクルから LLM レビューを除去（F1 / F2）

- [ ] `skills/autopilot/SKILL.md` の impl-phase satisfaction oracle を `const converged = redObserved && atGreen && coverageOk` に変更し、`verdict.overall_correctness === 'correct' && blocking.length === 0`（レビュー項）を削除する
- [ ] `skills/autopilot/SKILL.md` の収束ループから review エージェント呼び出し（`reviewing-deliverables` を回す `agent()`）・`reviewScope`・review 用 `VERDICT_SCHEMA`・`blocking` 算出・`prevFindings`（review 由来）を除去する。audit fingerprint payload は `{redObserved, atGreen, coverageOk, uncovered}` に整理
- [ ] verify: `skills/autopilot/SKILL.md` の oracle 行に review 由来項が無く、ループに reviewing-deliverables 呼び出しが無いことを grep / BATS pin で確認

### C. design-phase をレビューループ無しに（F3）

- [ ] design-phase（atRequired=false）で converged が iteration 1 で真になる（生成1回で次ステップ／Gate② へ）よう、レビュー除去後のループが design でも回り続けないことを保証する。`rejectionFindings` による人間差し戻し再生成の seed 経路は維持
- [ ] `skills/autopilot/SKILL.md` 冒頭の「`reviewing-deliverables` as the in-loop reviewer」記述を「収束は客観ゲート、設計は人間 Gate②、reviewing-deliverables はループ外の standalone」へ書き換える
- [ ] verify: design-phase 記述・Mechanism にレビューループが無く、Gate② が design 収束信号であることが BATS pin で確認できる

### D. 客観ゲートの Issue クラス一般化（F4 / F5）

- [ ] `skills/running-atdd-cycle/SKILL.md` の C1/C2 を、AT を実行可能（`tests/acceptance/`）と skill/doc 変更の BATS pin（`tests/*.bats`）の双方で red-first（変更前 赤 → 変更後 緑）し、`record_red_evidence <red.jsonl> <test-sha> <at-file> <impl-baseline-sha>` を呼ぶよう一般化する。`tests/acceptance/AT-<NNN>.*` 固有のファイル名前提を撤廃し「AC を表すテスト（modality は plan が宣言）」とする
- [ ] verify: `skills/running-atdd-cycle/SKILL.md` の Confirm RED が modality 非依存（BATS pin を含む）で record_red_evidence に impl_sha を渡す契約になっていることを `tests/test_running_atdd_cycle_skill.bats` で pin
- [ ] `skills/autopilot/SKILL.md` の red-gate プロンプトが red.jsonl の記録値（commit / impl_sha）を読むだけで、git log 考古学（commits touching tests/acceptance / git rev-parse HEAD / awk NR==2）を含まないことを確認（F8、既存実装を維持）
- [ ] verify: red-gate 手順から SHA 推測ステップが消えていることを grep / BATS pin で確認

### E. lib（F5 / F6、既存実装の維持と検証）

- [ ] `lib/autopilot_convergence.sh` の `record_red_evidence` が impl baseline SHA を 4th 引数で受けて red.jsonl に記録、`check_red_evidence` が記録値で判定することを維持・検証する（F5）
- [ ] `lib/autopilot_convergence.sh` の `record_halt` reason enum に `gate-unverifiable` を維持する（F6: 客観ゲート確立不能の早期 escalation）
- [ ] verify: `tests/test_autopilot_convergence.bats` で impl_sha 記録・記録値判定・gate-unverifiable enum 受理・enum 外拒否を確認

### F. gate-unverifiable の意味を「客観ゲート確立不能」に整理（F6）

- [ ] `skills/autopilot/SKILL.md` の `gate-unverifiable` 早期 escalation 条件を、レビュー除去後の定義「客観ゲートが確立できない（atRequired だが red.jsonl 記録が無い・カバレッジ計算不能・AT 未生成）」に書き換える。旧定義（review correct + tests green + 残り機構問題）は review 項削除に伴い撤廃
- [ ] verify: gate-unverifiable の条件が review 非依存で記述され、BATS pin で確認

## Testing

- [ ] `tests/test_autopilot_skill.bats`: F1（oracle = 客観ゲートのみ・review 項なし）・F2（ループに reviewing-deliverables 呼び出しなし）・F3（design は Gate② 収束・in-loop reviewer 記述撤廃）・F6（gate-unverifiable = 客観ゲート確立不能）の pin を追加／更新
- [ ] verify: `bats tests/test_autopilot_skill.bats` 全 green
- [ ] `tests/test_autopilot_convergence.bats`: F5（impl_sha 記録・記録値判定）・F6（gate-unverifiable enum）の構造アサーション
- [ ] verify: `bats tests/test_autopilot_convergence.bats` 全 green
- [ ] `tests/test_running_atdd_cycle_skill.bats`: F4（red-first modality 一般化・impl_sha 記録契約）の pin
- [ ] verify: `bats tests/test_running_atdd_cycle_skill.bats` 全 green
- [ ] `tests/test_reviewing_deliverables_skill.bats`: #345 で追加した F3-F7 pin を revert（main の形に戻す）
- [ ] verify: `bats tests/test_reviewing_deliverables_skill.bats` 全 green（main と一致）

## Finishing

- [ ] `docs/methodology/autopilot-iron-law.md` の AL-3/AL-4（オラクル定義）・AL-5（停止理由）を、レビュー除去・客観ゲートのみ・gate-unverifiable 新定義に追従。`docs/methodology/autopilot-overview.md` 等レビューを in-loop と記す箇所を整理
- [ ] verify: methodology ドキュメントが変更内容と整合し、C2 の Non-Goals 境界（red-first / coverage 内部判定 / 3ゲート不変）が文書上も保たれている
- [ ] バージョン bump（`.claude-plugin/plugin.json`）と `CHANGELOG.md` 追記。収束ループの挙動変更（レビュー除去）= 機能変更として minor bump
- [ ] verify: plugin.json version と CHANGELOG 最上位リリース見出しが一致
- [ ] ディレクトリ README 整合: `lib/README.md` / `skills/README.md` / `tests/README.md` を変更内容と整合
- [ ] verify: 変更した top-level ディレクトリの README が整合（DEVELOPMENT.md Directory READMEs ルール）
