# AC Review: QA Perspective

Issue #11: bug: autopilot の Agent Team で Developer/QA エージェントが滞留・大量生成される

## Overall Assessment

AC セットは十分にテスト可能であり、Bug の根本原因（Autonomy Rules に Agent tool 再生成禁止規則が欠落）に対して適切な修正範囲を定義している。Prompt Guard パターンによる修正であるため、検証は「禁止規則テキストの存在確認」が主軸となる。

## Per-AC Evaluation

### AC1: Autonomy Rules に「AC Review Round 以降の Agent tool による Developer/QA 新規生成禁止」を明記

**テスト可能性:** 高
- Autonomy Rules セクション内に禁止規則の文言が存在するかを grep で検証可能
- 既存テスト（test_autopilot_agent_teams_setup.bats AC-6 テスト群、行 60-87）と同一パターン

**検証方法:**
```bash
grep -A 30 "## Autonomy Rules" "$AUTOPILOT" | grep -q '<禁止規則の文言>'
```

**境界条件:**
- AC Review Round 自体は Agent tool 使用が正当（行 132: 初回生成ポイント）。禁止規則の適用範囲は「AC Review Round の後」であり、AC Review Round 自体は除外されるべき。AC の文言「AC Review Round 以降」の「以降」が AC Review Round を含むか否かが曖昧。
- **推奨:** 「AC Review Round で生成した Developer/QA を、Phase 2 以降で Agent tool により再生成することを禁止」と明確化する。

**既存 Autonomy Rules との統合:**
- 現在の 4 項目（Solo execution, Explore subagent substitution, Self-executing skill steps, Context-priority execution）の 5 番目として追加される。既存項目との重複はない。「Solo execution」は PO が単独実行することの禁止、本 AC は既存エージェントの重複生成の禁止であり、対象が異なる。

**判定:** PASS

### AC2: Phase 2〜4 各セクションに「Agent tool 禁止、SendMessage のみ」の注意書き追加

**テスト可能性:** 高
- 各フェーズセクション内に注意書きの文言が存在するかを grep で独立検証可能
- Phase 2, Plan Review Round, Phase 3, Phase 4 それぞれについて個別テストケースが書ける

**検証方法:**
```bash
grep -A 20 "## Phase 2: plan" "$AUTOPILOT" | grep -q '<注意書きの文言>'
grep -A 20 "## Plan Review Round" "$AUTOPILOT" | grep -q '<注意書きの文言>'
grep -A 20 "## Phase 3: Implementation" "$AUTOPILOT" | grep -q '<注意書きの文言>'
grep -A 20 "## Phase 4: PR Review" "$AUTOPILOT" | grep -q '<注意書きの文言>'
```

**既存テストとの衝突リスク（重要）:**

`#165-AC1`（行 227-232）と `#165-AC2`（行 250-255）は Phase 2〜4 で `Use Agent tool.*Developer` / `Use Agent tool.*QA` という文字列が存在しないことを否定テストで確認している:

```bash
! grep -A 15 "## Phase 2: plan" "$AUTOPILOT" | grep -q 'Use Agent tool.*Developer'
! grep -A 15 "## Phase 3: Implementation" "$AUTOPILOT" | grep -q 'Use Agent tool.*Developer'
! grep -A 20 "## Phase 2: plan" "$AUTOPILOT" | grep -q 'Use Agent tool.*QA'
! grep -A 15 "## Phase 4: PR Review" "$AUTOPILOT" | grep -q 'Use Agent tool.*QA'
```

AC2 の注意書きに "Use Agent tool" というパターンを含めると、これらの既存テストが失敗する。

**注意書きの文言制約:**
- OK: "Do NOT spawn new agents -- use SendMessage only"
- OK: "Agent re-generation is prohibited -- SendMessage only"
- NG: "Do NOT use Agent tool to spawn Developer" (既存テスト `#165-AC1` が失敗)
- NG: "Use Agent tool is prohibited" (`Use Agent tool.*Developer` にマッチする可能性)

**判定:** PASS（実装時に文言制約を厳守すること）

### AC3: Phase 0.9 Mid-phase resume は「セッション再開時のみ」の例外として矛盾なし

**テスト可能性:** 高
- Phase 0.9 セクション（行 95-100）に Mid-phase resume のロジックが既に存在する
- 「セッション再開時のみ Agent tool を使う」という条件の存在を grep で検証可能

**矛盾分析:**
- Phase 0.9 の Mid-phase resume は「Phase 0.5 で start phase が AC Review Round 以降と判定された場合」のみ Agent tool を使用
- これは「新セッション開始時にエージェントがまだ存在しない」状態を前提
- AC1 の禁止規則は「エージェントが既に存在する状態」での追加生成を禁止
- 両者は前提条件（エージェントの存在有無）が異なるため矛盾しない

**検証方法:**
- Phase 0.9 セクションに resume/restart の文脈でのみ Agent tool が参照されていることを確認
- AC1 の禁止規則テキストに「Phase 0.9 Mid-phase resume は例外」と明示されていることを確認

**判定:** PASS

### AC4: 既存テスト（test_autopilot_agent_teams_setup.bats）が全パス

**テスト可能性:** 高
- `bats tests/test_autopilot_agent_teams_setup.bats` を実行して全テスト（現在 71 テスト）がパスすることを確認

**影響分析:**
- AC1 の変更: Autonomy Rules セクションへの追加。AC-6 テスト群（行 60-87）は `grep -A 20` で検索しているため、追加項目が 20 行以内に収まっていれば既存テストに影響なし。20 行を超える場合は既存テストの grep 範囲外となるため影響なし。
- AC2 の変更: Phase 2〜4 への注意書き追加。上記「既存テストとの衝突リスク」のとおり、文言に注意が必要。

**判定:** PASS（AC2 の文言制約を厳守する前提）

## Missing Scenarios / Coverage Gaps

### 1. Plan Review Round が AC2 の対象に含まれるか

AC2 は「Phase 2〜4」としているが、Plan Review Round は Phase 2 と Phase 3 の間に位置する独立セクション。Plan Review Round も SendMessage のみであるべきだが、AC2 の範囲に明示的に含まれていない。

**現状:** Plan Review Round（行 160-171）は既に SendMessage のみで記述されており、Agent tool の記述はない。しかし注意書きの追加対象としては AC2 に含めるべき。

**推奨:** AC2 の記述を「Phase 2〜4 各セクションおよび Plan Review Round に」と修正するか、「Phase 2 以降のすべてのセクション（Plan Review Round 含む）に」と表現する。

**重要度:** 中 -- Plan Review Round は既に SendMessage のみで記述されているが、防御的に注意書きを追加すべき。

### 2. 禁止規則違反時の Failure Mode

AC1 は禁止規則の「明記」を求めているが、違反時の Failure Mode（報告 + STOP）が既存の Autonomy Rules の Failure Mode（行 112: "report what failed -> STOP -> user decides next step"）で十分カバーされるかを確認する必要がある。

**現状:** 既存の Autonomy Rules には共通の Failure Mode が記載されている（行 112）。新規禁止規則もこの共通 Failure Mode に従うのであれば、追加の AC は不要。

**推奨:** AC1 の実装時に、新規禁止規則が Autonomy Rules セクション内（共通 Failure Mode の適用範囲内）に配置されていることを確認。独立セクションに配置する場合は Failure Mode を明記する必要がある。

**重要度:** 低 -- 構造的に Autonomy Rules セクション内に追加すれば自動的にカバーされる。

### 3. Phase 1 (discover) の除外確認

Phase 1 では PO が単独で Skill tool を使用し、Developer/QA エージェントは存在しない。AC2 が Phase 2〜4 に限定しているのは正しい。ただし Phase 1 で誤って Agent tool を使ってしまうケースは AC の対象外。

**現状:** Phase 1 の Tools annotation は `Bash (gh), Skill` であり Agent tool は含まれていない（行 116）。構造的に防止されている。

**重要度:** 低 -- 既存構造で十分。

## QA Verdict

**PASS** -- AC セットは Bug の根本原因に対して適切な修正範囲を定義しており、各 AC は独立してテスト可能。以下の点を実装時に考慮すること:

1. **AC2 の文言制約:** 既存テスト `#165-AC1`, `#165-AC2` との衝突を避ける文言を使用する
2. **AC1 の適用範囲明確化:** 「AC Review Round 以降」を「AC Review Round で生成した後、Phase 2 以降で」と明確化する
3. **AC2 に Plan Review Round を含める:** 防御的に注意書きの追加対象とする
