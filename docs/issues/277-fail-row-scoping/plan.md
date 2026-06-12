# Plan: sameness / stuck rails の比較母集団を同一 step の FAIL 行のみに絞る (#277)

<!-- 2-5 分粒度のタスク行と verification 行を交互に配置する（superpowers writing-plans 形式）。
     各タスクは単一の操作に限定し、verification で完了条件を即確認できる粒度にする。 -->

前提: 修正対象は `lib/autopilot_convergence.sh` の `_fingerprints`（行 93-108）のみ。`check_sameness` / `check_stuck` は `_fingerprints` 経由で母集団を取得するため、フィルタ追加 1 箇所で両レールに効く。JSONL の `verdict` フィールドは既存（スキーマ変更なし）。

意味論ノート（跨 run FAIL 隣接）: FAIL-only フィルタにより、PASS を挟んで離れた同一 fingerprint の FAIL 行（同一 step の [FAIL(A), PASS, FAIL(A)] — run 1 で 1 回 FAIL 後に収束し、設計ゲート差し戻し後の run 2 初回が同一 fingerprint で FAIL）は母集団内で隣接し、`check_sameness` が従来の continue から halt へ変わる。これは承認済み PRD Outcome「比較母集団 = 同一 step の FAIL 行のみ・PASS 行は一切寄与しない」の直接帰結であり、同一 fingerprint（= 同一 oracle ペイロード）の FAIL 再発は「同じ失敗の繰り返し」として検出するのが正当 — **意図された挙動として AT-006 で pin する**。PRD は autopilot の immutable anchor（`autopilot-prd.pin`）として凍結済みのため追記せず、本ノートと AT-006 を意味論の正式な記録とする。

## Implementation

- [ ] `lib/autopilot_convergence.sh` の `_fingerprints` に FAIL-only フィルタを追加する: step 指定・省略の両モードで、fingerprint 抽出の前段に `grep -F '"verdict":"FAIL"'` を挟む（step フィルタとの AND。Gate ① 承認どおり全モード適用）
- [ ] verify: `source lib/autopilot_convergence.sh` し、PASS/FAIL 混在の一時 JSONL に対して `_fingerprints <log>` と `_fingerprints <log> <step>` がともに FAIL 行の fingerprint のみを返す

- [ ] `_fingerprints` の直前コメント（行 86-92）を「同一 step かつ verdict=FAIL の行のみ」という新しい検出意味論に更新する（#277 参照を追記）
- [ ] verify: `grep -n 'FAIL' lib/autopilot_convergence.sh` でコメントが実装と一致している

- [ ] `check_sameness` の直前コメント（行 110-115）を「比較母集団は FAIL 行のみ。PASS 行は失敗反復の証拠にならないため除外（#277）」に更新する
- [ ] verify: コメントに FAIL-only 意味論と #277 参照が含まれる

- [ ] `check_stuck` の直前コメント（行 128-136）を同様に更新する（window 母集団 = 同一 step の FAIL 行のみ）
- [ ] verify: コメントに FAIL-only 意味論と #277 参照が含まれる

- [ ] ファイルヘッダの Functions 一覧（行 12-13）の `check_sameness` / `check_stuck` 説明を「FAIL rows only」を含む記述に更新する
- [ ] verify: ヘッダ説明が新しい挙動（step-scoped, FAIL-only）を正確に述べている

## Testing

- [ ] `tests/test_autopilot_convergence.bats` に #277 再入シナリオの回帰テストを追加する: 同一 step に [PASS, PASS, FAIL]（PASS 2 行は同一 fingerprint = 収束定数）を記録し、`check_stuck <log> 3 <step>` が 0（continue）を返す
- [ ] verify: `bats tests/test_autopilot_convergence.bats` で新テストが green（Step 4 では RED → GREEN の順で確認）

- [ ] check_sameness の PASS 行除外テストを追加する: 同一 step に [PASS(fp X), FAIL(fp X)] を記録し、`check_sameness <log> <step>` が 0 を返す（PASS 行は prev として数えない）
- [ ] verify: 新テストが green

- [ ] レガシー全ログモード（step 引数省略）の FAIL-only テストを追加する: PASS 行と FAIL 行が同一 fingerprint で隣接するログに対し `check_sameness <log>`（step なし）が 0 を返す
- [ ] verify: 新テストが green

- [ ] 跨 run FAIL 隣接の意味論を pin するテストを追加する（AT-006）: 同一 step に [FAIL(fp A), PASS, FAIL(fp A)] を記録し、`check_sameness <log> <step>` が非ゼロ（halt）を返す — PASS を挟んだ同一 fingerprint の FAIL 再発は「同じ失敗の繰り返し」として検出される意図された挙動（前提の意味論ノート参照）
- [ ] verify: 新テストが green であり、テストコメントに「従来 continue → 新規 halt の意図された経路（#277 AT-006）」と明記されている

- [ ] 既存 `AT-003 (#272)`（step 省略時のレガシー互換テスト、行 364-371）の期待値を新意味論に更新する: フィクスチャ `_make_cross_step_log` は PASS+FAIL 混在のため、FAIL-only 適用後は halt ではなく continue（exit 0）が正。テスト名・コメントも「レガシーモードにも FAIL-only が適用される (#277)」へ書き換える
- [ ] verify: 更新後の AT-003 が green であり、変更理由コメントに #277 と Gate ① 全モード適用の承認が引用されている

- [ ] 真の失敗反復の検出力維持を確認する: 既存の FAIL 行のみのフィクスチャ群（sameness 連続一致 / stuck flatline / oscillation / AT-002 / AT-004a-c）に変更を加えず suite 全体を実行する
- [ ] verify: `bats tests/test_autopilot_convergence.bats` が全件 green（既存テストの期待値変更は AT-003 の 1 件のみ）

- [ ] `tests/README.md` の `test_autopilot_convergence.bats` 行に #277（FAIL-only 母集団・テスト総数）を追記する
- [ ] verify: README の記述が実テスト構成と一致している

## Finishing

- [ ] `skills/autopilot/SKILL.md` の rails 呼び出し説明（(c) check_sameness / (d) check_stuck のインラインコメント、#272 参照箇所）に「#277: FAIL 行のみ比較」を追記する
- [ ] verify: SKILL.md の rails 説明が lib の実態と一致している

- [ ] `docs/methodology/autopilot-iron-law.md` の sameness-detector / stuck detection 記述（行 34）に「同一 step の FAIL 行のみを比較」を反映する
- [ ] verify: iron-law doc の記述が実装の検出意味論と一致している

- [ ] `skills/README.md` の autopilot 行（行 41）の `step-scoped convergence checks (#272)` 記述を「同一 step かつ FAIL 行のみ（#277: FAIL-only population — PASS rows never contribute）」の意味論へ更新する（DEVELOPMENT.md §Directory READMEs: skills/ 配下の変更は同一 PR で skills/README.md を更新する）
- [ ] verify: skills/README.md の autopilot 行が lib の実態（step-scoped かつ FAIL-only）と一致し、#272 のみの旧記述が残っていない

- [ ] `lib/README.md` の `autopilot_convergence.sh` 行（行 14）の sameness-detector / stuck detection 説明に FAIL-only 母集団（#277）を追記する（DEVELOPMENT.md §Directory READMEs の列挙対象外だが、lib 本体を変更する PR のため同期する）
- [ ] verify: lib/README.md の説明が新しい検出意味論と一致している

- [ ] `CHANGELOG.md` に Fixed エントリを追加する（Keep a Changelog 形式・#277・新バージョン見出し）
- [ ] verify: CHANGELOG に本修正のエントリが存在する

- [ ] `.claude-plugin/plugin.json` のバージョンを patch バンプする（執筆時点 3.13.1 → 3.13.2。DEVELOPMENT.md §Versioning: version + CHANGELOG 更新は feature/fix PR と同一 PR で必須。マージ時に main の最新バージョンを再確認して採番する）
- [ ] verify: plugin.json の `version` と CHANGELOG の最新エントリ見出しが一致し、`scripts/check-plugin-version.sh` の更新通知が壊れない

- [ ] ドキュメント整合性チェック（doc-sync-checklist 6 点: lib コメント / SKILL.md / skills/README / iron-law / tests/README / CHANGELOG。加えて nit 対応の lib/README）
- [ ] verify: 関連ドキュメントが変更内容と整合している
