# Acceptance Tests: autopilot 収束ループの根本再設計 — 収束信号を客観ゲートに一本化

<!-- AT lifecycle: planned → draft → green → regression
     不変条件で書く（plugin version / 日付 / 行数の point-in-time pin を禁止 #289）。
     本 Issue の AT は SKILL/lib の挙動 pin（BATS, tests/*.bats）。 -->

## AT-355-F1: impl-phase オラクルから LLM レビュー項を除去

- [ ] [planned] AT-355-F1-1: impl-phase オラクルが客観ゲートのみ
  - Given: `skills/autopilot/SKILL.md` の satisfaction oracle 行
  - When: oracle を読む
  - Then: `converged` が `redObserved && atGreen && coverageOk` のみで構成され、`overall_correctness` や blocking-findings（LLM レビュー由来）を AND 項に含まない

## AT-355-F2: impl-phase ループから reviewing-deliverables 呼び出しを除去

- [ ] [planned] AT-355-F2-1: 収束ループに reviewing-deliverables 呼び出しが無い
  - Given: `skills/autopilot/SKILL.md` の Mechanism / Workflow 本体
  - When: 本体を読む
  - Then: impl-phase ループに `reviewing-deliverables` を回す review エージェント呼び出し・review 用 verdict schema・review-scope 構築が存在しない

## AT-355-F3: design-phase をレビューループ無しに

- [ ] [planned] AT-355-F3-1: design 収束は人間 Gate②
  - Given: `skills/autopilot/SKILL.md` の design-phase / Flow 記述
  - When: design-phase の収束記述を読む
  - Then: design-phase は LLM レビューループを持たず、生成 → Gate②（設計承認）で収束する旨が記述され、`rejectionFindings` による差し戻し再生成経路が維持されている

- [ ] [planned] AT-355-F3-2: 「in-loop reviewer」記述の撤廃
  - Given: `skills/autopilot/SKILL.md` 冒頭の役割記述
  - When: 記述を読む
  - Then: 「`reviewing-deliverables` as the in-loop reviewer」相当の記述が無く、reviewing-deliverables はループ外 standalone と位置づけられている

## AT-355-F4: 客観ゲートの Issue クラス一般化（red-first を全 modality へ）

- [ ] [planned] AT-355-F4-1: red-first が modality 非依存
  - Given: `skills/running-atdd-cycle/SKILL.md` の Confirm RED（C2）
  - When: 節を読む
  - Then: 実行可能 AT（`tests/acceptance/`）と skill/doc 変更の BATS pin（`tests/*.bats`）の双方で red-first（変更前 赤 → 変更後 緑）する旨が記述され、`tests/acceptance/AT-<NNN>.*` 固有のファイル名のみを前提としていない

- [ ] [planned] AT-355-F4-2: record_red_evidence に impl baseline SHA を渡す契約
  - Given: 同 SKILL の Confirm RED
  - When: record_red_evidence の呼び出し契約を読む
  - Then: `record_red_evidence <red.jsonl> <test-sha> <at-file> <impl-baseline-sha>` の 4 引数（impl_sha 含む）で呼ぶ契約が記述されている（`tests/test_running_atdd_cycle_skill.bats` が pin）

## AT-355-F5: red-gate の堅牢化（記録値読み取り）

- [ ] [planned] AT-355-F5-1: record_red_evidence が test SHA と impl baseline SHA を記録
  - Given: 一時 git リポジトリと空の red.jsonl
  - When: `record_red_evidence` を test-commit SHA・at-file・impl baseline SHA で呼ぶ
  - Then: red.jsonl の追記行に `commit`（test SHA）と `impl_sha` の両フィールドが含まれ、JSON として整形されている

- [ ] [planned] AT-355-F5-2: check_red_evidence は記録値で判定する
  - Given: red.jsonl に test SHA / impl_sha の red 記録があり ancestry が成立
  - When: `check_red_evidence` を test_sha / impl_sha / red.jsonl で呼ぶ
  - Then: exit 0（redObserved=true）を返す

- [ ] [planned] AT-355-F5-3: 記録の無い／改竄された SHA で fail-closed
  - Given: red.jsonl に該当記録が無い、または ancestry が成立しない
  - When: `check_red_evidence` を呼ぶ
  - Then: 非 0（fail-closed、redObserved=false）

- [ ] [planned] AT-355-F5-4: red-gate プロンプトから git log 考古学が排除されている
  - Given: `skills/autopilot/SKILL.md` の red-gate 呼び出し手順
  - When: 手順を読む
  - Then: red.jsonl の記録値（commit / impl_sha）を読む手順で、「search git log for commits touching tests/acceptance」「git rev-parse HEAD / awk NR==2」相当の SHA 推測が存在しない

## AT-355-F6: gate-unverifiable = 客観ゲート確立不能の早期 escalation

- [ ] [planned] AT-355-F6-1: record_halt が gate-unverifiable を受理
  - Given: 一時 JSONL ログ
  - When: `record_halt` を reason `gate-unverifiable` で呼ぶ
  - Then: `outcome":"HALT"` かつ `reason":"gate-unverifiable"` の HALT 行が追記される

- [ ] [planned] AT-355-F6-2: 未知 reason は拒否される（enum 不変条件）
  - Given: 一時 JSONL ログ
  - When: `record_halt` を enum 外の reason で呼ぶ
  - Then: 非 0 を返し HALT 行を書かない

- [ ] [planned] AT-355-F6-3: gate-unverifiable の条件が review 非依存
  - Given: `skills/autopilot/SKILL.md` の gate-unverifiable 早期 escalation 条件
  - When: 条件を読む
  - Then: 「客観ゲートが確立できない（atRequired だが red.jsonl 記録が無い / カバレッジ計算不能 / AT 未生成）」で記述され、旧定義（review correct + tests green）に依存していない

## AT-355-F7: reviewing-deliverables を standalone へ戻す

- [ ] [planned] AT-355-F7-1: reviewing-deliverables が main の形に一致
  - Given: `skills/reviewing-deliverables/SKILL.md`
  - When: main との差分を取る
  - Then: #345 追加分（scope guard / 多視点合議 2/3 / round memory / severity dedup / CONVERGED 停止）が無く、main と一致する

## AT-355-C2: Non-Goals 境界の不変性

- [ ] [planned] AT-355-C2-1: red-first / 3ゲート / coverage 内部判定が不変
  - Given: 変更後の skills/lib/docs
  - When: red-first の必須性（#334）・User gate 3ゲート（AL-1）・coverage/atGreen 内部判定を確認する
  - Then: これらは変わらず、変更はオラクルのレビュー項除去・modality 一般化・SHA 記録・停止理由整理に留まっている

## AT-355-C3: 既存 rails の保持

- [ ] [planned] AT-355-C3-1: sameness / stuck / log-integrity / MAX_ITERATIONS / ac-drift が維持
  - Given: 変更後の `lib/autopilot_convergence.sh` と `skills/autopilot/SKILL.md`
  - When: rails の存在を確認する
  - Then: check_sameness（FAIL 行のみ）・check_stuck（window=3・FAIL 行のみ）・check_log_integrity・check_max_iterations・ac-drift（check_pin）がすべて維持されている

<!-- 実装開始後は [planned] → [draft] → [green] -->
