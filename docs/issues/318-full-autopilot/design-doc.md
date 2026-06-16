# Design Doc: full-autopilot の3つの設計判断

本 epic は競合する代替案を持つ非自明なトレードオフを3点含むため、決定・代替案・根拠を記録する（Ubl 2020）。

## 決定1: 並列 worker の多重化 = headless プロセス（Workflow fan-out / 実窓制御を不採用）

**決定**: 各 worker を独立した headless プロセス `claude -p "/atdd-kit:autopilot <issue> --hand-off"` として `run_in_background` で起動する。

**代替案と却下理由**:
- **(あ) full-autopilot を1つの Workflow にし `parallel()` で worker を fan-out** — 却下。autopilot は Skill だが内部（impl/review）で Workflow ツールを呼ぶため、worker の Workflow が**入れ子になり1階層制限に抵触**。仮に `workflow()` で1階層ネストしても、全 worker が**単一の concurrency cap（≒10）と単一 token budget を共有**し真の K 並列にならない（abort signal も共有で1本の失敗が波及）。
- **(う) 実窓制御（osascript / tmux で別ターミナル窓に `claude` を起動）** — 却下。各窓の結果を**プログラム的に回収できず**、coordinator の自動 merge 判定（worker が merge-ready に到達したか）が成立しない。OS 依存・権限で脆い。

**根拠（2026-06-17 実証）**: headless `claude -p` が Workflow ツールを起動し完了結果を回収できることを確認（agent が `{"value":"PONG"}` 返却、`-p` でも background Workflow 完了を待って exit）。各 worker は top-level プロセスのため入れ子問題ゼロ・自前の cap/budget で真の並列。ログは3層回収可能（stdout json / `--session-id` で確定する transcript / 入れ子 Workflow の `subagents/workflows/wf_*/agent-*.jsonl`）。旧 atdd-kit の TeamCreate/spawn-profiles 構成は intra-issue 並列の参考だが inter-issue 並列には不足。

## 決定2: merge は autopilot から分離した専任 coordinator（容量1直列）

**決定**: merge を autopilot worker から外し、容量1の merge-lease を握る **merge coordinator** が `rebase→フル再ゲート→merge→regression` を直列 drain する（GitHub merge queue / Bors / Zuul 型）。

**代替案と却下理由**:
- **各 autopilot worker が自分で merge する** — 却下。理由2点:
  1. **green alone / broken together**: 単体 green な PR も main が他 PR で動けば壊れる。rebase 後の再ゲートを正しく行える場所は「main を1本で見る coordinator」だけ。worker に分散すると再ゲートのタイミングが噛み合わず競合窓ですり抜ける。
  2. **ロック保持の寿命問題**: worker に merge させると、完成 worker が merge 順番待ちで生き続け（rebase＋再 CI を回し続け）並列の旨味が消え、ロック保持中に死ぬとオーファンロックで main が詰まる。worker は「作って渡したら死ぬ」のが正しい lifecycle。

**根拠**: 「生成は並列・統合は直列」の定石。autopilot は元々「merge しない・near-green を gate に渡す」スコープなので、分離は既存スコープと整合（merge gate の宛先を人間→coordinator に差し替えるだけ）。

## 決定3: 設計 gate ②を full-autopilot 限定で自動承認（AL-1 をモード分岐で上書き）

**決定**: hand-off モードでは autopilot の Gate ②（設計承認）を**自動承認**する（設計ループ generate→review→fix と in-loop reviewer による near-green 収束は維持し、人間サインオフ待ちのみ外す）。autopilot Iron Law の AL-1（gate を厳密3つに固定）を **full-autopilot 限定のモード分岐**で上書きする。

**代替案と却下理由**:
- **設計承認を初回壁打ちに前倒しで畳む** — 却下寄り。キュー投入時点では US/plan/AT が未生成のため、設計の実体を人間が見られず「前倒し承認」が形骸化する。
- **AL-1 を恒久的に緩める（通常 autopilot も②を自動化）** — 却下。通常 autopilot の3 gate 規律はユーザーが価値を置く不変条件。full-autopilot 限定に閉じる。

**根拠**: ユーザーの中核要求は「最初の要件壁打ちだけ人間・あとはノールック承認」。autopilot は既に人間レビューを reviewer-oracle で代替しており、設計 gate を同じ reviewer-oracle に委ねるのは思想的に一貫。人間は Draft PR の設計成果物を見て差し戻す **override 権を保持**。

**緊張点（C3 疎結合との両立）**: hand-off は autopilot 本体（Iron Law）に手を入れる唯一の例外。**通常モードの AL-1 記述は不変**を担保し（AT-318-A2 で invariant assert）、変更を「full-autopilot 起動時のみ有効な分岐」に厳密に閉じることで疎結合の精神を保つ。
