#!/usr/bin/env bash
# check-hooks-registration.sh - hooks 未登録検出・案内スクリプト
#
# dbz-workflow の hooks（SessionStart, PreToolUse）がユーザーの settings.json に
# 登録されているかを確認し、未登録の場合は案内メッセージを出力する。
#
# プラグインの hooks/hooks.json は Claude Code が自動的に読み込まないため、
# ユーザーが settings.json に手動で追加する必要がある。
#
# 引数: なし
# 終了コード: 常に 0（案内のみで、スキルの実行をブロックしない）
# 出力: 未登録 hooks がある場合のみ案内メッセージを stdout に出力

set -euo pipefail

# --- 検査対象の settings.json パス ---
SETTINGS_FILES=()

# プロジェクトスコープ
if [[ -n "${CLAUDE_PROJECT_DIR:-}" ]]; then
  SETTINGS_FILES+=("${CLAUDE_PROJECT_DIR}/.claude/settings.json")
  SETTINGS_FILES+=("${CLAUDE_PROJECT_DIR}/.claude/settings.local.json")
fi

# ユーザースコープ
SETTINGS_FILES+=("${HOME}/.claude/settings.json")

# --- 検査対象の hooks キーワード ---
# hooks.json に定義された hooks を識別するための文字列
HOOK_CHECKS=(
  "check-update.sh:SessionStart:自動更新（セッション開始時にプラグインの新バージョンを検出）"
  "guard-dangerous-commands.sh:PreToolUse:危険コマンドガード（rm -rf, git reset --hard 等をブロック）"
)

# --- 検査ロジック ---
# いずれかの settings.json にキーワードが含まれているかを確認する関数
check_hook_registered() {
  local keyword="$1"
  for settings_file in "${SETTINGS_FILES[@]}"; do
    if [[ -f "$settings_file" ]] && grep -q "$keyword" "$settings_file" 2>/dev/null; then
      return 0
    fi
  done
  return 1
}

# --- メイン処理 ---
MISSING_HOOKS=()

for entry in "${HOOK_CHECKS[@]}"; do
  IFS=':' read -r script_name event_name description <<< "$entry"
  if ! check_hook_registered "$script_name"; then
    MISSING_HOOKS+=("${event_name}|${description}")
  fi
done

# 全て登録済みなら何も出力せず終了
if [[ ${#MISSING_HOOKS[@]} -eq 0 ]]; then
  exit 0
fi

# --- 案内メッセージ出力 ---
echo ""
echo "[注意] dbz-workflow の hooks が settings.json に未登録です"
echo ""
echo "以下の hooks が検出されませんでした:"
for item in "${MISSING_HOOKS[@]}"; do
  IFS='|' read -r event desc <<< "$item"
  echo "  - ${event}: ${desc}"
done
echo ""
echo "hooks を有効にするには、settings.json に以下を追加してください。"
echo "手順: Claude Code で \`/hooks\` を実行するか、settings.json を直接編集してください。"
echo ""
echo "詳細は README のセットアップ手順を参照:"
echo "  https://github.com/mediowl/claude-code-plugins/tree/main/dbz-workflow#セットアップ"
echo ""

exit 0
