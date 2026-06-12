# User Stories: session-start のプラグインバージョン検知 — RESTART_REQUIRED / STALE_SESSION の追加

## Functional Story

<!-- 機能要求を persona 抜き Connextra 形式で記述する。1 ストーリー = 1 ユーザーゴール。 -->

### US-1: RESTART_REQUIRED の検知（故障モード A）

**I want to** 新版がローカルにインストール済みで旧版がロード中のとき `RESTART_REQUIRED` が出力され、session-start レポートに再起動を促すメッセージが表示される,
**so that** ロード版とマーカーが一致していても新版の存在に気づける（新版検知漏れを塞ぐ）.

### US-2: STALE_SESSION の検知とダウングレード抑止（故障モード B）

**I want to** ロード版がマーカー版より古い（`CURRENT < CACHED`）とき `STALE_SESSION` が出力され、マーカーは更新されず、session-start 側が E2 Auto-Sync をスキップして再起動を促す,
**so that** 旧版テンプレート/deploy ファイルによるダウングレード上書きが起きない.

### US-3: CHANGELOG 集計ガード

**I want to** UPDATED 経路で CACHED エントリが CHANGELOG 内に見つからない場合に件数を `UNKNOWN` とする,
**so that** break に到達せず全エントリを数える `VERSIONS: 63` のような誤集計を防げる.

### US-4: session-start への出力プロトコル配線

**I want to** `RESTART_REQUIRED` / `STALE_SESSION` の出力プロトコル行を `skills/session-start/SKILL.md`（Phase 1-E / E2）に追加し、STALE_SESSION 時は E2 Auto-Sync をスキップ・両者で再起動を促すよう配線する,
**so that** スクリプトの新しい検知結果が session-start レポートの挙動に正しく反映される.

### US-5: 再起動後の正常系復帰

**I want to** RESTART_REQUIRED / STALE_SESSION 後に再起動した次セッションで、従来どおり正しい CHANGELOG 件数付きの UPDATED が出る,
**so that** 再起動が検知状態を正常系へ戻し、回帰なく通常のバージョン更新通知に復帰できる.

## Constraint Story (Non-Functional)

<!-- 非機能要求（NFR）を Story 形式で表現する（Pichler 2013）。
     システムが満たすべき品質特性（性能・セキュリティ・信頼性等）を制約として記述する。 -->

### CS-1: 後方互換フォールバック

**I want to** `installed_plugins.json` が無い/パース不能な環境でも、従来の FIRST_RUN / NO_UPDATE / UPDATED が壊れずフォールバックする,
**so that** 新検知が利用できない環境でも既存のバージョン検知が後方互換で動作し続ける.

### CS-2: ネットワーク非依存・ローカル完結

**I want to** すべての検知がネットワークアクセス不要でローカルファイル（`installed_plugins.json` / マーカー / `plugin.json` / CHANGELOG）のみで完結する,
**so that** オフライン/ネットワーク制限環境でも session-start のバージョン検知が決定的に動作する.

### CS-3: 回帰防止のテストカバレッジとリリース衛生

**I want to** 既存 BATS スイートが green を保ち、新規分岐（A/B 各分岐 + フォールバック + 再起動後の正常 UPDATED）に BATS テストが追加され、さらに本機能の feature PR で CHANGELOG.md が Keep a Changelog 形式で更新され plugin.json のバージョンが bump されている,
**so that** 検知ロジックの回帰が自動で守られ、DEVELOPMENT.md が全 feature PR の不変条件とする CHANGELOG エントリ + バージョン bump が PRD `## What`（CHANGELOG 更新）からストーリーへトレース可能になり、リリース頻度が上がっても信頼性が維持される.

> **Note（前提・トレーサビリティ）:** PRD `## Open Questions`（prd.md:42-43）は2つの設計判断を plan に委ねている — (1) `installed_plugins.json` 内で当該プロジェクトのエントリを特定するキー（`projectPath` がカレントに一致するか等）のスキーマ確認（US-1 が依存）、(2) RESTART_REQUIRED と STALE_SESSION が同時成立しうるケース（ロード版 < マーカー版 かつ installed 版 > ロード版）の分岐優先順位（US-1 と US-2 が co-trigger しうる）。US-1 と US-2 はこの解決を暗黙に前提とするが、解決自体は plan で確定する。本 Note はその前提を明示し、PRD → ストーリーのトレーサビリティを保つために記録する（design フェーズでは非ブロッキング）。
