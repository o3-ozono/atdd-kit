# User Stories: flaky-test-fix 専用の軽量ルート（bugfix ルートの兄弟）

## Functional Story

<!-- 機能要求を persona 抜き Connextra 形式で記述する。1 ストーリー = 1 ユーザーゴール。 -->

### FS-1 専用ルートの起動（PRD What#1 / Outcome#1）

**I want to** flaky-test-fix 専用の軽量ルートを既存スキル再利用のみで起動できる,
**so that** PRD/US/Plan の重い工程を踏まずに「確率的再現 → 非決定性分類 → 最小決定化 → 反復検証で green 安定」の最短工程で flaky を直せる.

### FS-2 確率的再現の確認（PRD What#2a / Outcome#2）

**I want to** 単発実行ではなく N回反復実行 / seed・実行順・並列度の変動で flaky を firsthand に確認し失敗率を証拠として記録できる,
**so that** 「再現できないので診断に進めない」で詰まらず、修正前後の失敗率で改善を客観的に示せる.

### FS-3 反復で観測可能な failing アンカー（PRD What#2b）

**I want to** 確認した非決定性を「反復実行で一定確率赤になる」実行可能アンカーに符号化できる,
**so that** 修正後に N回連続緑で決定化を確認でき、収束の判定基準が実ツールに裏付けられる.

### FS-4 非決定性の原因分類（PRD What#3）

**I want to** タイミング/順序依存/共有状態/外部依存/リソースリーク等の非決定性カテゴリで根本原因を `debugging` の Type 分類を flaky 軸で運用して特定できる,
**so that** ロジック欠陥向けでない flaky の原因を適切な軸で表現し、修正方針を誤らない.

### FS-5 cause-agreement ゲートの flaky アンカー（PRD What#4 / Outcome#3）

**I want to** 中間 User ゲートのアンカーを「非決定性分類 ＋ 失敗率（修正前 X% → 修正後 0%）」として cause-agreement で合意できる,
**so that** 「単一の赤テスト」を前提にせず flaky に即した原因合意ができ、AL-1（中間ゲートを消さない）を維持できる.

### FS-6 quarantine（隔離）判断（PRD What#5 / Outcome#5）

**I want to** 即時決定化が困難な flaky を一時隔離（skip/quarantine マーク）して他作業をブロックせず、隔離後も追跡（Issue 残置 / 再 dispatch）できる,
**so that** 直せない flaky に開発フロー全体を人質に取られず、かつ隔離が放置されない.

### FS-7 ルーティング拡張（PRD What#6 / Outcome#6）

**I want to** `route-eligibility.md` の flaky シグナル（ラベル `type:flaky` ＋キーワード `flaky`/`不安定`/`間欠的に失敗`/`intermittent`）と明示コマンドで本ルートを起動でき、低確信時は #305 ワンタップで User 確認できる,
**so that** flaky が bugfix ルートに誤って流れず、ルーティング SoT の「flaky 未定義」の穴が塞がる.

## Constraint Story (Non-Functional)

<!-- 非機能要求（NFR）を Story 形式で表現する（Pichler 2013）。
     システムが満たすべき品質特性（性能・セキュリティ・信頼性等）を制約として記述する。 -->

### CS-1 収束オラクルが反復ベース（PRD What#7 / Outcome#4）

**I want to** autopilot 収束判定が「N回連続 green（決定化の確認）＋ 既存テスト非破壊」で行われ、単発 green では収束としない,
**so that** たまたま1回緑になっただけの偽収束で flaky を未解決のまま閉じない.

### CS-2 重複ゼロ・既存スキル無編集（PRD What#1, What#3 / Non-Goals）

**I want to** flaky 特化の追補がすべて新オーケストレータ側に置かれ、既存 `bug`/`debugging`/`running-atdd-cycle`/`reviewing-deliverables`/`merging-and-deploying` と `fixing-bugs`（bugfix ルート）が無編集で再利用される,
**so that** #308 と同じ重複ゼロ方針を保ち、兄弟ルート間で挙動が分岐・退行しない.

### CS-3 マージは常に User gate（PRD Non-Goals / AL-1）

**I want to** flaky ルートでもマージが常に User gate（AL-1）であり自動マージされない,
**so that** 決定化が不十分なまま無人マージされるリスクを排除できる.
