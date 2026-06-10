# User Stories: autopilot 設計承認ゲート（#249）

## Functional Story

### F1: 設計承認ゲート（人間ゲート 3 点化）

**I want to** autopilot が design phase（extracting-user-stories → writing-plan-and-tests）を near-green まで収束させたら停止し、設計成果物（user-stories.md / plan.md / acceptance-tests.md）を私に提示して明示承認を待つ,
**so that** 「設計まで壁打ち → 成果物レビュー → 承認後に ATDD」という期待フローどおりに、実装前に設計を私が確認できる.

### F2: フェーズ別 AL-2 anchor（凍結矛盾の解消）

**I want to** design phase の anchor は承認済み prd.md のみ（`autopilot-prd.pin`）、impl phase の anchor は設計承認時に凍結した prd.md + user-stories.md（`autopilot-design.pin`）となり、ループが自分で生成・修正する成果物が同一フェーズの anchor に含まれない,
**so that** US の修正が ac-drift の偽 halt を起こさず、かつ各フェーズが人間承認済みの immutable な基準にだけ接地する.

### F3: 差し戻しの再投入

**I want to** 設計承認ゲートでの差し戻しコメントが finding（evidence_ref = 人間コメント）として design phase のループに再投入され、再収束後に再び承認を求められる,
**so that** 差し戻しが fire-and-forget にならず、私の指摘が確実に成果物へ反映される.

## Constraint Story (Non-Functional)

### C1: 既存原則の維持

**I want to** 本変更後も flow skill 本体と `lib/autopilot_convergence.sh` が無変更で、SKILL.md が行数 budget（≤240 行）に収まり、impl phase では AT/coverage の決定論ゲートが従来どおり機能する,
**so that** #246 の「薄い orchestrator / skill 恒久不変」原則と既存の安全保証が損なわれない.

### C2: テスト・ドキュメント同期

**I want to** ゲート 3 点化・2 段 pin が BATS（Unit + E2E 構造）で pin され、README / CHANGELOG / iron-law doc が同期され、version が 3.7.0 に bump される,
**so that** 変更が構造的に検証され、利用者向け記述と実装が一致する.
