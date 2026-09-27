#!/usr/bin/env bash
# PreToolUse フック: 画面操作ツール (Claude in Chrome / computer use / jev-browser) を
# メインの会話では止め、web-operator などのサブエージェントからだけ使わせる。
# キャプチャがメインの文脈に溜まって毎ターン読み直されるのを防ぐため。
# 一時的に許可するとき: JEV_KIT_ALLOW_MAIN_SCREEN=1 claude
input="$(cat)"
[ "${JEV_KIT_ALLOW_MAIN_SCREEN:-}" = 1 ] && exit 0
# agent_id はサブエージェント内で呼ばれたときだけ入る
if printf '%s' "$input" | grep -q '"agent_id"[[:space:]]*:[[:space:]]*"[^"]'; then
  exit 0
fi
cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Screen tools are blocked in the main session to keep screenshots out of its context. Delegate this to the web-operator subagent with the Agent tool: give it the goal, any values to type, and what to report back."}}
JSON
