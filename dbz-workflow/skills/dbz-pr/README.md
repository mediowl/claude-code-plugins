# PR ワークフロースキル

ブランチ作成からレビュー完了までの完全な PR ワークフローを管理するスキル。

## 使い方

```
/dbz-pr XXX          # Issue #XXXのワークフローを開始
/dbz-pr #XXX         # 同上（#プレフィックス付き）
/dbz-pr              # 現在のブランチの進捗を確認
/dbz-pr --status     # ステータスのみ表示（次アクションなし）
```

## ワークフローフェーズ

```
Phase 0: ブランチ準備
    ↓
Phase 1: 実装（implementer）+ コード簡素化
    ↓
Phase 2: 検証（lint → typecheck → test → e2e）
    ↓
Phase 3: PR作成
    ↓
Phase 4A: コードレビュー（reviewer）← 最大3ループ
    ↓
Phase 4B: 品質監査 ← 最大3ループ
    ↓
Phase 5: マージ（人間のみ）
```

## 使用エージェント

| エージェント | フェーズ | 用途 |
|-------------|---------|------|
| `implementer` | 1, 4A/4B | 実装と修正 |
| `reviewer` | 4A | コードレビュー |
| `audit-*` | 4B | 品質監査 |

## カスタマイズ

### 監査エージェント設定

`SKILL.md` の「監査エージェント設定」テーブルを編集して監査を有効/無効化：

```markdown
| エージェント | 有効 | 備考 |
|-------------|------|------|
| audit-black-hacker | true | 必須 |
| audit-white-hacker | true | 必須 |
| audit-doc | true | 必須 |
| audit-i18n | false | 単一言語プロジェクトでは無効化 |
```

## 必要環境

- Git リポジトリ
- GitHub CLI（`gh`）- PR 操作用
- Node.js プロジェクト（`npm run lint`, `npm run typecheck`）
