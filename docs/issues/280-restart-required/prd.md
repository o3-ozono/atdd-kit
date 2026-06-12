# PRD: session-start のプラグインバージョン検知 — RESTART_REQUIRED / STALE_SESSION の追加

## Problem

Claude Code はプラグインをセッション起動時にスナップショットし、ホットリロードしない。そのため、ローカルに新版がインストール済みでも、起動中セッションがロードしているのは旧版のまま、という乖離が必ず1セッション遅れで発生する。`scripts/check-plugin-version.sh` はこの乖離を検知できず、同一根本原因から2つの故障モードを生む。

- **故障モード A（新版検知漏れ）:** スクリプトは「ロード中の `PLUGIN_ROOT`」と「前回チェック時のマーカー（`<cache>/atdd-kit.version`）」の2つしか見ない。新版が `~/.claude/plugins/installed_plugins.json` にインストール済みでも、ロード版とマーカーが一致していれば `NO_UPDATE` を返し続け、ユーザーは新版の存在に気づけない（実例: stockbot-jp, 2026-06-12 — リモート/キャッシュ/installed が v3.12.0、ロード中が v3.11.1 なのに「v3.11.1（更新なし）」と表示）。
- **故障モード B（逆向き UPDATED / ダウングレード）:** 新版セッションがマーカーを `3.12.0` に更新した後、旧版（v3.11.1）をロードしたままの古いセッションが再実行すると、cached(`3.12.0`) ≠ current(`3.11.1`) を「更新」と誤検知し逆向きの `UPDATED` を出力する。さらに (1) v3.11.1 の CHANGELOG に `## [3.12.0]` が無く break に到達しないため全エントリを数えて `VERSIONS: 63` と誤集計し、(2) マーカーを `3.11.1` に書き戻して新版セッションの検知状態を巻き戻す。この `UPDATED` を信じて session-start の Phase E2（Auto-Sync）が走ると、旧版のテンプレート/deploy ファイルで上書き = 実質ダウングレードになる。

## Why now

#246 以降 autopilot が本格運用に入り、プラグインのリリース頻度が上がっている（直近30hで v3.4.0 → v3.12.0、16 リリース）。リリース頻度が上がるほど「新版インストール済み・旧版ロード中」の乖離窓に入るセッションが増え、A の検知漏れと B のダウングレード事故の発生確率が上がる。実際に stockbot-jp で両モードが観測された段階であり、運用が広がる前に塞ぐ必要がある。

## Outcome

- 新版インストール済み + 旧版ロード中のセッションで `RESTART_REQUIRED` が出力され、session-start レポートに再起動を促すメッセージが表示される。
- ロード版 < マーカー版（`CURRENT < CACHED`）のセッションで `STALE_SESSION` が出力され、**マーカーは更新されず**、session-start 側は E2 Auto-Sync をスキップして再起動を促す（ダウングレード上書きが起きない）。
- `installed_plugins.json` が無い/パース不能な環境でも、従来の FIRST_RUN / NO_UPDATE / UPDATED が壊れない（フォールバック）。
- RESTART_REQUIRED / STALE_SESSION 後に再起動した次セッションでは、従来どおり UPDATED（正しい CHANGELOG 件数付き）が出る。
- 既存 BATS スイート green + 新規分岐の BATS テスト追加。

## What

- `scripts/check-plugin-version.sh` に第3・第4の検知を追加（ネットワークアクセス不要）:
  - **RESTART_REQUIRED:** `~/.claude/plugins/installed_plugins.json` から当該プロジェクトの `version` を読み、ロード版（`PLUGIN_ROOT` の `plugin.json`）より新しければ出力（`RESTART_REQUIRED\n<loaded>\n<installed>`）。マーカーは更新しない。
  - **STALE_SESSION:** `CURRENT < CACHED`（`sort -V`）を検知したら出力（`STALE_SESSION\n<loaded>\n<cached>`）。マーカーは更新しない。
  - **CHANGELOG 集計ガード:** UPDATED 経路で CACHED エントリが CHANGELOG 内に見つからない場合は件数を `UNKNOWN` とする（`63` 誤集計の防止）。
- `installed_plugins.json` のパス（`~/.claude/plugins/installed_plugins.json`）が無い/パース不能なら従来動作にフォールバック。
- `skills/session-start/SKILL.md`（Phase 1-E / E2）の出力プロトコル表に `RESTART_REQUIRED` / `STALE_SESSION` の行を追加し、STALE_SESSION 時は E2 Auto-Sync をスキップ、両者で再起動を促すメッセージを表示する配線。
- BATS テスト追加（A/B 各分岐 + フォールバック + 再起動後の正常 UPDATED）。
- CHANGELOG 更新（Keep a Changelog）。

## Non-Goals

- 自動再起動・自動リロード — 検知して人間に再起動を促すのみ（Claude Code がホットリロードしない仕様は本 Issue の対象外）。
- ネットワーク経由のリモートタグ取得 — 検知はすべてローカルファイル（`installed_plugins.json` / マーカー / `plugin.json` / CHANGELOG）で完結する。
- マーカーファイルの更新基準の変更 — 従来どおり「ロード中バージョン」基準を維持し、RESTART_REQUIRED / STALE_SESSION 時のみ非更新とする。
- session-start の他フェーズ（D 移行・worktree 掃除等）の挙動変更。

## Open Questions

- `installed_plugins.json` 内で「当該プロジェクトのエントリ」を特定するキー（`projectPath` がカレントに一致するか等）の正確なスキーマ確認 → plan で実ファイルを確認して確定する。
- RESTART_REQUIRED と STALE_SESSION が同時に成立しうるか（例: ロード版 < マーカー版 かつ installed 版 > ロード版）の優先順位 → plan で分岐順序を確定する。
