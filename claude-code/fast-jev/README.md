# fast-jev-compaction 導入キット（Mac 用）

元ネタ: [@so_ainsight の投稿](https://x.com/so_ainsight/status/2102173541135466976)（Jev を使った OSS 8選）。
そのうち Claude Code のトークン消費に直接効く [tamaratran/fast-jev-compaction](https://github.com/tamaratran/fast-jev-compaction) を導入する。

## これは何か

Claude Code の `/compact`（と自動 compaction）を置き換えるプラグイン。

- 標準: Claude 自身が会話を**要約**する → 出力トークンを消費し、待ち時間が出る。ファイルパスやエラー文などが消えることがある
- fast-jev: TypeSafe の判定専用モデル **Jev** がツール呼び出し/結果ごとに「まだ要るか」を採点し、要らないものだけ削る。残す部分は**一字一句そのまま**。ユーザーと Claude の発言は削らない
- Jev が失敗した、または削減率が `minReductionRatio` に届かないときは標準の要約に自動で戻る

## 費用対効果

### Jev 側のコスト: ほぼゼロ

| 項目 | 値 |
| --- | --- |
| Jev 単価 | 入力 約 $0.04–0.05 / 100万トークン、出力は無料 |
| 1回の compaction | state 25k 以下 × リクエスト 1〜4 回 ≒ 30k〜120k トークン → **$0.001〜0.005** |
| 1日 10 回 × 30 日 | **月 $1.5 以下**（最悪ケース） |

### Claude 側への効果: 設定しだいでプラスにもマイナスにもなる

| | 効果 |
| --- | --- |
| ＋ | 要約の生成がなくなる（出力数千トークン＋全文の読み込み1回＋待ち時間） |
| ＋ | 情報が消えないので、compaction 後にファイルを読み直したりコマンドを再実行したりする回数が減る |
| − | 要約（1〜2万トークン程度）より**圧縮後の文脈が大きく残る**。最低削減率はデフォルトで 25% |
| − | 以後の毎ターン、その残った文脈を読み直す（cache 読込は 0.1 倍だが回数分かかる） |

**結論**: デフォルト設定のままだと、純粋なトークン量は**減らない場合もある**（品質と速度を上げる道具）。
ただし compaction が安くて情報も失われないので、**早めにこまめに圧縮して毎ターンの文脈を小さく保つ**使い方ができ、
これがトークン削減として一番効く。このため `setup-mac.sh` は次の設定で入れる。

| 設定 | デフォルト | このキット | 理由 |
| --- | ---: | ---: | --- |
| `compactAtPercent` | 60 | **50** | 毎ターンの文脈量に比例して課金されるので、早めに圧縮する |
| `minReductionRatio` | 0.25 | **0.4** | 4割以上削れないときは標準要約に任せる（中途半端に大きい文脈を残さない） |
| `truncateHeadChars` | 300 | **150** | 不要と判定されたツール出力の先頭を残す量を減らす |
| `keepThreshold` | 0.5 | 0.5 | 上げると削れる量は増えるが、必要な出力まで消えるリスクがある。まずは据え置き |

1M コンテキストのモデルを使う場合、50% は 50 万トークンなので遅すぎる。
圧縮が **8万〜12万トークン付近**で起きるよう `/plugin configure` で 10〜15 程度に下げる。

### 判定方法（2週間で決める）

```sh
./token-report.sh 14 > before.tsv   # 導入前に保存
# … 1〜2 週間使う …
./token-report.sh 14 > after.tsv
```

`weighted` 列（入力単価を 1 とした概算コスト指数）を 1ターンあたり（`weighted / turns`）で比べる。
下がっていなければ `./setup-mac.sh --uninstall` で撤去する。

## 注意点

- **データ送信**: 会話の全文（ユーザー/Claude の発言とツールの入力。ツール出力は1行の注記に置き換えたもの）が `api.typesafe.ai` に送られる。社外秘のリポジトリでは使うかどうか判断すること。送信先はこの1箇所だけ（コードで確認済み）
- **early-access 機能**: Claude Code 2.1.274 以降の function hooks を使う。Claude Code を更新すると動かなくなる可能性がある。その場合は自動で標準要約に戻るだけで、作業は止まらない
- **バージョン固定**: 内容を確認した commit `e3f262a`（v0.3.0）に固定して入れる。テスト 29 件通過、`claude plugin validate` 通過を確認済み。上流の更新は中身を見てから `setup-mac.sh` の `PIN` を書き換える

## セットアップ（Mac）

事前に [TypeSafe](https://typesafe.ai) で API キーを取得しておく。

```sh
git pull
cd claude-code/fast-jev
./setup-mac.sh
```

スクリプトがやること:

1. Claude Code のバージョンを確認（2.1.274 以上）
2. API キーを macOS キーチェーンに保存（`typesafe-api-key`）。ファイルには書かない
3. プラグインを `~/.claude/vendor/fast-jev-compaction` に取得し、上の commit に固定
4. ローカル marketplace として登録し、上の設定でインストール
5. `~/.claude/settings.json` の `env` に `CLAUDE_CODE_ENABLE_FUNCTION_HOOKS=1` を追加（変更前のファイルは `.bak.*` に保存）
6. `~/.zshrc` に、起動時にキーチェーンからキーを読む行を追加

新しいターミナルで `claude` を起動し、`/compact` を実行して
`fast-jev-compaction: kept N/M messages, no summary (…)` と出れば有効になっている。
`fallback to built-in summary` と出た場合は、セッションが短いか、削減率が 0.4 に届かなかったということ。

デスクトップアプリから起動する場合は `.zshrc` が読まれないので、`/plugin configure fast-jev-compaction@fast-jev-compaction` で API キーを設定する。

撤去: `./setup-mac.sh --uninstall`

## 投稿の残り 7 つについて

x.com はこの環境から開けず、全 8 件は確認できなかった。確認できたのは次の 2 件で、どちらも Claude Code のトークン削減には直接つながらないので今回は入れていない。

- `jev-browser` / [`jev-ultrafast`](https://github.com/browser-use/jev-ultrafast): ブラウザ操作を Jev の選択問題にする。スクリーンショットや DOM を Claude に渡さなくてよくなるので、ブラウザ自動化を多用する場合は効く
- `jev-search`: 検索クエリの意図解釈と情報源の選択を Jev で行う
