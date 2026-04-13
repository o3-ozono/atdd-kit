# AC Review — Developer (Issue #41)

## 総合評価

PASS（軽微な文言明確化を推奨）

## 指摘事項

### AC1: Agent Composition セクションのタスクタイプ依存
- **観点:** アーキテクチャ整合性
- **指摘:** AC1の文言は「Phase 3/Phase 4 のエージェント人数・フォーカス観点が表形式で記載される」となっているが、research タスクでは Phase 3 に Researcher が登場し、documentation では Writer が登場する。「Phase 3/Phase 4」と固定表記すると development/refactoring/bug 専用に見えてしまう。SKILL.md は全タスクタイプ共通ファイルであるため、タスクタイプに依存しない汎用的な表現（例: 「各 Phase の Variable-Count Agents」）に修正する方が一貫性を保てる。
- **深刻度:** 低（実装上の曖昧さを生む可能性あり）

### AC4: mid-phase resume 時の Agent Composition 取得
- **観点:** エッジケース・技術的実現性
- **指摘:** AC4 は「追加承認要求が発生しない」ことを要求するが、この実現は「plan コメントから Agent Composition を読み取れる」ことが前提条件。Phase 0.9 の mid-phase resume で Phase 3/4 にジャンプする場合、plan コメントが存在しない異常ケース（plan が未完了のまま resume された場合）の扱いが定義されていない。このケースで Agent Composition を取得できず、かつ承認要求も禁止されると、spawn できないまま処理が進む危険がある。
- **深刻度:** 中（異常ケースの fallback が未定義）

### AC3: Readiness Check の記述粒度
- **観点:** アーキテクチャ整合性
- **指摘:** 「Phase 3/4 の Variable-Count Agents が具体化されている」という追加チェック項目は、research/documentation タスクでは Reviewer ではなく Researcher/Writer になる。チェック項目をタスクタイプ固有の表現にすると SKILL.md の汎用性が下がる。タスクタイプに依存しない表現（例: 「Variable-Count Agents の人数と観点が具体化されている」）の方が整合性が高い。
- **深刻度:** 低

### AC6: レビュー担当エージェントの不明確さ
- **観点:** 実装複雑度
- **指摘:** AC6 は「Developer/QA への SendMessage レビュー観点に Agent Composition が含まれる」としているが、Agent Composition（誰を何人 spawn するか）はアーキテクチャ側の判断であり、QA ではなく Developer が評価すべき観点。QA は test strategy の妥当性を担当するため、Agent Composition を QA のレビュー観点に含めると責任分担が曖昧になる。Developer への指示のみに絞る方が明確。
- **深刻度:** 低

## 追加/削除/修正提案

### 修正提案: AC1 の文言をタスクタイプ汎用化

**現状:** 「Phase 3/Phase 4 のエージェント人数・フォーカス観点が表形式で記載される」

**修正案:**
> **AC1 (修正):** plan 成果物に `### Agent Composition` セクションが含まれ、各 Phase の Variable-Count Agents（人数・観点またはテーマ）が表形式で記載される

**理由:** 「Phase 3/Phase 4」固定は development/refactoring/bug の文脈。SKILL.md は全タスクタイプ共通のため汎用表現が適切。

### 追加提案: AC7 — mid-phase resume 時の plan 不在ケース

**Given:** autopilot が Phase 0.9 の mid-phase resume で Phase 3/4 にジャンプする  
**When:** plan コメントが Issue に存在しない（plan が未完了のまま session が中断されたケース）  
**Then:** `commands/autopilot.md` に従いエラーを報告し、ユーザーに Phase 2 からの再実行を促す（サイレントな spawn 省略または無限ループを発生させない）

**理由:** AC4 の「追加承認要求が発生しない」を実現するには plan コメントから Agent Composition を必ず読み取れることが前提。この前提が崩れる異常ケースの扱いを明示することで、AC4 の実装が完全になる。

### 修正提案: AC6 の担当エージェント明確化

**現状:** 「Developer/QA への SendMessage レビュー観点に Agent Composition が含まれる」

**修正案:**
> **AC6 (修正):** Plan Review Round で Developer への SendMessage レビュー指示に「Agent Composition の妥当性（人数・観点の具体性）」が含まれる

**理由:** Agent Composition はアーキテクチャ判断であり Developer が評価すべき。QA への SendMessage に含める必要はなく、責任分担を明確にする。

## 補足

- **変更規模の見積もり:** `skills/plan/SKILL.md` に約 20-30 行（`### Agent Composition` セクションテンプレート追加、Step 4 への導出ステップ追加、Step 6 テンプレート追記、Step 5 Readiness Check 項目追加）、`commands/autopilot.md` に約 10-15 行（Variable-Count Agents セクション改訂、Plan Review Round の SendMessage 指示追記）。Issue 分割は不要な規模。
- **スコープ逸脱リスク:** research/documentation タスクの Researcher/Writer も同じ「承認が唐突」問題を持つが、Issue 本文の例が `Reviewer x 1` のみのため、今回のスコープが research/documentation を含むか否かを明示することを推奨。含める場合は AC1/AC3 の汎用化修正が必要になる。
- **既存ドキュメント整合:** `docs/` 配下に Variable-Count Agents の承認フローを記述したファイルが存在する場合は合わせて更新が必要（DoD の「既存ドキュメントと矛盾しない」を確保するため、atdd フェーズで確認が必要）。
