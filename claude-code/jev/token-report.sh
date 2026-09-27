#!/usr/bin/env bash
# Claude Code のトークン消費を日別に集計する（fast-jev 導入前後の比較用）。
# 使い方: ./token-report.sh [日数=14]
# 読むのは ~/.claude/projects/**/*.jsonl のみ。外部には何も送らない。
set -euo pipefail

DAYS="${1:-14}"
ROOT="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects"
command -v jq >/dev/null || { echo "jq が必要です (macOS 15 以降は標準搭載 / brew install jq)" >&2; exit 1; }
[ -d "$ROOT" ] || { echo "$ROOT がありません" >&2; exit 1; }

# 同じ message.id がストリーミングの content block ごとに重複記録されるので id で重複排除する。
# weighted = 入力 + 1.25×cache書込 + 0.1×cache読込 + 5×出力（入力単価を1とした概算コスト指数）
find "$ROOT" -name '*.jsonl' -mtime "-$DAYS" -print0 \
| xargs -0 cat 2>/dev/null \
| jq -rn '
  reduce (inputs | select(type == "object")) as $r ({seen: {}, days: {}};
    ($r.timestamp // "" | .[0:10]) as $d
    | if ($r.type == "system" and $r.subtype == "compact_boundary") then
        .days[$d].compactions += 1
      elif ($r.message.usage? and $r.message.id?) and (.seen[$r.message.id] | not) then
        .seen[$r.message.id] = true
        | ($r.message.usage) as $u
        | .days[$d].sessions[$r.sessionId // "?"] = true
        | .days[$d].turns += 1
        | .days[$d].input += ($u.input_tokens // 0)
        | .days[$d].cw += ($u.cache_creation_input_tokens // 0)
        | .days[$d].cr += ($u.cache_read_input_tokens // 0)
        | .days[$d].out += ($u.output_tokens // 0)
      else . end)
  | .days | to_entries | map(select(.key != "")) | sort_by(.key)
  | (["date","sess","turns","input","cache_w","cache_r","output","compact","weighted"] | @tsv),
    (.[] | .value as $v
      | [ .key, ($v.sessions // {} | length), ($v.turns // 0), ($v.input // 0), ($v.cw // 0),
          ($v.cr // 0), ($v.out // 0), ($v.compactions // 0),
          ((($v.input // 0) + 1.25 * ($v.cw // 0) + 0.1 * ($v.cr // 0) + 5 * ($v.out // 0)) | floor) ]
      | @tsv)
' | { command -v column >/dev/null && column -t || cat; }
