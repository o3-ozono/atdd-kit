# Design Doc: autopilot SKILL.md ローダ分割の境界と BATS pin 追従方式

## Context

`skills/autopilot/SKILL.md` は 280/280 行で、DEVELOPMENT.md「SKILL.md Line-Budget Raises」により行バジェット引き上げは累計 2 回まで（240→260→280 消化済み）。第 3 回拡張の正規ルートは「ローダ stub + `docs/methodology/` 詳細への分割」（#283）。本 Issue はその初適用ケースであり、加えて express 適格プリチェックの追記分の行 headroom も確保する必要がある。

制約の核心: `tests/test_autopilot_skill.bats` は **208 件の grep を `SKILL_FILE`（= skills/autopilot/SKILL.md）本体に対して直接実行**している（canonical Workflow script の各行・args 防御パース・freeze/audit 配管・行順序 pin・User gates 番号リスト・Dialog economy セクションの sed 範囲抽出など）。86 テストが現状 green。素朴に内容を doc へ移すと、これらの pin が一斉に Red になる。

## Decision

**「pin される実体は SKILL.md 本体に据え置き、grep 非依存の説明的散文だけを doc へ移設する」非対称分割を採用する。**

SKILL.md の構成を次の 2 層に分ける:

1. **本体に据え置く（移設禁止）** — BATS が grep / sed で参照する pin 対象:
   - canonical Workflow script（`STEPS`, `AT_STEP`, `freeze:anchor`, `let uncovered`, `JSON.stringify({ atGreen` 等の行と行順序）
   - args 防御パース・phase fail-closed ガード（`Array.isArray(A.rejectionFindings)`, `Array.isArray(A.implSeedFindings)`, integer guard）
   - 監査ログ fail-closed 配管（freeze/audit, logLines baseline）
   - User gates 番号リスト（`## User gates` 〜 `## Dialog economy` の番号付き 3 項目）
   - Dialog economy セクション（`## Dialog economy` 〜 `## Output` の sed 抽出範囲・diff-in-body 文字列）
   - `MODEL` 定数・impl→sonnet 割当（#311 pin）
2. **doc へ移設する（grep 非依存の散文のみ）**:
   - Iron Law の背景説明的散文（pin は既に `docs/methodology/autopilot-iron-law.md` を参照しており、SKILL.md 側の重複解説を移設）
   - 運用ノート・補足説明のうち BATS が文字列照合していない段落
   - 移設後の本体には docs ポインタ（要点 1-2 行 + 参照リンク）を残す

行数削減は「pin されない散文の圧縮・移設」と「Tightening Guidelines（DEVELOPMENT.md）の適用」で達成する。それでも express プリチェック追記分が 280 を超える場合は、**プリチェックの詳細手順を移設先 doc に置き、SKILL.md には pin 対象の最小記述（route-eligibility.md 参照・auto-route 禁止明記・Gate ① 手前という位置）だけを残す**。

BATS pin の扱い:
- 本体据え置き対象 → テスト変更不要（pin はそのまま green）。
- やむを得ず doc へ移る pin → **テストの参照先を新 doc ファイルへ更新**（grep のターゲットを `SKILL_FILE` から移設先 doc パスへ変更）。これは「意味を保ったまま参照先が新構成へ追従」（CS-2）の正規操作であり、pin の削除や緩和ではない。
- **行バジェット pin の数値（≤280）は引き上げない**（第 3 回引き上げ禁止）。分割で本体行数が減るので、むしろ headroom が生まれる。

### FS-1 が触る session-start 側 #302 pin の影響（autopilot 側とは別系統）

ローダ分割（FS-2/CS-2）は autopilot 側の pin を論じるが、**FS-1 の route-eligibility.md 抽出は session-start 側の #302 pin に独立して影響する**。`tests/test_session_start_task_recommendation.bats`（単一の `test_session_start_skill.bats` は実在せず、session-start テストは 6 ファイルに分割済み）の以下 5 件は、信号文字列を `SKILL_EN=skills/session-start/SKILL.md` の Step 3 セクションから sed 抽出して grep している:

| pin（test 名） | grep 対象信号 |
|----------------|---------------|
| `#302-AC2: Step 3 has express-eligible signals` | docs / README / typo / gitignore / version.bump |
| `#302-AC2: Step 3 has autopilot signals` | CI / hooks / depend / security / 新機能 / 挙動変更 等 |
| `#302-AC2: Step 3 specifies hybrid determination (label + keyword + LLM)` | label / keyword(キーワード) / LLM |
| `#302-AC3: Step 3 documents fallback to autopilot when ambiguous` | doubt / ambiguous / 曖昧 / 不明 |
| `#302-AC4: Step 3 states recommendation only -- no auto-routing` | 推奨のみ / recommendation only / auto.route |

信号本文を route-eligibility.md へ移すと、これら 5 pin は session-start 本体に信号が残らなくなり一斉に RED になる。**autopilot 側の SKILL_FILE pin と同じ CS-2 正規操作で、これら 5 pin の grep ターゲットを `route-eligibility.md` へ振り替える**（pin の削除・緩和ではなく参照先更新）。一方 `#302-AC1`（推奨経路列の 4 列ヘッダ）と `#302-AC2: Task Recommendation Rules has Step 3`（Step 3 見出しの存在）は session-start 本体に残る構造を pin しているため**不変**（信号本文ではなく表ヘッダ・見出しを照合しているため、route-eligibility.md 抽出後も session-start 本体に残る）。

## Alternatives Considered

| 案 | 内容 | 不採用理由 |
|----|------|-----------|
| A. 全面移設 + テスト一括書き換え | canonical script を含む大半を doc へ移し、208 grep のターゲットを doc へ振り替える | pin の集団移設はレビュー困難でリグレッション risk 大。canonical Workflow script は autopilot の挙動の中核で、SKILL.md から消すとスキルとしての可読性・自己完結性が損なわれる |
| B. 行バジェット pin を 300 へ引き上げ | テストの 280 を 300 にして分割せず追記 | DEVELOPMENT.md が明示的に第 3 回引き上げを禁止。Issue 自体がこのルート（分割）を選ぶために起票されたもの。却下 |
| C. プリチェックを別 skill に切り出す | express プリチェックを autopilot 外の独立 skill にする | session-start を経由しない「直接 /autopilot 起動」の入口を塞ぐのが目的であり、autopilot の Flow に組み込まれている必要がある。skill 分離は入口問題を解決しない |
| **D. 非対称分割（採用）** | pin 実体は本体据え置き、説明散文のみ doc へ。残る pin 移設は参照先更新で追従 | pin 破壊を最小化しつつ行 headroom を確保。#283 の正規ルートに沿い、canonical script の自己完結性も保つ |

## Trade-offs / Risks

- **risk**: 「散文か pin 対象か」の境界判断ミスで pin を巻き込み移設 → Red。**緩和**: 上記「本体据え置きリスト」を分割作業の唯一の真実とし、移設前に各段落を grep 文字列と突き合わせる。分割後は必ず `bats tests/test_autopilot_skill.bats` を実行して 0 失敗を確認（AT-202）。
- **trade-off**: 本体据え置きにより SKILL.md は完全な stub にはならず「stub + canonical script」のハイブリッドになる。これは canonical script が挙動の中核で pin 対象である以上、避けられない。#283 の「ローダ stub」は厳密な空 stub を要求しておらず、行 headroom 確保という目的は満たす。
- **将来**: 全 skill への一般化・恒久対策は #314（Non-Goal）。本 Issue の非対称分割はその先行事例になり得るが横展開はしない。

## Out of Scope

- session-start 側の経路判定アルゴリズム自体の変更（信号・閾値の追加変更なし。doc 化のみ）。
- express skill 本体の挙動変更（auto-route しない）。
- 全 skill の SKILL.md 一般化分割（#314）。
