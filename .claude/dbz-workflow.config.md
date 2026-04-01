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

## モデル設定

| エージェント | モデル |
|-------------|--------|
| reviewer | sonnet |
| audit-doc | sonnet |
| audit-link | sonnet |

## カスタムルール

- CLAUDE.md のルールを遵守すること（対話言語、絵文字禁止、Git運用、バージョン管理等）
