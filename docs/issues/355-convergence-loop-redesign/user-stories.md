# User Stories: autopilot 収束ループの根本再設計 — 収束信号を客観ゲートに一本化

## Functional Story

### F1: impl-phase オラクルから LLM レビュー項を除去

**I want to** autopilot の impl-phase 満足オラクルを客観ゲートのみ `AND(redObserved, atGreen, coverageOk)` に変更し、`overall_correctness` / blocking-findings（LLM レビュー由来）の項を削除する,
**so that** demonstrably-done（test green ＋ AC カバレッジ）な成果物が、レビュアーの自己判定が湧かせ続ける nitpick に veto されて MAX_ITERATIONS まで空転する構造的非収束が解消される.

### F2: impl-phase ループから reviewing-deliverables 呼び出しを除去

**I want to** autopilot の impl-phase 収束ループから `reviewing-deliverables` の review エージェント呼び出しと review-scope 構築を削除する,
**so that** 1ラウンド ~6M トークン・~1時間を要したレビュー実行コストがループから消え、収束時間とトークンが大幅に削減される.

### F3: design-phase をレビューループ無しの「生成 → 人間 Gate②」に

**I want to** design-phase（extracting-user-stories / writing-plan-and-tests）が LLM レビューループを持たず、各ステップを生成して人間の Gate②（設計承認）で収束させる（差し戻しは `rejectionFindings` で再生成）ようにする,
**so that** 客観ゲートを持たない設計成果物の収束を人間判断に委ね、設計フェーズでも自己判定ループの非収束を持ち込まない.

### F4: 客観ゲートの Issue クラス一般化（red-first を全 modality へ）

**I want to** running-atdd-cycle の red-first（変更前 赤 → 変更後 緑）と `record_red_evidence` 呼び出しを、実行可能 AT（`tests/acceptance/`）だけでなく skill/doc 変更の BATS pin（`tests/*.bats`）にも適用できるよう一般化し、`tests/acceptance/AT-<NNN>.*` 固有のファイル名前提を撤廃する,
**so that** skill/doc 変更の Issue でも red.jsonl / redObserved / AC→AT カバレッジが成立し、客観ゲートが「実行可能 AT を持つ Issue」以外でも機能する（本 Issue 自身が空転した triggering instance の真因解消）.

### F5: red-gate の堅牢化（記録値読み取り、git log 考古学撤廃）

**I want to** `record_red_evidence` が test-commit SHA と impl baseline SHA の両方を red.jsonl に直接記録し、`check_red_evidence` と autopilot の red-gate がその記録値を読むだけにする（git log での SHA 推測を排除する）,
**so that** 多イテレーションで SHA 解決が false-negative 化して `redObserved=false` がオラクルを veto する事象が deterministic に排除される.

### F6: 客観ゲート確立不能時の gate-unverifiable 早期 escalation

**I want to** 客観ゲートが確立できない（red.jsonl が無い・AC→AT カバレッジが計算不能・AT が生成されない等）場合に、MAX_ITERATIONS まで空転させず `gate-unverifiable` で早期に人間へ escalation する,
**so that** 「成果物未完成」と「客観ゲートそのものが立たない」を別停止理由として扱い、後者を回数上限まで回さず即座に人間が引き取れる.

### F7: reviewing-deliverables を standalone スキルへ戻す

**I want to** reviewing-deliverables を #345 前（main）の形に戻し、autopilot 連携記述を「明示起動の standalone / 人間補助レビュー」に整理する,
**so that** レビュー機能は失わずに（Step 5・人間補助として存続）、autopilot 収束ループからは確実に外れる.

## Constraint Story (Non-Functional)

### C1: 収束性と低コストの両立

**I want to** 再設計後の収束ループが #341 / #345 再現シナリオで、(a) demonstrably-done が nitpick に veto されず収束、(b) レビュー除去でラウンドあたりトークン・時間が大幅減、(c) skill/doc 変更でも redObserved が deterministic に確定、のすべてを満たす,
**so that** 無限ラウンド・MAX 空転が排除され、収束時間とトークンコストが大幅に削減される.

### C2: Non-Goals 境界の不変性

**I want to** 本 Issue の変更が red-first 方針そのもの（#334）・3ゲート（AL-1）の数と位置・coverage/atGreen の内部判定アルゴリズムを変えず、オラクルからのレビュー項除去・客観ゲートの modality 一般化・SHA 記録方法・停止理由整理に留まる,
**so that** 既存の確立済みレールへ波及せず、収束性改善が他の不変条件を侵さない.

### C3: 既存 rails の保持

**I want to** sameness-detector（FAIL 行のみ・正規化 sha256 2連続同一）・stuck 検出（window=3・FAIL 行のみ）・check_log_integrity・MAX_ITERATIONS・ac-drift の各 rail が再設計後も維持される,
**so that** レビュー除去後も非収束・監査整合性破損・stuck の検出と fail-closed な halt が保たれる.
