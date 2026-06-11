# PRD: autopilot-log.jsonl 削除時に sameness / stuck 履歴が無音リセットされる（fail-open）

## Problem

autopilot の安全レール（`check_sameness` / `check_stuck`）は `docs/issues/<NNN>-*/autopilot-log.jsonl` の履歴に依存するが、このファイルが run 途中で削除・リセット・巻き戻しされても検出機構がなく、履歴が無音でリセットされる。結果、レールが実質無効化される（fail-open）。anchor 側には `pin_anchor` / `check_pin` の改竄検出があるのに対し、監査ログ側には同等のガードがない非対称が存在する。

## Why now

#246/#249 で autopilot が本格運用に入り、#254/#257 で実運用が始まった。レール無効化は自律ループの暴走（無限ループ・偽収束）リスクに直結するため、運用頻度が上がる前に塞ぐ必要がある。

## Outcome

- run 途中での autopilot-log.jsonl の削除・リセット・巻き戻しが、次の rails チェックで検出され halt（fail-closed）する
- 正当な初回実行（ログ未存在）では halt しない（誤検出ゼロ）
- 既存 BATS スイート green + 新規ガードの BATS テスト追加

## What

- `lib/autopilot_convergence.sh` に JSONL の存在・整合性チェックを追加（機構選定 — イテレーション連続性検証 / ログ fingerprint 化等 — は plan で決定）
- 不整合検出時は非ゼロ return → orchestrator が halt（AL-4/AL-5 整合）
- `skills/autopilot/SKILL.md` の Workflow script から新ガードを呼ぶ配管
- BATS テスト追加

## Non-Goals

- 削除されたログの復元 — 検出して halt するのみ（復元は人間の調査領域）
- #248 スコープの 3 項目（行レベル corruption guard / step 跨ぎログ分離 / halt 理由の JSONL 記録）— 別 Issue として既存
- anchor pin（`pin_anchor` / `check_pin`）側の変更 — 既に fail-closed

## Open Questions

- 「正当な初回（ログ未存在）」と「run 途中の削除」を区別する機構の選定 → plan で決定
