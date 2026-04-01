# ワークフローエージェント

dbz-workflow プラグインに含まれるエージェント集。

## スキル一覧

| スキル | 用途 |
|--------|------|
| `/dbz-init` | 対話式設定ファイル生成 |
| `/dbz-plan` | 実装計画の作成・レビュー |
| `/dbz-pr` | ブランチ作成からPR作成・レビューまで |
| `/dbz-team` | 複数Issueの並列処理（TeamCreate + ワークツリー） |

## エージェント一覧

| エージェント | 用途 | 使用フェーズ |
|-------------|------|-------------|
| `config-wizard` | 対話式設定ファイル生成 | /dbz-init |
| `implementer` | スコープ内で最高品質の実装 | Phase 1, 4A/4B |
| `reviewer` | 厳格なコードレビュー（8観点） | Phase 4A |
| `plan-reviewer` | 実装計画レビュー（7観点） | /dbz-plan Phase 4 |
| `audit-doc` | ドキュメント整合性監査 | Phase 4B |
| `audit-black-hacker` | セキュリティ監査（攻撃者視点） | Phase 4B |
| `audit-white-hacker` | セキュリティ監査（防御者視点） | Phase 4B |
| `audit-i18n` | 国際化対応監査 | Phase 4B |
| `audit-design` | デザイン一貫性監査 | Phase 4B |
| `audit-a11y` | アクセシビリティ監査 | Phase 4B |
| `audit-link` | リンク切れ監査 | Phase 4B |
| `audit-test` | テスト品質監査 | Phase 4B |

## ディレクトリ構成

```
workflow/
├── config-wizard.md          # 設定ファイル生成エージェント
├── implementer.md            # 実装エージェント
├── reviewer.md               # コードレビューエージェント
├── plan-reviewer.md          # 計画レビューエージェント
├── audit-doc.md              # ドキュメント監査エージェント
├── audit-black-hacker.md     # セキュリティ監査エージェント（攻撃者視点）
├── audit-white-hacker.md     # セキュリティ監査エージェント（防御者視点）
├── audit-i18n.md             # 国際化対応監査エージェント
├── audit-design.md           # デザイン一貫性監査エージェント
├── audit-a11y.md             # アクセシビリティ監査エージェント
├── audit-link.md             # リンク切れ監査エージェント
└── audit-test.md             # テスト品質監査エージェント
```

## 監査エージェント

以下の8つの監査エージェントが標準で含まれています：

- `audit-doc` - ドキュメント整合性監査
- `audit-black-hacker` - セキュリティ監査（攻撃者視点）
- `audit-white-hacker` - セキュリティ監査（防御者視点）
- `audit-i18n` - 国際化対応監査
- `audit-design` - デザイン一貫性監査
- `audit-a11y` - アクセシビリティ監査
- `audit-link` - リンク切れ監査
- `audit-test` - テスト品質監査

各監査エージェントは `.claude/dbz-workflow.config.md` で個別に有効/無効を設定可能です。

## コード簡素化（`/simplify` スキル）

`/dbz-pr` が implementer 完了後に呼び出す内蔵スキル。

**動作**:
- implementer 完了後、`/dbz-pr` が `git diff` で変更ファイルを検出し実行
- 可読性・一貫性・保守性を向上（挙動は変更しない）
- .md ファイルのみの変更時はスキップ
