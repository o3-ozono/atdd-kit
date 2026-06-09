# Plan: autopilot 復活 — 自律収束ループ（converging-deliverables）

## Implementation

### 設計確定 + autopilot 専用 Iron Law（A / C / F4）

- [x] design-doc.md に「autopilot 専用 Iron Law」節と autopilot 定義（半自動運転 / 人間ゲート2点 / skill は autopilot モードのみ役割変更）を追記
- [x] verify: `grep -q 'autopilot 専用 Iron Law' design-doc.md` かつ定義文が含まれる
- [x] docs/methodology/autopilot-iron-law.md に AL-1〜6 + 「skill は autopilot モードのみ役割変更」原則を確定（草案済み）
- [x] verify: `grep -qE 'AL-1|AL-6' autopilot-iron-law.md` かつ原則文が含まれる
- [x] rules/atdd-kit.md に「autopilot モードでは autopilot 専用 Iron Law が標準を上書き」の1行参照を追加
- [x] verify: rules に `autopilot-iron-law` 参照があり、ファイルが ≤60 行
- [x] docs/methodology/README.md の Documents 表に autopilot-iron-law.md 行を追加
- [x] verify: README 表に該当行がある

### reviewing-deliverables verdict 構造化（B / F2 / C1）

- [x] reviewing-deliverables/SKILL.md の `AGG_SCHEMA` に `overall_correctness` と `findings[{priority,confidence,file,line_range,detail,evidence_ref}]` を後方互換追加し、Aggregate プロンプトに evidence_ref 必須を追記
- [x] verify: AGG_SCHEMA に新フィールドがあり、既存 `verdict`/`summary`/`byLens` が維持され、SKILL.md が ≤240 行

### converging-deliverables skill（E / F1-F4）

- [x] skills/converging-deliverables/SKILL.md を実装（frontmatter[description=trigger 条件] + 半自動運転 orchestrator 本体 + 埋め込み Workflow script）
- [x] verify: 満足オラクル AND / generate→review→fix / 既存 4 skill 呼び出し / 人間ゲート2点 / 安全レール / autopilot-iron-law 参照 を含む
- [x] lib/autopilot_convergence.sh を実装（sameness-detector[sha256] / stuck[window=3] / MAX_ITERATIONS / JSONL append、pure bash）
- [x] verify: `bash -n` 通過、sameness-detector が同一 fingerprint 2連続で非ゼロ終了
- [x] skills/README.md と lib/README.md に新ファイル行を追加
- [x] verify: 両 README に記載

## Testing

- [x] tests/test_converging-deliverables_skill.bats（Unit Test）を書く
- [x] verify: bats green。満足オラクル / 安全レール / 人間ゲート2点 / iron-law 参照 / 行数 / Upstream・Downstream のアサーション
- [x] tests/test_autopilot_convergence.bats（lib 挙動テスト）を書く
- [x] verify: bats green。sameness-detector(sha256 2連続で halt) / stuck(window=3) / JSONL append の挙動検証
- [x] tests/e2e/converging-deliverables.bats（Skill E2E Test）を書く
- [x] verify: 構造が他 e2e と整合（@covers / `_run_claude`）、`run-skill-e2e.sh --dry-run` で解決
- [x] tests/test_reviewing_deliverables_skill.bats に verdict 構造化アサーションを追加
- [x] verify: bats green

## Finishing

- [x] .claude-plugin/plugin.json を 3.5.0 → 3.6.0 に bump
- [x] verify: version = 3.6.0
- [x] CHANGELOG.md の [Unreleased] に追記（converging-deliverables / autopilot Iron Law / verdict 構造化）
- [x] verify: 該当 3 項目が記載
- [x] README.md / README.ja.md の skill 一覧に converging-deliverables を sync
- [x] verify: 両 README に新 skill が記載
- [ ] ドキュメント整合性チェック（reviewing-deliverables Workflow で最終レビュー）
- [ ] verify: 関連ドキュメントが変更内容と整合
