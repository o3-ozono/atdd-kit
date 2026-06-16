# User Stories: autopilot impl phase が並行セッションの未追跡ファイル混入で偽 MAX_ITERATIONS / スコープ汚染を起こす問題の解消

## Functional Story

### US-1: foreign 未追跡ファイルを変更・回避対象にしない behavioral guard（対処案1・必須）

**I want to** autopilot の gen/impl 指示（`GEN_GUARD` および impl gen 指示）が「自分が作成しておらず当該 Issue のスコープ外の未追跡/未コミットファイルは変更・コミット・ゲート回避設定（exclude 等）の対象にしない」と明記している,
**so that** impl agent が並行セッション由来の foreign ファイルを「当該 Issue の修正対象」と誤認して無関係な `pyproject.toml` の exclude 等のスコープ汚染コミットを生成しなくなる.

### US-2: foreign ファイル由来のゲート失敗を escalate する（対処案1・必須）

**I want to** ゲートが foreign 未追跡/未コミットファイル由来で失敗するとき、impl agent がそれを修正しようと消耗せず `COMPLETED_WITH_DEBT` として人間にエスカレーションする,
**so that** スコープ外ファイルが原因のゲート失敗が真の収束失敗と区別され、偽 MAX_ITERATIONS（無駄なイテレーション消費）が起きなくなる.

### US-3: スコープ混入検知 completeness critic（対処案3・推奨）

**I want to** impl phase の収束判定/ハンドオフ時に「当該 Issue のスコープ外パスへの変更（特に `pyproject.toml` / CI 設定 / 他 Issue のソース）」を検出して P0 finding 化する critic が動作する,
**so that** 万一スコープ混入が起きても green と誤認されず、レビュー前に P0 finding として顕在化し恒久技術債務化を防げる.

### US-4: foreign ファイル混入ガードの回帰 AT（string-pin）

**I want to** foreign 未追跡ファイル混入に対する不変条件 ── (a) スコープ外コミット禁止＋ゲート回避設定禁止を指示する behavioral guard（`GEN_GUARD`）と (b) foreign 由来ゲート失敗の `COMPLETED_WITH_DEBT` エスカレーション指示、(c) スコープ外パス変更を P0 finding 化する混入検知 critic ── が SKILL.md に存在することを string-pin する回帰 AT が `tests/acceptance/` に存在する,
**so that** 本欠陥の修正（guard/critic の文言不変条件）が将来のリグレッションから守られ、並行セッション運用で再発しないことが自動で保証される.

> **Note（behavioral scenario reproduction は意図的にスコープ外）:** PRD Outcome bullet 4 は foreign 未追跡ファイル混入「シナリオを再現」する回帰 AT を要求するが、本 US-4 の回帰 AT は SKILL.md の guard/critic 文言を grep で string-pin する不変条件検証に narrowing している。理由: autopilot ループは subagent を spawn しなければ BATS 内で決定的に実走できず（runtime シナリオ再現が不可能）、既存の AT-296.bats も同一の grep ベース string-pin 規約（11 アサーション）を採用しているため。runtime/scenario 挙動（スコープ外コミットが実際に生成されないこと等）の検証は本 AT のスコープ外とし、guard/critic 文言の存在保証で代替する。

## Constraint Story (Non-Functional)

### CS-1: 既存の収束レール・orchestrator 所有物保護との非矛盾

**I want to** 本 Issue の追加（behavioral guard・混入検知 critic・回帰 AT）が、既存の AL-1〜AL-6 および #288 の orchestrator 所有物保護（audit log / pin への不可侵、自分が作成していない未コミット作業の stash/restore 禁止）と矛盾しない,
**so that** スコープ汚染と偽 halt を塞ぐ修正が、既存の作業ツリー × gen agent 相互作用ガードや audit-integrity レールを退行させない.
