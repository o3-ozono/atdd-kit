# Pre-mortem

> **Loaded by:** `defining-requirements` (Constraints 節・Open Questions 節)

See [common-principles.md](common-principles.md) for the operating principles shared across all 4 techniques in this catalog.

## 目的

プロジェクトが実行される前に、あたかも既に失敗したかのように仮定し、「なぜ失敗したのか」の理由を遡って洗い出すことで、実行前にしか見えないリスクを表面化させる。事後の post-mortem（検死）を実行前に行うという逆転の発想により、通常の議論では出にくい懸念を早期に引き出す。

## 問いの型

- 「このプロジェクトが半年後に失敗していたとします。何が原因だったと思いますか？」
- 「もし今の計画通り進めて破綻するとしたら、最初に綻びが出るのはどこですか？」
- 一人称の確信度を下げる仮定法（「失敗した」と既成事実として問う）を使い、楽観バイアスにブロックされずにリスクを言語化させる。

## 適用先マッピング

- `defining-requirements` の **Constraints 節**: 制約条件を洗い出す際に、「この制約を無視したらどこで破綻するか」を問う。
- `defining-requirements` の **Open Questions 節**: 未解決の意思決定事項を洗い出す際に、「この論点を放置したら何が起きるか」を問う。

## 一次情報

Gary Klein, "Performing a Project Premortem", *Harvard Business Review*, September 2007.

## 例

> 聞き手: 「このリリースが 3 ヶ月後に大きな問題を起こしていたと想像してください。振り返ったとき、最初の兆候はどこに出ていたと思いますか？」
> 回答者: 「たぶん、想定外の負荷でバックエンドが落ちていた」
> 聞き手: 「その負荷を事前に見積もれなかった理由は何だと思いますか？」

一問ずつ掘り下げ、一括で全リスクを聞き出そうとしない（[one-question-at-a-time.md](one-question-at-a-time.md) と併用）。
