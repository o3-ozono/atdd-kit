# Design Doc: autopilot-log.jsonl の削除・巻き戻し検出機構の選定（#262）

## 背景と決定すべき問い

PRD の Open Question:「正当な初回（ログ未存在）」と「run 途中の削除」を区別する機構をどう作るか。
`check_sameness` / `check_stuck` は `autopilot-log.jsonl` の履歴に依存するため、ログが消えると両レールは黙って return 0 する（fail-open）。検出には「ログには本来どれだけの履歴があるはずか」という外部の真実（expected）が必要であり、その真実をどこに置くかが設計の核心。

## 選択肢

### 案 A: イテレーション連続性検証（orchestrator 保持の期待行数）— **採用**

orchestrator（`skills/autopilot/SKILL.md` の Workflow script）が期待行数をメモリ上で追跡し、毎 rails チェックでシェル側ガード `check_log_integrity <jsonl> <expected-lines>` に渡す。

- freeze 時にログの現在行数を baseline として取得（再入時・phase 跨ぎの既存行を吸収）
- `record_iteration` 成功のたびに JS 側カウンタを +1
- ガードは「実際の行数 == baseline + 記録数」を検証。不一致（削除・truncate・外部追記）は非ゼロ return → halt

| 観点 | 評価 |
|------|------|
| 真実の置き場所 | JS プロセスメモリ。**ディスク操作では消せない** — ログと一緒に削除される攻撃面がない |
| 初回 run の区別 | expected が 0（baseline 0・記録 0）のときのみログ未存在を許容。誤検出ゼロが構造的に保証される |
| 再入（design-gate 差し戻し） | freeze 時 baseline 取得で既存行を正として吸収。pin の re-verify と同じパターン |
| 検出範囲 | 削除・リセット・巻き戻し（truncate）に加え、外部からの行追記も exact-match で検出 |
| コスト | 新規ファイルなし。SKILL.md にカウンタ 1 個と rails 呼び出し 1 個の配管 |

### 案 B: ログ fingerprint 化（sidecar pin / ハッシュチェーン）— 不採用

`record_iteration` がログ全体の sha256（または行数）を sidecar ファイル（例: `autopilot-log.pin`）に書き、チェック時にログと突合する。

- 長所: lib 内で自己完結し、orchestrator に状態を持たせない
- **致命的短所: sidecar はログと同じディスク・同じディレクトリにある。「ログ + sidecar の両方が消える」と初回 run と区別できず、塞ぎたい fail-open 穴がそのまま残る**（`git clean` / worktree リセット / ディレクトリ削除はまさに両方を消すシナリオ）
- 行レベルのハッシュチェーン化は #248（行レベル corruption guard）のスコープであり、本 Issue の Non-Goal

### 案 C: A + B のハイブリッド — 不採用

検出力は A 単独と実質同等（A が B の検出範囲を包含する）にもかかわらず、新規ファイル + 配管が倍になる。YAGNI。

## 決定

**案 A（イテレーション連続性検証）を採用。**

決め手: 真実（期待行数）を「ディスク外」の orchestrator メモリに置くことで、ログを消す操作そのものでは真実を消せない。これは anchor pin（pin は人間承認時に固定され、以後の loop は読み取りのみ）と同じ「loop が自分の採点基準を再ベースライン化できない」原則の監査ログ版であり、#262 の目的である非対称の解消に正確に対応する。

## 検証ポリシー（exact match）

`actual == expected` の**完全一致**を要求する（`>=` ではない）。orchestrator が唯一の正当な書き手である以上、行数の過不足はどちらも改竄・事故であり、fail-closed の原則（#256）に従い両方向とも halt する。

## 影響範囲

- `lib/autopilot_convergence.sh` — `check_log_integrity` 追加（純 bash + coreutils、zero-dependency 維持）
- `skills/autopilot/SKILL.md` — freeze での baseline 取得、recorded カウンタ、rails 5 項目目の配管、halt 理由 `log-integrity`
- `tests/test_autopilot_convergence.bats` / `tests/test_autopilot_skill.bats` — 検出・非検出・配管のテスト
