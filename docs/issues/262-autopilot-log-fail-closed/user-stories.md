# User Stories: autopilot-log.jsonl 削除時に sameness / stuck 履歴が無音リセットされる（fail-open）

## Functional Story

<!-- 機能要求を persona 抜き Connextra 形式で記述する。1 ストーリー = 1 ユーザーゴール。 -->

### US-1: 監査ログの存在・整合性ガード

**I want to** `lib/autopilot_convergence.sh` に `autopilot-log.jsonl` の存在・整合性を検証するガード関数が追加されている,
**so that** run 途中のログの削除・リセット・巻き戻しを次の rails チェックで検出できる.

### US-2: 不整合検出時の fail-closed halt

**I want to** ガードが不整合を検出したとき非ゼロ return で orchestrator に halt を伝える,
**so that** AL-4/AL-5 と整合する形で安全レールが fail-closed に倒れ、レール無効化のまま自律ループが暴走しない.

### US-3: Workflow script への配管

**I want to** `skills/autopilot/SKILL.md` の Workflow script が rails チェックの一部として新ガードを呼んでいる,
**so that** ガードが配管漏れなく毎イテレーション実行され、anchor 側（`pin_anchor` / `check_pin`）との改竄検出の非対称が解消される.

## Constraint Story (Non-Functional)

<!-- 非機能要求（NFR）を Story 形式で表現する（Pichler 2013）。
     システムが満たすべき品質特性（性能・セキュリティ・信頼性等）を制約として記述する。 -->

### US-4: 正当な初回実行での誤検出ゼロ

**I want to** 正当な初回実行（ログ未存在）ではガードが halt しないことが保証されている,
**so that** 誤検出ゼロで autopilot の正常な新規 run が阻害されない.

### US-5: BATS による回帰保証

**I want to** 新ガードの BATS テストが追加され、既存 BATS スイートも green を維持している,
**so that** レール群に回帰を入れずガードの検出・非検出の両挙動が継続的に検証される.
