# User Stories — #275 Diff-in-body

## US-1（再提示）

**As a** autopilot を運用するユーザー
**I want** 差し戻し修正後の再提示メッセージ本文に finding ごとの diff ハンク（key lines 明示）が含まれていること
**So that** 「差分を見せて」と追加要求せずにその場で承認判断ができる

→ AC-1（prd.md）/ AT-001

## US-2（初回提示）

**As a** autopilot を運用するユーザー
**I want** 初回提示で各成果物の key decisions が file/line 参照付きで示されること
**So that** 要約だけを見て中身の判断を保留する必要がなくなる

→ AC-2 / AT-002

## US-3（マージ引き継ぎ）

**As a** マージゲートで判断するユーザー
**I want** ハンドオフメッセージに実装 diff（per-file stat + key hunks）が本文で含まれること
**So that** green ステータスの要約だけでなく実変更を見てマージを判断できる

→ AC-3 / AT-003

## US-4（無内容準拠の防止）

**As a** ルールの執行性を保ちたいメンテナ
**I want** key lines / key decision に操作的定義があること
**So that** 形式準拠だが無内容なゲート提示でルールを満たせない

→ AC-4 / AT-004
