# User Stories: express skill の再導入 — 機能破壊リスクのないドキュメント級タスクの省略経路

## Functional Story

<!-- 機能要求を persona 抜き Connextra 形式で記述する。1 ストーリー = 1 ユーザーゴール。 -->

### US-1: コマンド発動と Issue 駆動ガード

**I want to** `/atdd-kit:express <issue>` コマンドで express 経路を発動でき、Issue 番号なしでは起動エラーになり、ユーザの明示的承認なしには開始されない（implicit fallback 禁止）,
**so that** Issue 駆動という最低限のガバナンスを保ったまま、Claude の独断開始を排除して省略経路を安全に使い始められる（AC1/AC3）.

### US-2: 適用基準チェックによる入口判定

**I want to** 発動直後に文書化された適用基準（OK 例: docs/README 追記・typo・コメント・gitignore・バージョン bump のみ等 / NG 例: 新機能・振る舞い変更・依存追加・CI/hooks 変更・セキュリティ影響あり等）で対象 Issue が判定され、NG または判定に迷う場合は即フルフローへ案内される,
**so that** 機能破壊リスクのあるタスクが express に紛れ込まず、「迷ったらフルフロー」の原則で適用範囲が自律的に守られる（AC2）.

### US-3: 中間成果物ゼロの最短経路実行

**I want to** 適用基準を通過したら branch 作成 → 実装 → commit → PR 作成まで一直線に進み、中間成果物（`docs/issues/<NNN>/` ディレクトリ、PRD / US / plan / AT、レビューレポート）が一切作られない,
**so that** ドキュメント級タスクでフルフローのオーバーヘッドを支払わず、人間の接点を「発動承認」と「merge」の 2 点だけにした経路の短さを体感できる.

### US-4: PR での express 利用の識別と理由の記録

**I want to** express 経路で作られた PR に `express-mode` ラベルと PR body の固定セクション（適用基準のどれに該当して express を選択したかの理由）が必ず付与される,
**so that** どの PR が省略経路を通ったか・なぜ省略が正当かが事後監査・traceability として成立する（AC5/AC6）.

### US-5: skill-gate との統合

**I want to** skill-gate が express 経路を正規ルートとして認識し、express 実行中の作業を Issue 駆動違反やスキル未発動としてブロックしない,
**so that** 省略経路がガバナンス機構と衝突せず、ユーザが skill-gate の誤ブロック解除に手を取られない（AC8）.

### US-6: スコープ逸脱時のフルフロー切替

**I want to** 実装中に diff が適用基準を超えた場合（スコープ逸脱）に express が中断され、フルフローへの切り替えが利用者に報告される,
**so that** 入口判定をすり抜けた想定外の変更規模でも省略経路のまま突き進まず、適切なガバナンスへ自動的に戻れる（AC9）.

## Constraint Story (Non-Functional)

<!-- 非機能要求（NFR）を Story 形式で表現する（Pichler 2013）。
     システムが満たすべき品質特性（性能・セキュリティ・信頼性等）を制約として記述する。 -->

### CS-1: CI ゲートと人間 merge ゲートの維持

**I want to** express 経路でも CI ゲートが省略されず（CI FAIL なら merge 不可）、merge は常に人間が行う,
**so that** 「レビュー省略」が「CI 省略」「人間排除」にすり替わらず、CI がガバナンスの最後の砦として維持される（AC4 / Non-Goals）.

### CS-2: 対象リポジトリが atdd-kit 自身の場合の DEVELOPMENT.md 遵守

**I want to** express 実行の対象リポジトリが atdd-kit 自身の場合、DEVELOPMENT.md ルール（version bump + CHANGELOG 更新）が省略されない,
**so that** 省略経路を通ってもプラグインのバージョニングとリリース履歴の整合が壊れない（AC7）.

### CS-3: SKILL.md の最小構成（簡略性の不可逆ガード）

**I want to** `skills/express/SKILL.md` が v1.0 capability-name 体系の最小構成で書かれ、フルフロー級の儀式（多段ゲート・成果物テンプレート・構造化レビュー・セクション単位の確認）が express 内に持ち込まれず、ステップとして存在するのは AC が明示的に要求するガードレールだけである,
**so that** express の存在意義であるスピードと簡略性が実装後も維持され、省略経路に儀式が逆流して価値が消えることがない（設計原則 / Non-Goals）.

### CS-4: 回帰防止のテストカバレッジとリリース衛生

**I want to** 本機能の導入 PR で BATS テスト（`tests/test_express_skill.bats`）が追加され、`skills/README.md` / `commands/README.md` が更新され、CHANGELOG.md が Keep a Changelog 形式で更新されて plugin.json が minor bump されている,
**so that** express skill 自体の回帰が自動で守られ、atdd-kit 開発ルール上の必須整備（PRD `## What` 末尾）がストーリーへトレース可能になる.

> **Note（前提・トレーサビリティ）:** PRD `## Open Questions` は 3 つの設計判断を後続ステップに委ねている — (1) 発動形態の詳細（コマンド起動のみか、keyword 検出 + Y/n 確認付き提案まで許すか。US-1 の発動 UX が依存）、(2) skill-gate 統合のメカニズム（skill-gate 側編集か express 側宣言か。US-5 の実現方式が依存）、(3) 旧 PR #96 実装の再利用度合い（CS-3 の最小構成にどこまで流用するか）。本ステップではいずれもストーリーの粒度に影響しないため確定せず、解決は plan（writing-plan-and-tests）で行う。本 Note はその前提を明示し、PRD → ストーリーのトレーサビリティを保つために記録する。
