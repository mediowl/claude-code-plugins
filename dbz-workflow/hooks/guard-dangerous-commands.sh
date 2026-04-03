#!/usr/bin/env bash
set -euo pipefail

# PreToolUse hook: Bash ツールの危険コマンドをブロックする
# stdin から JSON を受け取り、tool_input.command を検査する
#
# Exit codes:
#   0 - 通過（正常コマンドまたは jq 未インストール）
#   2 - ブロック（危険コマンド検出）

# jq が未インストールの場合はサイレント通過
if ! command -v jq &>/dev/null; then
  exit 0
fi

# stdin から JSON を読み取り、command フィールドを抽出
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0

# command が空の場合は通過
if [[ -z "$COMMAND" ]]; then
  exit 0
fi

# --- 破壊的コマンド ---
if echo "$COMMAND" | grep -qE 'rm\s+-[a-zA-Z]*[fF]'; then
  echo "BLOCKED: rm -rf / rm -f は破壊的コマンドのため禁止されています。" >&2
  exit 2
fi

if echo "$COMMAND" | grep -qE 'git\s+reset\s+--hard'; then
  echo "BLOCKED: git reset --hard は破壊的コマンドのため禁止されています。" >&2
  exit 2
fi

if echo "$COMMAND" | grep -qE 'git\s+checkout\s+--\s+\.(\s|$|;|&|\|)'; then
  echo "BLOCKED: git checkout -- . は破壊的コマンドのため禁止されています。" >&2
  exit 2
fi

if echo "$COMMAND" | grep -qE 'git\s+restore\s+\.(\s|$|;|&|\|)'; then
  echo "BLOCKED: git restore . は破壊的コマンドのため禁止されています。" >&2
  exit 2
fi

if echo "$COMMAND" | grep -qiE 'DROP\s+TABLE'; then
  echo "BLOCKED: DROP TABLE は破壊的コマンドのため禁止されています。" >&2
  exit 2
fi

if echo "$COMMAND" | grep -qiE 'DROP\s+DATABASE'; then
  echo "BLOCKED: DROP DATABASE は破壊的コマンドのため禁止されています。" >&2
  exit 2
fi

# --- プロセス違反 ---
if echo "$COMMAND" | grep -qE 'git\s+push\s+--force(\s|$)|git\s+push\s+-f\b'; then
  echo "BLOCKED: git push --force / git push -f はプロセス違反のため禁止されています。" >&2
  exit 2
fi

# --- dbz-workflow 固有ルール ---
if echo "$COMMAND" | grep -qE 'git\s+merge\b|gh\s+pr\s+merge\b'; then
  echo "BLOCKED: git merge / gh pr merge はエージェントに許可されていません。マージは人間のみが実行できます。" >&2
  exit 2
fi

if echo "$COMMAND" | grep -qE 'git\s+add\s+(-A\b|--all\b|\.(\s|$|;|&|\|))'; then
  echo "BLOCKED: git add -A / git add --all / git add . は禁止されています。変更ファイルを明示的に指定してください。" >&2
  exit 2
fi

# 正常コマンド: 通過
exit 0
