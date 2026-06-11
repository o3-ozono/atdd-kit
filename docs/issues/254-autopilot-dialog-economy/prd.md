# PRD: autopilot 時の壁打ち・確認対話を「判断が必要な点のみ」に省力化する

## Problem

- **現状**: autopilot Gate ①（requirements approval）の壁打ちが `defining-requirements` の通常フロー設計（6 セクションを 1 問ずつ逐次確認）のまま走る。#251 の初回実運用では自明なセクションにも毎回 ok 応答が必要だった。
- **それによって困ること**: autopilot の目的は人間の関与を 3 ゲートに絞ることなのに、ゲート内のマイクロ確認が削減されておらず、半自動運転の省力効果が要件定義フェーズで失われている。

## Why now

- #251 で実運用が始まり、ユーザーフィードバック（「判断に迷うところ、大事なところだけを聞くようにして」）が既に出ている。
- #252（収束ループのプロンプト欠陥修正、v3.7.2）が完了し、autopilot 運用本格化を阻む UX 上の最大の摩擦がこれになった。

## Outcome

- autopilot モードの人間向け対話で、質問が「人間にしか決められない点」のみになる:
  - 自明セクションへの逐次 ok 確認: **0 回**
  - ドラフトは全セクション一括提示、承認は固定ゲート（PRD 承認 / 設計承認 / merge）で **各 1 回**
- ゲート数は AL-1 の 3 点のまま不変。

## What

- autopilot モード時の対話省力化指針を `skills/autopilot/SKILL.md`（orchestrator 側の Gate 実行指示）に明文化する:
  - **聞くべき**: 設計判断が分かれる点（トレードオフ・割り切り）、スコープの増減、Outcome の合否基準など「人間にしか決められない」点
  - **聞かない**: Issue 本文・文脈から自明に導けるドラフト内容の逐次確認 → 一括提示し、固定ゲートでまとめて承認・差し戻し
- 適用範囲は autopilot 中の人間向け対話全般（Gate ① の壁打ちに加え、design ゲート提示等のゲート内対話を含む）。
- `defining-requirements` の「Each section step is one question at a time」は通常フローの設計として維持されることを autopilot SKILL.md 側で明記（under autopilot ではオーバーライドされる）。
- BATS pin（指針文言の存在を `tests/test_autopilot_skill.bats` で構造検証）。

## Non-Goals

- 人間ゲートの増減 — AL-1 の 3 点固定は不変。省くのは「ゲート間・ゲート内のマイクロ確認」のみ。
- `defining-requirements` ほか flow skill 本体への恒久変更 — C1 原則。指針は orchestrator（autopilot SKILL.md）側にのみ書く。
- 通常フロー（非 autopilot）の対話設計変更 — 1 問ずつの逐次確認は通常フローでは維持。

## Open Questions

- ~~指針の置き場所~~ → **A: `skills/autopilot/SKILL.md`** に決定（2026-06-10 Gate ① 承認時。flow skill 無変更で C1 と完全整合）。
- ~~適用範囲~~ → **autopilot 中の人間向け対話全般**に決定（2026-06-10 Gate ① 承認時）。
- 残課題なし。
