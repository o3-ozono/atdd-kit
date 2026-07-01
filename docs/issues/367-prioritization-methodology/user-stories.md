# User Stories: 機能優先度の方法論 doc を新設（#367）

## Functional Story

<!-- 機能要求を persona 抜き Connextra 形式で記述する。1 ストーリー = 1 ユーザーゴール。 -->

### US-1: 優先度方法論 doc の新設

**I want to** `docs/methodology/prioritization.md` に 5 段階（MUST/SHOULD/WANT/次回以降/破棄）・2 軸（効き・工数）・anti-pattern・破棄の扱いを明文化した方法論 doc を持つ,
**so that** 機能要件の優先度判断がセッションごとにばらつかず、一貫した基準で分類できる.

### US-2: 効きと工数の 2 軸分離

**I want to** 効き（本質課題への解決力）と工数（今回の実装コスト）を独立した軸として評価できるフレームを doc 内に持つ,
**so that** 「効くけど大変だから WANT に下げる」という工数を効きに混ぜた誤用を避け、効く機能が工数理由で後回しにされない.

### US-3: 破棄機能のテーブル内保存

**I want to** 破棄した機能要件を PRD のコア機能テーブルから削除せず、`破棄` ラベルと理由を付けて残せる運用を doc で規定する,
**so that** 別セッション・別担当者が同じ機能を再提案したとき、「なぜ一度破棄したか」の判断根拠をその場で参照でき、ゾンビ復活を防げる.

### US-4: defining-requirements スキルからの参照接続

**I want to** `defining-requirements` スキルの機能要件パートが本 doc の 5 段階・2 軸フレームを参照できる接続（loaded-docs リストへの追記 + SKILL.md への参照コメント）を持つ,
**so that** 優先度分類時に明文化された基準を AI が参照でき、属人的・場当たり的な判定を避けられる.

## Constraint Story (Non-Functional)

<!-- 非機能要求（NFR）を Story 形式で表現する（Pichler 2013）。 -->

### CS-1: DSDM/MoSCoW 一次情報への忠実性

**I want to** MoSCoW（DSDM 原典）を一次情報として忠実に扱い、原典から逸脱する派生・拡張部分を `[独自]` で明示した状態,
**so that** 標準フレームと atdd-kit 独自拡張の境界が読み手に明確になり、方法論の出所が追跡可能になる.

### CS-2: BATS による構造検証ピン

**I want to** `prioritization.md` の必須セクション（5 段階定義テーブル・2 軸定義・anti-pattern・破棄の扱い）の存在を検証する BATS ピンが CI に組み込まれている状態,
**so that** doc の骨格セクションが欠落したまま変更されても CI で検出でき、方法論の完全性が退行しない.

### CS-3: Versioning ルール準拠

**I want to** 本変更が CHANGELOG.md の更新と `.claude-plugin/plugin.json` の patch version bump を伴う状態,
**so that** DEVELOPMENT.md の Versioning ルールを満たし、プラグイン更新通知システムが正しく動作する.
