# Jev でトークン削減セット（Mac の Claude Code 用）

元ネタ: [@so_ainsight の投稿](https://x.com/so_ainsight/status/2102173541135466976)（Jev を使った OSS）。
Jev は TypeSafe の判定専用モデル。文章を書かず「選ぶ・採点する・はい/いいえ」だけを返すので速くて安い
（入力 約 $0.04–0.05 / 100万トークン、出力は無料）。

## 6 リポジトリの評価

| リポジトリ | 何をするか | Claude Code のトークン削減 | 判定 |
| --- | --- | --- | --- |
| [fast-jev-compaction](https://github.com/tamaratran/fast-jev-compaction) | `/compact` を「要約」から「不要なツール出力だけ削除」に置き換える | ◎ 設定しだいで効く（下記） | **導入** |
| [hermes-jev-skills](https://github.com/kerpopule/hermes-jev-skills) | モデル振り分け（lanes）、検索結果の絞り込みなど 10 スキル | ○ ただし効くのは Jev ではなく「安いモデルのサブエージェントに任せる」部分 | **考え方だけ採用**（Jev なしのレーンとして導入） |
| [jev-browser](https://github.com/Ying-Kai-Liao/jev-browser) | ブラウザ操作の MCP。ページの読み取りを Jev が担当 | ○ ブラウザ操作をするときだけ（中央値 1/5、大きいページほど効く） | **任意**（`--with-browser`） |
| [jev-search](https://github.com/superagents-lab/jev-search) | 人間向けの検索 Web アプリ（Search1API の契約も必要） | × Claude Code とつながらない | 見送り |
| [reticle](https://github.com/reticlehq/reticle) | 「完了」の主張を実アプリで検証するツール。Jev は探索の補助だけ | △ 目的は品質。回帰テストの再実行は安いが、インストーラーが全エージェントに登録し、テレメトリが既定オン | 見送り（Web アプリ開発で E2E 検証したくなったら再検討） |
| [NanoJev](https://github.com/TianyuCodings/NanoJev) | Jev を 0.6B で再現した研究（ゲームのデモ） | × 実用ツールではない | 見送り |

### hermes-jev-skills を丸ごと入れない理由

作者自身の計測（[docs/lanes.md](https://github.com/kerpopule/hermes-jev-skills/blob/main/docs/lanes.md)）が根拠:

- 実コミット 9 件の再現で、Opus(high) 全部 $3.27 → Jev に振り分けさせると $1.60（**-51%**）。ただし Jev は 9 件**すべて**を medium（Sonnet）に振った。つまり削減は「Sonnet に任せた」ことによるもので、Jev の判定はほぼ効いていない
- Claude Code の実運用 2,656 回の分析では、Jev による振り分けの削減は **-3.9%**
- 丸ごと入れると 10 スキル（計 77KB）の説明文と CLAUDE.md の追記が毎セッション文脈に入る。メール仕分けや GUI 操作など、Claude Code での開発に関係ないものも多い

そこで、Jev を使わない 2 レーンだけを入れる。

| サブエージェント | モデル | 用途 |
| --- | --- | --- |
| `lane-small` | Haiku, low | リネーム、1行修正、検索などの機械的な作業 |
| `lane-medium` | Sonnet, medium | 普通の実装・調査。迷ったらこれ |
| （メイン） | 今のモデル | 設計判断やセキュリティに関わる変更 |

同じ計測では、Haiku だけで回すと手戻りが増えて Sonnet より高くついた（$2.00）。このため既定は medium にしている。
CLAUDE.md への追記は約 120 トークン。

## fast-jev-compaction の費用対効果

- **Jev の料金**: 1 回の圧縮で $0.001〜0.005。多く使っても**月 $1.5 以下**
- **Claude 側**: 要約の生成（出力トークン＋待ち時間）がなくなり、情報も消えない。一方で、圧縮後に残る文脈は要約より大きいので、デフォルト設定のままでは総トークンが減らないこともある
- **効く使い方**: 毎ターンの費用は文脈の大きさに比例する。安く情報も失わずに圧縮できるので、**早めにこまめに圧縮して文脈を小さく保つ**。このため次の設定で入れる

| 設定 | デフォルト | このキット | 理由 |
| --- | ---: | ---: | --- |
| `compactAtPercent` | 60 | **50** | 早めに圧縮する |
| `minReductionRatio` | 0.25 | **0.4** | 4 割以上削れないときは通常の要約に任せる |
| `truncateHeadChars` | 300 | **150** | 不要と判定されたツール出力を先頭 150 文字だけ残す |

1M コンテキストのモデルでは 50% は 50 万トークンなので遅すぎる。
圧縮が 8〜12 万トークン付近で起きるよう、`/plugin configure fast-jev-compaction@fast-jev-compaction` で 10〜15 に下げる。

## 判定方法（2 週間で決める）

```sh
./token-report.sh 14 > before.tsv   # 導入前
# … 1〜2 週間使う …
./token-report.sh 14 > after.tsv
```

`weighted / turns`（1 ターンあたりの概算コスト指数）を比べる。下がっていなければ `./setup-mac.sh --uninstall` で撤去する。

## セットアップ（Mac）

事前に [TypeSafe](https://console.typesafe.ai/settings/keys) で API キーを取得しておく。

```sh
git pull
cd claude-code/jev
./setup-mac.sh                  # fast-jev-compaction + レーン
./setup-mac.sh --with-browser   # ブラウザ操作もするなら（Node.js が必要）
./setup-mac.sh --uninstall      # 全部元に戻す
```

スクリプトがやること:

1. Claude Code 2.1.274 以上であることを確認
2. API キーを macOS キーチェーン（`typesafe-api-key`）に保存。ファイルには書かない
3. fast-jev-compaction を確認済みの commit `e3f262a` に固定して入れる。上の設定を適用し、`settings.json` に `CLAUDE_CODE_ENABLE_FUNCTION_HOOKS=1` を追加、`~/.zshrc` にキーチェーンからキーを読む行を追加
4. `~/.claude/agents/` に `lane-small.md` と `lane-medium.md` を置き、`~/.claude/CLAUDE.md` に短いルールを追記
5. （`--with-browser` のとき）jev-browser 0.1.1 と Chromium を入れ、キーチェーンからキーを読むラッパー経由で MCP に登録

変更するファイル（`settings.json`、`CLAUDE.md`）は、変更前に `.bak.<日時>` として保存する。
新しいターミナルで `claude` を起動し、`/compact` 後に `fast-jev-compaction: kept N/M messages` と出れば有効になっている。
デスクトップアプリからは `.zshrc` が読まれないので、`/plugin configure` で API キーを設定する。

## 注意点

- **データ送信**: fast-jev は会話（発言とツールの入力。ツール出力は 1 行のメモに置き換えたもの）を、jev-browser はページの要素一覧を `api.typesafe.ai` に送る。送信先はこの 1 箇所だけ（コードで確認済み）。社外秘の作業で使うかは判断すること。レーンは外部送信なし
- **試験提供中の機能**: fast-jev は Claude Code の function hooks を使うので、更新で動かなくなる可能性がある。その場合も自動で通常の要約に戻るだけで、作業は止まらない
- **確認済み**: fast-jev はテスト 29 件通過・`claude plugin validate` 通過・インストール動作を確認。レーンは Haiku・low effort で起動することを確認。jev-browser は MCP サーバーの起動と 8 ツールの公開を確認（単体テストはこちらのコンテナの Chromium の版が合わず実行できず）
