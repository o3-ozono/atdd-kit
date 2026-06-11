# User Stories: workflow-detail.md のレビュー記述を #234 の動的・並列 Workflow パネルへ整合

## Functional Story

### US-1: Execution Mode 節のレビュー記述が現行アーキテクチャを伝える

**I want to** `docs/workflow/workflow-detail.md` Execution Mode 節（line 46）の「specialist reviewer subagents を **serially** spawn → final aggregator が単一 PASS/FAIL を返す」という記述が、#234 実装（Scout → 動的レンズパネル生成 → 並列レビュー → adversarial 検証 → Aggregate が単一 PASS/FAIL + 観点別ノートを返す）と整合する記述に置換されている,
**so that** session-start が本ドキュメントをロードしたセッションが、Step 5（`reviewing-deliverables`）を「固定 reviewer を直列 spawn する」誤った実行像ではなく現行アーキテクチャどおりに理解する.

### US-2: Reviewer Aggregation Flow 節の mermaid 図が現行フェーズ構成を描く

**I want to** Reviewer Aggregation Flow 節（lines 97–120）の固定 5 reviewer（prd/us/plan/code/at）→ `final-reviewer: aggregate 47 criteria` という mermaid 図と導入文が、現行の Workflow フェーズ構成（Scout / Generate / Review / Verify / Aggregate）を描く図に置換されている,
**so that** 図を参照した読者が旧機構（固定 roster・47 基準集約）を実行像として再生産せず、line 46 のみの修正で生じるドキュメント内矛盾も残らない.

### US-3: Execution Mode 節にその他のレガシー記述が残っていない

**I want to** Execution Mode 節を通読した結果として、旧レビュー機構（固定 roster / serial spawn / 47 基準）を前提とするその他の記述が確認・修正され、同ドキュメント内に残っていない,
**so that** `workflow-detail.md` のどこを読んでも `skills/reviewing-deliverables/SKILL.md`（#234 実装）と矛盾せず、レガシー記述によるセッション挙動の揺れが再生産されない.

## Constraint Story (Non-Functional)

### CS-1: リリース規律（CHANGELOG + patch bump）を伴って出荷される

**I want to** ドキュメントのみの変更であっても、CHANGELOG.md の更新と `.claude-plugin/plugin.json` の patch version bump（DEVELOPMENT.md Versioning 準拠）を伴って出荷されている,
**so that** プラグイン利用側が変更内容をリリース履歴から追跡でき、バージョンと配布内容の対応が崩れない.

### CS-2: 変更はドキュメント側に限定され、実装と Non-Goals に波及しない

**I want to** 変更対象が `docs/workflow/workflow-detail.md` に限定され、`skills/reviewing-deliverables/SKILL.md` 本体（現行実装が正）および `agents/` 配下のレガシー記述（別 Issue で追跡）に手を入れていない,
**so that** 「実装が正でありドキュメントを実装へ整合させる」という本 Issue の方向が逆転せず、ファイル群の存廃判断を伴うスコープ外の変更が混入しない.
