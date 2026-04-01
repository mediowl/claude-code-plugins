# claude-code-plugins

mediowl 社内共通の Claude Code プラグイン配布リポジトリ。

## 含まれるプラグイン

| プラグイン | 説明 |
|-----------|------|
| dbz-workflow | 実装計画・プルリクエストワークフローツールキット |
| piwf | Product Innovation Workflow Framework（Phase 0-3 + ゲートレビュー + 振り返り） |

## インストール

```bash
# 1. リポジトリをクローン（初回のみ）
git clone https://github.com/mediowl/claude-code-plugins.git ~/.claude/plugin-sources/mediowl-plugins

# 2. マーケットプレイスを登録（初回のみ）
claude plugin marketplace add ~/.claude/plugin-sources/mediowl-plugins

# 3. プラグインをインストール
claude plugin install dbz-workflow@mediowl-plugins --scope project
# または
claude plugin install piwf@mediowl-plugins --scope project

# 4. 確認
claude plugin list
```

## 更新

セッション開始時に自動でバージョンチェックと更新が行われます。

手動で更新する場合:

```bash
claude plugin update dbz-workflow@mediowl-plugins --scope project
claude plugin update piwf@mediowl-plugins --scope project
```

更新後は Claude Code の再起動が必要です。

## ディレクトリ構成

```
.claude-plugin/
  marketplace.json       # マーケットプレイス定義
dbz-workflow/            # dbz-workflow プラグイン
piwf/                    # piwf プラグイン
```
