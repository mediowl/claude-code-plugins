# dbz-workflow 設定

**ペルソナ有効**: false

## プロジェクト情報

**プロジェクト名**: claude-code-plugins
**技術スタック**: シェルスクリプト (bash), Markdown
**テストコマンド**: なし
**E2Eコマンド**: なし

## 監査エージェント設定

| エージェント | 有効 | 備考 |
|-------------|------|------|
| audit-black-hacker | false | UIなし、セキュリティ面はシンプル |
| audit-white-hacker | false | UIなし、セキュリティ面はシンプル |
| audit-doc | true | 必須（全プロジェクト共通） |
| audit-i18n | false | 多言語対応なし |
| audit-design | false | UIなし |
| audit-a11y | false | UIなし |
| audit-link | true | ドキュメント内リンク切れ検出に有用 |
| audit-test | false | テストフレームワークなし |

## カスタムルール

- ユーザーとの対話はすべて日本語で行うこと
- 絵文字使用禁止。ステータスには [OK], [NG], [注意] のテキストラベルを使用する
- コミットメッセージは日本語で記述
- PRタイトルにIssue番号を含める
- main ブランチへの直接コミット・プッシュを禁止し、フィーチャーブランチで作業する
- プラグイン更新時は該当プラグインの .claude-plugin/plugin.json の version を必ず更新する
- プロジェクト固有の情報（特定プロジェクトのURL、技術スタック、ディレクトリ構成等）を記述しない
