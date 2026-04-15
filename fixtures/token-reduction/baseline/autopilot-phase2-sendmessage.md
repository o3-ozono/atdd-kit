Use SendMessage to: "Developer" with implementation strategy instructions. Include Issue number, approved AC set, unified Plan, and reference to the Issue comment containing prior phase context:

## Issue #85 — Tamp-inspired token reduction

**Approved AC Set:**

### AC1: gh 呼び出しの `--json` フィールドが監査済み許可リストと一致
- **Given:** `skills/session-start/SKILL.md` および `commands/autopilot.md` の全 gh 呼び出しと、後段の参照箇所が存在する
- **When:** BATS テストが各 gh 呼び出しの `--json` 引数を抽出し、後段で実際に参照されているフィールド集合と突き合わせる
- **Then:** 全ての `--json` フィールドリストが後段参照フィールド集合と過不足ゼロで一致している

### AC2: Agent Team spawn プロンプトが参照のみを含み、フルテキストを重複注入しない
- **Given:** `commands/autopilot.md` の Phase 1 AC Review Round / Phase 2 plan / Phase 3 実装 / Phase 4 レビュー の SendMessage および Agent spawn 指示が存在する
- **When:** BATS テストが各 spawn/SendMessage プロンプト記述を抽出する
- **Then:** 各プロンプトには Issue body / Plan コメント本文 / PR body のフルテキストが含まれず、参照のみを含む

**Implementation Plan (full text):**
[...1000 chars of plan text...]

Proceed with implementation strategy for the following areas:
- file structure
- implementation order
- dependencies
- technical risks
