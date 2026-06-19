# Plan: フロー完了時の自動振り返り（メトリクス + フィードバック抽出）

<!-- 2-5 分粒度のタスク行と verification 行を交互に配置する（superpowers writing-plans 形式）。
     各タスクは単一の操作に限定し、verification で完了条件を即確認できる粒度にする。 -->

## Implementation

- [ ] `templates/docs/issues/retrospective.md` を新規作成し、5 メトリクス区分（対話量 / コスト / 前回比 / 摩擦点 / 改善候補）の見出し骨格を置く
- [ ] verify: テンプレに 5 区分の見出しがすべて存在する

- [ ] `scripts/retrospective.sh` を新規作成（引数: issue 番号 / PR 番号、stdout に retrospective.md 本文を出力するスタブ）
- [ ] verify: `scripts/retrospective.sh --help` が usage を返す

- [ ] token / cost 取得を実装（primary = headless `<worker-out>.json` の `usage`/`total_cost_usd` を read-only 読み取り、autopilot は入れ子 Workflow dir で subagent 総量を加算、欠落時 best-effort 注記。`autopilot-log.jsonl` はトークンを持たないため除外）
- [ ] verify: headless ログ有 / 無の両ケースで非空の出力（有=数値、無=best-effort 注記）が得られる

- [ ] 対話量（ターン数・フェーズ別内訳）の集計を実装（ターン数 = transcript `<munged-cwd>/<session-id>.jsonl` の `type:"user"`/`"assistant"` レコード数、フェーズ内訳 = autopilot-log.jsonl の `step`、手動は best-effort、すべて read-only）
- [ ] verify: 出力にターン数とフェーズ別内訳行（autopilot）または best-effort 注記（手動）が含まれる

- [ ] 直近マージ PR を `gh` で特定して diff 行数を取得し、トークン / diff 行数の正規化比を算出する（token 欠落時は比率を best-effort 注記に degrade）
- [ ] verify: 正規化比フィールドが数値、または token 欠落時に best-effort 注記が出力される

- [ ] 摩擦点抽出を実装（永続シグナル起点 = `autopilot-log.jsonl` の `verdict:"FAIL"` step ＋ `gh issue/pr view --comments`、in-memory `rejectionFindings` は不採用、手動 flow は best-effort 注記、すべて read-only）
- [ ] verify: 出力でゲート種別（requirements / design / merge）に分類される

- [ ] skill-fix 候補のサマリ列挙を実装する（自動起票は行わない）
- [ ] verify: 候補セクションがあり、起票コマンドが実行されない

- [ ] 横断 JSONL `docs/retrospective-log.jsonl` への append-only 追記を実装（安定キー schema: issue / pr / tokens / diff_lines / normalized_ratio / friction / feedback_candidates）
- [ ] verify: 追記後に valid JSONL（1 行 = 1 オブジェクト）になっている

- [ ] `skills/merging-and-deploying/SKILL.md` 末尾に振り返り呼び出しステップ（retrospective の唯一の起動点）を追加。express スキップは「express は merging-and-deploying を経由しない＝構造的スキップ」と明記し、`if 非 express` 分岐に依存しない旨を書く
- [ ] verify: SKILL に retrospective 起動点 ＋ express 構造的スキップの根拠が明記され、express/SKILL.md に retrospective 起動が無いことを含め BATS pin が green

- [ ] 全チャネル同期（ターミナル + Issue / PR コメントに同内容を出す）を skill ステップに明記する
- [ ] verify: skill ステップに両チャネル出力が明記されている

## Testing

- [ ] `tests/test_retrospective_skill.bats` を作成（merging-and-deploying SKILL 構造 pin: 呼び出しステップ・express スキップ・全チャネル同期）
- [ ] verify: green

- [ ] `tests/test_retrospective_script.bats` を作成（`retrospective.sh` の出力契約: 各メトリクス・正規化比・JSONL valid・自動起票なし、＋ CS-1 軽量性 pin: `claude `/`Workflow` grep 0・`read -p`/`AskUserQuestion` 0・`gh` スタブ下でローカル集計部 5 秒以内）
- [ ] verify: green（軽量性しきい値含む）

- [ ] `tests/acceptance/AT-309-*.bats` を作成（受け入れシナリオ。緑化は running-atdd-cycle が担当）
- [ ] verify: draft → green に進む

## Finishing

- [ ] `scripts/README.md` に `retrospective.sh` を追記する
- [ ] verify: README に項目がある

- [ ] `templates/docs/issues/README.md` に `retrospective.md` を追記する
- [ ] verify: README に項目がある

- [ ] CHANGELOG `### Added` に項目追加 + `.claude-plugin/plugin.json` を minor bump（新機能）
- [ ] verify: plugin.json version が CHANGELOG 先頭リリース見出しと一致

- [ ] ドキュメント整合性チェック
- [ ] verify: 関連 README / CHANGELOG が変更内容と整合している
