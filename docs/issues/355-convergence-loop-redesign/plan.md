# Plan: autopilot 収束ループ＋review ラウンドの根本再設計 — done を堅牢に認識して止まる

<!-- 2-5 分粒度のタスク行と verification 行を交互に配置する（superpowers writing-plans 形式）。
     各タスクは単一の操作に限定し、verification で完了条件を即確認できる粒度にする。 -->

> 3層構成（PRD/US 準拠）: (A) 記録層 = red-gate 堅牢化（F8/C2、triggering instance）/ (B) レビュー層 = 多視点合議制＋停止条件（F3-F7）/ (C) ループ層 = 停止理由の二分類＋`gate-unverifiable` 早期 escalation（F1/F2/C1）。横断制約 C3（User gate 構造・red-first・coverage/atGreen 内部判定の不変性）を全タスクで遵守する。
>
> SKILL.md 編集は behavior-shaping code（DEVELOPMENT.md）。各 SKILL 変更は対応 BATS（`tests/test_*_skill.bats`）を編集前後で実行し green を維持する。lib 変更は `tests/test_autopilot_convergence.bats` を同様に扱う。

## Implementation

### A. 記録層 — red-gate 堅牢化（F8 / C2、triggering instance の修正）

- [ ] `lib/autopilot_convergence.sh` の `record_red_evidence` シグネチャを拡張し、red 観測時点の **impl baseline SHA も** red.jsonl に直接記録する（現状は `{step, commit, at_file, timestamp}` のみ）。記録行に `impl_sha`（red 観測時点の HEAD、または「impl 未着手」を表す sentinel）フィールドを追加する
- [ ] verify: `record_red_evidence` を呼ぶと red.jsonl 行に `commit`（test SHA）と `impl_sha` の両方が含まれることを BATS アサーションで確認

- [ ] `lib/autopilot_convergence.sh` の `check_red_evidence` を、test_sha / impl_sha を **引数で受けて git log 考古学で推測しない**形に変更し、red.jsonl に記録済みの test SHA レコード存在と（記録済み値に基づく）commit 分離アンカーだけで `redObserved` を deterministic に確定する。ancestry 検証は維持するが、SHA の **解決元を red.jsonl の記録値に固定**する（git log 探索による再構成を排除）
- [ ] verify: red.jsonl に記録がある test SHA に対し `check_red_evidence` が exit 0、記録が無い／改竄された SHA で fail-closed（非 0）になることを BATS で確認

- [ ] `skills/autopilot/SKILL.md` の red-gate 呼び出しプロンプト（現状: test-commit SHA を `git log` 探索、impl-commit SHA を `git rev-parse HEAD`/`awk NR==2` で推測する多段手順）を、**red.jsonl の記録済み SHA を読むだけ**の手順へ書き換える。git log 考古学のステップを削除する
- [ ] verify: `skills/autopilot/SKILL.md` の red-gate 手順から「search git log for commits touching tests/acceptance」「git rev-parse HEAD / awk NR==2」相当の SHA 推測記述が消え、red.jsonl 読み取りベースになっていることを grep / BATS pin で確認

- [ ] `skills/running-atdd-cycle/SKILL.md` の C2「Confirm RED」節を更新し、`record_red_evidence` 呼び出し契約に impl baseline SHA 記録を追加する（red 観測時点で test SHA と impl baseline SHA の両方を red.jsonl へ書く）
- [ ] verify: `tests/test_running_atdd_cycle_skill.bats` が `record_red_evidence` の更新契約（impl SHA 記録）を pin し green

### B. レビュー層 — 多視点合議制＋停止条件（F3-F7、旧 #345 集約）

- [ ] `skills/reviewing-deliverables/SKILL.md` のパネル構成を、PRD 解決済み設計（N=3: 機能正当性 / 安全性 / 設計妥当性）に沿って明示し、**2/3 majority** で同一所見を blocker/major として採用、単一レンズ単独判定は severity を一段下げるルールを Aggregate 規則に追加する（F3）
- [ ] verify: SKILL の Aggregate 規則に「majority（2/3）採用」「単一レンズ単独判定 → severity 一段下げ」が明記され、`tests/test_reviewing_deliverables_skill.bats` の pin が green

- [ ] `skills/reviewing-deliverables/SKILL.md` に **ラウンド横断の収束／停止条件**を追加する: (a) 新規 blocker/major ゼロ、または (b) 残存が「設計判断」「スコープ外」タグのみ で **CONVERGED（条件付き PASS）** を返す。最大ラウンド数上限を明記する（F4）
- [ ] verify: SKILL に CONVERGED の二条件と最大ラウンド数上限が記述され、BATS pin が green

- [ ] `skills/reviewing-deliverables/SKILL.md` の Scout に **スコープガード**を追加する: Issue の PRD/US から境界を抽出し、対象外ファイル／関心事の所見を `out-of-scope` タグで分離（FAIL 要因にせず follow-up 起票候補へ回す）（F5）
- [ ] verify: SKILL に Scout のスコープ境界抽出と `out-of-scope` 分離（FAIL 非要因）が明記され、BATS pin が green

- [ ] `skills/reviewing-deliverables/SKILL.md` に **設計判断のラウンド間記憶**を追加する: 実装側が docstring/ADR で「意図的トレードオフ」と宣言した点は、合議で「設計として不当」と判定されない限り再提出しない（解決済み／意図的を round 間で保持）（F6）
- [ ] verify: SKILL に設計判断のラウンド間記憶（意図的トレードオフの非蒸し返し）規則が明記され、BATS pin が green

- [ ] `skills/reviewing-deliverables/SKILL.md` の severity 付与を **単一化**する: レンズ横断で同一所見をマージしてから 1 回だけ severity を付与し、レンズ別の重複付与を排除する（F7）
- [ ] verify: SKILL に「レンズ横断マージ後に 1 回だけ severity 付与」が明記され、BATS pin が green

### C. ループ層 — 停止理由の二分類＋gate-unverifiable 早期 escalation（F1 / F2、C1）

- [ ] `lib/autopilot_convergence.sh` の `record_halt` reason enum（現状: `MAX_ITERATIONS|sameness-detector|stuck|ac-drift|log-integrity`）に **`gate-unverifiable`** を追加し、distinct な停止理由として記録できるようにする（F2）
- [ ] verify: `record_halt` に reason `gate-unverifiable` を渡すと HALT 行が書かれ、enum 外の値は従来どおり拒否（非 0）されることを BATS で確認

- [ ] `skills/autopilot/SKILL.md` のオラクル／停止条件レールを更新し、停止理由を **二分類**する: (i) 成果物未完成（review findings 残存 / tests red）→ 従来どおり generate→review→fix を継続 / (ii) ゲート機構の自己検証失敗（red-gate の SHA／tooling 不全）→ MAX まで空転させず `gate-unverifiable` で早期に人間 escalation。**review=correct ＋ tests green ＋ 残り機構問題のみ**の状態で機構が確証できない場合に gate-unverifiable へ分岐するロジックを記述する（F1/F2）
- [ ] verify: `skills/autopilot/SKILL.md` に二分類（未完成 vs 機構自己検証失敗）と gate-unverifiable 早期 escalation 条件（demonstrably-done だが機構未確証）が明記され、`tests/test_autopilot_skill.bats` の pin が green

- [ ] `skills/autopilot/SKILL.md` の satisfaction oracle 記述（現状 line 226 付近 `AND(redObserved, atGreen, coverageOk, overall_correctness, P0/P1==0)`）を、demonstrably-done が **単一の脆弱 signal（redObserved 等）に veto されて MAX 空転しない**よう、機構自己検証失敗を未完成と区別して扱う形に更新する。**C3 を遵守**し coverage-gate/atGreen の内部判定アルゴリズム・3ゲート構造・red-first 方針は変えない
- [ ] verify: oracle 記述で coverageOk/atGreen の内部判定ロジック・User gate 3ゲート・red-first 必須性が不変のまま、停止理由分類のみが追加されていることを diff レビューと BATS pin で確認

## Testing

- [ ] `tests/test_autopilot_convergence.bats` に F8/C2/F2 の lib 変更（record_red_evidence の impl SHA 記録、check_red_evidence の記録値ベース判定、record_halt の gate-unverifiable enum）の構造アサーションを追加する
- [ ] verify: `bats tests/test_autopilot_convergence.bats` が全 green

- [ ] `tests/test_reviewing_deliverables_skill.bats` に F3-F7（majority 採用・CONVERGED 停止条件・スコープガード・設計判断記憶・severity 単一化）の pin を追加する
- [ ] verify: `bats tests/test_reviewing_deliverables_skill.bats` が全 green

- [ ] `tests/test_autopilot_skill.bats` と `tests/test_running_atdd_cycle_skill.bats` に F1/F2 ループ層・F8 記録契約の pin を追加する
- [ ] verify: 両 BATS が全 green

- [ ] #341 / #345 再現シナリオ（C1）の検証: (a) demonstrably-done が単一脆弱 signal で MAX 空転しない、(b) 機構自己検証失敗が gate-unverifiable で早期 escalation、(c) review が有限ラウンド内で CONVERGED 到達 — を BATS／headless fixture で確認できる形に落とす
- [ ] verify: C1 の3条件が再現シナリオで満たされることをテストで確認（不可能な部分は SKILL pin ＋ lib unit で代替）

## Finishing

- [ ] バージョン bump（`.claude-plugin/plugin.json`、現 4.1.0）と `CHANGELOG.md` 追記。**skill rename は行わない**ため minor bump（新規ゲート／合議制追加 = 機能追加）で判定する。skill id は据え置き
- [ ] verify: `scripts/check-plugin-version.sh` 相当の整合チェック通過。plugin.json version と CHANGELOG 最上位リリース見出しが一致

- [ ] ディレクトリ README 整合: `lib/` を変更したため `lib/README.md`、skill を変更したため `skills/README.md`、テスト追加のため `tests/README.md` を同 PR で更新
- [ ] verify: 変更した top-level ディレクトリの README が変更内容と整合（DEVELOPMENT.md Directory READMEs ルール）

- [ ] ドキュメント整合性チェック（autopilot-iron-law.md 等、停止理由分類・合議制を参照する methodology ドキュメントの追従）
- [ ] verify: 関連ドキュメントが変更内容と整合し、C3 の Non-Goals 境界（red-first / coverage 内部判定 / 3ゲート不変）が文書上も保たれている
