# User Stories: merging-and-deploying — retrospective の actionable findings を Issue 化する手順を正典化する

## Functional Story

**I want to** `skills/merging-and-deploying/SKILL.md` の Flow Step 5（Report + Retrospective）を読んだだけで、retrospective.sh 出力の各所見を「壊れた/異常なメトリクス → `type:bug` 起票」「friction point / improvement candidate → skill-fix 起票（`atdd-kit:skill-fix` ルート案内）」「非アクション → スキップ」の 3 分類で迷わず判定できる,
**so that** surface された所見が「manually に検討」止まりで放置されず、追加の判断なしに Issue 化まで進められる.

**I want to** actionable な所見から起票した Issue 番号を retrospective サマリに追記し、terminal と Issue/PR コメントの両方へ同じ内容で出力する（全チャネル同期）,
**so that** どの所見がどの Issue につながったかがどこから見ても追跡でき、取りこぼしが可視化される.

**I want to** `templates/docs/issues/retrospective.md` の "Improvement Candidates" 節の消極的注記（`No Auto-Routing: 候補を列挙するのみ。自動起票は行わない`）を、3 分類の基準要点と「起票した番号を本サマリに追記する」旨を促す積極的な文言へ置き換え、詳細手順は SKILL.md を権威とする,
**so that** テンプレートを使う実行者が SKILL.md の手順と矛盾しない形で起票を促され、所見が実際の改善につながる.

## Constraint Story (Non-Functional)

**I want to** retrospective 所見の Issue 化が auto-routing されず、actionable 判定の最終確認を必ず人間が担う設計として明文化されている,
**so that** 誤検出（false positive）による無用な起票を抑制し、人間判断の保持という運用方針が維持される.

**I want to** 本手順が `scripts/retrospective.sh` 本体・その出力フォーマットに一切変更を加えず、現行フォーマットを前提とした「出力の活用手順」に限定されている,
**so that** #348 で対応済みのスクリプト修正と責務が重複せず、フォーマット依存の破壊なく手順だけを追加できる.
