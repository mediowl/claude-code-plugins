# dbz-workflow

実装計画・プルリクエストワークフローツールキット

## インストール

### 1. リポジトリをクローン

```bash
git clone https://github.com/mediowl/claude-code-manual.git
cd claude-code-manual
```

### 2. マーケットプレイスを登録

```bash
claude plugin marketplace add ./shared-plugin/plugins
```

### 3. プラグインをインストール

```bash
# プロジェクトスコープ（チーム共有）
claude plugin install dbz-workflow@shared-plugins --scope project

# またはユーザースコープ（個人環境）
claude plugin install dbz-workflow@shared-plugins --scope user
```

### 4. 確認

```bash
claude plugin list
```

## 更新

プラグインのソースコードが更新された場合：

```bash
claude plugin update dbz-workflow@shared-plugins --scope project
```

> **注意**: 更新後は **Claude Code の再起動が必須**です。再起動しないと変更が反映されません。

> **開発者向け**: プラグインのソースを変更した場合、`plugin.json` のバージョン更新が必要です。詳細は [shared-plugin/CLAUDE.md](../../CLAUDE.md#バージョン管理ルール) を参照してください。

## 提供スキル

| スキル | 説明 |
|--------|------|
| `/dbz-init` | 対話式で設定ファイルを生成 |
| `/dbz-plan` | Issue番号を指定して実装計画を作成・レビュー |
| `/dbz-pr` | ブランチ作成からPR作成・レビューまでのワークフロー管理 |
| `/dbz-team` | 複数Issueの並列処理（TeamCreate + ワークツリー） |

## 使い方

```bash
# 設定ファイルを生成（初回のみ）
/dbz-init

# 実装計画を作成
/dbz-plan 123

# PRワークフローを開始
/dbz-pr 123

# 複数Issueを並列処理
/dbz-team 101 102 103
```

## 提供エージェント

| エージェント | 説明 |
|-------------|------|
| `config-wizard` | 対話式設定ファイル生成 |
| `implementer` | スコープ内で最高品質の実装 |
| `reviewer` | 厳格なコードレビュー（8観点） |
| `plan-reviewer` | 実装計画レビュー（7観点） |
| `audit-doc` | ドキュメント整合性監査 |

## カスタマイズ

### 設定ファイルの作成

プロジェクト固有の設定を行うには、設定ファイルを作成します。

```bash
# 設定ファイルを作成
mkdir -p .claude
touch .claude/dbz-workflow.config.md
```

### 設定ファイルの内容

`.claude/dbz-workflow.config.md` に以下の形式で記述します：

```markdown
# dbz-workflow 設定

**ペルソナ有効**: false

## ペルソナ設定

**名前**: レビュー担当
**役割**: コードレビュー担当者
**一人称**: 私
**語尾**: 〜です、〜ます
**口調の特徴**:
- 丁寧で建設的な指摘
- 改善提案時は根拠を明確に
- 承認時は良い点を具体的に評価

## プロジェクト情報

**プロジェクト名**: My Awesome Project
**技術スタック**: React, TypeScript, Vite
**テストコマンド**: npm run test
**E2Eコマンド**: npm run e2e

## 監査エージェント設定

| エージェント | 有効 | 備考 |
|-------------|------|------|
| audit-black-hacker | true | Webプロジェクトで有効 |
| audit-white-hacker | true | Webプロジェクトで有効 |
| audit-doc | true | 必須（全プロジェクト共通） |
| audit-i18n | false | 多言語対応プロジェクトのみ |
| audit-design | false | デザインシステム採用プロジェクトのみ |
| audit-a11y | true | Webフロントエンドプロジェクトのみ |
| audit-link | false | HTMLページを持つプロジェクトのみ |
| audit-test | true | テストスイートがあるプロジェクトのみ |

## モデル設定

<!-- 以下はカスタマイズ例です。プラグインのデフォルトから変更したいエージェントのみ記載してください。 -->
<!-- デフォルト: implementer=opus, reviewer=opus, plan-reviewer=opus, config-wizard=opus, audit-black-hacker=sonnet, audit-white-hacker=sonnet, audit-doc=opus, audit-link=haiku, audit-i18n=haiku, 他の監査エージェント=sonnet -->

| エージェント | モデル | 備考 |
|-------------|--------|------|
| plan-reviewer | sonnet | コスト削減のため Sonnet に変更 |
| config-wizard | sonnet | コスト削減のため Sonnet に変更 |

指定可能なモデル: `sonnet`, `opus`, `haiku`

## カスタムルール

- コミットメッセージは日本語で記述
- PRタイトルにIssue番号を含める
```

### 設定項目の説明

| セクション | 説明 |
|-----------|------|
| ペルソナ有効 | ペルソナ機能のオン/オフ（true 有効 / false 無効） |
| ペルソナ設定 | エージェントの口調・キャラクター設定（ペルソナ有効時のみ） |
| プロジェクト情報 | プロジェクト名、技術スタック、テストコマンド |
| 監査エージェント設定 | 各監査エージェントの有効/無効（true/false） |
| モデル設定 | 各エージェントが使用するモデル（未指定はプラグインのデフォルト） |
| カスタムルール | プロジェクト固有のルール |

### 設定ファイルがない場合

設定ファイルがない場合はデフォルト動作：
- ペルソナ有効: false 無効（デフォルト）
- ペルソナ: なし（丁寧な日本語で対応）
- プロジェクト情報: CLAUDE.md を参照
- 監査エージェント: すべて有効
- モデル設定: プラグインのデフォルト（各エージェントの .md ファイルで定義）

詳細仕様は `docs/config-loader.md` を参照。

## 記述ルール

- 設定ファイルおよびドキュメントに絵文字を使用しないこと
- 真偽値は `true`/`false` で記述すること
- 理由: 環境やフォントによって表示が崩れる可能性があるため

## アンインストール

```bash
claude plugin uninstall dbz-workflow@shared-plugins
```
