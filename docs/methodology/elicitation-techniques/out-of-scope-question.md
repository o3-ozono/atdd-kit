# Out-of-Scope Question

> **Loaded by:** `defining-requirements` (Non-Goals 節), `batch-discovery` (スコープ境界確認)

See [common-principles.md](common-principles.md) for the operating principles shared across all 4 techniques in this catalog.

## 目的

スコープの境界は「何をやるか」だけでなく「何をあえてやらないか」を明示することで確定する。意図的に除外した項目とその理由を言語化させることで、後から「なぜこれが入っていないのか」という手戻りを防ぐ。

## 問いの型

- 「これは今回やらない、と決めたものはありますか？」
- 「一見この Issue に関係しそうだけど、あえて対象外にした項目はありますか？その理由は？」
- 「隣接する機能・要求のうち、今回のスコープに含めなかったものは何ですか？」

## 適用先マッピング

- `defining-requirements` の **Non-Goals 節**: 意図的に除外した項目とその一行理由を洗い出す際に使う。
- `batch-discovery` の **スコープ境界確認**: 複数 Issue を横断してスコープの重複・除外境界を確認する際に使う。

## 一次情報

Jeff Patton, *User Story Mapping: Discover the Whole Story, Build the Right Product*, O'Reilly Media, 2014.

## 例

> 聞き手: 「今回のスコープには含めない、と決めたものはありますか？」
> 回答者: 「多言語対応は将来やるけど、今回は日本語のみ」
> 聞き手: 「その判断の理由を一言で言うと？」
> 回答者: 「今のユーザーは全員日本語話者だから、優先度が低い」
