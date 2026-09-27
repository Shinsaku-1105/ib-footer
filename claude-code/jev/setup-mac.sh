#!/usr/bin/env bash
# Jev を使ったトークン削減セットを Mac の Claude Code に導入する。
#   ./setup-mac.sh                 fast-jev-compaction + サブエージェントのレーン
#   ./setup-mac.sh --with-browser  上に加えて jev-browser (MCP)
#   ./setup-mac.sh --uninstall     すべて撤去
# API キーは macOS キーチェーンにだけ保存し、リポジトリや設定ファイルには書かない。
set -euo pipefail

KIT="$(cd "$(dirname "$0")" && pwd)"
PIN="e3f262a7f4d42bd8dd32ced30d26176f7cb545b0"   # fast-jev-compaction: 内容を確認した commit（2026-09-17, v0.3.0）
UPSTREAM="https://github.com/tamaratran/fast-jev-compaction"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
VENDOR="$CLAUDE_DIR/vendor/fast-jev-compaction"
PLUGIN="fast-jev-compaction@fast-jev-compaction"
KEY_SERVICE="typesafe-api-key"
SETTINGS="$CLAUDE_DIR/settings.json"
CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
RC="$HOME/.zshrc"
MIN_CLAUDE="2.1.274"
# トークン削減寄りの設定（理由は README.md）。デフォルトに戻すなら空にする
PLUGIN_CONFIG=(compactAtPercent=50 minReductionRatio=0.4 truncateHeadChars=150)
RC_MARK="fast-jev-compaction"
MD_MARK="ib-footer-jev:lanes"

die() { echo "ERROR: $*" >&2; exit 1; }
say() { echo "==> $*"; }

version_ge() {  # version_ge 2.1.283 2.1.274
  awk -v a="$1" -v b="$2" 'BEGIN { split(a, x, "."); split(b, y, ".");
    for (i = 1; i <= 3; i++) { if (x[i] + 0 > y[i] + 0) exit 0; if (x[i] + 0 < y[i] + 0) exit 1 } exit 0 }'
}

backup() { [ -f "$1" ] && cp "$1" "$1.bak.$(date +%Y%m%d%H%M%S)" || true; }

strip_block() {  # strip_block <file> <marker>: marker の BEGIN〜END 行を取り除く
  [ -f "$1" ] || return 0
  local tmp; tmp="$(mktemp)"
  awk -v m="$2" 'index($0, m " BEGIN") { skip = 1 }
    !skip { if ($0 == "") blank++; else { for (; blank > 0; blank--) print ""; print } }
    index($0, m " END") { skip = 0 }' "$1" > "$tmp"
  cat "$tmp" > "$1" && rm -f "$tmp"
}

set_hooks_flag() {  # settings.json の env.CLAUDE_CODE_ENABLE_FUNCTION_HOOKS を設定/削除
  mkdir -p "$CLAUDE_DIR"
  [ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
  backup "$SETTINGS"
  local tmp; tmp="$(mktemp)"
  if [ "$1" = on ]; then
    jq '.env = ((.env // {}) + {CLAUDE_CODE_ENABLE_FUNCTION_HOOKS: "1"})' "$SETTINGS" > "$tmp"
  else
    jq 'if .env then .env |= del(.CLAUDE_CODE_ENABLE_FUNCTION_HOOKS) else . end' "$SETTINGS" > "$tmp"
  fi
  mv "$tmp" "$SETTINGS"
}

[ "$(uname)" = Darwin ] || die "macOS 用のスクリプトです"
command -v claude >/dev/null || die "claude コマンドが見つかりません"
command -v jq >/dev/null || die "jq が必要です (macOS 15 以降は標準搭載 / brew install jq)"

WITH_BROWSER=0
case "${1:-}" in
  --uninstall)
    say "fast-jev-compaction を削除"
    claude plugin uninstall "$PLUGIN" || true
    claude plugin marketplace remove fast-jev-compaction || true
    set_hooks_flag off
    strip_block "$RC" "$RC_MARK"
    say "レーンを削除"
    rm -f "$CLAUDE_DIR/agents/lane-small.md" "$CLAUDE_DIR/agents/lane-medium.md"
    backup "$CLAUDE_MD"; strip_block "$CLAUDE_MD" "$MD_MARK"
    say "jev-browser を削除"
    claude mcp remove -s user jev-browser >/dev/null 2>&1 || true
    say "完了。キーチェーンのキーも消す場合: security delete-generic-password -s $KEY_SERVICE"
    exit 0 ;;
  --with-browser) WITH_BROWSER=1 ;;
  "") ;;
  *) die "不明なオプション: $1" ;;
esac

ver="$(claude --version | awk '{print $1}')"
version_ge "$ver" "$MIN_CLAUDE" || die "Claude Code $MIN_CLAUDE 以上が必要です（現在 $ver）。claude update を実行してください"
say "Claude Code $ver OK"

# 1. API キー（キーチェーン）
if security find-generic-password -s "$KEY_SERVICE" -w >/dev/null 2>&1; then
  say "TypeSafe API キーはキーチェーンに登録済み"
else
  say "TypeSafe API キーをキーチェーンに登録します（入力は表示されません）"
  security add-generic-password -a "$USER" -s "$KEY_SERVICE" -U -w
fi

# 2. fast-jev-compaction: 確認済み commit に固定して取得し、ローカル marketplace から入れる
if [ -d "$VENDOR/.git" ]; then
  git -C "$VENDOR" fetch --quiet origin
else
  mkdir -p "$(dirname "$VENDOR")"
  git clone --quiet "$UPSTREAM" "$VENDOR"
fi
git -C "$VENDOR" -c advice.detachedHead=false checkout --quiet "$PIN"
say "fast-jev-compaction を ${PIN:0:7} に固定"
claude plugin marketplace list 2>/dev/null | grep -q fast-jev-compaction \
  || claude plugin marketplace add "$VENDOR"
claude plugin marketplace update fast-jev-compaction >/dev/null 2>&1 || true
config_args=()
for kv in ${PLUGIN_CONFIG[@]+"${PLUGIN_CONFIG[@]}"}; do config_args+=(--config "$kv"); done
claude plugin install "$PLUGIN" ${config_args[@]+"${config_args[@]}"}
set_hooks_flag on   # function hooks の有効化（秘密情報ではないので settings.json に置く）

# キーはシェル起動時にキーチェーンから読む
strip_block "$RC" "$RC_MARK"
cat >> "$RC" <<RCEOF
# >>> $RC_MARK BEGIN
export TYPESAFE_API_KEY="\$(security find-generic-password -s $KEY_SERVICE -w 2>/dev/null)"
# <<< $RC_MARK END
RCEOF

# 3. サブエージェントのレーン（Jev 不要、データ送信なし）
mkdir -p "$CLAUDE_DIR/agents"
cp "$KIT/agents/lane-small.md" "$KIT/agents/lane-medium.md" "$CLAUDE_DIR/agents/"
backup "$CLAUDE_MD"; strip_block "$CLAUDE_MD" "$MD_MARK"
{ [ -s "$CLAUDE_MD" ] && echo; cat "$KIT/claude-md-block.md"; } >> "$CLAUDE_MD"
say "レーン (lane-small / lane-medium) を追加"

# 4. jev-browser（任意）
if [ "$WITH_BROWSER" = 1 ]; then
  command -v npx >/dev/null || die "jev-browser には Node.js (npx) が必要です: brew install node"
  npx -y -p jev-browser@0.1.1 playwright install chromium
  claude mcp remove -s user jev-browser >/dev/null 2>&1 || true
  claude mcp add -s user jev-browser -- "$KIT/jev-browser-mcp.sh"
  say "jev-browser を MCP に登録（このリポジトリの場所を移動したら再実行）"
fi

say "完了。新しいターミナルで claude を起動し、/compact 後に"
say "  'fast-jev-compaction: kept N/M messages' のトーストが出れば有効です。"
