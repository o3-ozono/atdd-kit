# User Stories: autopilot 時の壁打ち・確認対話を「判断が必要な点のみ」に省力化する

## Functional Story

### US-1: 質問は「人間にしか決められない点」のみ

**I want to** autopilot 実行中の人間向け質問が「人間にしか決められない点」（設計判断が分かれるトレードオフ・割り切り、スコープの増減、Outcome の合否基準）のみに絞られている,
**so that** 自明な内容への応答に時間を取られず、判断が必要な点だけに集中できる.

### US-2: ドラフトは一括提示・固定ゲートで一括承認

**I want to** autopilot 中のドラフトが全セクション一括で提示され、承認・差し戻しを固定ゲート（PRD 承認 / 設計承認 / merge）でまとめて各 1 回行える,
**so that** 自明セクションへの逐次 ok 応答が 0 回になり、半自動運転の省力効果が要件定義フェーズでも失われない.

### US-3: 指針は orchestrator 側に明文化され対話全般に適用

**I want to** この対話省力化指針（聞くべき / 聞かない の区別）が `skills/autopilot/SKILL.md` の Gate 実行指示として明文化され、Gate ① の壁打ちに加え design ゲート提示等の autopilot 中の人間向け対話全般に適用される,
**so that** どのゲート内対話でもマイクロ確認が削減され、一貫した省力運用ができる.

## Constraint Story (Non-Functional)

### CS-1: 人間ゲートは AL-1 の 3 点固定のまま不変

**I want to** 人間ゲートが AL-1 の 3 点（PRD 承認 / 設計承認 / merge）のまま増減せず、削減対象がゲート間・ゲート内のマイクロ確認に限定されている,
**so that** 省力化によって人間の統制点（承認・差し戻しの機会）が損なわれない.

### CS-2: 通常フローの対話設計は不変（C1 原則）

**I want to** `defining-requirements` の「Each section step is one question at a time」が通常フロー（非 autopilot）では維持され、under autopilot でオーバーライドされる旨が autopilot SKILL.md 側にのみ明記される,
**so that** flow skill 本体を autopilot のために恒久変更しない C1 原則が守られ、通常フローの対話設計が影響を受けない.

### CS-3: 指針文言は BATS pin で構造検証される

**I want to** 指針文言の存在が `tests/test_autopilot_skill.bats` の BATS pin で構造検証されている,
**so that** 将来の SKILL.md 編集で指針が欠落・改変されてもテストで即座に検知できる.
