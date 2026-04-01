#!/bin/bash
# check-update.sh - Claude Code プラグイン自動更新スクリプト
#
# SessionStart フックから呼び出され、プラグインの新バージョンを検出して自動更新する。
#
# 引数:
#   $1 - プラグイン名 (例: dbz-workflow)
#   $2 - マーケットプレイス名 (例: mediowl-plugins)
#   $3 - GitHub リポジトリ (例: mediowl/claude-code-plugins)
#
# 動作:
#   1. 24h キャッシュを確認（キャッシュ有効なら即終了）
#   2. GitHub API でリモートの plugin.json の version を取得
#   3. ローカルの version と比較
#   4. 差分があれば git pull → claude plugin update を実行
#   5. 結果を stdout に出力（Claude のコンテキストに追加される）
#
# エラー時はサイレントに終了する（セッション開始をブロックしない）

set -euo pipefail

PLUGIN_NAME="${1:-}"
MARKETPLACE="${2:-}"
REPO="${3:-}"

if [[ -z "$PLUGIN_NAME" || -z "$MARKETPLACE" || -z "$REPO" ]]; then
  exit 0
fi

# --- 定数 ---
CACHE_DIR="${HOME}/.cache/claude-code-plugins"
CACHE_FILE="${CACHE_DIR}/${PLUGIN_NAME}-version-check"
CACHE_TTL=86400  # 24h in seconds
SOURCE_DIR="${HOME}/.claude/plugin-sources/${MARKETPLACE}"

# --- キャッシュチェック ---
if [[ -f "$CACHE_FILE" ]]; then
  cache_age=$(( $(date +%s) - $(stat -f %m "$CACHE_FILE" 2>/dev/null || stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0) ))
  if [[ $cache_age -lt $CACHE_TTL ]]; then
    exit 0
  fi
fi

# --- キャッシュディレクトリ作成 ---
mkdir -p "$CACHE_DIR"

# --- ローカルバージョン取得 ---
# プラグインディレクトリを探す（SOURCE_DIR 内）
LOCAL_PLUGIN_JSON="${SOURCE_DIR}/${PLUGIN_NAME}/.claude-plugin/plugin.json"
if [[ ! -f "$LOCAL_PLUGIN_JSON" ]]; then
  # ソースディレクトリが存在しない場合はスキップ
  touch "$CACHE_FILE"
  exit 0
fi

LOCAL_VERSION=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$LOCAL_PLUGIN_JSON" | head -1 | grep -o '"[^"]*"$' | tr -d '"')
if [[ -z "$LOCAL_VERSION" ]]; then
  touch "$CACHE_FILE"
  exit 0
fi

# --- リモートバージョン取得（GitHub API） ---
REMOTE_VERSION=$(curl -sf --max-time 10 \
  "https://api.github.com/repos/${REPO}/contents/${PLUGIN_NAME}/.claude-plugin/plugin.json" \
  -H "Accept: application/vnd.github.v3.raw" 2>/dev/null \
  | grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' \
  | head -1 \
  | grep -o '"[^"]*"$' \
  | tr -d '"') || true

if [[ -z "$REMOTE_VERSION" ]]; then
  # API 失敗時はキャッシュ更新してサイレント終了
  touch "$CACHE_FILE"
  exit 0
fi

# --- キャッシュ更新（チェック完了を記録） ---
touch "$CACHE_FILE"

# --- バージョン比較 ---
if [[ "$LOCAL_VERSION" == "$REMOTE_VERSION" ]]; then
  exit 0
fi

# --- 自動更新実行 ---

# 1. ソースリポジトリを git pull
if ! git -C "$SOURCE_DIR" pull --ff-only --quiet 2>/dev/null; then
  echo "[${PLUGIN_NAME}] v${REMOTE_VERSION} が利用可能ですが、自動更新に失敗しました。手動で更新してください:"
  echo "  cd ${SOURCE_DIR} && git pull"
  echo "  claude plugin update ${PLUGIN_NAME}@${MARKETPLACE} --scope project"
  exit 0
fi

# 2. claude plugin update 実行
if claude plugin update "${PLUGIN_NAME}@${MARKETPLACE}" --scope project 2>/dev/null; then
  echo "[${PLUGIN_NAME}] v${LOCAL_VERSION} -> v${REMOTE_VERSION} に自動更新しました。"
else
  echo "[${PLUGIN_NAME}] v${REMOTE_VERSION} が利用可能です。git pull は成功しましたが、plugin update に失敗しました:"
  echo "  claude plugin update ${PLUGIN_NAME}@${MARKETPLACE} --scope project"
fi
