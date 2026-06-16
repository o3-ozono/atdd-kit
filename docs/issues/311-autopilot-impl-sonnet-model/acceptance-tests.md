# Acceptance Tests: autopilot impl phase の Sonnet 指定を Workflow スクリプトに恒久反映

<!-- AT lifecycle: planned → draft → green → regression
     各エントリには状態マーカー [planned] / [draft] / [green] / [regression] を付与する。
     状態は実装の進行に合わせて更新する。 -->

対象スイート: `tests/test_autopilot_skill.bats`（SKILL_FILE = `skills/autopilot/SKILL.md`）
不変条件アサート方針（#289）: 行数・モデル名はこの変更の固定仕様そのもの（point-in-time 値ではない）ため pin 可。出現回数 6 / 定数文字列 / `freeze:anchor` 不付与はいずれも仕様不変条件。

## AT-001: MODEL 定数の Sonnet デフォルト定義（AC1 / US2）

- [ ] [planned] AT-001: impl phase に限定して Sonnet を選ぶ MODEL 定数が Workflow スクリプトに存在する
  - Given: `skills/autopilot/SKILL.md` の Workflow スクリプト本文
  - When: `const MODEL = PHASE === 'impl' ? 'sonnet' : undefined` を固定文字列で検索する
  - Then: 該当行がちょうど 1 件存在し、`const PHASE = A.phase` の直後（より大きい行番号で隣接）に位置する

## AT-002: 6 つの impl agent への model: MODEL 付与（AC2 / US1）

- [ ] [planned] AT-002: impl phase ループ内の 6 つの agent() 呼び出しすべてに `model: MODEL` が付与されている
  - Given: SKILL.md の impl agent ラベル `gen:` / `review:` / `at-gate:` / `coverage:` / `audit:` / `rails:`
  - When: 各ラベル（`` label: `gen: `` 等）を含む行に `model: MODEL` が含まれるか検査し、`model: MODEL` の総出現回数を数える
  - Then: 6 つのラベル行すべてに `model: MODEL` が含まれ、SKILL.md 全体での `model: MODEL` 出現回数がちょうど 6 である

## AT-003: freeze:anchor は model 不付与（AC3 / US2）

- [ ] [planned] AT-003: design phase / orchestrator glue の `freeze:anchor` には `model` が付与されていない
  - Given: SKILL.md の `freeze:anchor` ラベルを持つ agent() 呼び出し（両 phase で走る glue）
  - When: `freeze:anchor` を含む行に `model:` が含まれるか検査する
  - Then: その行に `model:` が含まれず、design phase / orchestrator がセッションモデルを継承することが固定される

## AT-004: SKILL.md 行数バジェット ≤ 280 維持（AC4 / CS1）

- [ ] [planned] AT-004: 変更後も SKILL.md の総行数が 280 行以下を維持する
  - Given: 変更後の `skills/autopilot/SKILL.md`
  - When: `wc -l < skills/autopilot/SKILL.md` で総行数を取得する
  - Then: 行数が 280 以下であり、既存の line budget pin（≤ 280）も非回帰のまま green である（3 回目の raise 禁止に抵触しない）

## ライフサイクル例

| 状態 | 意味 |
|------|------|
| [planned] | テスト設計済み・未実装 |
| [draft] | 実装中・まだ通過していない |
| [green] | テスト通過済み |
| [regression] | リグレッション対象として継続監視中 |
