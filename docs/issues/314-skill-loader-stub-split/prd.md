# PRD: 全 Skill の SKILL.md ローダー stub 分割（行数バジェット恒久対策）— research

## Problem

複数 Skill（特に autopilot）が SKILL.md 行数バジェット pin に張り付き、機能追加のたびに上限衝突する。#311 で autopilot は 280/280 ぴったり着地、以後 1 行追記不可（DEVELOPMENT.md で 3 回目の pin raise 禁止）。個別 Issue で対症的に分割するのでなく、全 Skill 横断の標準パターンを確立したい。

## Why now

autopilot が 280/280 で頭打ち（#326 のような機能追加が将来また budget 衝突）。autopilot が #283/#304 で「ローダ stub + `docs/methodology` 分離」の先行事例を確立済み＝一般化の土台がある。

## Outcome

全 Skill に適用可能なローダー stub 分割の標準パターンと適用計画が methodology doc（design doc 相当）として確立される。**実装（実際の分割）は本 research の結論を受けた別 Issue** で行う。

## What（調査 → 方針確立）

1. **標準分割パターン設計**: SKILL.md = 薄いローダ/エントリ、本体詳細 → `docs/methodology/<skill>-*.md`（autopilot 先例に統一）。stub に残すもの／分離するものの基準。
2. **全 Skill 棚卸し表**: 各 Skill の現行行数・pin 上限・budget 逼迫度ランキング・分割優先度。
3. **i18n / language policy・既存 AT 影響分析**: 分割が string-pin 系 AT・テンプレート同期・行数 pin テストに与える影響と対応方針。
4. **#304 / autopilot との関係**: autopilot を reference implementation に位置づけ、#304（個別分割・merge 済）を先行事例化。
5. **DEVELOPMENT.md line-budget ルール整合**: 分割後の pin 運用（stub budget・分離先 budget の pin 方法）。
6. **適用計画**: 優先度順の適用順序（実装は別 Issue 群）。

成果物 = `docs/methodology/skill-loader-split.md`（仮）。構造 bats でピン（English-only / README 登録 / Loaded-by メタ）。

## Non-Goals

- 各 Skill の実際の分割実装（本 Issue は方針＋計画まで・実装は派生 Issue）
- autopilot の再分割（#304 完了済・先行事例として参照のみ）
- DEVELOPMENT.md line-budget ルール自体の改定（整合確認まで）

## Open Questions

1. 分割コンテンツ置き場所 → ✅ (a) `docs/methodology/<skill>-*.md`
2. スコープ → ✅ (a) パターン+棚卸し+影響分析+適用計画（実装は別 Issue）
3. 残（research 実施中に確定）: 逼迫度しきい値・適用優先度の具体
