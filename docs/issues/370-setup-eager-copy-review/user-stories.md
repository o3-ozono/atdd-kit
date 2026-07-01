# User Stories: setup-* の eager-copy を「参照優先 + 使う時に不足検出してプロンプト」モデルへ見直す

## Functional Story

<!-- W-1: 仕分け一覧の作成（doc） -->

**I want to** setup-* が現在コピーする全成果物を「参照で足りる（plugin-global 参照）」と「プロジェクトローカルに要る（ユーザー管理が必要）」に二分類した仕分け一覧を `docs/design/setup-eager-copy-inventory.md` として得る,
**so that** どのファイルを eager-copy から外し、どれをプロジェクトローカルに残すべきかをアイテム単位の判定根拠つきで判断できる.

<!-- W-2: オンデマンド移管の設計方針 doc -->

**I want to** 移管対象ごとに「トリガー（どの skill・コマンドが呼ばれたとき）」「検出ロジック（何が不足しているか判定する方法）」「プロンプト方法（通知 / 自動修復 / confirm 要求）」と冪等性の担保方法を定義した設計方針を `docs/design/setup-on-demand-policy.md` として得る,
**so that** 今後の個別オンデマンド実装が統一された指針（ガードの標準パターン・冪等性チェックリスト）に従って進められる.

<!-- W-3a: ラベル不足検出プロンプト -->

**I want to** 各ワークフロー skill（autopilot / full-autopilot 等）の起動時に必須 GitHub ラベルの存在を確認し、不足があれば作成を促す（または confirm 後に自動作成する）pre-flight check が動作する,
**so that** setup-github を実行していない環境でもラベル未設定による実行時エラーをその場で防げる.

<!-- W-3b: hook 配線の plugin-global 寄せ -->

**I want to** プロジェクト個別設定に頼っていた hook を plugin-global hook として提供する,
**so that** setup-* を実行していない環境でも hook が機能し、setup 漏れによる摩擦が解消される.

## Constraint Story (Non-Functional)

<!-- 冪等性（Outcome 3 / Open Question 3） -->

**I want to** W-3 の各実装が「対象が既に存在すれば何もしない（or 差分のみ適用する）」を原則として冪等に動作する（ラベル作成は既存なら 422 を無視、hook 配線は plugin-global の常時有効性を活用して重複適用を回避）,
**so that** skill の再実行で副作用が重複せず、実行のたびに安全に不足検出を回せる.

<!-- UX を壊さない（Open Question 2） -->

**I want to** 不足検出が失敗（不足あり）してもエラー終了せず「不足を通知 → ユーザーが confirm してから続行」でスキップ可能に振る舞う,
**so that** pre-flight check の導入がワークフローの UX を阻害しない.

<!-- 鮮度（Problem 2） -->

**I want to** 参照で足りると判定した成果物を plugin 本体への参照経路で解決し、プロジェクトへコピーしない,
**so that** コピー物が plugin 更新に追随せず実装と乖離する鮮度乖離リスクを排除できる.
