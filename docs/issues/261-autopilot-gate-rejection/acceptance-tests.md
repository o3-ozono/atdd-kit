# Acceptance Tests: autopilot 設計ゲート差し戻しの未規定挙動 — コメントを再実行へ運ぶ配管の不在と部分承認の扱い

<!-- AT lifecycle: planned → draft → green → regression
     各エントリには状態マーカー [planned] / [draft] / [green] / [regression] を付与する。
     状態は実装の進行に合わせて更新する。 -->

実行コマンド: `bats tests/test_autopilot_skill.bats`（SKILL.md は宣言的成果物のため、AT は BATS の静的 pin として実装する — #252/#256 で導入済みの parse / phase ガード pin と同方式）。

## AT-001: 差し戻しコメントが iteration 1 の generate に届く配管（US-1）

- [x] [green] AT-001: `rejectionFindings` args 配管が存在し、iteration 1 の generate プロンプトへ verbatim で到達する
  - Given: `skills/autopilot/SKILL.md` の埋め込み Workflow script
  - When: BATS pin が script 本文を検査する
  - Then: args parse 部に `rejectionFindings` を受け取る `const REJECTION_FINDINGS` 束縛が存在し、step ループ内の `prevFindings` 初期化が `REJECTION_FINDINGS` を参照する（`null` 固定初期化が `REJECTION_FINDINGS` シードに置き換わっており、既存の `JSON.stringify(prevFindings)` 埋め込み分岐で iteration 1 の generate プロンプトに verbatim 到達する）

## AT-002: rejectionFindings の fail-closed バリデーション（US-1, CS-1）

- [x] [green] AT-002: 不正な `rejectionFindings` は 1 イテレーションも走らせず throw する
  - Given: 埋め込み Workflow script の args parse 部（FREEZE より前）
  - When: BATS pin が script 本文を検査する
  - Then: (a) 配列でない `rejectionFindings` で throw、(b) 非空文字列の `evidence_ref` を欠く要素で throw（AL-4）、(c) `phase !== 'design'` での `rejectionFindings` 指定で throw — の 3 ガードが存在し、いずれも `freeze:anchor` より前に位置する

## AT-003: priority 既定値 0（blocker）の fail-safe 正規化（US-1）

- [x] [green] AT-003: priority 無指定の差し戻し finding は blocker として扱われる
  - Given: `prevFindings` への `REJECTION_FINDINGS` シード処理
  - When: BATS pin が script 本文を検査する
  - Then: `prevFindings` の初期化（シード）行が既存の `priorityOf` を参照している — すなわち既存の正規化（absent / non-numeric priority → 0 = blocker）がシード時に適用される（grep で静的に pin 可能な正の形のアサーション。Plan の初期化行設計 `prevFindings = REJECTION_FINDINGS ? REJECTION_FINDINGS.map((f) => ({ ...f, priority: priorityOf(f) })) : null` と対応）

## AT-004: 部分承認は承認ではない — 全体差し戻し規律の明文化（US-2）

- [x] [green] AT-004: 非 'ok' 応答が成果物セット全体の差し戻しとして扱われる規律が SKILL.md Flow 節にある
  - Given: SKILL.md の Flow 節 step 3（design-approval gate）
  - When: BATS pin が SKILL.md を検査する
  - Then: 「A は ok / B は要修正」等の部分承認を含む非 'ok' 応答を成果物セット全体の差し戻しとして扱い（部分承認は承認ではない）、impl phase へ進まないことが明記され、`args = { issue: NNN, phase: 'design', rejectionFindings: [...] }` での再呼び出しが指示されている

## AT-005: セクション単位 finding 分割の明文化（US-3）

- [x] [green] AT-005: 複合コメントのセクション単位分割規律が SKILL.md にある
  - Given: SKILL.md の Flow 節 step 3（design-approval gate）
  - When: BATS pin が SKILL.md を検査する
  - Then: 複合コメントをセクション単位で分割して N 件の finding にする（1 セクションの指摘 = 1 finding）こと、および各 finding の `evidence_ref` = 該当部分の人間コメント verbatim が明記されている

## AT-006: BATS pin が green でスイートに回帰なし（CS-1）

- [x] [green] AT-006: #261 で追加した pin を含む BATS スイート全体が pass する
  - Given: `tests/test_autopilot_skill.bats` に #261 の pin テストが追加されている
  - When: `bats tests/test_autopilot_skill.bats` を実行する
  - Then: 追加テストを含む全テストが pass し、既存 pin（#252 parse / issue ガード、#256 phase ガード、AL-2 pin 系、design-gate rejection 文言、line budget pin（#254: SKILL.md ≤ 260 行 — 行数超過はこのスイート実行で決定的に検出される））に回帰がない

## AT-007: スコープの限定（PRD Non-Goals）

- [x] [green] AT-007: 変更が SKILL.md の配管・規律明文化 + BATS pin + 対応 README 同期に限定されている
  - Given: 本 Issue のブランチ `fix/261-autopilot-gate-rejection` の差分
  - When: `git diff --name-only main` で変更ファイル一覧を取得する
  - Then: `skills/autopilot/SKILL.md` / `skills/README.md` / `tests/test_autopilot_skill.bats` / `tests/README.md` / `.claude-plugin/plugin.json` / `CHANGELOG.md` / `docs/issues/261-*` 以外の変更がなく（両 README は DEVELOPMENT.md「Directory READMEs」規約による同一 PR 内の必須同期）、特に `lib/autopilot_convergence.sh`・`skills/reviewing-deliverables/` 配下・Workflow ツール（harness）側の変更を含まない

<!-- 実装開始後は [planned] → [draft] に変更する -->
<!-- テストが通過したら [draft] → [green] に変更する -->
<!-- リグレッション対象になったら [green] → [regression] に変更する -->

## ライフサイクル例

| 状態 | 意味 |
|------|------|
| [planned] | テスト設計済み・未実装 |
| [draft] | 実装中・まだ通過していない |
| [green] | テスト通過済み |
| [regression] | リグレッション対象として継続監視中 |
