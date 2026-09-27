#!/usr/bin/env bash
# fast-jev-compaction を Mac の Claude Code に導入する（または --uninstall で元に戻す）。
#   ./setup-mac.sh             導入
#   ./setup-mac.sh --uninstall 撤去
# API キーは macOS キーチェーンにだけ保存し、リポジトリや settings.json には書かない。
set -euo pipefail

PIN="e3f262a7f4d42bd8dd32ced30d26176f7cb545b0"   # 内容を確認した commit（2026-09-17, v0.3.0）
UPSTREAM="https://github.com/tamaratran/fast-jev-compaction"
VENDOR="$HOME/.claude/vendor/fast-jev-compaction"
PLUGIN="fast-jev-compaction@fast-jev-compaction"
KEY_SERVICE="typesafe-api-key"
SETTINGS="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
RC="$HOME/.zshrc"
MIN_CLAUDE="2.1.274"
# トークン削減寄りの設定（理由は README.md）。デフォルトに戻すなら空にする
PLUGIN_CONFIG=(compactAtPercent=50 minReductionRatio=0.4 truncateHeadChars=150)
BEGIN="# >>> fast-jev-compaction >>>"
END="# <<< fast-jev-compaction <<<"

die() { echo "ERROR: $*" >&2; exit 1; }
say() { echo "==> $*"; }

version_ge() {  # version_ge 2.1.283 2.1.274
  awk -v a="$1" -v b="$2" 'BEGIN { split(a, x, "."); split(b, y, ".");
    for (i = 1; i <= 3; i++) { if (x[i] + 0 > y[i] + 0) exit 0; if (x[i] + 0 < y[i] + 0) exit 1 } exit 0 }'
}

set_hooks_flag() {  # settings.json の env.CLAUDE_CODE_ENABLE_FUNCTION_HOOKS を設定/削除
  mkdir -p "$(dirname "$SETTINGS")"
  [ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
  cp "$SETTINGS" "$SETTINGS.bak.$(date +%Y%m%d%H%M%S)"
  local tmp; tmp="$(mktemp)"
  if [ "$1" = on ]; then
    jq '.env = ((.env // {}) + {CLAUDE_CODE_ENABLE_FUNCTION_HOOKS: "1"})' "$SETTINGS" > "$tmp"
  else
    jq 'if .env then .env |= del(.CLAUDE_CODE_ENABLE_FUNCTION_HOOKS) else . end' "$SETTINGS" > "$tmp"
  fi
  mv "$tmp" "$SETTINGS"
}

remove_rc_block() {
  [ -f "$RC" ] && sed -i '' "/^$BEGIN\$/,/^$END\$/d" "$RC"
}

[ "$(uname)" = Darwin ] || die "macOS 用のスクリプトです"
command -v claude >/dev/null || die "claude コマンドが見つかりません"
command -v jq >/dev/null || die "jq が必要です (macOS 15 以降は標準搭載 / brew install jq)"

if [ "${1:-}" = "--uninstall" ]; then
  say "プラグインを削除"
  claude plugin uninstall "$PLUGIN" || true
  claude plugin marketplace remove fast-jev-compaction || true
  set_hooks_flag off
  remove_rc_block
  say "完了。キーチェーンのキーも消す場合: security delete-generic-password -s $KEY_SERVICE"
  exit 0
fi

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

# 2. プラグイン本体を確認済み commit に固定して取得
if [ -d "$VENDOR/.git" ]; then
  git -C "$VENDOR" fetch --quiet origin
else
  mkdir -p "$(dirname "$VENDOR")"
  git clone --quiet "$UPSTREAM" "$VENDOR"
fi
git -C "$VENDOR" -c advice.detachedHead=false checkout --quiet "$PIN"
say "fast-jev-compaction を ${PIN:0:7} に固定"

# 3. ローカル marketplace として登録してインストール
claude plugin marketplace list 2>/dev/null | grep -q fast-jev-compaction \
  || claude plugin marketplace add "$VENDOR"
claude plugin marketplace update fast-jev-compaction >/dev/null 2>&1 || true
config_args=()
for kv in ${PLUGIN_CONFIG[@]+"${PLUGIN_CONFIG[@]}"}; do config_args+=(--config "$kv"); done
claude plugin install "$PLUGIN" ${config_args[@]+"${config_args[@]}"}

# 4. function hooks の有効化（秘密情報ではないので settings.json に置く）
set_hooks_flag on

# 5. キーはシェル起動時にキーチェーンから読む
remove_rc_block
cat >> "$RC" <<RCEOF
$BEGIN
export TYPESAFE_API_KEY="\$(security find-generic-password -s $KEY_SERVICE -w 2>/dev/null)"
$END
RCEOF

say "完了。新しいターミナルで claude を起動し、/compact 後に"
say "  'fast-jev-compaction: kept N/M messages' のトーストが出れば有効です。"
