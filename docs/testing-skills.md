# Testing Skills

atdd-kit の skill テスト体系。**Unit Test** と **Skill E2E Test** の 2 層に統一されている。

> v1.0 で旧用語（SAT / L1-L3 / Fast layer / Integration layer）は廃止された（#222）。本文書がテスト体系の単一の正典。

## (a) 2 層の定義

| 層 | claude 起動 | 検証対象 | 場所 | 失敗時ゲート | 想定コスト/回 |
|---|----------|---------|-----|------------|------|
| **Unit Test** | ❌ 呼ばない | SKILL.md の構造（行数 / 出力 path 言及 / 上下流名）、shell script ロジック、grep ベースの用語規約 | `tests/*.bats` | CI `skill-tests` ジョブ FAIL | $0 |
| **Skill E2E Test** | ✅ `claude -p` を呼ぶ | LLM が SKILL.md を読んで規定の挙動を返すか（キーワード抽出 / 上下流順序 / multi-turn 振る舞い） | `tests/e2e/<skill>.bats` | reviewing-deliverables 引き渡し前ゲート（local 必須、CI 任意） | ~$0.10–$5 |

**境界:** `claude` バイナリを呼ぶか呼ばないかが唯一の分類軸。stub claude や jsonl リプレイは Unit Test 側に分類される。

## (b) Skill E2E Test の構造（1 skill = 1 ファイル、1 User Story = 1 case）

`tests/e2e/<skill>.bats` 1 ファイルに、各 User Story 1 つを 1 個の `@test` ブロックで対応させる。テスト名は User Story の Connextra そのもの。

```bash
#!/usr/bin/env bats
# tests/e2e/defining-requirements.bats
# @covers: skills/defining-requirements/SKILL.md

setup() {
  : "${CLAUDE_BIN:?CLAUDE_BIN must be set or claude in PATH}"
}

@test "I want to read the SKILL.md and recover the 4-element PRD structure, so that section coverage is verified" {
  out=$(claude -p --max-turns 1 --permission-mode bypassPermissions <<EOF
List the PRD sections defined in this skill, in order.

$(cat skills/defining-requirements/SKILL.md)
EOF
  )
  [[ "$out" =~ 基礎項目 ]] || [[ "$out" =~ Basics ]]
  [[ "$out" =~ 問題定義 ]] || [[ "$out" =~ Problem ]]
  [[ "$out" =~ ゴール ]] || [[ "$out" =~ Goal ]]
  [[ "$out" =~ 機能要件 ]] || [[ "$out" =~ "Functional Requirements" ]]
  [[ "$out" =~ "Open Questions" ]]
}

@test "I want to see upstream session-start cited before downstream extracting-user-stories, so that chain order is preserved" {
  # ...
}
```

User Stories は `docs/issues/<NNN>/user-stories.md` に定義された Functional Story / Constraint Story を 1:1 で写す。`extracting-user-stories` skill (#189) 完成後は User Story 抽出と E2E `@test` 生成が同一フォーマットで連動する。

## (c) 影響範囲算定ロジック（path-based）

変更ファイルから影響を受ける skill を **`scripts/run-skill-e2e.sh`** が path-based マッピングで自動算定する。

| 変更ファイルの prefix | 影響範囲 |
|-------------------|---------|
| `skills/<X>/...` | `tests/e2e/<X>.bats` のみ |
| `rules/...`, `templates/...`, `docs/methodology/...` | 全 `tests/e2e/*.bats` |
| `lib/<file>`, `scripts/<file>` | SKILL.md が当該 file を参照する全 skill の E2E |
| その他 | 影響なし（実行対象 0） |

```bash
# skill 1 つ変更（軽量）
scripts/run-skill-e2e.sh --changed-files skills/defining-requirements/SKILL.md

# 共有資材変更（全 E2E）
scripts/run-skill-e2e.sh --changed-files rules/atdd-kit.md

# 複数ファイル
scripts/run-skill-e2e.sh --changed-files skills/foo/SKILL.md,scripts/bar.sh

# 全実行
scripts/run-skill-e2e.sh --all

# 対象列挙のみ（実行しない）
scripts/run-skill-e2e.sh --changed-files <list> --dry-run
```

## (d) 証跡コメント規約（reviewing-deliverables 引き渡しゲート）

atdd-kit 自体の修正 PR では、reviewing-deliverables への引き渡し前に **影響範囲分の Skill E2E Test all green ログを PR コメントに貼付する** ことが必須。

### 必須フィールド

`scripts/run-skill-e2e.sh` が `tests/e2e/.logs/<run-id>.log` に出力する 5 フィールド:

| フィールド | 値の例 |
|----------|------|
| `run-id` | `20260512T083000Z-12345` |
| `git_sha` | `git rev-parse HEAD` の結果（最新コミット SHA） |
| `timestamp` | ISO8601 `2026-05-12T08:30:00Z` |
| `targets` | 対象 `tests/e2e/*.bats` の列挙 |
| `results` + `summary` | 各 target の `PASS` / `FAIL` + `summary: PASS (N/N)` |

### 検証側（reviewing-deliverables skill）

reviewer は次を確認する:

1. PR コメントに最新ログが貼付されているか
2. ログ内の `git_sha` が PR HEAD と一致するか（古いログでの merge を防ぐ）
3. `summary: PASS (N/N)` で `FAIL` が 0 件か

`git_sha` 不一致なら **変更後に再実行が必要**。reviewer はその場で差し戻す。

### コメント運用ルール（最新 1 件を update）

PR 内に **証跡コメントは 1 つだけ** 保持し、追加 commit ごとに同じコメントを update する。複数のログコメントを並べない。

1. 最初の動作実証時に新規コメントを投稿（タイトルは `## Skill E2E Test 証跡`）
2. 追加 commit ごとに同じコメントを `gh api -X PATCH /repos/{owner}/{repo}/issues/comments/{comment_id}` で update
3. 古い証跡コメントが残っている場合は `gh api -X DELETE ...` で削除
4. コメント本文に `Updated: <ISO8601>` と最新 `git_sha` を含めて、history は git ログで追う

ねらい: PR レビュアーが「どれが最新ログか」を判断する手間を取り除く。`git_sha` は 1 件のコメントを見れば一意に決まる。

### 配布プロジェクトでの扱い

atdd-kit を **適用するプロジェクト**（プラグイン利用者）は本ゲートの対象外。本ゲートは atdd-kit リポジトリ自身の修正 PR にのみ適用される。

## (e) Unit Test の追加

1. `tests/test_<topic>.bats` を作成（テンプレート: `tests/test_bats_runner.bats` 参照）
2. `bats tests/test_<topic>.bats` で local 実行
3. PR で `skill-tests` ジョブが自動実行

## (f) Skill E2E Test の追加

1. `tests/e2e/<skill>.bats` を作成（1 skill = 1 ファイル、`@covers: skills/<skill>/SKILL.md` ヘッダ）
2. 対応する User Stories を `docs/issues/<NNN>/user-stories.md` から 1 US = 1 `@test` で写す
3. local 実行: `bash scripts/run-skill-e2e.sh --changed-files skills/<skill>/SKILL.md`
4. 全 green を確認後、ログを PR コメントに貼付
5. 変更後の追加 commit でも **同じ手順で再実行 → 最新ログを再投稿**

## (g) Cost Baseline

| 層 | 想定コスト/回 |
|---|--------------|
| Unit Test | $0 |
| Skill E2E Test (1 skill) | ~$0.10 |
| Skill E2E Test (全 skill, `--all`) | ~$5.00 |

Skill E2E Test は影響範囲算定で対象を絞るのが基本。全実行は `rules/` / `templates/` / `docs/methodology/` 変更時に自動的に発生する。

## (h) Exit Codes（`scripts/run-skill-e2e.sh`）

| Code | 意味 |
|------|------|
| 0 | PASS / dry-run 成功 / 影響範囲 0 件 |
| 1 | 1 つ以上の Skill E2E Test FAIL |
| 3 | usage / infra error（フラグ不正、bats バイナリ未設置等） |

## (i) GH_TOKEN

Skill E2E Test 内で `gh` を呼ぶ場合、`.claude/settings.local.json` の `env.GH_TOKEN` を使う。Token はトランスクリプトに書き込まれないこと、verbose mode でも mask されることを Unit Test で検証する。

## (j) サブスク内 CI 実行（self-hosted runner）

Skill E2E Test を GitHub Actions からキックする場合、**課金はサブスク（Pro/Max）の範囲内のみ**とする。従量課金 API には費用を使わない。ワークフローは `.github/workflows/skill-e2e-subscription.yml`（`workflow_dispatch` 限定）。

### 課金方針（必須）

- 認証は self-hosted runner 上の **Claude サブスク資格情報（macOS Keychain `Claude Code-credentials`）**。`claude -p` は 6/15 以降サブスクの月次クレジットプール（Max 5x $100 / 20x $200）から消費する。
- **`ANTHROPIC_API_KEY` を CI の env / secret に置くことを禁止**（置くとプールを迂回し従量課金になる）。ワークフローの Guard ステップが検出して fail する。
- **`usage credits`（overflow 課金）を有効化しない**。プール超過時はリクエストが止まるだけで課金されない（月初リセットで復活）。
- GitHub-hosted runner + `CLAUDE_CODE_OAUTH_TOKEN` は OAuth トークンが短時間で失効し CI が落ちるため**常設しない**。

### self-hosted runner 登録（リポジトリ単位）

`o3-ozono` は User アカウントのため org 共有 runner は不可。atdd-kit ごとに runner を登録する（同じ Mac を再利用しつつ atdd-kit 専用に別登録）。

```bash
DIR="$HOME/actions-runner-atdd-1"; mkdir -p "$DIR" && cd "$DIR"
VER=2.334.0
curl -fsSL -o runner.tar.gz \
  "https://github.com/actions/runner/releases/download/v${VER}/actions-runner-osx-arm64-${VER}.tar.gz"
tar xzf runner.tar.gz && rm -f runner.tar.gz
TOKEN=$(gh api -X POST repos/o3-ozono/atdd-kit/actions/runners/registration-token --jq .token)
./config.sh --url https://github.com/o3-ozono/atdd-kit \
  --token "$TOKEN" --name "$(scutil --get ComputerName)-atdd" --labels atdd-kit-e2e --work _work --unattended --replace
```

LaunchAgent（`~/Library/LaunchAgents/com.github.actions.runner-atdd.plist`）で常駐化する。`RunAtLoad` / `KeepAlive` を付け、`EnvironmentVariables` の `PATH` に `claude` の場所（例 `~/.local/bin`）を含める。

> **`SessionCreate` は付けない。** `SessionCreate: true` は別セキュリティセッションを作り login keychain を遮断するため、`claude -p` が `Not logged in` で失敗する（検証済み, #243）。iOS addon の XCUITest runner とは要件が逆なので注意。

複数マシン（例 iMac と MacBook Air）で運用する場合、**両方に同一ラベル `atdd-kit-e2e`** を付ける。`runs-on: [self-hosted, macOS, atdd-kit-e2e]` が空いている方で走る。クレジットプールはユーザー単位なので2台でも共有・二重課金なし。各マシンで `claude` を Pro/Max ログイン済みにしておく。

### ハードニング（必須・bats で構造固定）

2 本の bats が以下を固定する（将来のリファクタで課金方針・信頼境界が green CI のまま反転するのを防ぐ）:

- **`tests/test_skill_e2e_guard.bats`（挙動検証）**: `scripts/ci/skill-e2e-guard.sh` を**実行**して、7 課金 env それぞれで非ゼロ終了 / 非 main ref・tag・空 ref の拒否 / clean env で 0 を assert。Guard を反転・gut すると赤になる（grep ではない）。
- **`tests/test_skill_e2e_subscription_workflow.bats`（構造）**: 入力の env 化（`inputs.*` / `github.ref` を `run:` に直接展開しない）、`workflow_dispatch` 限定（push/schedule/workflow_call も否定）、`permissions: contents: read`（write 昇格の否定）、専用ラベル `atdd-kit-e2e`、Action の SHA pin（40hex anchored）、`timeout-minutes`、空 diff の no-op（exit 0）、Guard スクリプトへの委譲を assert。
- 課金 env のブロックリスト（7 変数）は `scripts/ci/skill-e2e-guard.sh` が**単一ソース**（Guard / bats / docs の乖離を排除）。

### accept-risk（public repo × self-hosted × login Keychain）

本構成は「サブスク課金内で CI E2E を回す」要件が必然的に要求するもので、**GitHub が一般には非推奨**とする組み合わせ（public repo の非 ephemeral self-hosted runner ＋ login Keychain）。信頼モデルを正直に明示した上で受容する:

- **真の信頼境界は write 権限**: `workflow_dispatch` 時はディスパッチした ref のリポジトリ全体（ワークフロー YAML・`scripts/ci/skill-e2e-guard.sh` 含む）が実行されるため、**write 権限保有者は Guard を編集して迂回できる**。したがって本ワークフローの Guard 群（main-ref / 課金 env / `permissions: contents: read`）は**悪意ある write 共同作業者に対する境界ではなく、誤用に対する safety rail**。write 権限を信頼できるメンテナに限定することが前提（atdd-kit は単独〜少人数メンテ）。
- **main ref 限定（safety rail）**: `refs/heads/main` 以外での実行を Guard で弾く＝**accidental な非 main dispatch を排除**。E2E は元来「ローカル必須・CI 任意」ゲート（feature ブランチの事前検証はローカル）なので、CI はマージ後リグレッションに限定して支障なし。
- **Guard は単一ソース＋挙動検証**: `scripts/ci/skill-e2e-guard.sh` が課金 env ブロックリスト（7 変数）と main-ref を一元定義し、`tests/test_skill_e2e_guard.bats` が**実行**して反転・gut を検知する（grep ではない）。
- **残存リスク（受容）**: write 権限保有者は単一 dispatch で runner 上の login Keychain（gh トークン / SSH 鍵 / サブスク資格情報）にアクセスし得る（`bypassPermissions` の `claude -p`）。これを許容できない場合は専用 Keychain / ephemeral 隔離を将来検討。課金 env は OS env のみ Guard が見るため、runner の `~/.claude/settings.json` 等の env リダイレクトは runner 設定がメンテナ管理であることを前提に信頼する。
- **専用ラベル分離**: `atdd-kit-e2e` は本ワークフロー専用。他ワークフローはこのラベルを使わない（iOS addon runner とも別系統）。
- **runner 前提**: `claude`（Pro/Max ログイン済み）と `bats` が PATH に存在。LaunchAgent は `SessionCreate` 無し（(j) 前述）。runner 登録の tarball DL は version 固定済み（`v2.334.0`）。さらに固めるなら配布物の checksum 検証を追加する。

### metered 版との関係

`skill-e2e-live.yml`（#208）は GitHub-hosted + `ANTHROPIC_API_KEY`（**従量課金**）で同じ `run-skill-e2e.sh` を回す。**サブスク以外お金を使わない方針では本 `skill-e2e-subscription.yml`（self-hosted + Keychain）が正系**で、`skill-e2e-live.yml` は metered な代替（方針上は非推奨）。`pr.yml` の `skill-e2e-test` は dry-run（トークン消費 0）で構造のみ検証する。
