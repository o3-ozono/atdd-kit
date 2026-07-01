#!/usr/bin/env bats
# @covers: docs/design/**
# Issue #370: setup-* の eager-copy を「参照優先 + 使う時に不足検出してプロンプト」モデルへ見直す
#
# AT lifecycle: draft -> green -> regression
# Current state: [draft]

INVENTORY="docs/design/setup-eager-copy-inventory.md"
POLICY="docs/design/setup-on-demand-policy.md"

# --- AT-370-1: 仕分け一覧 doc が全 setup-* を網羅する（W-1 / Outcome 1） ---
#
# Given: PRD W-1 と Functional Story（仕分け一覧）が承認済み
# When:  docs/design/setup-eager-copy-inventory.md を読む
# Then:  setup-github / setup-ci / setup-discord / setup-ios / setup-web の
#        5 コマンドすべてが表に登場し、各成果物にソースパスと配置先が記載されている

@test "#370 AT-370-1: setup-eager-copy-inventory.md exists" {
  [ -f "$INVENTORY" ]
}

@test "#370 AT-370-1: inventory covers setup-github" {
  grep -q 'setup-github' "$INVENTORY"
}

@test "#370 AT-370-1: inventory covers setup-ci" {
  grep -q 'setup-ci' "$INVENTORY"
}

@test "#370 AT-370-1: inventory covers setup-discord" {
  grep -q 'setup-discord' "$INVENTORY"
}

@test "#370 AT-370-1: inventory covers setup-ios" {
  grep -q 'setup-ios' "$INVENTORY"
}

@test "#370 AT-370-1: inventory covers setup-web" {
  grep -q 'setup-web' "$INVENTORY"
}

@test "#370 AT-370-1: inventory references templates/ source paths" {
  grep -q 'templates/' "$INVENTORY"
}

@test "#370 AT-370-1: inventory references addons/ source paths" {
  grep -q 'addons/' "$INVENTORY"
}

# --- AT-370-2: 全アイテムが Gate① 基準で二分類されている（W-1 / Outcome 1） ---
#
# Given: 仕分け一覧 doc が存在する
# When:  doc 内の分類表を検査する
# Then:  全アイテムに二分類のいずれかと 1 行以上の判定根拠が付与されており、
#        未分類（空欄）のアイテムが 0 件である

@test "#370 AT-370-2: inventory has reference-suffices classification label" {
  grep -qF '参照で足りる' "$INVENTORY"
}

@test "#370 AT-370-2: inventory has project-local-required classification label" {
  grep -qF 'プロジェクトローカルに要る' "$INVENTORY"
}

@test "#370 AT-370-2: inventory has a rationale column heading" {
  grep -qE '判定根拠' "$INVENTORY"
}

# --- AT-370-3: 高リスク項目が「プロジェクトローカルに要る」に固定されている（W-1 / Non-Goals） ---
#
# Given: 仕分け一覧 doc が存在する
# When:  discord webhook（秘匿値）と GitHub ラベル（書き込み対象）の分類行を検査する
# Then:  両者が「プロジェクトローカルに要る」に分類され、かつ本 Issue のオンデマンド
#        移管対象外である旨が doc に明記されている

@test "#370 AT-370-3: inventory mentions discord webhook as project-local" {
  grep -qi 'webhook' "$INVENTORY"
}

@test "#370 AT-370-3: inventory mentions GitHub labels as project-local (write target)" {
  grep -q 'ラベル' "$INVENTORY"
}

@test "#370 AT-370-3: inventory states out-of-scope for on-demand migration" {
  grep -qE '対象外' "$INVENTORY"
}

# --- AT-370-4: オンデマンド移管の設計方針 doc が 3 要素を定義する（W-2 / Outcome 2） ---
#
# Given: PRD W-2 が承認済み
# When:  docs/design/setup-on-demand-policy.md を読む
# Then:  少なくとも W-3a（ラベル不足検出）を含む移管対象が、トリガー・検出ロジック・
#        プロンプト方法の 3 要素すべてを埋めた行として存在する

@test "#370 AT-370-4: setup-on-demand-policy.md exists" {
  [ -f "$POLICY" ]
}

@test "#370 AT-370-4: policy defines trigger column" {
  grep -qF 'トリガー' "$POLICY"
}

@test "#370 AT-370-4: policy defines detection-logic column" {
  grep -qF '検出ロジック' "$POLICY"
}

@test "#370 AT-370-4: policy defines prompt-method column" {
  grep -qF 'プロンプト方法' "$POLICY"
}

@test "#370 AT-370-4: policy includes a row covering label shortage detection (W-3a)" {
  grep -q 'ラベル' "$POLICY"
}

# --- AT-370-5: pre-flight check の標準ガードパターンが明文化されている（W-2 / Open Question 2） ---
#
# Given: 設計方針 doc が存在する
# When:  doc の標準ガードパターン節を検査する
# Then:  「エラー終了しない」かつ「スキップ可能」を要件とする pre-flight check の
#        標準パターンが記述されている

@test "#370 AT-370-5: policy has a standard guard pattern section" {
  grep -qE '標準(ガード|パターン)' "$POLICY"
}

@test "#370 AT-370-5: policy states pre-flight check must not error-exit" {
  grep -qF 'エラー終了しない' "$POLICY"
}

@test "#370 AT-370-5: policy states pre-flight check is skippable" {
  grep -qF 'スキップ可能' "$POLICY"
}

# --- AT-370-6: 冪等性チェックリストが存在する（W-2 / Outcome 3 / Constraint Story 冪等性） ---
#
# Given: 設計方針 doc が存在する
# When:  doc の冪等性チェックリストを検査する
# Then:  箇条書きの冪等性チェックリストが存在し、ラベル作成（既存を無視）と
#        hook 配線（plugin-global 常時有効で重複回避）の冪等化方法が各 1 項目以上含まれる

@test "#370 AT-370-6: policy has idempotency checklist heading" {
  grep -qE '冪等性(チェックリスト)?' "$POLICY"
}

@test "#370 AT-370-6: policy idempotency checklist covers label creation" {
  grep -q 'ラベル作成' "$POLICY"
}

@test "#370 AT-370-6: policy idempotency checklist covers hook plugin-global wiring" {
  grep -qF 'plugin-global' "$POLICY"
}

# --- AT-370-7: ラベル不足検出スクリプトが不足を通知する（W-3a / Functional Story ラベル不足検出） ---
#
# Given: commands/setup-github.md の 16 ラベルが正準ソースとして参照される
# When:  必須ラベルの一部が存在しない状態で bash scripts/check-required-labels.sh を実行する
# Then:  不足しているラベル名が列挙され、スクリプトはエラー終了せず（非破壊で通知のみ）完了する

@test "#370 AT-370-7: check-required-labels.sh exists and is executable" {
  [ -x scripts/check-required-labels.sh ]
}

@test "#370 AT-370-7: check-required-labels.sh reports missing labels without non-zero exit" {
  # gh label list をモックし、setup-github.md の16ラベルのうち一部を欠落させる
  mock_dir="$(mktemp -d)"
  cat > "$mock_dir/gh" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "label" ] && [ "$2" = "list" ]; then
  echo "in-progress"
  echo "ready-to-go"
  exit 0
fi
exit 0
EOF
  chmod +x "$mock_dir/gh"
  PATH="$mock_dir:$PATH" run bash scripts/check-required-labels.sh
  [ "$status" -eq 0 ]
  echo "$output" | grep -qi 'ready-for-plan-review\|不足\|missing'
  rm -rf "$mock_dir"
}

# --- AT-370-8: ラベル未取得環境でもクラッシュせずスキップする（W-3a / Open Question 2） ---
#
# Given: gh label list が結果を返せない環境（gh 不在または未認証）
# When:  bash scripts/check-required-labels.sh を実行する
# Then:  クラッシュせず「スキップした」旨のメッセージを出して正常終了し、ワークフローを阻害しない

@test "#370 AT-370-8: check-required-labels.sh skips gracefully when gh is absent" {
  mock_dir="$(mktemp -d)"
  # gh を配置しない PATH で実行（gh 不在を模倣）
  run env PATH="$mock_dir:/usr/bin:/bin" bash scripts/check-required-labels.sh
  [ "$status" -eq 0 ]
  echo "$output" | grep -qi 'スキップ\|skip'
  rm -rf "$mock_dir"
}

@test "#370 AT-370-8: check-required-labels.sh skips gracefully when gh is unauthenticated" {
  mock_dir="$(mktemp -d)"
  cat > "$mock_dir/gh" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "label" ] && [ "$2" = "list" ]; then
  echo "error: not authenticated" >&2
  exit 1
fi
exit 1
EOF
  chmod +x "$mock_dir/gh"
  PATH="$mock_dir:$PATH" run bash scripts/check-required-labels.sh
  [ "$status" -eq 0 ]
  echo "$output" | grep -qi 'スキップ\|skip'
  rm -rf "$mock_dir"
}

# --- AT-370-9: ラベル作成が冪等である（W-3a / Constraint Story 冪等性） ---
#
# Given: 一部ラベルが既に存在する状態
# When:  ラベル作成経路（gh label create --force）を2回連続で実行する
# Then:  2回目でエラー・重複作成が起きず、既存ラベルは変更されない（--force により冪等）

@test "#370 AT-370-9: check-required-labels.sh remediation path uses gh label create --force" {
  grep -q 'gh label create' scripts/check-required-labels.sh
  grep -q -- '--force' scripts/check-required-labels.sh
}

@test "#370 AT-370-9: check-required-labels.sh remediation runs twice without error (idempotent)" {
  mock_dir="$(mktemp -d)"
  call_log="$mock_dir/calls.log"
  cat > "$mock_dir/gh" <<EOF
#!/usr/bin/env bash
echo "\$@" >> "$call_log"
if [ "\$1" = "label" ] && [ "\$2" = "list" ]; then
  echo "in-progress"
  exit 0
fi
if [ "\$1" = "label" ] && [ "\$2" = "create" ]; then
  exit 0
fi
exit 0
EOF
  chmod +x "$mock_dir/gh"
  PATH="$mock_dir:$PATH" run bash scripts/check-required-labels.sh --create
  [ "$status" -eq 0 ]
  first_output="$output"
  PATH="$mock_dir:$PATH" run bash scripts/check-required-labels.sh --create
  [ "$status" -eq 0 ]
  rm -rf "$mock_dir"
}

# --- AT-370-10: ワークフロー skill に起動時ガードが配線されている（W-3a / Functional Story） ---
#
# Given: W-3a のスクリプトが存在する
# When:  skills/autopilot/SKILL.md または skills/full-autopilot/SKILL.md を読む
# Then:  check-required-labels の呼び出しと「不足は通知のみ・エラー終了しない・skip 可」
#        旨が記述されている

@test "#370 AT-370-10: autopilot or full-autopilot SKILL.md references check-required-labels.sh" {
  grep -q 'check-required-labels' skills/autopilot/SKILL.md skills/full-autopilot/SKILL.md
}

@test "#370 AT-370-10: wiring documents notify-only / non-error-exit / skippable behavior" {
  grep -l 'check-required-labels' skills/autopilot/SKILL.md skills/full-autopilot/SKILL.md | while read -r f; do
    grep -qF 'skip' "$f" || grep -qF 'スキップ' "$f"
  done
}

# --- AT-370-11: hook が plugin-global に配線されている（W-3b / regression 不変条件） ---
#
# Given: hook は setup-* を実行していない環境でも機能する必要がある
# When:  hooks/hooks.json の全 command フィールドを検査する
# Then:  すべての command が ${CLAUDE_PLUGIN_ROOT} を含み、.claude/hooks/ 等の
#        プロジェクトローカルパスへの配線が存在しない
#
# Note: これは回帰 AT。将来のバージョン・行数・hook 個数といった時点値を pin せず、
# 「全 command が plugin-global 参照」という不変条件のみを assert する（#289 の教訓）。

@test "#370 AT-370-11: every hooks.json command references \${CLAUDE_PLUGIN_ROOT}" {
  run python3 -c "
import json
with open('hooks/hooks.json') as f:
    d = json.load(f)
def walk(node):
    if isinstance(node, dict):
        if 'command' in node:
            cmd = node['command']
            assert '\${CLAUDE_PLUGIN_ROOT}' in cmd, f'command missing CLAUDE_PLUGIN_ROOT ref: {cmd}'
        for v in node.values():
            walk(v)
    elif isinstance(node, list):
        for v in node:
            walk(v)
walk(d)
print('OK')
"
  [ "$status" -eq 0 ]
  [ "$output" = "OK" ]
}

@test "#370 AT-370-11: hooks.json has no project-local .claude/hooks/ command wiring" {
  ! grep -q '"\.claude/hooks/' hooks/hooks.json
}
