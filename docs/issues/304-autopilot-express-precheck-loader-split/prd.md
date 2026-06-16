# PRD: autopilot SKILL.md ローダ分割 ＋ express 適格プリチェック

## Problem

`skills/autopilot/SKILL.md` は **280/280 行**に達しており、DEVELOPMENT.md「SKILL.md Line-Budget Raises」規定により**行バジェット引き上げは累計 2 回まで**（240→260→280 を消化済み）で 3 回目は不可。

その結果、#302（autopilot/express 経路判定）の壁打ちで Q1(b) として挙がった「**autopilot 冒頭の express 適格プリチェック**」を追記しようとすると行バジェットを超過し、機能追加そのものがブロックされている。

加えて、経路判定ヒューリスティック（express 適格信号 / autopilot 信号 / 曖昧時フォールバック）は現状 `skills/session-start/SKILL.md` 内に**散文として 1 箇所だけ**存在し、autopilot 側から再利用できる共有資産になっていない。プリチェックを autopilot に inline 複製すると二重管理になり、行バジェット問題をさらに悪化させる。

## Why now

- #302 が経路判定ルーティングを確立し（#303 merge 済み）、session-start 側の推奨経路ロジックは稼働している。プリチェックは「直接 `/autopilot` 起動」という session-start を経由しない入口を塞ぐ補完であり、ペアで揃って初めて経路判定の不変条件（auto-route しない・ユーザーが最終選択）が全入口で一貫する。
- #302 が行バジェット制約のため本機能を descope し本 Issue へ委譲した、その解消待ちの状態。
- DEVELOPMENT.md #283 が「3 回目の拡張が必要になったらローダ stub + `docs/methodology/` 分割」を正規ルートと定めており、autopilot SKILL.md は今まさにその条件に該当する最初のケース。

## Outcome

1. `skills/autopilot/SKILL.md` がローダ stub（frontmatter + 要点 + docs ポインタ）に分割され、詳細（Workflow スクリプト本体・Iron Law 参照・Dialog economy 等）が `docs/methodology/autopilot-*.md` に移設される。分割後も autopilot の **BATS 構造 pin・行バジェット pin が追従して全 green**（pin が指す挙動規定が分割で漏れない＝意味を保ったまま参照先が新構成に追従する）。
2. 直接 `/atdd-kit:autopilot <issue>` 起動時、対象 Issue が express 適格（doc-grade）と判定されたら**一度だけ**「express の方が低コスト。autopilot で続行しますか？」を提示し、**明示続行が無ければ進めない**（auto-route しない、#302 Q3 と整合）。適格でなければ従来どおり無言で autopilot を続行する。
3. この express プリチェックは **Gate ①（requirements approval）の手前の pre-flight advisory** であり、**User gate を 4 つに増やさない**（AL-1: exactly three を堅持）。
4. express 適格判定ロジックは `docs/methodology/route-eligibility.md`（新規・共有 doc）に切り出され、`session-start` と autopilot プリチェックの双方がそれを参照する（判断基準の二重管理を排除）。

## What

1. **共有判定基準の抽出**: 現状 `session-start/SKILL.md` 散文の express 適格信号 / autopilot 信号 / 曖昧時フォールバック / 不変条件（推奨のみ・auto-route しない）を `docs/methodology/route-eligibility.md` に切り出し、session-start をその参照に置き換える。
2. **autopilot SKILL.md のローダ分割**: stub（frontmatter + 要点 + `docs/methodology/` ポインタ）+ 詳細 doc。BATS の構造 pin・行バジェット pin を分割後の構成（stub と移設先 doc の双方）へ追従させる。
3. **express 適格プリチェック**: 直接 `/atdd-kit:autopilot <issue>` 起動時、`route-eligibility.md` の基準で対象 Issue を判定し、express 適格なら一度だけ続行確認を提示。明示続行が無ければ進めない（auto-route 禁止）。Gate ① の手前に位置する pre-flight advisory として実装。

## Non-Goals

- **全 Skill の SKILL.md ローダ stub 分割（#314）**: 本 Issue は autopilot SKILL.md のみを対象とする。全 Skill への一般化・恒久対策は research Issue #314 が扱う。本 Issue の分割がパターンの先行事例になり得るが、横展開は #314 のスコープ。
- **session-start 側の経路判定アルゴリズム自体の変更**: 判定基準は #302/#303 で確立済みのものをそのまま共有 doc 化するだけで、新しい信号や閾値の追加・変更はしない。
- **express スキル本体の挙動変更**: プリチェックは「express 適格かどうかの提示」までで、express への自動切替（auto-route）はしない。

## Open Questions

- none remain（壁打ちで判断① = 共有 doc 抽出方式、判断② = Outcome 合否基準を確定済み）。
