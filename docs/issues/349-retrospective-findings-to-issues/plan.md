# Plan: merging-and-deploying — retrospective の actionable findings を Issue 化する手順を正典化する

<!-- 2-5 分粒度のタスク行と verification 行を交互に配置する（superpowers writing-plans 形式）。
     各タスクは単一の操作に限定し、verification で完了条件を即確認できる粒度にする。 -->

本 Issue は docs / skill-content 変更に限定される。対象は 2 ファイル:
`skills/merging-and-deploying/SKILL.md`（Flow Step 5 への 3 分類起票手順の追記）と
`templates/docs/issues/retrospective.md`（"Improvement Candidates" 節の文言更新）。
`scripts/retrospective.sh` 本体・出力フォーマットには一切触れない（#348 と責務分離、Non-Goal）。

## Implementation

- [ ] SKILL.md の Flow Step 5（Report + Retrospective）末尾に、retrospective.sh 実行後の「所見の 3 分類 → Issue 化」小節を追記する。壊れた/異常なメトリクス（例: Dialogue Volume=0、friction 分類の異常値）→ `type:bug` 起票、と記述する
- [ ] verify: `skills/merging-and-deploying/SKILL.md` に `type:bug` と「壊れた」または「異常」なメトリクスを起票対象とする記述が Step 5 セクション内に存在する

- [ ] 同小節に、friction point / improvement candidate（特定 skill の操作上の摩擦）→ skill-fix 起票（`atdd-kit:skill-fix` ルートを案内）と記述する
- [ ] verify: SKILL.md に `atdd-kit:skill-fix` ルート案内と friction point / improvement candidate → skill-fix 起票の記述が存在する

- [ ] 同小節に、非アクション（正常メトリクス・参考情報のみ）→ スキップ（起票不要）と記述し、判定基準（明示的な異常値・閾値超え・エラーメッセージを含まないものは非アクション、曖昧な場合は人間が最終確認）を明記する
- [ ] verify: SKILL.md に「非アクション」→ スキップの記述と、異常値/閾値/エラーメッセージを判定基準とする文言が存在する

- [ ] 同小節に、起票した Issue 番号をすべて retrospective サマリに追記し、terminal と Issue/PR コメントの両方へ同一内容を出力する（全チャネル同期）旨を記述する
- [ ] verify: SKILL.md に「起票した Issue 番号を retrospective サマリに追記」かつ「terminal と Issue/PR コメント両方（全チャネル同期）」の記述が存在する

- [ ] 同小節に、auto-routing は行わず actionable 判定は人間が最終確認する（誤検出抑制）旨を明記する
- [ ] verify: SKILL.md に auto-routing を行わない旨と人間が最終確認する旨の記述が存在する

- [ ] `templates/docs/issues/retrospective.md` の "Improvement Candidates" 節の消極的注記コメント（`No Auto-Routing: 候補を列挙するのみ。自動起票は行わない`）を、3 分類の要点（bug / skill-fix / skip）と「起票した番号を本サマリに追記する」旨、および詳細手順は SKILL.md を権威とする旨の積極的な文言へ置き換える
- [ ] verify: `templates/docs/issues/retrospective.md` の "Improvement Candidates" 節に 3 分類の要点・「番号を本サマリに追記」・SKILL.md 参照の記述が存在し、旧 `No Auto-Routing: 候補を列挙するのみ` 文言が残っていない

## Testing

- [ ] `tests/acceptance/AT-349.bats` を作成し、SKILL.md Step 5 の 3 分類・全チャネル同期・no-auto-routing の各記述、およびテンプレート文言更新を content-invariant として検証する（実装は Step 4 = running-atdd-cycle 所管）
- [ ] verify: `scripts/run-tests.sh --all` で AT-349 が green（Step 4 で実装後）

## Finishing

- [ ] CHANGELOG.md に本変更（retrospective findings → Issue 化手順の正典化）を追記する
- [ ] verify: `CHANGELOG.md` の最新 Unreleased/次リリース節に本 Issue の変更エントリが存在する

- [ ] ドキュメント整合性チェック（SKILL.md の手順とテンプレート文言が矛盾しないこと、#348 スクリプト修正と責務が重複していないこと）
- [ ] verify: SKILL.md の 3 分類とテンプレートの 3 分類要点が一致し、`scripts/retrospective.sh` に差分が入っていない（`git diff --name-only` に scripts/retrospective.sh が含まれない）
