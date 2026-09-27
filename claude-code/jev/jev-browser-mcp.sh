#!/usr/bin/env bash
# jev-browser の MCP サーバー起動ラッパー。API キーは macOS キーチェーンから読むので設定ファイルに平文で残らない。
set -euo pipefail
if [ -z "${TYPESAFE_API_KEY:-}" ]; then
  TYPESAFE_API_KEY="$(security find-generic-password -s typesafe-api-key -w)"
  export TYPESAFE_API_KEY
fi
exec npx -y -p jev-browser@0.1.1 jev-browser-mcp
