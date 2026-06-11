# User Stories: フェーズ別モデル割り当て — impl / review の Sonnet 化の採否と適用範囲

## Functional Story

<!-- 機能要求を persona 抜き Connextra 形式で記述する。1 ストーリー = 1 ユーザーゴール。 -->

### US-1: reviewing-deliverables の Sonnet 恒久化

**I want to** reviewing-deliverables の Workflow script の `agent()`（Scout〜Verify）が `model: 'sonnet'` で実行される（Aggregate のみセッションモデル維持）,
**so that** 実行頻度の高いレビュー Workflow のサブスク枠消費を機能品質同等のまま約 1/4 に抑えられる.

### US-2: impl phase の推奨モデルガイダンス明文化

**I want to** autopilot / running-atdd-cycle の impl phase の推奨モデル（Sonnet 標準・設計絡み Issue はセッションモデルへ昇格）が運用ガイダンスとして明文化されている,
**so that** Issue ごとのモデル選択を都度再判断せず、ベンチ実証済みの基準に沿って運用できる.

### US-3: agents/README.md のモデルポリシー更新

**I want to** agents/README.md の「Model and effort are intentionally unset」ポリシーが新方針（impl / review は Sonnet）と escalation path（halt / 収束失敗時にセッションモデルへ昇格）のセットで更新されている,
**so that** ベンチ結果が参照可能な運用方針として活き、品質低下時の復帰手順が明確になる.

## Constraint Story (Non-Functional)

<!-- 非機能要求（NFR）を Story 形式で表現する（Pichler 2013）。
     システムが満たすべき品質特性（性能・セキュリティ・信頼性等）を制約として記述する。 -->

### CS-1: コスト削減と品質維持の両立

**I want to** impl / review の subagent 実行が機能品質同等のままコスト約 1/4（Sonnet 1.0 : Opus 2.2 : Fable 4.1）で行われる,
**so that** autopilot の本格運用でレビュー Workflow の実行頻度が上がってもサブスク枠の累積消費が抑えられる.

### CS-2: escalation path によるフェイルセーフ

**I want to** Sonnet 化された phase で halt / 収束失敗が発生した場合にセッションモデルへ昇格する経路が常に規定されている,
**so that** コスト削減が品質劣化の固定化につながらず、安全に新方針へ移行できる.

### CS-3: 適用範囲の限定（design phase / メインループ不変）

**I want to** design phase（extracting-user-stories / writing-plan-and-tests）とメインループ（オーケストレータ）のモデルが本変更の対象外としてセッションモデルのまま維持されている,
**so that** ベンチ未実証の領域に変更が及ばず、設計判断の一貫性（Fable 20/20）が損なわれない.
