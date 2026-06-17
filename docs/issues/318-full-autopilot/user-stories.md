# User Stories: full-autopilot — キュー方式で複数 issue を並列・無人で merge まで回す

## Functional Story

### F1 — キュー消化
**I want to** `ready-to-go` まで固めた issue をキューに積むだけで実装〜merge が自動消化される,
**so that** 工程ごとに人間が起動・承認せず、関与を issue 冒頭の壁打ちに閉じられる.

### F2 — 並列度 K
**I want to** 並列度 K を指定して複数 issue を同時に進められる,
**so that** スループットを上げつつ、K=1 では純粋な数珠つなぎとしても使える.

### F3 — 数珠つなぎ
**I want to** worker slot が空いたら自動でキューから次の issue を取って着手する,
**so that** 1 issue 完了のたびに人間が次の autopilot を起動しなくて済む.

### F4 — hand-off モード
**I want to** autopilot を「`merge-ready` で手放す」モードで起動できる,
**so that** merge を専任ロールに委ねつつ autopilot 本体を疎結合に保てる.

### F5 — merge coordinator
**I want to** `merge-ready` な PR を容量1で直列に `rebase→再ゲート→merge→post-merge regression` する,
**so that** 並列生成した複数 PR を安全に1本ずつ統合できる.

### F6 — 自動差し戻し
**I want to** rebase 衝突 / 再ゲート fail を新しい autopilot イテレーションへ自動差し戻しする,
**so that** 一時的な失敗で無人運転が止まらない.

### F7 — エスカレーション
**I want to** 自動差し戻しが N 回失敗したら human にフラグを立てる,
**so that** 自動で解けない問題だけが人間に上がる.

## Constraint Story (Non-Functional)

### C1 — broken together 防止
**I want to** merge 直前に必ず最新 main へ rebase してフル再ゲート（AT＋verdict）が通る,
**so that** 単体 green な複数 PR を統合しても main が壊れない.

### C2 — 並列排他
**I want to** branch / issue / merge の各 lease で並行 worker が同一資源を奪い合わない,
**so that** 並列実行が互いの作業を破壊しない.

### C3 — 疎結合
**I want to** autopilot 本体の判断ロジックを hand-off モード追加以外で改変しない,
**so that** full-autopilot を autopilot のオーケストレータに保てる.

### C4 — 暴走防止の安全弁
**I want to** 消化対象を人間が固めた `ready-to-go` issue に限定する,
**so that** 誤った issue を勝手に作って実装し始める暴走を防ぐ.
