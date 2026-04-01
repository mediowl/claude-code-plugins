# Hooks 活用ガイド

Claude Code Hooks を活用してワークフローを自動化するためのテンプレートとガイド。

## 概要

Claude Code Hooks は、Claude Code のライフサイクルイベントに応じてカスタムスクリプトを実行する仕組みです。このガイドでは、開発体験を向上させる実用的な Hooks テンプレートを提供します。

## 利用可能なフックイベント

| イベント | 発火タイミング | ブロック可能 |
|---------|-------------|-------------|
| `SessionStart` | セッション開始時 | いいえ |
| `PreToolUse` | ツール実行前 | はい |
| `PostToolUse` | ツール成功後 | はい |
| `Stop` | Claude 応答完了時 | はい |
| `Notification` | 通知送信時 | いいえ |

その他のイベント: `UserPromptSubmit`, `PermissionRequest`, `PostToolUseFailure`, `StopFailure`, `SubagentStart`, `SubagentStop`, `ConfigChange`, `CwdChanged`, `FileChanged`, `InstructionsLoaded`

## hooks.json の基本構造

```json
{
  "hooks": {
    "<イベント名>": [
      {
        "matcher": "<ツール名の正規表現>",
        "hooks": [
          {
            "type": "command",
            "command": "スクリプトのパス",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

### フィールド説明

| フィールド | 型 | 説明 |
|----------|-----|------|
| `type` | string | `command`（シェルコマンド）、`http`、`prompt`、`agent` |
| `matcher` | string | ツール名をフィルタする正規表現（例: `Write\|Edit`） |
| `command` | string | 実行するコマンド。`$PLUGIN_DIR` 等の変数が使える |
| `timeout` | number | タイムアウト秒数（command のデフォルト: 600秒） |

### exit code の意味

| コード | 意味 | 動作 |
|--------|------|------|
| `0` | 成功 | stdout の JSON を処理する |
| `2` | ブロック | stderr を表示し、ツール実行を拒否する |
| その他 | 非ブロックエラー | stderr をログ出力し、実行は継続する |

### 環境変数

| 変数 | 説明 |
|------|------|
| `$CLAUDE_PROJECT_DIR` | プロジェクトルートディレクトリ |
| `$CLAUDE_PLUGIN_ROOT` | プラグインのインストール先 |
| `$PLUGIN_DIR` | （プラグイン hooks.json 内）プラグインディレクトリ |

### 標準入力（stdin）で渡されるデータ

PreToolUse / PostToolUse では、以下の JSON が stdin で渡されます:

```json
{
  "session_id": "abc123",
  "hook_event_name": "PreToolUse",
  "tool_name": "Write",
  "tool_input": {
    "file_path": "/path/to/file.ts",
    "content": "..."
  }
}
```

---

## テンプレート一覧

### 1. PostToolUse: Write/Edit 後に auto-format を自動実行

ファイルの書き込み・編集後にフォーマッターを自動実行し、コードスタイルを統一します。

**hooks.json への追加:**

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/auto-format.sh",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

**スクリプト例（.claude/hooks/auto-format.sh）:**

```bash
#!/bin/bash
# PostToolUse: Write/Edit 後に auto-format を自動実行
#
# stdin から tool_input を読み取り、変更されたファイルに対してフォーマッターを実行する。
# プロジェクトで使用するフォーマッターに合わせてコマンドを変更すること。

set -euo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [[ -z "$FILE_PATH" || ! -f "$FILE_PATH" ]]; then
  exit 0
fi

# ファイル拡張子を取得
EXT="${FILE_PATH##*.}"

# 拡張子に応じてフォーマッターを選択
case "$EXT" in
  ts|tsx|js|jsx|json|css|scss|md|yaml|yml)
    # Prettier（プロジェクトに合わせて変更）
    if command -v npx &>/dev/null && [[ -f "${CLAUDE_PROJECT_DIR}/node_modules/.bin/prettier" ]]; then
      npx prettier --write "$FILE_PATH" 2>/dev/null || true
    fi
    ;;
  py)
    # Black / Ruff（プロジェクトに合わせて変更）
    if command -v ruff &>/dev/null; then
      ruff format "$FILE_PATH" 2>/dev/null || true
    elif command -v black &>/dev/null; then
      black --quiet "$FILE_PATH" 2>/dev/null || true
    fi
    ;;
  go)
    if command -v gofmt &>/dev/null; then
      gofmt -w "$FILE_PATH" 2>/dev/null || true
    fi
    ;;
  rs)
    if command -v rustfmt &>/dev/null; then
      rustfmt "$FILE_PATH" 2>/dev/null || true
    fi
    ;;
esac

exit 0
```

---

### 2. PreToolUse: セキュリティスキャン（機密情報の書き込み防止）

Write / Edit ツールの実行前に、書き込み内容に機密情報（APIキー、パスワード、トークン等）が含まれていないかチェックします。検出された場合はツール実行をブロックします。

**hooks.json への追加:**

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/security-scan.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

**スクリプト例（.claude/hooks/security-scan.sh）:**

```bash
#!/bin/bash
# PreToolUse: Write/Edit 前のセキュリティスキャン
#
# 書き込み内容に機密情報パターンが含まれていないか検査する。
# 検出時は exit 2 でツール実行をブロックする。

set -euo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# Write の場合は content、Edit の場合は new_string を検査対象にする
if [[ "$TOOL_NAME" == "Write" ]]; then
  CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // empty')
elif [[ "$TOOL_NAME" == "Edit" ]]; then
  CONTENT=$(echo "$INPUT" | jq -r '.tool_input.new_string // empty')
else
  exit 0
fi

if [[ -z "$CONTENT" ]]; then
  exit 0
fi

# 機密情報パターンの定義
# プロジェクトに合わせてパターンを追加・変更すること
PATTERNS=(
  # AWS
  'AKIA[0-9A-Z]{16}'
  # 一般的な API キー形式
  '(?i)(api[_-]?key|api[_-]?secret|access[_-]?token|auth[_-]?token|secret[_-]?key)\s*[:=]\s*["\x27][A-Za-z0-9+/=_-]{16,}'
  # パスワードのハードコード
  '(?i)(password|passwd|pwd)\s*[:=]\s*["\x27][^\s"'\'']{8,}'
  # プライベートキー
  '-----BEGIN (RSA |EC |DSA )?PRIVATE KEY-----'
  # GitHub トークン
  'gh[pousr]_[A-Za-z0-9_]{36,}'
  # 汎用シークレット
  '(?i)secret\s*[:=]\s*["\x27][A-Za-z0-9+/=_-]{16,}'
)

FOUND=false
MATCHES=""

for pattern in "${PATTERNS[@]}"; do
  if echo "$CONTENT" | grep -qP "$pattern" 2>/dev/null; then
    FOUND=true
    MATCHED=$(echo "$CONTENT" | grep -oP "$pattern" 2>/dev/null | head -1)
    # マッチした内容を一部マスクして表示
    MASKED="${MATCHED:0:8}..."
    MATCHES="${MATCHES}\n  - パターン一致: ${MASKED}"
  fi
done

if [[ "$FOUND" == "true" ]]; then
  echo "機密情報の可能性があるコンテンツを検出しました:${MATCHES}" >&2
  echo "書き込みをブロックしました。環境変数や設定ファイルの利用を検討してください。" >&2
  exit 2
fi

exit 0
```

---

### 3. Stop: プログレスファイルの自動更新

Claude の応答完了時に、作業の進捗状況をファイルに記録します。長時間の作業セッションで進捗を追跡するのに役立ちます。

**hooks.json への追加:**

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/update-progress.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

**スクリプト例（.claude/hooks/update-progress.sh）:**

```bash
#!/bin/bash
# Stop: プログレスファイルの自動更新
#
# Claude の応答完了時に、セッション情報とタイムスタンプをプログレスファイルに記録する。
# 長時間作業のログや、セッション間での進捗共有に活用できる。

set -euo pipefail

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
STOP_HOOK_NAME=$(echo "$INPUT" | jq -r '.hook_event_name // empty')

# プログレスファイルのパス（.claude/ 配下に保存）
PROGRESS_DIR="${CLAUDE_PROJECT_DIR}/.claude"
PROGRESS_FILE="${PROGRESS_DIR}/progress.md"

# .claude ディレクトリが存在しない場合は何もしない
if [[ ! -d "$PROGRESS_DIR" ]]; then
  exit 0
fi

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# プログレスファイルが存在しない場合は新規作成
if [[ ! -f "$PROGRESS_FILE" ]]; then
  cat > "$PROGRESS_FILE" <<HEADER
# 作業プログレス

自動記録された作業セッションのログ。

---

HEADER
fi

# セッション情報を追記
cat >> "$PROGRESS_FILE" <<ENTRY
- ${TIMESTAMP} | session: ${SESSION_ID:0:8}
ENTRY

exit 0
```

---

## プロジェクトへの導入方法

### 方法1: .claude/settings.json に直接記述

プロジェクトの `.claude/settings.json` に hooks 設定を追加します。チームで共有可能です。

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/auto-format.sh",
            "timeout": 30
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/security-scan.sh",
            "timeout": 10
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/update-progress.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

### 方法2: ~/.claude/settings.json に記述

ユーザー単位で全プロジェクトに適用したい場合は、ホームディレクトリの設定に記述します。

### 方法3: /dbz-init で設定

`/dbz-init` の設定ウィザードで Hooks テンプレートの導入を選択できます（後述）。

---

## カスタマイズのポイント

### auto-format

- プロジェクトで使用するフォーマッターに合わせて `case` 文のコマンドを変更する
- Lint も同時に実行したい場合は、フォーマッターの後に lint コマンドを追加する
- 特定のディレクトリ（例: `vendor/`, `node_modules/`）を除外したい場合は、`FILE_PATH` のチェックを追加する

### security-scan

- プロジェクト固有のシークレットパターン（社内APIキーの形式等）を `PATTERNS` に追加する
- `.env.example` や `*.test.*` ファイルへの書き込みは許可したい場合は、ファイルパスによる除外条件を追加する
- `grep -P`（Perl正規表現）が使えない環境では `grep -E` に書き換え、パターンを調整する

### update-progress

- 記録する情報を増やしたい場合は、`transcript_path` から直近の操作を抽出する
- `.gitignore` に `progress.md` を追加して、Git 管理対象から除外することを推奨する

---

## 参考

- [Claude Code Hooks 公式ドキュメント](https://docs.anthropic.com/en/docs/claude-code/hooks)
