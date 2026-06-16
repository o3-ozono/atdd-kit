# User Stories: autopilot: 直接 /autopilot 起動時の express 適格プリチェック（+ SKILL.md ローダ分割）

## Functional Story

<!-- PRD ## What 由来。1 ストーリー = 1 ユーザーゴール。 -->

### FS-1: 共有判定基準の抽出（route-eligibility.md）

**I want to** express 適格信号 / autopilot 信号 / 曖昧時フォールバック / 不変条件（推奨のみ・auto-route しない）を `docs/methodology/route-eligibility.md` に切り出し、`session-start/SKILL.md` をその参照に置き換える,
**so that** 経路判定基準を session-start と autopilot プリチェックの双方が単一ソースとして共有し、判断基準の二重管理を排除できる.

### FS-2: autopilot SKILL.md のローダ分割

**I want to** `skills/autopilot/SKILL.md` をローダ stub（frontmatter + 要点 + `docs/methodology/` ポインタ）に分割し、詳細（Workflow スクリプト本体・Iron Law 参照・Dialog economy 等）を `docs/methodology/autopilot-*.md` へ移設する,
**so that** 行バジェット第 3 回引き上げ不可の制約（240→260→280 消化済み）を DEVELOPMENT.md #283 の正規ルートで解消し、冒頭プリチェックの追記をブロックから解放できる.

### FS-3: express 適格プリチェック（pre-flight advisory）

**I want to** 直接 `/atdd-kit:autopilot <issue>` 起動時に `route-eligibility.md` の基準で対象 Issue を判定し、express 適格（doc-grade）なら一度だけ「express の方が低コスト。autopilot で続行しますか？」を提示し、明示続行が無ければ進めない（適格でなければ無言で従来どおり続行する）,
**so that** session-start を経由しない直接起動の入口でも経路判定の不変条件（auto-route しない・ユーザーが最終選択）が一貫し、doc-grade Issue を高コストな autopilot で走らせる無駄を防げる.

## Constraint Story (Non-Functional)

<!-- PRD ## Outcome 由来の不変条件。NFR を制約として記述する（Pichler 2013）。 -->

### CS-1: User gate を 3 つに据え置く（AL-1 堅持）

**I want to** express プリチェックが Gate ①（requirements approval）の手前の pre-flight advisory として位置づけられ、User gate を 4 つに増やさない,
**so that** autopilot の「exactly three gates」不変条件（AL-1）が維持され、ユーザーの承認負荷が増えない.

### CS-2: 分割後も BATS 構造 pin・行バジェット pin が全 green

**I want to** ローダ分割後も autopilot の BATS 構造 pin・行バジェット pin が新構成（stub と移設先 doc の双方）へ追従して全 green である,
**so that** pin が指す挙動規定が分割で漏れず、意味を保ったまま参照先が新構成へ追従したことを検証できる.

### CS-3: auto-route 禁止（推奨のみ）

**I want to** プリチェックが express 適格の提示までに留まり、express への自動切替（auto-route）を一切行わない,
**so that** #302 Q3 と整合し、ユーザーが経路の最終選択権を保持できる.
