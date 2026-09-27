# Jev でトークン削減セット（Mac の Claude Code 用）

元ネタ: [@so_ainsight の投稿](https://x.com/so_ainsight/status/2102173541135466976)（Jev を使った OSS）。
Jev は TypeSafe の判定専用モデル。文章を書かず「選ぶ・採点する・はい/いいえ」だけを返すので速くて安い
（入力 約 $0.04–0.05 / 100万トークン、出力は無料）。

## 前提: トークンを使っているのはブラウザ操作と computer use

画面キャプチャは 1 枚で約 1,000〜1,600 トークンある。しかも会話に残り続け、**以後の毎ターン読み直される**。
30 枚撮れば約 4 万トークンが常駐し、1 ターンごとにそれを払う。対策は効く順に 3 つ。

| # | 対策 | 仕組み | 効果 |
| --- | --- | --- | --- |
| 1 | **ブラウザ操作は jev-browser** | ページの要素一覧を Jev が読み、どこを押すか決める。Claude には「done / stuck」などの結果だけが返る | 作者の計測で Claude が読む量は 557k → 8.3k トークン（41 タスク合計、中央値 1/5）。比較対象はテキストのスナップショットなので、キャプチャ方式と比べれば差はもっと大きい。Jev 側の 602k トークンは約 $0.03 |
| 2 | **画面操作はサブエージェント（`web-operator`, Sonnet）に任せる** | キャプチャはサブエージェントの文脈にだけ溜まり、終われば捨てられる。メインには数行の報告だけが戻る | メインの会話がキャプチャで膨らまない。操作自体も Opus より安い Sonnet で動く |
| 3 | fast-jev-compaction | 圧縮を「要約」から「不要なツール結果の削除」に置き換える | キャプチャ中心の会話では効きにくい（下記） |

1 と 2 は Jev なしでも一部効くが、組み合わせると一番効く。

## 6 リポジトリの評価

| リポジトリ | 判定 | 理由 |
| --- | --- | --- |
| [jev-browser](https://github.com/Ying-Kai-Liao/jev-browser) | **導入（本命）** | 上記 1。41 タスク中 40 成功、嘘の「完了」は 0。注文・送信・削除の前は止まって確認を返す |
| [hermes-jev-skills](https://github.com/kerpopule/hermes-jev-skills) | **一部採用** | モデル振り分けの削減は、作者の計測でほぼ「Sonnet に任せた」ことによるもので、Jev の判定の効果は約 4%。Jev なしのレーンとして取り入れた。同梱の `jev-computer-use` は次の段階の候補（下記） |
| [fast-jev-compaction](https://github.com/tamaratran/fast-jev-compaction) | **導入（補助）** | 文字の多い開発作業では効く。キャプチャ中心の会話では効きにくい |
| [jev-search](https://github.com/superagents-lab/jev-search) | 見送り | 人が使う検索サイト。Claude Code とつながらない |
| [reticle](https://github.com/reticlehq/reticle) | 見送り | 目的は検証（品質向上）。全 AI ツールに自動登録され、使用状況の送信も最初からオン |
| [NanoJev](https://github.com/TianyuCodings/NanoJev) | 見送り | 研究用の再現モデル |

## 入るもの

| 名前 | 中身 |
| --- | --- |
| `jev-browser` (MCP) | ブラウザ操作ツール 8 個。定義は約 1.4k トークン（Claude Code は MCP ツールを必要になるまで遅延読み込みする） |
| `web-operator` | ブラウザと computer use の担当（Sonnet, medium）。jev-browser の `browser_do` を優先し、キャプチャは見た目の確認が必要なときだけ撮る。パスワード入力や取り消せない操作はしない |
| `lane-small` / `lane-medium` | 機械的な作業は Haiku、普通の実装は Sonnet |
| `~/.claude/CLAUDE.md` の追記 | 約 170 トークン。「画面操作は web-operator に任せ、メインで撮らない」など |
| fast-jev-compaction | 下記 |

## fast-jev-compaction について

- **Jev の料金**: 1 回の圧縮で $0.001〜0.005。多く使っても月 $1.5 以下
- **キャプチャとの相性**: このプラグインはツール結果の文字しか見ていない。キャプチャを削っても、その分が削減率に数えられない。キャプチャ中心の会話では「削れていない」と判定され、通常の要約に戻ることが多い（戻っても害はない）。このため `minReductionRatio` はデフォルトの 0.25 のままにしている
- **設定**: `compactAtPercent` 60 → **50**（早めに圧縮して毎ターンの文脈を小さく保つ）、`truncateHeadChars` 300 → **150**
- 1M コンテキストのモデルでは、`/plugin configure fast-jev-compaction@fast-jev-compaction` で `compactAtPercent` を 10〜15 に下げる

## 次の段階: computer use を Jev に置き換える（未導入）

`hermes-jev-skills` の `jev-computer-use` は、デスクトップアプリも jev-browser と同じ方式で動かす。
アクセシビリティ情報から押せるボタンの一覧を作り、Jev に選ばせる。キャプチャは送らない。
Claude からはコマンドを 1 回呼ぶだけで、結果が JSON で返る。

ただし cua-driver（画面操作ドライバー。入手元はリポジトリに明記がなく要確認）の導入と、Mac のアクセシビリティ・画面収録の許可が必要になる。
キャプチャなしで動かないアプリ（ゲームや canvas 描画のアプリ）もある。
まず 1〜3 を 2 週間使い、それでも computer use でトークンが切れるなら導入する。

## 判定方法（2 週間で決める）

```sh
./token-report.sh 14 > before.tsv   # 導入前
# … 1〜2 週間使う …
./token-report.sh 14 > after.tsv
```

`weighted / turns`（1 ターンあたりの概算コスト指数）と、1 日あたりの `weighted` を比べる。

## セットアップ（Mac）

事前に [TypeSafe](https://console.typesafe.ai/settings/keys) で API キーを取得し、Node.js を入れておく（`brew install node`）。

```sh
git pull
cd claude-code/jev
./setup-mac.sh               # jev-browser + レーン + fast-jev-compaction
./setup-mac.sh --no-browser  # jev-browser なし
./setup-mac.sh --uninstall   # 全部元に戻す
```

スクリプトがやること:

1. Claude Code 2.1.274 以上であることを確認
2. API キーを macOS キーチェーン（`typesafe-api-key`）に保存。ファイルには書かない
3. fast-jev-compaction を確認済みの commit `e3f262a` に固定して入れる。上の設定を適用し、`settings.json` に `CLAUDE_CODE_ENABLE_FUNCTION_HOOKS=1` を追加、`~/.zshrc` にキーチェーンからキーを読む行を追加
4. `~/.claude/agents/` に `web-operator.md`・`lane-small.md`・`lane-medium.md` を置き、`~/.claude/CLAUDE.md` に短いルールを追記
5. jev-browser 0.1.1 と Chromium を入れ、キーチェーンからキーを読むラッパー経由で MCP に登録（このリポジトリを別の場所に移したら再実行）

変更するファイル（`settings.json`、`CLAUDE.md`）は、変更前に `.bak.<日時>` として保存する。

**今使っているブラウザ系ツールとの関係**: Playwright MCP や Claude in Chrome を入れている場合、Claude がそちらを選ぶことがある。
jev-browser に寄せたいなら、それらを無効にするか、依頼時に「web-operator に任せて」と書く。

## 注意点

- **データ送信**: jev-browser はページの要素一覧と表示テキストを、fast-jev は会話（発言とツールの入力）を `api.typesafe.ai` に送る。送信先はこの 1 箇所だけ（コードで確認済み）。キャプチャは送らない。社外秘の画面を操作するときは判断すること
- **試験提供中の機能**: fast-jev は Claude Code の function hooks を使うので、更新で動かなくなる可能性がある。その場合も自動で通常の要約に戻るだけ
- **確認済み**: fast-jev はテスト 29 件通過・インストール動作を確認。レーンは指定モデルで起動することを確認。`web-operator` は Sonnet で起動し、jev-browser を優先する方針で動くことを確認。jev-browser は MCP サーバーの起動と 8 ツールの公開を確認
- **未確認**: キーを使った実際のブラウザ操作（この環境に TypeSafe のキーがなく、Chromium の版も合わないため）。Mac 上でのセットアップスクリプトの実行
