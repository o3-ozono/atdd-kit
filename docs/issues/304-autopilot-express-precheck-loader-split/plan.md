# Plan: autopilot SKILL.md ローダ分割 ＋ express 適格プリチェック

<!-- 2-5 分粒度のタスク行と verification 行を交互に配置する（superpowers writing-plans 形式）。
     各タスクは単一の操作に限定し、verification で完了条件を即確認できる粒度にする。 -->

設計判断（ローダ分割の境界・BATS pin の追従方式）は `design-doc.md` を参照。
要点: SKILL.md 内の **BATS が grep で直接参照する文字列（canonical Workflow script・args ガード・freeze/audit 配管・行順序 pin 等）は SKILL.md 本体に据え置く**。docs へ移設するのは grep 非依存の説明的散文（Iron Law 詳細・運用ノート）に限定し、SKILL.md は「stub + canonical script」構成にする。**Dialog economy セクションは BATS が grep/sed pin しているため移設せず本体に据え置く**（design-doc.md「本体据え置きリスト」）。これにより 208 件の `SKILL_FILE` grep pin を壊さずに行数を 280 以下へ削減できる。

## Implementation

### FS-1: 共有判定基準の抽出（route-eligibility.md）

- [ ] `skills/session-start/SKILL.md` の経路判定散文（express 適格信号 / autopilot 信号 / 曖昧時フォールバック / 不変条件、L223-245 周辺）を読み、移設対象範囲を確定する
- [ ] verify: 移設対象の行範囲（Step 3 Route recommendation ブロック）が特定でき、`autopilot`/`express`/曖昧時フォールバック/不変条件の 4 要素が含まれることを目視確認

- [ ] `docs/methodology/route-eligibility.md` を新規作成し、express 適格信号 / autopilot 信号 / 曖昧時フォールバック（when in doubt → autopilot）/ 不変条件（推奨のみ・auto-route しない・ユーザーが最終選択）を見出し付きで転記する
- [ ] verify: `docs/methodology/route-eligibility.md` が存在し、4 要素すべてが見出しまたは箇条書きで含まれる（`grep -c` で確認）

- [ ] `skills/session-start/SKILL.md` の Step 3 散文本体を `docs/methodology/route-eligibility.md` への参照（1-2 行ポインタ）へ置き換える。判定結果を表に記入する手順自体は残す
- [ ] verify: session-start の判定アルゴリズム記述が doc 参照に置換され、判定信号の二重定義が消えている（session-start に信号の重複本文が残らない）

- [ ] **#302 既存 pin の参照先追従（CS-2 の正規操作）**: `tests/test_session_start_task_recommendation.bats` L72-100 の #302-AC2/AC3/AC4 5 件（`#302-AC2: Step 3 has express-eligible signals` / `has autopilot signals` / `specifies hybrid determination (label + keyword + LLM)` / `#302-AC3: ... fallback to autopilot when ambiguous` / `#302-AC4: ... recommendation only -- no auto-routing`）は、信号文字列（docs/README/typo・CI/hooks/depend/security・label/keyword/LLM・doubt/曖昧・推奨のみ）を `SKILL_EN=skills/session-start/SKILL.md` の Step 3 セクションから sed 抽出して grep している。信号を route-eligibility.md へ移すとこれらが一斉に RED になるため、**これら 5 pin の grep ターゲットを `route-eligibility.md` へ振り替える**（pin の削除・緩和ではなく参照先更新）。なお `#302-AC1`（推奨経路列ヘッダ）・`#302-AC2: ... has Step 3`（Step 3 見出しの存在）は session-start 本体に残る構造なので不変。
- [ ] verify: `bats tests/test_session_start_task_recommendation.bats` が全 green（信号 grep が route-eligibility.md を指し、session-start には信号本文が残っていない状態でも green）

### FS-2: autopilot SKILL.md のローダ分割

- [ ] 移設先 doc（`docs/methodology/autopilot-overview.md` 新規、または既存 `autopilot-iron-law.md` への追記）を用意し、SKILL.md から移設する grep 非依存の説明的散文（Iron Law の背景説明・運用ノート）を移す。design-doc.md「doc へ移設リスト」に明記された **Responsibility Boundary テーブル（ロール所有者表と説明段落）** も移設対象に含まれる（BATS pin 非依存の散文であることを事前確認）。BATS が grep する文字列は移設しない。**Dialog economy セクション（`## Dialog economy` 〜 `## Output` の範囲）は移設禁止**: `tests/test_autopilot_skill.bats` L308-394 がヘッダ・`Dialog economy` 出現回数・US-1/US-2/US-3 の diff-in-body 文字列を grep/sed pin しているため、design-doc.md「本体据え置きリスト」のとおり本体に据え置く
- [ ] verify: 移設先 doc が存在し、移設した散文が読める。移設対象に BATS pin 文字列（design-doc.md「pin 据え置きリスト」記載）が含まれていない。Responsibility Boundary テーブルも移設先 doc に含まれる

- [ ] `skills/autopilot/SKILL.md` から移設済み散文を削除し、`docs/methodology/` への docs ポインタ（要点 + 参照リンク）へ置き換える。canonical Workflow script・args ガード・freeze/audit 配管・User gates 番号リスト・Dialog economy の pin 対象行は本体に据え置く
- [ ] verify: `wc -l skills/autopilot/SKILL.md` が **280 以下**（理想は headroom を確保し 280 未満）

- [ ] SKILL.md の docs ポインタが移設先 doc を正しく指す（リンク切れなし）ことを確認する
- [ ] verify: SKILL.md 中の `docs/methodology/*.md` 参照がすべて実在ファイルを指す（`ls` で照合）

## Testing

### CS-2: 分割後も BATS 構造 pin・行バジェット pin が全 green

- [ ] `bats tests/test_autopilot_skill.bats` を実行し、分割で落ちた pin を洗い出す
- [ ] verify: 失敗テスト一覧が得られる（理想は 0 失敗）

- [ ] 落ちた pin について、対象文字列が SKILL.md に残るべきもの（=本体に戻す）か doc へ追従させるべきもの（=テストの参照先を doc へ更新）かを design-doc.md の方針に従って分類し、修正する。行バジェット pin の上限（≤280）は引き上げない
- [ ] verify: 分類が design-doc の方針と一致し、行バジェット pin の数値（280）は不変

- [ ] `bats tests/test_autopilot_skill.bats` と `bats tests/test_session_start_task_recommendation.bats`（FS-1 が触る Step 3 経路判定 pin の所在ファイル。session-start テストは 6 ファイルに分割済みで単一 `test_session_start_skill.bats` は実在しない）を再実行し全 green を確認する
- [ ] verify: 両 BATS スイートが全 green（autopilot 86 件 + session-start task-recommendation、0 失敗）

### FS-3 / CS-1 / CS-3: express プリチェックの構造 pin

- [ ] autopilot の express プリチェック挙動（pre-flight advisory・一度だけ提示・明示続行が無ければ進めない・auto-route 禁止・Gate ① の手前）を pin する BATS テストを追加する
- [ ] verify: 追加テストが Red（未実装段階）→ 実装後 Green に遷移できる（AT-301〜AT-306 に対応）

## Implementation: express プリチェック本体（FS-3 / CS-1 / CS-3）

- [ ] `skills/autopilot/SKILL.md`（stub）または移設先 doc に、Gate ① の手前で `route-eligibility.md` 基準により対象 Issue を判定する pre-flight advisory ステップを追記する。express 適格時のみ「express の方が低コスト。autopilot で続行しますか？」を一度だけ提示し、明示続行が無ければ進めない。非適格時は無言で続行
- [ ] verify: プリチェックステップが Gate ①（requirements approval）より前に位置し、`route-eligibility.md` を参照していることを目視確認

- [ ] auto-route を一切行わない（提示までに留める）ことを明記する。User gate を 4 つに増やさない（pre-flight advisory は gate ではない）
- [ ] verify: SKILL.md に auto-route 禁止の明記があり、User gates 番号リストが 3 件のまま（既存の gate count pin が green）

## Finishing

- [ ] `docs/methodology/README.md`（および必要なら `skills/README.md`）を新規 doc（route-eligibility.md・移設先 autopilot doc）追加に追従させる
- [ ] verify: 該当 README に新規 doc 行が追加されている

- [ ] `.claude-plugin/plugin.json` の version を minor bump（新規 gate 追加 = minor）し、`CHANGELOG.md` に Keep a Changelog 形式でエントリを追加する
- [ ] verify: plugin.json version == CHANGELOG 最上位リリース見出し（`scripts/check-plugin-version.sh` 整合）

- [ ] ドキュメント整合性チェック
- [ ] verify: 関連ドキュメント（DEVELOPMENT.md #283 の分割ルートに沿った構成・session-start / autopilot の相互参照）が変更内容と整合している
