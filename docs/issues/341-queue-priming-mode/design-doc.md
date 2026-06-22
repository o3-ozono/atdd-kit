<!-- このファイルは trade-off または alternatives の検討がある場合にのみ使用します -->

# Design Doc: batch-discovery の設計判断（壁打ちバッチ化・順序制御・最終承認・収束オラクル）

## Context

PRD（#341）は新スキル `batch-discovery` の What を確定したが、Open Questions として 4 つの設計判断を「plan で詰める」と委ねた。いずれも複数の実装案にトレードオフがあり、plan のタスク（特に B/D/E と Testing の収束判定）はこの判断を前提にする。本 doc がその真実源であり、plan・acceptance-tests はここで採択した案を参照する。

確定済みの前提（PRD で決定済み・本 doc では再議論しない）:
- スキル形態は **独立スキル `batch-discovery`**（`full-autopilot --prime` サブモード化は不採用）。
- 消化フェーズは full-autopilot へ手渡し、本体は書き換えない（疎結合 C3）。
- 並列基盤は full-autopilot の `lib/full-autopilot-dispatch.sh` / `lib/lease-store.sh` / `lib/full-autopilot-run.sh`（worktree 播種 #329）を**転用**する。

## Goals

- 横断バッチ壁打ちの **AskUserQuestion 束ね方**を確定する（D1）。
- 選別最終承認で **覆りうる点の昇格基準**を確定する（D2）。
- **実装順序の記録先と dispatcher の読み取り経路**を確定する（D3）。
- 準備フェーズ worker の **収束オラクル（ready-to-go DoR を deterministic に判定）** を確定する（D4）。
- いずれの判断も AL-1 三ゲート不変条件と CS-1（対話回数の定数性）を損なわない。

## Non-Goals

- full-autopilot 本体（収束レール・merge coordinator）の再設計。
- フルな依存グラフ解決 / 双方向 barrier 同期（軽量順序記録のみ）。
- AC 承認ゲート（false-green の外部アンカー）の撤廃。
- キューの GitHub webhook 化。

## Proposal

### D1. AskUserQuestion の束ね方 ＝ 「判断軸ごと横断束ね（Issue はオプション選択肢）」を採用

人間判断点を **判断軸（トレードオフ / 割り切り / スコープ取捨 / リスク許容度 / 合否基準）でグルーピング**し、1 メッセージ最大 4 質問の枠に軸単位で割り当てる。各質問の選択肢内で対象 Issue を識別子付きで列挙する。軸が 4 を超える、または 1 軸内の判断点が多すぎる場合は **メッセージを分割**するが、分割数は Issue 件数 N ではなく軸数（定数オーダ）に比例させ、CS-1（件数非依存の定数回）を保つ。

### D2. 覆りうる点の昇格基準 ＝ 「種別ベース（デフォルト 3 種）＋ priority 補助」を採用

reviewer-oracle / 準備フェーズが検出した finding のうち、**種別が「トレードオフ」「意図的割り切り」「スコープ取捨」のいずれか**に該当するものを最終承認対象へ昇格させる（PRD のデフォルトを踏襲）。それ以外（純粋な技術 PASS / 自明な修正）は昇格しない。priority は補助シグナルとして高優先 finding を取りこぼさないための保険に使う。昇格対象がゼロなら最終承認自体をスキップする。

### D3. 実装順序の記録先 ＝ 「専用 manifest ファイル（バッチ run 配下）」を採用

実装順序は **バッチ run に紐づく専用 manifest**（Issue 番号の順序付きリスト）に記録する。dispatcher はキュー列挙時にこの manifest を読み、keystone→後続の順序を尊重して `select` の入力順を決める。Issue 本文メタへの埋め込みは採らない（複数 Issue 横断の順序を 1 か所で見たい / 編集容易性）。

### D4. 収束オラクル ＝ 「DoR チェックリスト deterministic 照合（full-autopilot `__default_result` の類推）」を採用

worker の準備完了は、full-autopilot の result 判定（`is_error:false` ＋ ラベル二重確認）に倣い、**DoR（`docs/methodology/definition-of-ready.md` R1-R5）の deterministic 照合**で判定する。具体的には reviewing-deliverables PASS（plan review）＋ Draft PR 存在＋ `ready-to-go` 付与可否を GitHub state（永続真実源）で確認する。LLM の主観 PASS 宣言だけに依存しない。

## Alternatives Considered

- **D1 代替: Issue ごとグルーピング** — Issue 単位で質問を束ねる案。Issue が増えるとメッセージ数が N に比例し CS-1（件数非依存）を破るため却下。
- **D2 代替: priority のみで昇格** — priority 閾値だけで判定する案。種別の意味（トレードオフか否か）を捨てると本来人間が覆せる判断を取りこぼす／逆に瑣末な高 priority を昇格させ過剰提示になるため、種別ベースを主とし priority を補助に降格。
- **D3 代替: research doc / Issue 本文メタ** — research doc は順序専用でなく散逸しやすい。Issue 本文メタは横断の一覧性が低く編集が GitHub 往復になるため却下。
- **D4 代替: LLM 自己申告のみ** — worker の「準備完了」宣言だけを信じる案。false-green を生むため、GitHub state ＋ DoR 照合の deterministic 判定を採用。

## Trade-offs

- **得るもの**: 人間拘束の定数化（D1）、最終承認の最小化と取りこぼし防止の両立（D2）、順序の単一真実源と一覧性（D3）、false-green 耐性のある収束判定（D4）。
- **失うもの / コスト**: D1 は軸が多いバッチでメッセージ分割が起きうる（ただし定数オーダ）。D3 の manifest は新規ファイル形式の導入（軽量だが 1 つ増える）。D4 は GitHub state 照合の往復コストが worker 完了判定に乗る。

## Risks

- **R-1: 軸の取り違えで重要判断を自律ドラフトしてしまう** — 昇格基準（D2）を reviewer-oracle 段でも再検査し、覆りうる点の検出漏れを最終承認前にもう一度フィルタする。
- **R-2: manifest と実キューの不整合（順序記録が古い）** — dispatcher 読み取り時に manifest の Issue が open / 対象集合に含まれるか検証し、欠落は警告して既定順へフォールバック。
- **R-3: 既存 lib 転用時のリース二重取得** — `lib/lease-store.sh` の fail-closed acquire（排他保証できなければ取得失敗）に従い、batch-discovery 側で独自リース実装をしない。
- **R-4: AL-1 整合の文言ドリフト** — AT-341-E-2 を [regression] 化し、Gate ③ 不変・3 ゲート対応の不変条件を継続監視する（時点固定値はピン留めしない / #289）。
