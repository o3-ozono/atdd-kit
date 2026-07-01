# Plan: 機能優先度の方法論 doc を新設（#367）

<!-- 2-5 分粒度のタスク行と verification 行を交互に配置する（superpowers writing-plans 形式）。
     各タスクは単一の操作に限定し、verification で完了条件を即確認できる粒度にする。 -->

## 設計判断（概要）

- **接続方式**：PRD Open Questions #2 の Gate ① 承認どおり、`defining-requirements` スキルの機能要件パートから `docs/methodology/prioritization.md` を参照する接続を SKILL.md に追記する（loaded-docs 相当の参照）。`defining-requirements` は現状 loaded-docs リストを持たないため、機能要件を扱う Flow ステップ（Section 4 — What）に doc 参照指示を挿入し、参照コメントを添える最小変更とする。実装ロジック（判断アルゴリズム）は変更しない（Non-Goal 準拠）。
- **BATS 配置**：既存の doc 構造検証は `test_docs_restructure.bats`（`[ -f ... ]` + `grep -q` セクション検証）の型を踏襲。本 Issue は独立ファイル `tests/test_prioritization_doc.bats` を新設し、`prioritization.md` の必須セクション存在を `grep` で pin する。
- **一次情報の忠実性**：MoSCoW（DSDM）を原典として扱い、原典逸脱部を `[独自]` マーカーで明示する（CS-1）。BATS は `[独自]` マーカーの存在も pin して境界表示の退行を防ぐ。
- **回帰安全性**：BATS ピンは point-in-time 値（バージョン番号・行数・日付）を exact-pin せず、セクション見出し・キーワードの不変条件のみを assert する。

## Implementation

- [ ] `docs/methodology/prioritization.md` を新規作成し、冒頭に doc の目的と「MoSCoW（DSDM）一次情報 + atdd-kit 派生（`[独自]` 明示）」の位置づけを記述する（US-1 / CS-1）
- [ ] verify: `prioritization.md` が存在し、冒頭に `MoSCoW` と `DSDM` と `[独自]` の 3 語が含まれる

- [ ] 「5 段階」セクションを追加し、MUST / SHOULD / WANT / 次回以降 `[独自]` / 破棄 `[独自]` の 5 行を含む定義テーブルを記述する（US-1）
- [ ] verify: セクション見出しに「5 段階」相当が存在し、テーブルに `MUST` `SHOULD` `WANT` `次回以降` `破棄` の 5 ラベルがすべて含まれる

- [ ] 「2 軸判定 `[独自]`」セクションを追加し、軸 A：効き（本質課題への解決力）と軸 B：工数（今回の実装コスト）を分離評価するフレーム、および効き×工数→推奨ラベルのマッピング表を記述する（US-2）
- [ ] verify: セクションに「効き」「工数」の両語が含まれ、2 軸統合マッピング表が存在する

- [ ] 「anti-pattern」セクションを追加し、工数を効きに混ぜる誤用・視点漏れ・「次回以降」のバケツ化・破棄理由の空欄化の 4 項目を記述する（US-2 / US-3）
- [ ] verify: セクションに「anti-pattern」相当の見出しと「効くけど大変だから WANT」の誤用記述が含まれる

- [ ] 「破棄の扱い」セクションを追加し、破棄要件は PRD コア機能テーブルから削除せず `破棄` ラベル + 理由付きで残す（ゾンビ復活防止）運用を記述する（US-3）
- [ ] verify: セクションに「破棄」見出しと「ゾンビ復活」相当の記述が含まれる

- [ ] `defining-requirements` スキルの機能要件を扱う Flow ステップに `docs/methodology/prioritization.md` の 5 段階・2 軸フレーム参照指示を追記する（US-4 / Non-Goal: ロジック変更なし・参照追記のみ）
- [ ] verify: `skills/defining-requirements/SKILL.md` に `docs/methodology/prioritization.md` への参照が 1 箇所以上存在する

## Testing

- [ ] `tests/test_prioritization_doc.bats` を新設し、必須 4 セクション（5 段階定義テーブル・2 軸定義・anti-pattern・破棄の扱い）と `[独自]` マーカーの存在、および `defining-requirements` からの参照接続を検証する BATS ピンを追加する（CS-2 / US-4）
- [ ] verify: `bats tests/test_prioritization_doc.bats` が green

- [ ] BATS ピンが point-in-time 値（バージョン・行数・日付）を exact-pin していないことを確認する（回帰安全性）
- [ ] verify: `test_prioritization_doc.bats` 内に数値バージョン・行数の literal 比較が存在しない

## Finishing

- [ ] `docs/README.md` の methodology セクションに `prioritization.md` を追記する（Non-Goal: 本文複製はしない・一覧登録のみ）
- [ ] verify: `docs/README.md` に `prioritization.md` への言及が存在する

- [ ] `CHANGELOG.md` の `[Unreleased]` に本追加を記載し、`.claude-plugin/plugin.json` の version を patch bump（4.4.0 → 4.4.1）する（CS-3）
- [ ] verify: CHANGELOG 先頭リリース見出しの version と plugin.json の version が整合する（`scripts/check-plugin-version.sh` 相当）

- [ ] ドキュメント整合性チェック
- [ ] verify: 関連ドキュメント（`docs/README.md` methodology 一覧・DEVELOPMENT.md の doc 構成記述）が変更内容と整合している
