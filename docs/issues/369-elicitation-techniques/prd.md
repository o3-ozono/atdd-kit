# PRD: docs/methodology — 要件抽出の技法カタログ（Pre-mortem / Job Story / One question at a time / Out-of-scope question）を一次情報付きで新設

## Problem

`defining-requirements` / `batch-discovery` は要件を対話で引き出すスキルだが、「**具体的に何をどう問うか**」の再利用可能な技法カタログが方法論ドキュメントに存在しない。

現状の問題は二層ある。

1. **技法が skill 本文に埋もれている** — 問い方の指針が SKILL.md の散在する箇所に混在しており、一次情報（原典）を辿れない。技法ごとの適用タイミング・目的・問いの型が統一的に参照できない。
2. **SKILL.md の肥大化** — 技法の詳細手順・例・背景をスキル本体に持つと SKILL.md が膨らみ、スキル実行者が「どこに何があるか」を把握しにくくなる。

結果として、セッションごとに技法の使い方がブレ、引き出せる要件の質が安定しない。

## Why now

`defining-requirements` および `batch-discovery` の autopilot 実行頻度が増えており、技法のばらつきが蓄積する機会が増えている。また `docs/methodology/` ディレクトリが整備途上にあり、今が技法カタログを体系的に配置する最適なタイミングである。一次情報への参照が明示されないまま使い続けると、技法の変質（原典から乖離した独自解釈の定着）が起こる。

## Outcome

- `docs/methodology/elicitation-techniques/` 以下に 4 技法が**一次情報付きで**ドキュメント化されている
- 各技法ドキュメントに「どの skill のどの節で使うか」のマッピングが記載されている
- skill 本体（SKILL.md）は各技法への**マッピング参照（リンク）のみ**を持ち、詳細手順・例・背景は doc 側に委ねる分担が成立している
- `docs/methodology/elicitation-techniques/` の構造を検証する BATS ピンが追加されている
- CHANGELOG.md が更新され、`.claude-plugin/plugin.json` のバージョンが DEVELOPMENT.md Versioning 規約に従い bump されている

## What

### ディレクトリ構成

`docs/methodology/elicitation-techniques/` を新設し、以下を配置する（ファイル名は実装フェーズで確定）。

| 技法 | 一次情報 | 主な適用先（skill / 節） |
|------|---------|------------------------|
| Pre-mortem | Gary Klein, "Performing a Project Premortem", *Harvard Business Review*, Sep 2007 | `defining-requirements` — Constraints 節・Open Questions 節 |
| Job Story | Alan Klement, "Replacing the User Story with the Job Story", JTBD blog, Nov 2013 | `defining-requirements` — ユーザーニーズ（Problem / Outcome 節） |
| One question at a time | Steve Krug, *Rocket Surgery Made Easy*, New Riders, 2010 | 全 skill の対話共通ルール（セッション横断） |
| Out-of-scope question | Jeff Patton, *User Story Mapping*, O'Reilly, 2014 | `defining-requirements` — Non-Goals 節；`batch-discovery` — スコープ境界の確認 |

### 各技法ドキュメントに含める内容

- **目的**: 技法が解決する問いの型（一次情報に忠実に記述。独自解釈を加える場合は `[独自]` を明示）
- **問いの型**: 対話で使う問いのテンプレートと、その使い方
- **適用先マッピング**: どの skill のどの節（ステップ）で使うか
- **一次情報**: 著者・出典・発行年・URL（または書誌情報）
- **例**: 実際の問い・応答の例（簡潔な形式）

### 共通原則ドキュメント

4 技法に横断する共通原則を独立ドキュメントとして配置する。

- 対話のキャッチボールで埋める（テンプレ穴埋めではなく、1 回の返答から次の問いを組み立てる）[独自整理]
- 上位工程の責務を侵さない（AC / 設計 doc / test plan はこの技法群の出口ではない）[独自整理]
- 対話ログを残す（各節を埋めた根拠を後追いできるよう、節目で要点を確認する）[独自整理]

### skill 本体の変更範囲

`defining-requirements/SKILL.md` および `batch-discovery/SKILL.md` に、各技法ドキュメントへのマッピング参照（節名 → doc リンク）を追加する。技法の詳細手順・一次情報・例は doc 側に委ね、SKILL.md には持ち込まない。

### BATS ピン

`docs/methodology/elicitation-techniques/` の構造（ファイル一覧・必須フィールド存在）を検証する BATS テストを追加する。

### バージョン・CHANGELOG

- CHANGELOG.md に本変更を記載する
- `.claude-plugin/plugin.json` の patch version を DEVELOPMENT.md Versioning 規約に従い bump する

## Non-Goals

- **他 skill への技法マッピング拡張** — `writing-plan-and-tests` / `reviewing-deliverables` など `defining-requirements` / `batch-discovery` 以外の skill への適用マッピング追加は本 Issue 外。ニーズが明確になった時点で別 Issue で扱う
- **4 技法以外の追加** — 5 本目以降の技法の追加は本 Issue 外。カタログの枠組みを先に確立する
- **既存 SKILL.md の他の記述の見直し** — マッピング参照の追加のみを行い、SKILL.md 全体の整理は対象外
- **対話ログの自動化・構造化** — 「対話ログを残す」は運用指針であり、ツール・フォーマットの自動化は本 Issue 外

## Open Questions

1. **`docs/methodology/elicitation-techniques/` のディレクトリ名** — `elicitation-techniques` vs `requirement-elicitation` vs `techniques` 等の候補があった。
   → **Resolved（Gate ① 承認, 2026-07-01）**: `docs/methodology/elicitation-techniques/` で確定。

2. **4 技法のカバレッジで十分か** — Issue 本文に列挙された 4 技法以外に追加すべきものがないか検討が必要だった。
   → **Resolved（Gate ① 承認, 2026-07-01）**: 本 Issue は 4 技法に絞る。追加は Non-Goals とし別 Issue 化する。

3. **共通原則の扱い** — 4 技法横断の共通原則（キャッチボール / 責務侵犯しない / ログ残す）を各技法ドキュメントに分散させるか、独立ドキュメントにまとめるか。
   → **Resolved（Gate ① 承認, 2026-07-01）**: 独立ドキュメント（`common-principles.md` 相当）として配置し、各技法ドキュメントから参照する。
