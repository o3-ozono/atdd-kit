# Plan: acceptance test の「計画前 feasibility 実地探索」を正典フローとして確立する

<!-- 2-5 分粒度のタスク行と verification 行を交互に配置する（superpowers writing-plans 形式）。
     各タスクは単一の操作に限定し、verification で完了条件を即確認できる粒度にする。 -->

## Implementation

### Story 1: 既存資産の棚卸し

- [ ] `docs/methodology/`（atdd-guide / test-mapping / definition-of-ready / test-execution-policy 等）を通読し、AT 計画・検証に関する既存記述と doctrine の接続点・非矛盾点を箇条書きでメモする
- [ ] verify: 棚卸しメモに各既存 doc のファイル名と「doctrine との関係（相互参照すべき箇所）」が列挙されている

- [ ] `skills/launching-preview` / `skills/running-atdd-cycle` / `skills/writing-plan-and-tests` の SKILL.md を読み、feasibility プローブを差し込める統合点（AT を `[planned]` 確定にする前段）を特定する
- [ ] verify: doctrine 草案の「フロー統合点」節に、3 skill のどこに何を差し込むかが具体名で書かれている

- [ ] addon（ios / web）の MCP・preview 構成（`addons/*/addon.yml`）を確認し、GUI=実操作プローブの具体手段が addon 供給であることを裏付ける
- [ ] verify: doctrine の「ツール抽象」節が addon 供給の具体例（Playwright CLI / Xcode MCP）を抽象の下位実装として参照している

### Story 2: 外部調査による doctrine 根拠の収集

- [ ] deep-research ハーネスで agentic E2E / self-verifying AC / browser・mobile UI agent / API 探索→契約検証 を fan-out 調査し、「計画前 feasibility 実地探索」採用の有無・パターン・落とし穴を抽出する
- [ ] verify: doctrine の根拠節に外部事例の傾向・採用パターン・落とし穴が一次情報リンク付きで 3 件以上要約されている

### Story 3: AT feasibility 正典ドキュメントの執筆

- [ ] `docs/methodology/acceptance-test-feasibility.md` を新規作成し、冒頭に `> **Loaded by:**` メタコメント（参照 skill 列挙）を置く
- [ ] verify: ファイルが存在し、1 行目近傍に `> **Loaded by:**` が含まれる

- [ ] 「普遍ルール」節を書く（技術スタック非依存の計画前 feasibility 実地探索原則。GUI=実操作／非 GUI=実 API call の二分岐と判定基準）
- [ ] verify: 普遍ルール節に GUI／非 GUI 二分岐と判定基準が明記されている

- [ ] 「フロー統合点」節を書く（6-step flow のどこに差し込むか。AT を `[planned]` 確定にする前に feasibility プローブを通す）
- [ ] verify: フロー統合点節が `writing-plan-and-tests` と `[planned]` への言及を含む

- [ ] 「ユーザーゲート」節を書く（実現可能ルート不在／不安定時に計画段階でユーザー判断を仰ぐゲート設計）
- [ ] verify: ユーザーゲート節が「ルート不在／不安定 → 計画段階でユーザー判断」のゲート条件を記述している

- [ ] 「ツール抽象」節を書く（feasibility プローブ抽象。addon が具体手段を供給し特定ツールに密結合しない）
- [ ] verify: ツール抽象節が「プローブ」抽象と addon 供給・非密結合を明記している

- [ ] 「autopilot との整合」節を書く（design phase で feasibility プローブを走らせ Gate ②（設計承認）に反映）
- [ ] verify: autopilot 整合節が design phase と Gate ②（設計承認）への反映を記述している

- [ ] 既存 methodology doc（atdd-guide / test-mapping / definition-of-ready / test-execution-policy）への相互参照リンクを doctrine 内に張り、`docs/methodology/README.md` の Documents 表に新 doc 行を追加する
- [ ] verify: doctrine が 4 既存 doc を相対リンクで参照し、README 表に `acceptance-test-feasibility.md` 行がある

## Testing

- [x] `tests/acceptance/AT-312.bats` を新規作成し、doctrine の必須セクション存在・`> **Loaded by:**` メタ・既存 doc 相互参照健全性・README 登録・外部調査根拠・双方向逆参照を構造的に検証する AT を実装する
- [x] verify: `bats tests/acceptance/AT-312.bats` が green（acceptance-tests.md の AT-312-01〜08 に対応、25 tests）

## Finishing

- [ ] `CHANGELOG.md` の `### Added` に doctrine 追加エントリを記載し、`.claude-plugin/plugin.json` の version を minor bump する（新 doc 追加 = minor、DEVELOPMENT.md 準拠）
- [ ] verify: CHANGELOG の最上位リリース見出しと plugin.json の version が一致し、新 doc エントリが Added にある

- [ ] ドキュメント整合性チェック（doctrine が既存正典と矛盾せず、相互参照が双方向に破綻していない）
- [ ] verify: 全 bats suite が green かつ doctrine の参照先ファイルがすべて実在する
