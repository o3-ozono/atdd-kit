# Elicitation Techniques Catalog

要件抽出（Discovery）の対話で使う技法を、一次情報付きで整理したカタログ。各技法ドキュメントは「目的 / 問いの型 / 適用先マッピング / 一次情報 / 例」の統一 5 フィールドを備える。`defining-requirements` / `batch-discovery` の SKILL.md は各節からこのカタログへマッピング参照するのみで、詳細手順・一次情報・例はここに委ねる。

## 技法一覧

| 技法 | 一次情報 | 適用先 | doc |
|------|---------|--------|-----|
| Pre-mortem | Gary Klein, "Performing a Project Premortem", *Harvard Business Review*, 2007 | `defining-requirements` Constraints 節・Open Questions 節 | [pre-mortem.md](pre-mortem.md) |
| Job Story | Alan Klement, "Replacing the User Story with the Job Story", JTBD blog, 2013 | `defining-requirements` Problem/Outcome 節 | [job-story.md](job-story.md) |
| One question at a time | Steve Krug, *Rocket Surgery Made Easy*, New Riders, 2010 | 全 skill の対話共通ルール | [one-question-at-a-time.md](one-question-at-a-time.md) |
| Out-of-scope question | Jeff Patton, *User Story Mapping*, O'Reilly, 2014 | `defining-requirements` Non-Goals 節・`batch-discovery` スコープ境界確認 | [out-of-scope-question.md](out-of-scope-question.md) |
| 共通原則 | — （カタログ独自整理） | 4 技法すべて | [common-principles.md](common-principles.md) |

## 使い方

1. どの節で問いを組み立てるか迷ったら、上表の「適用先」列から該当技法を探す。
2. 技法 doc の「問いの型」を参照して具体的な質問を組み立てる。
3. すべての技法に共通する運用原則（対話のキャッチボールで埋める／上位工程の責務を侵さない／対話ログを残す）は [common-principles.md](common-principles.md) を参照する。
