# PRD: autopilot impl phase が並行セッションの未追跡ファイル混入で偽 MAX_ITERATIONS / スコープ汚染を起こす問題の解消

## Problem

**現状:** autopilot の impl phase は、作業ツリーに対してプロジェクトの AT ゲート（例: `uv run mypy src` をサブプロセス実行する品質ゲート meta テスト）を実行する。並行セッション（別 Issue）が作業ツリーに残した**未追跡・未コミットファイル**も、このサブプロセスゲートからは可視のため、それ由来の型エラー等でローカル AT ゲートが落ち続ける。

**それによって何が困るか（2026-06-15 別プロジェクト #66 で実発生）:**

1. **偽 MAX_ITERATIONS** — docs タスク #66（README 追記のみ）の impl phase が、別セッション #60 の未コミット `src/stockbot/web/` の mypy エラーでゲートが落ち、7 イテレーション連続 FAIL で `COMPLETED_WITH_DEBT (MAX_ITERATIONS)` halt。実際には AT 29/29 green・実装に欠陥なしだが収束が認識されなかった。
2. **スコープ汚染** — impl agent が foreign ファイル由来のゲート失敗を「当該 Issue の修正対象」と誤認し、無関係な `pyproject.toml` に `exclude = ["src/stockbot/web/"]` を追加するコミットを #66 のブランチに作成。foreign ファイルは未コミットのため CI（fresh checkout）には存在せず、exclude は本来不要な恒久技術債務だった。

並行セッション運用（複数 Issue 同時進行）では一般的に起こりうる構造的欠陥であり、`gen agent` の作業ツリー状態との相互作用に起因する点で #288 と同根。

## Why now

- autopilot は複数 Issue 同時進行（並行セッション）を前提に運用フェーズへ移行しており、本欠陥は「たまたま」ではなく**並行運用すれば再現する**。放置すると docs/軽微タスクの PR に他 Issue のゲート回避コミットが紛れ込み、レビューで気づかなければ恒久債務化する。
- #287〜#307 で autopilot harness の堅牢化（作業ツリー × gen agent 相互作用: #288 含む）を連続修正してきた流れの直接の続きであり、同根の最後の欠陥を閉じる好機。

## Outcome

完了時に以下が成立する:

- **スコープ汚染ゼロ:** impl phase は、当該 Issue のスコープ外の foreign 未追跡/未コミットファイルを変更・コミット・ゲート回避設定（exclude 等）の対象にしない。
- **偽 MAX_ITERATIONS の排除:** foreign ファイル由来のゲート失敗に対し、impl agent はそれを「直そう」と消耗せず、`COMPLETED_WITH_DEBT` として人間にエスカレーションする（真の収束失敗と区別される）。
- 既存の AL-1〜AL-6・#288 の orchestrator 所有物保護（audit log / pin への不可侵）と矛盾しない。
- 回帰 AT で foreign 未追跡ファイルが存在するシナリオを再現し、(a) スコープ外コミットが生成されない、(b) 適切に escalate される、ことを検証する。

## What

（スコープは Open Questions の意思決定により確定。推奨スコープ = 対処案1 + 対処案3）

- **対処案1（推奨・必須）— gen/impl prompt への明記:** autopilot Workflow の `GEN_GUARD`（および impl gen 指示）に、「自分が作成しておらず当該 Issue のスコープ外の未追跡/未コミットファイルは、変更・コミット・ゲート回避設定（exclude 等）の対象にしない。ゲートがそれら由来で失敗する場合は修正を試みず `COMPLETED_WITH_DEBT` として人間にエスカレーションする」を追加する。既存の #288 ガード（orchestrator 所有物・foreign work のロールバック禁止）と整合する形で拡張。
- **対処案3（推奨）— 混入検知 completeness critic:** impl phase の収束判定/ハンドオフ時に「当該 Issue のスコープ外パスへの変更（特に `pyproject.toml` / CI 設定 / 他 Issue のソース）」を検出し finding 化する critic を追加。混入が起きても green と誤認せず P0 finding として顕在化させる。
- 回帰 AT（`tests/acceptance/`）に foreign 未追跡ファイル混入シナリオを追加。

## Non-Goals

- **対処案2（ゲートをコミット済みツリーに対して実行 / foreign 未追跡パスの `git stash -u` 退避）は既定で Non-Goal**（Open Question で採否を確認）。理由: foreign 未追跡ファイルの stash 退避は #288 の `GEN_GUARD`（「自分が作成していない未コミット作業を stash / restore しない」）と actor は異なるが思想的に緊張し、並行セッションの作業ツリーを別アクターが触ることで新たな競合・データ損失リスクを生む。behavioral guard（対処案1）+ 検知（対処案3）でスコープ汚染と偽 halt の双方を塞げるため、より重く侵襲的な対処案2は第一段では見送る。
- 並行セッション間の作業ツリー分離そのもの（worktree 運用の強制等）— skill-gate / 運用ルールの領域であり本 Issue では扱わない。
- `gen agent` の作業ツリー巻き戻しによる audit log 破壊（#288）— 既に対処済み。本 Issue は同根だが foreign ファイル**混入**側を扱う。

## Open Questions

1. **【要人間判断】対処案2（ゲートをコミット済みツリーに実行 / foreign 未追跡パス退避）を本 Issue のスコープに含めるか?**
   - **A（推奨）:** Non-Goal とし、対処案1 + 対処案3 のみで対応。第一段は behavioral guard + 検知で確実にスコープ汚染と偽 halt を塞ぎ、より侵襲的な退避方式は実績を見て別 Issue で判断。
   - **B:** 対処案2 も含める（foreign 未追跡パス退避 or 変更ファイルにスコープした型チェック）。根本的にゲートを foreign ファイルから隔離できるが、並行セッションの作業ツリーを触る新リスクと #288 思想との緊張を伴う。
