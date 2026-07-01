# Plan: docs/methodology — 要件抽出の技法カタログ（Pre-mortem / Job Story / One question at a time / Out-of-scope question）を一次情報付きで新設

<!-- 2-5 分粒度のタスク行と verification 行を交互に配置する（superpowers writing-plans 形式）。
     各タスクは単一の操作に限定し、verification で完了条件を即確認できる粒度にする。 -->

<!-- 対応 US: FS-1 4技法カタログ / FS-2 統一フィールド / FS-3 共通原則 doc / FS-4 SKILL マッピング /
     CS-1 一次情報忠実性 / CS-2 構造検証 BATS / CS-3 version+CHANGELOG。
     doc ファイル名は PRD「実装フェーズで確定」に従い本 Plan で kebab-case に確定する。 -->

## Implementation

### ディレクトリと共通原則 doc（FS-3 / CS-1）

- [ ] `docs/methodology/elicitation-techniques/` ディレクトリを作成する
- [ ] verify: `test -d docs/methodology/elicitation-techniques`

- [ ] `common-principles.md` を作成し、3 共通原則（対話のキャッチボールで埋める / 上位工程の責務を侵さない / 対話ログを残す）を記述し、各原則に `[独自整理]` を明示する
- [ ] verify: `grep -c '\[独自整理\]' docs/methodology/elicitation-techniques/common-principles.md` が 3 以上を返す

### 4 技法 doc（FS-1 / FS-2 / CS-1）

- [ ] `pre-mortem.md` を作成し、統一 5 フィールド（目的 / 問いの型 / 適用先マッピング / 一次情報 / 例）を記述する。一次情報 = Gary Klein, "Performing a Project Premortem", Harvard Business Review, Sep 2007。適用先 = `defining-requirements` Constraints 節・Open Questions 節
- [ ] verify: `pre-mortem.md` に `## 目的` `## 問いの型` `## 適用先マッピング` `## 一次情報` `## 例` の 5 見出しが全て存在する

- [ ] `job-story.md` を作成し、統一 5 フィールドを記述する。一次情報 = Alan Klement, "Replacing the User Story with the Job Story", JTBD blog, Nov 2013。適用先 = `defining-requirements` ユーザーニーズ（Problem / Outcome 節）
- [ ] verify: `job-story.md` に統一 5 見出しが全て存在する

- [ ] `one-question-at-a-time.md` を作成し、統一 5 フィールドを記述する。一次情報 = Steve Krug, *Rocket Surgery Made Easy*, New Riders, 2010。適用先 = 全 skill の対話共通ルール（セッション横断）
- [ ] verify: `one-question-at-a-time.md` に統一 5 見出しが全て存在する

- [ ] `out-of-scope-question.md` を作成し、統一 5 フィールドを記述する。一次情報 = Jeff Patton, *User Story Mapping*, O'Reilly, 2014。適用先 = `defining-requirements` Non-Goals 節；`batch-discovery` スコープ境界確認
- [ ] verify: `out-of-scope-question.md` に統一 5 見出しが全て存在する

- [ ] 各技法 doc の「目的」節に原典忠実な記述を置き、独自解釈を加える箇所には `[独自]` を付す（無ければ付さない）。各技法 doc に `common-principles.md` への相互リンクを追加する
- [ ] verify: 各技法 doc に `common-principles.md` への相対リンクが 1 つ以上存在する

### カタログ README（FS-1 / FS-2 のインデックス）

- [ ] `docs/methodology/elicitation-techniques/README.md` を作成し、4 技法 + 共通原則の一覧表（技法名 / 一次情報 / 適用先 / doc リンク）を置く
- [ ] verify: `README.md` に 4 技法 doc と `common-principles.md` への 5 リンクが全て存在する

### SKILL.md マッピング参照（FS-4）

- [ ] `skills/defining-requirements/SKILL.md` に、Constraints/Open Questions → pre-mortem、Problem/Outcome → job-story、Non-Goals → out-of-scope-question、対話共通 → one-question-at-a-time のマッピング参照（節名 → doc 相対リンク）を追加する。詳細手順・一次情報・例は doc 側に委ね SKILL.md には持ち込まない
- [ ] verify: `defining-requirements/SKILL.md` に `docs/methodology/elicitation-techniques/` への相対リンクが存在し、`wc -l` が 200 行以下（`test_defining_requirements_skill.bats` line budget pin）

- [ ] `skills/batch-discovery/SKILL.md` に、スコープ境界確認 → out-of-scope-question、対話共通 → one-question-at-a-time のマッピング参照を追加する
- [ ] verify: `batch-discovery/SKILL.md` に `docs/methodology/elicitation-techniques/` への相対リンクが存在し、既存 batch-discovery line budget pin を超えない

## Testing

- [ ] `tests/test_elicitation_techniques_docs.bats` を作成し、(a) 4 技法 doc + `common-principles.md` + `README.md` の存在、(b) 各技法 doc の統一 5 フィールド見出しの存在、(c) `defining-requirements`/`batch-discovery` SKILL.md からカタログへのリンク存在、を検証する
- [ ] verify: `bats tests/test_elicitation_techniques_docs.bats` が全 green

- [ ] 既存 skill line budget BATS（`test_defining_requirements_skill.bats` / `test_batch_discovery_skill.bats`）が SKILL.md 追記後も green であることを確認する
- [ ] verify: `bats tests/test_defining_requirements_skill.bats tests/test_batch_discovery_skill.bats` が全 green

## Finishing

- [ ] `docs/methodology/README.md` に新カタログへの参照を追記する（DEVELOPMENT.md「Directory READMEs」規約）
- [ ] verify: `docs/methodology/README.md` に `elicitation-techniques` への参照が存在する

- [ ] `.claude-plugin/plugin.json` の patch version を bump し、`CHANGELOG.md` に本変更エントリ（Keep a Changelog 形式）を追加する
- [ ] verify: plugin.json の version が CHANGELOG.md 最上位リリース見出しと一致する

- [ ] `tests/README.md` に新 BATS ファイルを追記する（DEVELOPMENT.md「Directory READMEs」規約）
- [ ] verify: `tests/README.md` に `test_elicitation_techniques_docs` への参照が存在する

- [ ] ドキュメント整合性チェック
- [ ] verify: 関連ドキュメント（methodology README / tests README / CHANGELOG / plugin.json）が変更内容と整合している
