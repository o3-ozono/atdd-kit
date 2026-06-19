# PRD: full-autopilot の使い勝手再設計（真因0-4 一括）

## Problem

full-autopilot の使い勝手が悪い。3エージェント調査（実装乖離 / 歴史痛み / 敵対的レビュー）でコード裏取りした結果、痛みは5つの真因に集約された。

- **真因0（最大レバー）**: queue に1件積むコストが高い。Issue テンプレート `templates/issue/{ja,en}/development.yml` が User Story・AC（3個以上）・サブタスク・完了条件まで人間に `required` で手書きさせる。DoR 相当を人間が書いている。
- **真因1**: queue が `lib/full-autopilot-run.sh:156` で起動時に1回だけ配列化され freeze。走行中に `ready-to-go` を付与しても現セッションで拾われない。
- **真因2**: 通知が既定 OFF。Discord addon と `FA_NOTIFY_CMD` 機構は実在するが既定 no-op で、「起動したら blind」が標準体験。
- **真因3**: 成否判定が浅い。既定 `FA_RESULT_CMD` は worker stdout の `is_error:false` 自己申告のみ。`merge-ready` ラベル未照合、`.rc` ファイルは書くが未読。偽陽性 merge リスク。
- **真因4**: routing 非強制。`docs/methodology/route-eligibility.md` に判定は文書化されているが skill-gate で強制されず、ユーザーがどのモードを使うべきか縛られない。
- **doc 整合バグ**: `skills/full-autopilot/SKILL.md:29` の「`ready-to-go` の前提 = PRD 承認済み」が正典 DoR（`docs/methodology/definition-of-ready.md`: ready-to-go = DoR ＋ plan review PASS）とズレている。

## Why now

#329 の調査で真因が確定し、敵対的レビューで優先度も付いた。真因0（人間/Claude 境界の再定義）は使い勝手への最大レバーで、放置するほど「使いにくい full-autopilot」のまま運用知見が積み上がる。今まとめて直すのが機会コスト最小。

## Outcome

- 人間が Issue 段階で固めるのは **意図3点（痛み / 望む結果 / スコープ境界）のみ**。AC・サブタスク・完了条件は Claude が生成し、人間は **AC セットをワンタップ承認するだけ**。
- full-autopilot を走らせながら `ready-to-go` Issue を追加投入でき、現行セッションが拾う（queue 動的化）。
- 起動時に通知先が確認され、無人運転中の進捗・エスカレーションが人に届く。
- `merge-ready` 判定が worker 自己申告だけに依存せず、外部（GitHub ラベル）で二重確認される。
- skill-gate が route-eligibility を必須チェックし、不適合モードを抑止（override 可）。
- full-autopilot SKILL.md の `ready-to-go` 前提記述が正典 DoR と整合。

## What

1. **真因0**: `templates/issue/{ja,en}/development.yml` を意図シードに軽量化。Problem/Outcome/スコープを required に、AC・サブタスク・完了条件・User Story を任意化。`.github/ISSUE_TEMPLATE/` への always-sync 経路（session-start E2）を壊さない。**AC 承認ゲート（Gate ①）は維持**（authoring は Claude、approval は人間）。
2. **真因1**: `lib/full-autopilot-run.sh` の queue 取得を、空きスロット充填時に `ready-to-go` を再評価する動的 enqueue に変更。
3. **真因2**: full-autopilot 起動時に通知先（webhook 等）を確認し session に inject、または軽量通知を既定有効化。
4. **真因3**: 既定 `FA_RESULT_CMD` に `merge-ready` ラベル照合を追加し、ラベル不在なら fail に倒す。
5. **真因4**: skill-gate に route-eligibility 必須チェックを追加（override 可）。
6. **doc 整合**: `skills/full-autopilot/SKILL.md:29` の `ready-to-go` 前提記述を正典 DoR に合わせて修正。
7. 各変更に bats 受け入れテストを追加（AL-3 deterministic AT gate を満たす）。

## Non-Goals

- **個別 Issue へのスピンオフはしない**（ユーザー指示: 全部 #329 で一括 / 1 PR）。
- **autopilot 本体（収束レール `lib/autopilot_convergence.sh`）の再設計はしない**（#329 真因 H5「成熟度ギャップ」は過大評価と判定済み）。
- **AC 承認ゲートそのものの撤廃はしない**（false-green の外部アンカーを保つ / autopilot Iron Law Gate ①）。
- queue を GitHub webhook 化する大改修は対象外（真因1は polling 再評価で足りる。webhook 化は将来）。

## Open Questions

- 真因2 の既定 ON 化の踏み込み度（opt-in 維持 vs 起動時必須確認）。→ plan で詰める。デフォルトは「起動時に通知先を一度確認」を採用。
- 真因1 の再評価頻度（毎スロット充填時 vs 一定間隔）。→ plan で詰める。
- 6項目を1 PR に収める際のコミット分割方針。→ plan で項目ごとにコミット。
