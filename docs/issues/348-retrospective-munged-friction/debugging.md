# Debugging: Issue #348 — retrospective.sh Dialogue Volume ゼロ化 + friction 分類異常

bugfix ルート（`fixing-bugs`）。`debugging` Step 1-5（Scientific Debugging）の診断記録。

## Part 1: Dialogue Volume 恒久ゼロ化 — Type C (Logic Error) + Type B (Test Gap)

### 再現（実地確認済み）
`scripts/retrospective.sh:101` の munged-path 生成:
```bash
munged="$(echo "${REPO_ROOT}" | sed 's|/|-|g; s|^-||')"
```

REPO_ROOT=`/Users/o3/github.com/o3-ozono/atdd-kit` に対し:

| | 生成値 | 実 transcript ディレクトリ | 一致 |
|---|---|---|---|
| 現行 sed | `Users-o3-github.com-o3-ozono-atdd-kit` | — | ✗（存在しない） |
| 実際 | — | `-Users-o3-github-com-o3-ozono-atdd-kit` | — |
| 修正 sed | `-Users-o3-github-com-o3-ozono-atdd-kit` | `-Users-o3-github-com-o3-ozono-atdd-kit` | ✓ |

2 点の不一致:
1. **先頭ダッシュ削除** — `s|^-||` が削除するが、実際は先頭ダッシュを保持する
2. **ドット非変換** — `github.com` のまま。実際はドットも `-` に変換（`github-com`）

`[[ -d "$transcript_dir" ]]` ガードが存在しないディレクトリで silent 短絡し、`aggregate_turns` が常に `user=0 assistant=0 total=0` を返す。ドットを含むパスの repo で Dialogue Volume が恒久ゼロ化。

### 根本原因分類
- **Type C (Logic Error)**: munged-path の sed が Claude Code の実命名規則と乖離。意図は明確（Claude Code の `~/.claude/projects/<munged>` 命名に一致させる）→ 仕様判断不要。
- **Type B (Test Gap)**: `AT-309-3-behavioral`（`tests/acceptance/AT-309.bats:579`）の fixture が**同じ壊れた sed** で transcript dir を作るため、fixture と script が自己整合し欠陥を捕捉できない。

### 修正
```bash
munged="$(echo "${REPO_ROOT}" | sed 's|[/.]|-|g')"
```
（`/` と `.` を両方 `-` へ、先頭ダッシュは保持）。回帰テスト `AT-348-1`（実命名規則を fixture 化・ドット含むパスで両不具合を exercise）を追加。赤→緑アンカー。

## Part 2: friction 分類異常 — 分類ロジックが実 step 名と不整合（要方針決定）

### 再現（実地確認済み）
#323 の retrospective 出力:
```
friction: requirements=none design=none merge=running-atdd-cycle,running-atdd-cycle,running-atdd-cycle,running-atdd-cycle
```

`extract_friction`（`scripts/retrospective.sh:217-222`）の case パターンに実 autopilot step 名を通すと:

| step | 分類先 | 正否 |
|---|---|---|
| `extracting-user-stories` | **merge (default catch-all)** | ✗ design フェーズなのに merge |
| `writing-plan-and-tests` | design | ✓ |
| `running-atdd-cycle` | **merge (default catch-all)** | ✗ impl フェーズなのに merge |
| `merging-and-deploying` | merge | ✓ |
| `reviewing-deliverables` | merge | ✓（merge readiness の一部） |

### 設計意図（#309 AT-309-6 / design-doc）
摩擦点は **requirements / design / merge の 3 ゲート**別に「どのゲートで否決が発生したか」を分類する。しかし:
- `extracting-user-stories`（design フェーズ step）が default catch-all で merge に誤分類。
- `running-atdd-cycle`（impl フェーズ）の FAIL は autopilot 収束ループの**各反復の非収束**であり、そもそも**ゲート否決ではない**。3 ゲート taxonomy に impl フェーズのバケットが無い（#309 で未定義）。

### 論点（cause-agreement ゲートで方針決定）
impl フェーズ FAIL の扱いは #309 で未定義のため、正しい挙動には方針判断が必要。修正方針は Part 2 の分類ルールを確定してから赤テストを書く。
