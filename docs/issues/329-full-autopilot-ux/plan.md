# Plan: full-autopilot の使い勝手再設計（真因0-4 一括）

<!-- 2-5 分粒度のタスク行と verification 行を交互に配置する（superpowers writing-plans 形式）。
     各タスクは単一の操作に限定し、verification で完了条件を即確認できる粒度にする。
     コミット分割方針（PRD Open Questions）: 真因ごとに1コミット（US-0/1/2/3/4/5 + バージョン/CHANGELOG）。 -->

## Implementation

### US-0 / 真因0 — Issue テンプレートを意図シードに軽量化（Gate ① 維持）

- [ ] `templates/issue/ja/development.yml` の `acceptance-criteria` / `subtasks` / `completion-criteria` / `user-story` の `validations.required` を `true` → `false` に変更し、各 description に「未記入なら Claude が defining-requirements で生成する」旨を追記する
- [ ] verify: `acceptance-criteria` / `subtasks` / `completion-criteria` / `user-story` の各フィールドで `required: true` が消えている（required は意図3点フィールドのみ）

- [ ] `templates/issue/ja/development.yml` に意図3点（痛み=Problem / 望む結果=Outcome / スコープ境界）を required で表現するフィールド構成へ整理する。**フィールドマッピング（3点 → 具体的 yaml id）を確定する**: 痛み=既存 `summary`（id=summary, :32-34, label を「概要」→「痛み / 解決したい問題」へ役割再定義し『何を実装するか』記述から痛み記述へ）、望む結果=新規 required フィールド `outcome`（id=outcome, label「望む結果」）を追加、スコープ境界=新規 required フィールド `scope-boundary`（id=scope-boundary, label「スコープ境界（やる / やらない）」）を追加。**required の入れ替え**: 既存 required の `user-story`（:26-27）を `required: false` に降格（US-0 が任意化対象に含む, user-stories.md:9）、新規2フィールド（outcome / scope-boundary）を `required: true` で追加。最終的な required は意図3点（summary / outcome / scope-boundary）のみ、user-story / acceptance-criteria / subtasks / completion-criteria は optional
- [ ] verify: ja テンプレートの required フィールドが `summary`（痛み）/ `outcome`（望む結果）/ `scope-boundary`（スコープ境界）の意図3点のみで、`user-story` / `acceptance-criteria` / `subtasks` / `completion-criteria` はいずれも optional

- [ ] `templates/issue/en/development.yml` を ja と同じ required/optional 構成・同じ意図3点に同期する
- [ ] verify: `tests/test_bilingual_templates.bats` が green（ja/en の構造対応が保たれている）

- [ ] `.github/ISSUE_TEMPLATE/` への always-sync 経路（session-start E2）が壊れていないことを確認する（同期対象に development.yml が含まれ続ける）
- [ ] verify: `tests/test_template_sync.bats` が green

### US-1 / 真因1 — queue 動的化（起動時 freeze 撤廃）

- [ ] `lib/full-autopilot-run.sh:156` 付近の起動時1回 freeze（`while ... done < <($QUEUE_CMD)` で `queue` 配列を作る箇所）を、空きスロット充填ループ内で `$QUEUE_CMD` を再評価する動的 enqueue に置き換える
- [ ] verify: `run()` 内で `$QUEUE_CMD` が起動時1回ではなく空きスロット充填時に再評価される（コードレビューで確認）

- [ ] 再評価で取得した未処理 issue を、既に lease 保持済み / in-flight / 完了済みの issue と重複させない dedup ロジックを追加する
- [ ] verify: 同一 issue が2回 `launch` されない（in-flight 集合と既処理集合の両方で除外）

### US-2 / 真因2 — 起動時に通知先を確認

- [ ] `lib/full-autopilot-run.sh` 起動時（`run()` 冒頭）に、`NOTIFY_CMD` 未設定なら未設定を1行警告し、設定済みなら確認ログを出すプリフライトを追加する（PRD 既定方針「起動時に通知先を一度確認」を採用）
- [ ] verify: `NOTIFY_CMD` 未設定で `run()` 起動時にログへ「通知先未設定」警告が1回出る／設定済みなら確認ログが1回出る（本体は停止しない）

### US-3 / 真因3 — merge-ready の GitHub ラベル二重確認

> **設計前提（レビュー finding #1 反映）**: 現状 `merge-ready` は (a) notify イベント名（`lib/full-autopilot-run.sh:110` の event class）/ (b) `__default_result` の状態文字列（:54）/ (c) Discord 通知テキスト / (d) autopilot hand-off の手放し状態（`skills/autopilot/SKILL.md:35`）として**しか**存在せず、worker が Issue/PR に付ける GitHub ラベルとしては**どこも生成していない**（`commands/setup-github.md:35-49` のラベル定義に `merge-ready` 不在、`lib/` で `--add-label merge-ready` 相当なし＝実在の `--add-label` は `lib/skill_fix_dispatch.sh` の `blocked-ac` / `ready-to-go` のみ）。したがって**照合（consume）だけ**を実装すると `__default_result` は本番でラベル常時不在のため常に `failed` を返し全 merge が fail-closed でブロックされる。本 US-3 は**生成（produce）と照合（consume）を対で実装する**（finding #1 修正案 (a)）。

- [ ] **produce ①（ラベル定義）**: `commands/setup-github.md` の Step 3 ラベル定義に `gh label create "merge-ready" --color "0E8A16" --description "worker hand-off succeeded; awaiting serial merge by coordinator" --force` を追加し、Step 4 Summary のラベル件数（`Labels: 15 created`）を 16 に更新する
- [ ] verify: `commands/setup-github.md` のラベル列挙に `merge-ready` が含まれ、Summary 件数が定義数と一致する

- [ ] **produce ②（worker 成功時のラベル付与）**: worker hand-off の成功（gate③ で autopilot が `merge-ready` 状態へ手放す）時点で対象 Issue に `merge-ready` GitHub ラベルを付与する経路を実装する。配線箇所は `skills/autopilot/SKILL.md:35`（hand-off honor 時 gate③ で `gh issue edit <i> --add-label merge-ready`）に記述し、full-autopilot 側 launcher が hand-off worker に許可ツールとして `Bash` を既に渡している（`lib/full-autopilot-run.sh:48`）ことを前提に、autopilot が手放し時にラベルを付与する。`FA_HANDOFF=1` マーカー不在の通常起動（AL-1 3ゲート）ではラベル付与経路を起動しない
- [ ] verify: autopilot hand-off 成功時に対象 Issue へ `merge-ready` ラベルが付与される記述が `skills/autopilot/SKILL.md` に存在し、通常（非 hand-off）起動では付与されない

- [ ] **consume（照合）**: `lib/full-autopilot-run.sh` の `__default_result` を、worker stdout の `is_error:false` 自己申告に加えて `gh issue view <i> --json labels` で `merge-ready` ラベル存在を照合し、不在なら `failed` を出力する実装に変更する
- [ ] verify: `is_error:false` でも `merge-ready` ラベルが無ければ `__default_result` が `failed` を返す／両方満たすときのみ `merge-ready` を返す（照合の `gh` 呼び出しは env で stub 化可能だが、produce ②でラベルを付ける本番経路が存在するため AT は produce→consume の往復を検証する）

### US-4 / 真因4 — skill-gate に route-eligibility 必須チェック

- [ ] `skills/skill-gate/SKILL.md` に route-eligibility（`docs/methodology/route-eligibility.md`）必須チェック手順を追加し、不適合モード（例: 挙動変更 Issue に express）を抑止、override 手段を明示する
- [ ] verify: `skills/skill-gate/SKILL.md` に route-eligibility 必須チェックと override 記述が存在する

### US-5 / doc 整合 — DoR 記述の修正

- [ ] `skills/full-autopilot/SKILL.md` の `ready-to-go` 前提記述（現「PRD が承認済み」）を正典 DoR（`docs/methodology/definition-of-ready.md`: ready-to-go = DoR ＋ plan review PASS）に合わせて修正する
- [ ] verify: `skills/full-autopilot/SKILL.md` の Input セクションが「ready-to-go = DoR ＋ plan review PASS」を反映し、`docs/methodology/definition-of-ready.md` と矛盾しない

## Testing

### CS-1 — 各真因に bats 受け入れテスト（AL-3 deterministic AT gate）

- [ ] US-0 の AT bats（`tests/acceptance/AT-329-template.bats`）: development.yml の AC/サブタスク/完了条件が optional、意図3点が required を検証
- [ ] verify: 当該 bats が green

- [ ] US-1 の AT bats（`tests/acceptance/AT-329-queue.bats`）: queue 動的再評価で走行中追加 issue が拾われ、二重起動しないことを env stub で検証
- [ ] verify: 当該 bats が green

- [ ] US-2 の AT bats（`tests/acceptance/AT-329-notify.bats`）: 起動時に通知先確認ログが出ることを検証
- [ ] verify: 当該 bats が green

- [ ] US-3 の AT bats（`tests/acceptance/AT-329-result.bats`）: (consume) merge-ready ラベル不在で `__default_result` が failed に倒れ、ラベル存在＋`is_error:false` で merge-ready を返すことを `gh` stub で検証。(produce) `commands/setup-github.md` のラベル定義に `merge-ready` が含まれ、autopilot hand-off 成功時にラベルを付与する記述が `skills/autopilot/SKILL.md` に存在することを構造 pin で検証（produce 半分の欠落＝fail-closed を AT が見逃さないようにする）
- [ ] verify: 当該 bats が green（produce 側のラベル定義・付与記述が消えると当該 bats が red になる）

- [ ] US-4 の AT bats（skill-gate 構造 pin）: route-eligibility 必須チェック記述の存在を検証
- [ ] verify: 当該 bats が green

- [ ] US-5 の AT bats（full-autopilot SKILL.md 構造 pin）: ready-to-go 前提が DoR 整合であることを検証
- [ ] verify: 当該 bats が green

- [ ] 全 bats スイートを実行して回帰がないことを確認する
- [ ] verify: `bats tests/`（および該当時 `bats addons/*/tests/`）が全 green

## Finishing

- [ ] バージョン bump（`.claude-plugin/plugin.json`）と CHANGELOG 追記（minor: 新規ゲート追加・テンプレート任意化）
- [ ] verify: `scripts/check-plugin-version.sh` 相当が通り、CHANGELOG 最上位リリース見出しと plugin.json の version が一致

- [ ] 関連ディレクトリの README 更新（`tests/README.md`、`templates/README.md`、必要なら `lib`/`skills` README）
- [ ] verify: 変更した各 top-level ディレクトリの README が変更内容と整合（DEVELOPMENT.md「Directory READMEs」ルール）

- [ ] ドキュメント整合性チェック（route-eligibility / definition-of-ready / full-autopilot SKILL.md / skill-gate SKILL.md の相互参照が矛盾しない）
- [ ] verify: 関連ドキュメントが変更内容と整合している
