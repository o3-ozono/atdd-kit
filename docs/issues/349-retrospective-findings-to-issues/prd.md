# PRD: merging-and-deploying — retrospective の actionable findings を Issue 化する手順を正典化する

## Problem

`merging-and-deploying`（Step 6）は post-deploy 後に `scripts/retrospective.sh` を実行するが、その出力に含まれる actionable な所見（壊れたメトリクス・friction point・improvement candidate）の扱いが「manually に検討」止まりで運用が未定義のまま放置されている。

1. **取りこぼしリスク**: `templates/docs/issues/retrospective.md` の "Improvement Candidates" 節は `No Auto-Routing: 候補を列挙するのみ。自動起票は行わない` と述べるが、「では誰がいつ何を起票するか」を規定する手順が存在しない。
2. **実害の実証**: #323 の retrospective は Dialogue Volume 恒久ゼロ化（→ #348）を surface したが、手順がないため自動でも手動でも何も起票されなかった。バグが surface されてから Issue 化まで追加の手作業と判断が必要となり、所見が実際の改善につながる保証がない。

## Why now

#348（retrospective.sh メトリクス修正）が「所見の surface」を正確にする一方で、surface された所見を改善に変える経路が依然として空白のままである。#348 単独では「正確に表示されるが活かされない」状態が継続するため、両輪を揃える必要がある。また autopilot 運用でマージ頻度が上昇しており、retrospective の実行回数に比例して取りこぼしリスクが累積する。

## Outcome

- `skills/merging-and-deploying/SKILL.md` の Flow Step 5（Report + Retrospective）を読んだ実行者が、retrospective.sh 出力のどの所見を Issue 化し、どの所見をスキップするかを迷わず判断できる
- actionable 所見が出た場合、retrospective サマリ（terminal + Issue/PR コメント）に起票した Issue 番号が記載されており、追跡可能な状態になっている
- `templates/docs/issues/retrospective.md` の "Improvement Candidates" 節の文言が、上記手順と矛盾しない形に更新されている
- 誤検出抑制のため auto-routing は行われず、人間が actionable 判定の最終確認を担う設計が明文化されている

## What

### 1. `skills/merging-and-deploying/SKILL.md` — Flow Step 5 への手順追加

retrospective.sh 実行後に以下の手順を実施することを明記する:

- **壊れた/異常なメトリクス**（例: Dialogue Volume=0、friction 分類の異常値）→ `type:bug` Issue を起票する
- **friction point / improvement candidate**（特定 skill の操作上の摩擦）→ skill-fix Issue を起票する（`atdd-kit:skill-fix` ルートを案内）
- **非アクション**（正常メトリクス・参考情報のみ）→ スキップ（起票不要）
- 起票した Issue 番号をすべて retrospective サマリに追記し、terminal と Issue/PR コメントの両方に出力する（全チャネル同期）
- auto-routing は行わず、actionable 判定は人間が最終確認する（誤検出抑制）

### 2. `templates/docs/issues/retrospective.md` — "Improvement Candidates" 節の文言更新

現行の `No Auto-Routing: 候補を列挙するのみ。自動起票は行わない` という消極的注記を、上記の分類・起票手順を促す積極的な文言（「以下の基準で Issue 化し、番号を本サマリに追記する」旨）に置き換える。

## Non-Goals

- **`scripts/retrospective.sh` 自体のメトリクス・バグ修正** — #348 で対応済み・または対応中。本 Issue は「出力の活用手順」に限定し、スクリプト本体には触れない
- **起票 Issue の自動化（auto-routing）** — 誤検出抑制・人間判断の保持を優先し、自動起票は行わない。将来の自動化検討は別 Issue とする
- **retrospective.sh の出力フォーマット変更** — 現行フォーマットを前提として手順を記述する。フォーマット変更を伴う改善は別途 Issue 化する

## Open Questions

1. **"Improvement Candidates" 節のテンプレート文言の粒度** — 手順全文を埋め込むか、SKILL.md への参照リンクに留めるか。
   → **Resolved（Gate ① 承認, 2026-07-01）**: テンプレートには分類基準の要点（3 分類 + 「番号をサマリに追記」）を簡潔に記載し、詳細手順は SKILL.md を権威とする。
2. **起票不要な "非アクション" の判定基準** — 「正常メトリクス」「参考情報のみ」の線引きをどこに置くか。
   → **Resolved（Gate ① 承認, 2026-07-01）**: 明示的な異常値・閾値超え・エラーメッセージを含まないものは非アクションとする。曖昧な場合は人間が最終確認の際に判断する（auto-routing なしの設計で吸収）。
