# Design Doc: autopilot 復活 — 自律収束ループ（#246）

> 形式: Ubl 2020（Context / Goals / Non-Goals / Design / Trade-offs / Alternatives / Open Questions）。
> 前提となる先行事例調査は [research.md](research.md) を参照。

## Context

旧 autopilot は v1.0 で意図的に廃止された（#202-207, v3.0.0 BREAKING）。理由は「autopilot 中心設計が開発・レビューしにくい状態を生んだ」こと（discover skill 787 行 / autopilot 関連 BATS 20+ ファイル、Agent Teams orchestration の複雑性）。

しかし v1.0 移行の結果、**新しい基盤が揃った**:
- `reviewing-deliverables` が **Workflow 化（#235）**: 動的レビューパネル + 並列 + 敵対的多ラウンド検証 + documentation lens(#241)。
- Workflow ツール（決定論的 JS orchestration）と goal/loop プリミティブ。
- `running-atdd-cycle` の RED→GREEN（実行可能 AT）、`skill-gate` の並列衝突検出（#197）。

**ユーザー仮説**: 各成果物を人間がレビューする代わりに、reviewer を Workflow で手厚く行い、goal のようなループで成果物を納得行くまで作り上げれば、人間レビュー同等の効果を AI 単独で出せる。

先行事例調査（research.md）の結論は「**実現可能性は高い**が、最強プレイヤー（Anthropic/OpenAI）は意図的に『置換』でなく『拡張』を選び人間マージゲートを残す」。本 Design はこの知見を踏まえ、**スコープを絞った autopilot** を提案する。

## Goals

1. **内側ループの自律化**: `defining-requirements → … → running-atdd-cycle` の各成果物について、`generate → review(Workflow) → fix → re-review` を **満足オラクルを満たすまで自律反復**する薄い orchestrator を提供する。
2. **前倒し収束（shift-left convergence）**: 人間が成果物を見る時点で **near-green**（レビュー指摘がほぼ枯れた状態）にする。人間レビューの労力を「ゼロから読む」から「near-green を確認する」へ前倒しする。
3. **既存 primitive の再利用**: `reviewing-deliverables`(#235) を **single-pass primitive のまま**使い、autopilot はその上の薄い loop orchestrator に徹する（Codex/Anthropic の「ループとレビュアーを分離せよ」原則）。
4. **満足オラクル = AND(実行可能 AT, レビュアー verdict)**: atdd-kit の構造的差別化。AT の RED→GREEN を **override 不能な客観 backstop** とし、LLM verdict と AND でゲートする。
5. **安全に失敗する**: 非収束・予算超過・同一失敗反復を検出し、人間へ escalation して停止する（無限ループ・silent fake-green を構造的に防ぐ）。

## Non-Goals

- **自動マージはしない**。merge は人間ゲートのまま（Anthropic *"does not approve or block PRs"* / OpenAI *"not a replacement"* と整合）。
- **人間レビューの完全消去はしない**。人間ゲートは **discover(AC 承認)** と **merge** の 2 点に固定（Open SWE / 全候補 / 既存 `workflow-overrides` と一致）。
- **legacy の自律 refactor は約束しない**。この種ループは well-specified / greenfield 向き（Ralph/Huntley が明言）。
- **旧 autopilot の逐語復活はしない**（Agent Teams orchestration / persona / autonomy-levels / circuit_breaker.sh は復活させない）。新基盤（Workflow/AT）に載せ替える。

## Design

### 全体像

```
discover(人間ゲート: AC承認)
  └→ [autopilot orchestrator]
        各 step S in {US, plan+AT, ATDD実装}:
          loop (最大 N_S 回):
            1. S の skill で成果物を generate/修正
            2. reviewing-deliverables(Workflow) を single-pass 実行 → 構造化 verdict
            3. 満足オラクル判定:
                 AT_required(S) ? (AT全緑 AND verdict.correct AND P0/P1=0) : (verdict.correct AND P0/P1=0)
               - 満たす → 次 step へ
               - 満たさない → findings を逐語で S にフィードバックして再 generate
            4. 安全レール: 非収束/同一失敗/予算超過 → halt + human escalation
  └→ reviewing-deliverables 最終 PASS（near-green）
  └→ merge(人間ゲート)
```

### 1. loop と primitive の分離
`reviewing-deliverables` は変更しない（single-pass の Workflow primitive）。autopilot は「いつ回すか・verdict をどう解釈してループするか」だけを担う薄い orchestrator（Workflow script or command）。これにより primitive の進化と loop の進化が独立する。

### 2. 満足オラクル = AND ゲート
- **AT がある step（plan+AT 以降）**: `AT(RED→GREEN) == green` AND `verdict.overall_correctness == correct` AND `P0/P1 findings == 0`。
- **AT が無い step（PRD/US）**: `verdict.overall_correctness == correct` AND `P0/P1 == 0`（reviewer のみ。AT backstop 不在は §2.1 と Open Question 2 で扱う）。
- **決定論ゲートは決定論に任せる**: lint/test/AT の合否は **コード/CI が判定**し、LLM に「テストが通るか」を再判定させない（Open SWE のリファクタ教訓）。

#### 2.1 AT 自体の客観性 — AC→AT トレーサビリティゲート（重要）
AND ゲートの AT は「override 不能な客観 backstop」と称するが、**その AT は同じ autopilot ループ内の AI（Step 3 plan+AT）が書く**。したがって AT が緑でも、それは「**ループが自分で生成した spec に対して**緑」でしかなく、生成 AT が discover で**人間が承認した AC** を忠実・網羅的にエンコードしている保証は別途必要になる（さもなくば「自分の宿題を自分の物差しで採点」）。

そこで backstop の前提として **AC→AT カバレッジ/トレーサビリティゲート**を置く:
- discover で**人間が承認した AC set は immutable**（autopilot は変更不可）。
- 生成された `acceptance-tests.md` が、その承認済み AC を**漏れなく**エンコードしているかを、**AT を書いた generator とは別 context** で検証する（各 AC → 対応 AT のトレーサビリティ、未カバー AC = P0 finding）。
- immutability は「AI が AT を書いた**後**に固定される」ものなので、**固定前のカバレッジ検証**が客観性の前提である点を明記する。
- このゲートが緑になって初めて、以降の step で AT を客観 backstop として信頼する。

これにより「AT を持つ step では循環参照で false-green を防げない」という穴を正面から塞ぐ（人間承認 AC という外部アンカーに接地させる）。eval による定量裏付けは Open Question 4 に残す。

### 3. 構造化 verdict schema（Codex 式）
`reviewing-deliverables` の Aggregate 出力を機械可読に拡張:
```
{ overall_correctness: "correct"|"incorrect",
  findings: [ { priority: 0-3, confidence: 0-1, file, line_range,
               detail, evidence_ref } ] }   // evidence_ref は必須（型は step 種別で異なる、下記）
```
**`evidence_ref` の型（裏付けの無い指摘を弾くため必須、step 種別ごとに定義）**:
- **AT がある step**: 失敗 AT 名 / ログのパス（実行可能な証拠）。
- **AT が無い step（PRD/US）**: immutable な PRD / 承認済み AC からの **引用行（source quote + 行番号）**。
- **人間差し戻し由来の finding（§7）**: 人間コメントの URL / 引用。

ループ exit 条件 = （AT step なら AT 全緑 AND）`overall_correctness=correct` AND P0/P1 ゼロ。canonical verdict 行を fail-closed パース。

### 4. 収束 / 安全レール（ループ非収束・livelock 対策）
- **MAX_ITERATIONS**（step ごと, 例: 実装 8 / 設計系 4。Ralph=10, sandbox=20 を参考）。
- **sameness-detector**: 失敗の正規化 fingerprint（sha256）が **2 連続同一で halt**（dantodor）。
- **stuck 検出**: window=3 で進捗なし → halt（SWE-AF）。
- **COMPLETED_WITH_DEBT 退避**: 予算到達時は未解決 finding を debt として記録し人間へ。
- 非収束時は **exit 非ゼロ + human escalation**（"review manually: <理由>"）。

### 5. レビュアーの独立性 / 反幻覚（false-green 対策）
- reviewer を **別 context / read-only** で実行（generator と盲点を共有させない）。
- **immutable な `acceptance-tests.md` / AC set にアンカー**（sandbox の :ro mount 相当）。
- 各 finding に **`evidence_ref` を強制**（§3: 失敗 AT/ログ、または AC/PRD の引用行、または人間コメント — 裏付けの無い指摘を弾く）。
- **detect-then-validate**（フレッシュ agent で再検証, Anthropic）+ **false-positive denylist** + **引用ファイルを開いて行番号検証**（yeameen）。
- **precision over recall**: P0/P1 のみブロック、minor/nit は pass-with-notes（OpenAI/Anthropic の共通選択）。

### 6. 監査整合性（silent fake-green 対策）
- **裏付けレビュアーコメントの無い PASS は自動降格 + 再実行**（RyanAmundson）を hard rule 化。
- 各反復の verdict を `docs/issues/<NNN>/autopilot-log.jsonl` に **JSONL 永続化**（fresh-context-per-iteration の外部真実源 / 監査証跡）。

### 7. 人間差し戻しのループ内取り込み（人間コメントの取り込み）
- 人間コメントを **「もう一つの finding」として反復に再投入**。判定は timestamp cutoff でなく「**Addressed 返信が無い**」で（RyanAmundson）。fire-and-forget にしない（途中介入可能）。
- **ループ・ライフサイクル上の再投入点**（全体像のループは収束後に exit している点に注意）:
  1. 人間コメントが付くのは主に **merge ゲート**（near-green を人間が確認する時点）か、ループ実行中の途中介入。
  2. コメントを finding 化し、**対象成果物に対応する step のループを再開**する（対象が特定できなければ直近 step）。
  3. 再開時は **MAX_ITERATIONS を再起動**（人間介入は新しい収束サイクルの開始とみなす）。ただし sameness-detector の履歴は保持し、同一失敗の再発は引き続き検出する。
  4. 人間 finding の `evidence_ref` は **人間コメントの URL / 引用**（§3 と整合、必須要件を満たす）。

### 8. リスク段階化 / コスト（コスト・false-positive 疲労対策）
- 変更規模 / keyword（auth/migration/secrets）で **レビュアー強度・反復予算を tier**（1/2/3 パス）。小変更に full-council コストを払わせない。
- **model-tier routing**（haiku=gating, opus=bug/logic）— 本設計の提案手法（安価モデルで足切り、強モデルで bug/logic 判断）。

### 9. 既存資産との接続
- `skills/reviewing-deliverables/`（#235 Workflow primitive、#241 doc lens）をそのまま呼ぶ。
- `skills/running-atdd-cycle/`（RED→GREEN backstop）。
- `.claude/rules/workflow-overrides.md`（plan 承認省略 + ユーザー差し戻し権）= 人間ゲート配置の既存ポリシーと一致。
- `skill-gate`(#197) の衝突検出 = 並列 autopilot 実行時の安全装置。

## Trade-offs

| 採用する設計 | 代償・限界 |
|--------------|-----------|
| 並列マルチレビュアー × 反復ループ | **コスト増**（adversarial-review=6 calls/反復, SWE-AF≈$19/run）。→ tiering / model-routing で緩和するが、小変更でも単純フローよりは高い。 |
| AND(AT, verdict) を hard ゲート | AT が無い step（PRD/US）では backstop が reviewer のみになり、false-green リスクが相対的に残る（§2.1 / OQ2）。 |
| AC→AT トレーサビリティゲート（§2.1）で AT の客観性を担保 | 追加の独立検証 step が要る（コスト・実装複雑性増）。また「人間承認 AC が網羅的・正確」であることに依存する（AC 自体の品質は discover の人間ゲートに帰着）。 |
| 前倒し収束（置換でなく拡張） | 「人間レビュー完全消去」という当初仮説より一段控えめ。人間は merge ゲートで最終確認する負荷が残る（ただしエビデンスはこれを支持）。 |
| 薄い orchestrator + 安全レール | 非収束時は「完成しない」ことがある（COMPLETED_WITH_DEBT/escalation）。"必ず緑になる" は保証しない。 |
| fresh-context-per-iteration + JSONL 外部真実源 | 実装が状態管理を持つぶん複雑。ただし監査性と引き換え。 |

## Alternatives

1. **現状維持（人間が各成果物をレビュー）** — 最も安全だが、ユーザーの課題（レビュー労力）を解かない。却下。
2. **テストのみゲート（Ralph A 層, 独立 LLM レビュアー無し）** — シンプル・低コストだが、テストが捉えない設計/可読性/要件逸脱を見逃す。atdd-kit の reviewing-deliverables 資産を捨てることになる。部分採用（AT を AND の一項に）。
3. **完全置換 + 自動マージ** — フィールドの最強プレイヤーが意図的に避ける（独立な本番代替エビデンスが無い）。リスク過大。却下（将来 eval で信頼が確立したら再検討）。
4. **旧 autopilot（Agent Teams orchestration）の復活** — v1.0 で「開発・レビューしづらい」として廃止した当の機構。複雑性が再来する。却下。新基盤（Workflow/AT）に載せ替える。

## Open Questions

1. **スコープの最終確定（要ユーザー判断）**: 本 Design は「前倒し収束（merge は人間）」を推奨するが、ユーザー当初仮説は「人間レビュー置換」。どこまで人間を外すか（merge ゲートを残すか）は最終的にユーザーの意思決定。
2. **PRD/US step の backstop**: AT が無い step で false-green をどう抑えるか（§2.1 の AC アンカー + 引用 evidence で一定担保するが、さらに人間 1 点確認を残す / 別種の客観チェックを足す / reviewer 多重化のみで許容するか）。
3. **成果物形態**: orchestrator を Workflow script / `/atdd-kit:autopilot` command / 新 skill のどれで実装するか。
4. **信頼度を上げる eval（research.md「穴」#5: 本番代替の独立エビデンス不足）**: 本番代替の独立エビデンスが無いため、`comment→change 率` / `post-merge defect 率` / `loop 収束率・平均反復数・コスト` を自前 eval で測り、段階的に人間ゲートを緩める。閾値をどう置くか。
5. **コスト上限**: 1 Issue あたりの token/コスト ceiling と、超過時の挙動（COMPLETED_WITH_DEBT で止める）。

## 推奨次アクション

本 Design を承認後、**段階実装**を別 Issue で:
- Phase 1: 構造化 verdict schema を `reviewing-deliverables` 出力に追加（後方互換）。
- Phase 2: 薄い orchestrator（1 step ぶんの generate→review→fix ループ + 安全レール）を最小実装し、`defining-requirements`(PRD) で dogfood。
- Phase 3: 全 step へ展開 + eval 計測 + tiering。

各 Phase は atdd-kit 自身の 6-step フローで進める（ATDD 自己適用）。
