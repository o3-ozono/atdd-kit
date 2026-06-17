# User Stories: bugfix 専用の軽量ルート（フル機能ルートと分離）

## Functional Story

**I want to** バグ修正を、PRD / User Stories / Plan の作成をスキップする bugfix 専用の軽量オーケストレーションスキルで進められる,
**so that** Connextra User Story 等の空回りする成果物を作らず、`再現確認 → 根本原因診断 → 最小修正 → 回帰テスト green` の最短工程に直行できる.

**I want to** 報告されたバグを、`.claude/config.yml` の `platform` に応じた実ツール（web=Playwright CLI、iOS=Xcode/simulator MCP、other=CLI/スクリプト実行）で実システムを動かして再現確認し、確認できた再現を実行可能な failing test に符号化できる,
**so that** 推測ではなく firsthand 証拠でバグの存在を確かめ、その failing test を autopilot オラクルのアンカー（赤→修正後に緑）にできる.

**I want to** Issue ラベル（`type:bug` 等）＋キーワード＋タスク内容から bugfix ルートが自動判定され、低確信時は User にワンタップで確認され、明示コマンド（例 `/atdd-kit:autofix`）でも起動できる,
**so that** カテゴリに合ったルートへ自動で振り分けられ、誤判定時も #305 ワンタップ承認と整合した形で安全に確定できる.

**I want to** bugfix ルートを autopilot で自律収束でき、収束オラクル = 回帰テスト green ＋ 既存テスト非破壊（＋再現テスト赤→緑）、User gate は最小（原因合意=任意 ＋ マージ）になっている,
**so that** バグ修正も autopilot の自律収束の恩恵を受けつつ、品質の芯（再現・根本原因・回帰ガード）を外さない.

**I want to** `debugging` の Root Cause 分類が Type A（AC Gap = 仕様/設計判断が必要）の場合に、bugfix 軽量ルートを離脱し `defining-requirements` 起点のフル機能ルートへ昇格できる,
**so that** バグだと思ったら設計判断が要る大物だった場合でも、既存の debugging→defining-requirements 連鎖を流用して適切な工程へエスカレーションできる.

## Constraint Story (Non-Functional)

**I want to** bugfix ルートが既存スキル（`bug` / `debugging` / `running-atdd-cycle` / `reviewing-deliverables` / `merging-and-deploying`）の再利用のみで構成され、新規のメソドロジー・ステップ・スキルを増やさず重複ゼロである,
**so that** 既存スキルの本質的書き換えや成果物の重複を生まず、保守コストを増やさずにルートを追加できる.

**I want to** マージが bugfix ルートでも常に User gate（autopilot Iron Law AL-1）を経由する,
**so that** カテゴリ別ルートで工程を軽量化しても、マージの最終判断は常に人間の手元に残る.
