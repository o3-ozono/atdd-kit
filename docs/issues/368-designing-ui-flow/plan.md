# Plan: 新スキル `designing-ui` + 方法論 doc 2 本 — UI/UX 設計フロー

<!-- 2-5 分粒度のタスク行と verification 行を交互に配置する（superpowers writing-plans 形式）。
     各タスクは単一の操作に限定し、verification で完了条件を即確認できる粒度にする。 -->

## Implementation

### スキル本体（US-1, US-7, US-10, CS-1, CS-2, CS-3）

- [ ] `skills/designing-ui/` ディレクトリを作成し `SKILL.md` に YAML frontmatter（`name: designing-ui` / `description:` は "Use when" 起点のトリガー条件のみ）を書く
- [ ] verify: `grep '^name: designing-ui' skills/designing-ui/SKILL.md` が一致し、`description` が `Use when` で始まる（DEVELOPMENT.md Skill Description Field Rules 準拠・ワークフロー要約を含まない）

- [ ] SKILL.md に Session Start Check セクションを追記する（core skill 慣習に沿う）
- [ ] verify: `grep -q 'Session Start Check' skills/designing-ui/SKILL.md`

- [ ] SKILL.md に 5 フェーズ順序（UI 要件確認 → 情報設計 → ワイヤーフレーム → ビジュアル方針 → 実装連携）を引き出し型（pull）対話として明記する
- [ ] verify: 5 フェーズ名が SKILL.md に順に出現し、pull/引き出し型の記述が存在する

- [ ] SKILL.md の成果物定義表に 5 成果物パス（`docs/issues/<NNN>/ui-requirements.md` / `information-architecture.md` / `wireframes.md` / `visual-policy.md` / `implementation-handoff.md`）を記述する
- [ ] verify: 5 成果物パスすべてが SKILL.md に出現する

- [ ] SKILL.md に中核思想（「何を出すか=プロダクト側」「どう見せるか=プラットフォーム作法(HIG/Material/Baseline)」「[独自] 明示」「アクセシビリティ=横串: WAI-ARIA/WCAG 2.2/JIS Z 8520」）を書く
- [ ] verify: `[独自]`・`WAI-ARIA`・`WCAG`・`JIS Z 8520`・`HIG`・`Material` 各トークンが SKILL.md に出現する

- [ ] SKILL.md に責任境界（コード実装・AT 実装・Plan 作成は担わない／`writing-design-doc` は技術アーキテクチャ・`designing-ui` は画面設計の工程駆動）を Responsibility Boundary として書く
- [ ] verify: `writing-design-doc` への言及と「AT/Plan を生成しない」旨が SKILL.md に存在する

- [ ] SKILL.md に Integration セクション（Upstream: `defining-requirements` / Downstream: `writing-plan-and-tests`）を追記する
- [ ] verify: `grep -q '^## Integration' skills/designing-ui/SKILL.md` かつ Upstream/Downstream 双方が記述される

### 方法論 doc1（US-8）

- [ ] `docs/methodology/designing-ui-doc1.md` を作成し UI 要件・情報設計・ワイヤーフレームの規律（骨格・配置・画面遷移まで／装飾なし）を書く
- [ ] verify: `[ -f docs/methodology/designing-ui-doc1.md ]` かつ「装飾を含めない」旨とワイヤー骨格規律が本文に存在する

- [ ] doc1 に「画面の単位は情報設計フェーズでワイヤー前に確定する」規律と、ゲシュタルト原則を doc2 文脈へ位置づける記述を書く
- [ ] verify: 情報設計フェーズでの画面単位確定規律が doc1 に存在する

### 方法論 doc2（US-9, CS-2）

- [ ] `docs/methodology/designing-ui-doc2.md` を作成しビジュアル方針・実装連携の規律（ゲシュタルト/Typography/Color/Spacing/Component 選択、プラットフォーム別作法の選択意思決定）を書く
- [ ] verify: `[ -f docs/methodology/designing-ui-doc2.md ]` かつ HIG/Material Design/Baseline の選択記述が存在する

- [ ] doc2 に Design system 再利用規律とアクセシビリティ実装連携（WAI-ARIA ロール・WCAG 2.2 達成基準・JIS Z 8520 注記の書き方）を書く
- [ ] verify: `WAI-ARIA`・`WCAG 2.2`・`JIS Z 8520` が doc2 本文に出現する

## Testing

- [ ] 構造検証 BATS（`tests/test_designing_ui_skill.bats`）を新規追加し、`skills/designing-ui/SKILL.md` の存在・`name` 一致・`description` が Use when 起点・Integration セクション存在を pin する（CS-5, CS-3, US-10）
- [ ] verify: `bats tests/test_designing_ui_skill.bats` が green（SKILL.md 構造 pin が通過）

- [ ] 同 BATS に `docs/methodology/designing-ui-doc1.md` / `docs/methodology/designing-ui-doc2.md` の存在確認 pin を追加する（CS-5）
- [ ] verify: doc1/doc2 存在確認 pin を含む `bats tests/test_designing_ui_skill.bats` が green

- [ ] スキル成果物 5 パスと中核思想トークン（`[独自]` / アクセシビリティ規格名）が SKILL.md に存在することを pin するコンテンツ検証を BATS に追加する（US-2〜US-6, CS-1, CS-2）
- [ ] verify: 該当 pin を含む `bats tests/test_designing_ui_skill.bats` が green

## Finishing

- [ ] `.claude-plugin/plugin.json` の version を minor bump（新スキル追加 = minor）し `CHANGELOG.md` の `[Unreleased]` に本 Issue の Added エントリを記述する（CS-6）
- [ ] verify: plugin.json の version が CHANGELOG 最上位リリース見出しと一致し、`bats tests/test_check_plugin_version.bats tests/test_changelog_format.bats` が green

- [ ] `skills/README.md` に `designing-ui` を、`docs/methodology/README.md` に doc1/doc2 を追記する（DEVELOPMENT.md Directory READMEs 規約）
- [ ] verify: `grep -q 'designing-ui' skills/README.md` かつ doc1/doc2 が `docs/methodology/README.md` の一覧に出現する

- [ ] ドキュメント整合性チェック（SKILL.md の成果物パス・doc 参照・命名が PRD の承認済み命名と一致）
- [ ] verify: 関連ドキュメントが変更内容と整合し、全 BATS スイート（`scripts/run-tests.sh --all`）が green
