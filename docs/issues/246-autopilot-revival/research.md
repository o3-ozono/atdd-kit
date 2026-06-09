# 先行事例調査 — AI 単独の自律開発フローとレビュー扱い（#246）

> 2026-06-07 に Workflow（多角検索 → 深掘り → 統合、20 agents）で GitHub / Web を網羅調査した結果。各主張は深掘りフェーズで firsthand 確認した。一部の引用について正確な出典 URL は本文に注記する（design 提案レビュー #246 の指摘を反映）。

## 要約

自律（または半自律）AI 開発フローの「レビュー」扱いは、はっきり **3 層**に分かれる。ユーザー仮説「workflow reviewers + iterate-until-satisfied で人間レビューを置換」は **未踏の発明ではなく、確立されたパターンの妥当な再構成**であり、これは実現可能性の証拠（同型実体が複数）。ただし最強プレイヤー（Anthropic / OpenAI）は意図的に **「置換」でなく「拡張」** を選んでいる。

## ランドスケープ（3 層）

### A 層: テスト/CI ゲートで人間レビューを置換（独立 AI レビュアー無し）
- **snarktank/ralph**（https://github.com/snarktank/ralph, 約20k★）+ Geoffrey Huntley の Ralph Wiggum 技法（https://ghuntley.com/ralph/）。bash/Stop-hook ループでフレッシュなエージェントを回し、PRD の全ストーリーが `passes:true`（完了センチネル `<promise>COMPLETE</promise>`）になるまで反復。"satisfier" は typecheck/lint/test/browser 検証という**決定論的バックプレッシャー**であって独立レビュアーではない。Huntley: *"Ralph only works if there are feedback loops"*。
- 学術: **Reflexion**（https://github.com/noahshinn/reflexion, HumanEval 91% pass@1）、**AlphaCodium**（https://github.com/Codium-ai/AlphaCodium, "test anchor" で回帰防止）、**CodeCoR**（arXiv 2501.07811）— いずれも「テスト=客観ゲート」で iterate-until-pass。

### B 層: AI レビュアーをループに入れ中間ゲートにするが、人間がマージ権を保持
- **Open SWE / LangChain**（https://github.com/langchain-ai/open-swe, 約10k★）— Manager/Planner/Programmer/Reviewer の 4 ノード。Reviewer が問題を見つけたら Programmer にフィードバックを返し「コードが完璧になるまで」action-review ループ。**現行版は Deep Agents へリファクタされ、レビューは graph node から prompt section + 決定論的 middleware(lint/test) へ移行**、ループは step limit で hard-bound（`notify_step_limit_reached`）。人間ゲートは plan 承認と PR(draft) レビューの 2 点のみ。
- 個人実装: **dantodor/claude-autopilot**, **gregorydickson/pickle-rick-claude**（収束ゲート: 連続2ラウンド clean + P0/P1 ゼロ + 最小ラウンド床）, **csabakecskemeti/claude-autopilot-sandbox**（別コンテナの supervisor が Stop-hook で complete/not_complete 判定）, **RyanAmundson/claude-agent-pipeline**, **Agent-Field/SWE-AF**（3段ネストの budget-bounded ループ + stuck 検出 + COMPLETED_WITH_DEBT 退避）, **jmcveen/merge-ready**（iterate-until-APPROVE。owner/repo ではなく **gist**: https://gist.github.com/jmcveen/6bca940430798f849cc688c923674ec4 ）。
- マルチエージェント・レビューパネル: **alecnielsen/adversarial-review**（Claude×GPT が相互論破, 両者 NO_ISSUES まで最大3反復 + stagnation circuit breaker）, **yeameen/claude-code-review-council**（7レビュアー + 引用ファイルを開いて幻覚検証）, **spencermarx/open-code-review**, **liatrio-labs/claude-deep-review**（prompt-injection 防御）。学術: ChatDev, CodeAgent（QA-Checker 監督 agent, arXiv 2402.02172, 脆弱性検出 +41%）。

### C 層: ベンダー公式 — 強力な AI レビュアーを持つが意図的に人間マージゲートを維持
- **Anthropic 公式 code-review plugin**（README: https://github.com/anthropics/claude-code/blob/main/plugins/code-review/README.md）— 並列マルチエージェント + 検証パスで false positive 削減。README からの firsthand 引用は *「findings as a starting point for human review」*。「**Claude does not approve or block pull requests**」という強い言明は Anthropic の code-review **docs ページ**（code.claude.com/docs の code-review）に基づく（README ではなく docs が出典）。自社マージの 80%超が AI 生成でもレビュアーは助言のみ。**ループ（ralph-wiggum）とレビュー（code-review）を別 plugin に分離** = Anthropic の設計判断は「ループとレビューを融合しない」。
- **OpenAI Codex**（https://github.com/openai/codex）+ Scaling code verification（https://alignment.openai.com/scaling-code-verification/, firsthand）— 10万 PR/日超、52.7% が修正に至るが *「the reviewer is a support tool, not a replacement for careful judgment」「precision over recall」*。一方、社内 harness-engineering 事例では約100万行を manual コード無しで出荷し agent reviewer 群のループが主要な正しさ機構だった（=最強事例では実質的に人間レビューを代替）。
- **GitHub Copilot coding agent / Google Jules / Devin(Cognition)** も同様: 実装/自己テストは自律ループ化、レビュー(or マージ)は人間保持。**CodeRabbit / Qodo / Greptile**（82% bug catch）も autofix はするが auto-merge しない。

## 最も近い先行事例（atdd-kit autopilot への教訓）

| 事例 | URL | 教訓 |
|------|-----|------|
| Open SWE (LangChain) | https://github.com/langchain-ai/open-swe | 仮説の最も忠実な OSS 実体。「完璧まで」は実際 step limit で hard-bound（**無限ループ不可避 → 上限+escalation 必須**）。LLM レビューノードを廃し決定論ゲート + prompt 自己レビューに退化＝**「テスト通るか」を LLM に再判定させず決定論ゲートに任せよ**。人間ゲートは plan + PR の 2 点（workflow-overrides と一致）。 |
| Anthropic code-review plugin | https://github.com/anthropics/claude-code/.../code-review | 最も権威ある反証データ点（advisory-only）。盗む技術: **HIGH-SIGNAL-ONLY + false-positive denylist + detect-then-validate（フレッシュ agent 再検証）の 2 段パイプライン**。（注: 安価モデルで gating・強モデルで bug/logic という **model-tier routing は本設計の提案手法**であり、code-review README に明記された Anthropic 仕様ではない。） |
| OpenAI Codex + verification | https://alignment.openai.com/scaling-code-verification/ | 最大規模の実運用でも「replacement でない」「precision over recall」（出典: alignment ページ）。**構造化 findings schema（priority 0-3, confidence 0-1, overall_correctness=correct/incorrect をループの緑/赤ゲートに）** は openai-cookbook の Codex SDK code-review 例（build_code_review_with_codex_sdk.md）が出典。ループとレビュアーの分離、AGENTS.md=rules による precision steerability。 |
| claude-autopilot-sandbox | https://github.com/csabakecskemeti/claude-autopilot-sandbox | 「別エージェントがレビュアーとして is-this-done 判断を代替」の最もクリーンな実体。**(1) reviewer を別 context/read-only で走らせ自己レビュー盲点を排除、(2) immutable な AC copy にアンカー、(3) `status: complete\|not_complete` の fail-closed パース、(4) 二重ループ上限（MAX_CONTINUE_CYCLES=100 / SUPERVISOR_MAX_LOOPS=20）で強制 exit + escalation**。 |
| snarktank/ralph | https://github.com/snarktank/ralph | iterate-until-satisfied の源流かつ最普及。フレッシュ context 毎反復 + 外部ファイルを唯一の真実源、1反復1作業、完了センチネル + MAX_ITERATIONS=10。**弱点（独立レビュアー無し・停止条件が品質でなく完全性）がそのまま atdd-kit の差別化余地**。 |
| Agent-Field/SWE-AF | https://github.com/Agent-Field/SWE-AF | ATDD 型に最も近い。PM が AC 発行 → 各 issue へ伝播 → verifier が全 AC を実コードに対し検証する verify-fix ループ。3段ネスト + budget 上限 + stuck 検出(window=3) + COMPLETED_WITH_DEBT 退避。**フィードバックは逐語（vague summary でなく）で次反復へ**。 |

## フィールドの「穴」（atdd-kit の差別化余地）

1. **AI レビュアー × 実行可能 AT ゲートの併用が稀** — 多くは「LLM レビュアーのみ」か「テストのみ」のどちらか。両方を AND ゲートにし各指摘を失敗 AT/ログで裏付けさせる設計は SWE-AF / AlphaCodium を除きほぼ無い。**AT が第一級成果物の atdd-kit は構造的優位**。
2. **ループ非収束の進捗検出が未成熟** — 多くは MAX_ITERATIONS 上限のみ。dantodor の sameness-detector（失敗の正規化 sha256 が2連続同一で halt）が唯一の高度例。
3. **false-green / 監査整合性の強制が弱い** — RyanAmundson の「passed ラベルに対応するレビュアーコメントが無ければ自動降格+再実行」は数少ない例。
4. **人間差し戻しのループ内取り込み** — 人間コメントを「もう一つの finding」として再投入する設計は一部のみ。
5. **本番代替の独立検証エビデンスが事実上ゼロ** — 個人 dogfood/benchmark は豊富だが、第三者による本番マージ成功率の独立検証は無い（OpenAI/Anthropic も自社数値のみ）。
6. **AC=spine をレビュアーが参照する設計の標準化不足** — reviewer を immutable AC set にアンカーするのは少数。多くは diff だけ見る。

## 結論

実現可能性は **高い**（同型実体 6 件以上・ベンダー本番 2 件）。仮説はコンポーネントとして実証済み。ただし **「置換」は最強プレイヤーが避けている語**であり、atdd-kit も **「前倒し収束（人間が見る時には near-green）」** にスコープを絞り、discover(AC 承認) と merge の人間ゲートは残すのが、エビデンスとも既存 `workflow-overrides`（plan 承認省略 + 差し戻し権）とも整合する。設計の詳細は [design-doc.md](design-doc.md) を参照。
