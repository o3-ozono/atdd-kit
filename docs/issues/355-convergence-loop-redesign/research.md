# 調査 — レビュー収束ループが収束しない根本原因と、根拠のある再設計（#355）

> 2026-06-23 deep-research（5角度・21ソース・90主張抽出・25主張を3票敵対検証 → 20 confirmed / 5 killed）。
> 棄却された5主張は**すべて rubric 較正系**で、出典が将来日付の疑わしい arxiv ID（2601.x / 2604.x / 2605.x / 2510.16062）だった。検証が正しく殺した。
> 信頼できるアンカーは定番論文に限定する: CriticGPT(2407.00215) / MT-Bench(2306.05685) / Huang(2310.01798) / Self-Refine(2303.17651) / Feedback Friction(2506.11930)、および実運用 docs（OpenAI alignment / Anthropic code-review / open-swe）。

## 結論（先に）

**#355 の現行アプローチ（レビュアーをより賢くする方向: 多視点パネル・dedup・round memory）は、レイヤを間違えている。** 根本原因は「レビュアーの賢さ不足」ではなく、**収束信号をレビュアーの自己判定に置いていること**そのもの。エビデンスは「外部の客観信号なしの自己判定ループは収束しない（振動・飽和する）」と「敵対レビューの nitpick 膨張は構造的でゼロにできない」を支持する。

→ 直すべきは: **(1) 収束信号を客観ゲート（AT/test green ＋ AC カバレッジ）に一本化し、LLM レビューを autopilot 収束ループから完全に外す（advisory にもしない — レビュー自体が長時間化の主因）。(2) 停止は客観ゲート green ＋ ~2-3 ラウンド上限＋sameness/stuck rails。(3) severity gating は AC/失敗テスト紐づけのみブロック、minor/nit は follow-up。(4) 客観ゲートを Issue クラスに適合させる。人間判断は merge gate に集約。**

> ユーザー決定（2026-06-23）: A は「advisory にも残さない」。LLM レビューは autopilot 収束ループから**完全除去**する。下表の B（precision operating point）/ D（panel scope freeze）は「ループ内レビュアー」前提のため、ループ除去に伴い不要化。

## 検証済みエビデンス（confirmed）

### 1. nitpick 膨張は構造的（ゼロにできない、トレードオフのみ） — CriticGPT (arXiv 2407.00215)
- comprehensiveness と spurious-claim（nitpick/hallucination）率は **precision-recall の Pareto フロンティア上**にある。バグ検出率を上げる＝主張数を増やす＝nitpick も増える。**3-0 confirmed**。
- precision と recall は別個に最適化可能な独立軸。**3-0 confirmed**。
- Force Sampling Beam Search (FSBS) は**推論時の調整ノブ**で、より保守的（nitpick 少・見逃し増）側に倒せる。**3-0 confirmed**。
- baseline ChatGPT も CriticGPT も nitpick/hallucination を出す（弱モデル固有の欠陥ではない）。**3-0 confirmed**。
- 〔棄却〕「LLM critic は人間より本質的に nitpick が多い」= **1-2 で棄却**（本質的とまでは確証できず）。
- **含意**: dedup や多数決では nitpick 膨張は止まらない（生成し続ける）。**operating point を precision 側に倒し、severity gating で吸収する**しかない。

### 2. LLM-as-judge は系統的バイアスを持ち、自由形式の判定は基準と紐づかない — MT-Bench (arXiv 2306.05685)
- LLM-as-judge は系統的バイアス（position 等）を持つ。**3-0 confirmed**。
- central tendency / hedging bias がある。**3-0 confirmed**。
- 自由形式の判定根拠は評価基準への**検証可能な紐づけを欠く**（＝なぜその severity かが客観的に追えない）。**2-1 confirmed**。
- position-swap + chain-of-thought の併用が緩和に効く。**2-1 confirmed**。
- 〔棄却・低信頼〕「rubric 較正が verbosity bias を減らす」「style bias が支配的」「rubric 粒度を細かくすると信頼性が落ちる(76→57%)」= **すべて 0-3 で棄却**（出典が疑わしい将来日付 preprint）。
- **含意**: 「固定 rubric にすればバイアスが減る」は**今回のエビデンスでは支持されない**（その主張群は棄却）。ただし**指摘に objective evidence_ref（失敗AT/AC引用）を必須化**して「基準と紐づかない自由判定」を排除する方向は、2-1 confirmed の主張と整合する。

### 3. 外部の客観信号なしの自己修正は収束しない — Huang(2310.01798) / Feedback Friction(2506.11930) / Self-Refine(2303.17651)
- **intrinsic self-correction（外部ツール/信号なしでモデルが自己再評価）は信頼的に改善せず、振動・劣化しうる**。**3-0 confirmed**（Huang "Cannot Self-Correct Reasoning Yet"）。
- **理想的な高品質フィードバックがあってもモデルは plateau する**（Feedback Friction）。**3-0 confirmed**。
- 外部フィードバックによる自己修正(S2)は intrinsic より高い利得。**3-0 confirmed**。
- Self-Refine の報告利得は**短い反復ホライズンで計測**されたもの（無限改善ではない）。**2-1 confirmed**。
- consensus/confidence 閾値は調整可能なゲートになりうる。**2-1 confirmed**。
- **含意**: 観測された「P0数が 多→4→0→1 と振動」は、まさに intrinsic 自己判定ループの**ドキュメント化された振動現象**。収束信号をレビュアーの自己判定に置く限り構造的に収束しない。**外部客観ゲートにアンカーし、~2-3 ラウンドで打ち切る**べき。

## 実運用の収束設計（practitioner）

- **OpenAI scaling-code-verification**: レビュアーは support tool であって replacement ではない／**precision over recall**。
- **Anthropic code-review plugin**: advisory-only。**"Claude does not approve or block PRs"**。マルチエージェント＋検証パスで false positive 削減、findings は人間レビューの起点。
- **langchain-ai/open-swe**: LLM レビューノードを**廃し**、決定論ゲート（lint/test）＋ step limit の hard-bound に退化させた。
- 共通項: **収束/ブロッキングの権限を LLM レビュアーから外し、客観ゲート＋上限に移す。レビューは助言。**

## #355 への設計含意（エビデンス紐づけ）

| # | 再設計アクション | 根拠 |
|---|------------------|------|
| A | **収束信号を客観ゲート（AT/test green ＋ AC→AT カバレッジ）に一本化。LLM レビュー PASS をオラクルの必須項から外し advisory に降格。** test green ＋ AC カバレッジが満たされたら done。レビュー指摘は原則 follow-up。 | Huang/Feedback Friction（自己判定は収束しない）／open-swe（レビューノード廃止）／Anthropic・OpenAI（advisory-only） |
| B | **レビュアーを precision 側 operating point へ**: 「壊れる所を探せ」型の敵対探索をやめ、**AC アンカー・high-confidence・objective evidence_ref 必須**の指摘のみ。evidence_ref が "unverified" の指摘はブロッキングにしない。 | CriticGPT（nitpick は構造的・FSBS で保守側へ）／OpenAI precision over recall／MT-Bench（基準に紐づかない自由判定を排除） |
| C | **severity gating の厳格化**: AC または失敗テストに紐づく blocker/major のみ merge を block。minor/nit は**絶対にブロックせず** follow-up Issue へ。 | severity gating 原則／advisory-only |
| D | **scope freeze**: round 1 で diff＋AC 集合＋パネル（角度集合）を**凍結**。後続ラウンドは**新規指摘・新規レンズを禁止**し、round 1 指摘の解消確認のみ。新スコープの所見は out-of-scope follow-up。 | nitpick 膨張は「毎回別角度」で発生（CriticGPT 構造的）／scope freeze 原則 |
| E | **停止条件の客観化＋上限**: 停止 = 客観ゲート green AND 凍結指摘集合に未解消 blocker/major ゼロ。**~2-3 ラウンド上限**（利得が飽和）。sameness/stuck 検出は維持。 | Self-Refine 短ホライズン／Feedback Friction plateau／consensus 閾値 |
| F | **客観ゲートを Issue クラスに適合させる**（#355 triggering instance の真因）: skill/doc 変更で AT が BATS pin の Issue では「BATS green」が客観ゲート。`tests/acceptance/ red→green ＋ red.jsonl` を全 Issue に強制しない。 | impl phase で観測した gate-unverifiable 空転（本 Issue 自身の実装が再現） |

## 棄却・低信頼として扱うもの（誠実性）
- 「固定 rubric/checklist にすればバイアスが減り収束する」: **今回のエビデンスでは支持されない**（該当主張は 0-3 で棄却、出典が疑わしい将来日付 preprint）。checklist は**バイアス低減ではなく scope 凍結（D）の手段**としてのみ採用する。
- 「severity 粒度は粗いほど信頼的（binary > 5-way）」: 棄却（0-3）。粒度の最適点は未確定（open question）。

## Open Questions（未解決）
- multi-round code review の最適ラウンド数（文献で確定値なし。~2-3 は飽和の経験則）。
- confidence で「収束」と「Feedback Friction plateau」を区別できるか。

## 出典
- CriticGPT "LLM Critics Help Catch LLM Bugs": https://arxiv.org/abs/2407.00215
- "Judging LLM-as-a-Judge with MT-Bench and Chatbot Arena": https://arxiv.org/abs/2306.05685
- "Large Language Models Cannot Self-Correct Reasoning Yet" (Huang et al.): https://arxiv.org/abs/2310.01798
- "Self-Refine: Iterative Refinement with Self-Feedback" (Madaan et al.): https://arxiv.org/abs/2303.17651
- "Feedback Friction" (理想フィードバックでも plateau): https://arxiv.org/abs/2506.11930
- OpenAI "Scaling code verification": https://alignment.openai.com/scaling-code-verification/
- Anthropic code-review plugin / docs: https://code.claude.com/docs/en/code-review
- langchain-ai/open-swe: https://github.com/langchain-ai/open-swe
