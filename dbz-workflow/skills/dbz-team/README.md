# dbz-team

複数Issueを並列処理するチームワークフロースキル。

## 使い方

```bash
/dbz-team 101 102 103          # Issue #101, #102, #103 を並列処理
/dbz-team 101,102,103          # カンマ区切りでもOK
/dbz-team #101 #102 #103       # #付きでもOK
```

---

## 同時実行数

マシンスペックに応じて自動算出される:

```
max_concurrent = min(5, floor(cores / 2), floor(mem_gb / 4))
```

- 最低値: 1
- 算出失敗時のデフォルト: 2
- 上限: 5

---

## ワークフロー

1. **Phase 0: 準備** — スペック算出、チーム作成、タスク作成、teammate スポーン
2. **Phase 1: 並列実行** — 各 teammate がワークツリー内で計画・実装・PR作成
3. **Phase 2: キュー管理** — Lead がタスク割り当て、質問中継、失敗処理
4. **Phase 3: 最終レポート** — 成功/失敗テーブルと PR リンク

---

## 承認フロー

- **計画レビュー**: Lead が plan-reviewer teammate をスポーンし自動レビュー（最大3ループ）。Minor/Suggestion のみなら自動承認、Critical/Major は修正ループ
- **コードレビュー**: Lead が reviewer teammate + 監査 teammate をスポーンし自動レビュー（各最大3ループ）
- **マージ**: 人間のみ（teammate は絶対にマージしない）

---

## 必須ツール

TeamCreate, SendMessage, EnterWorktree, ExitWorktree, TaskCreate, TaskList, TaskUpdate

---

## 前提条件

- dbz-workflow プラグインが導入済みであること
- `.claude/dbz-workflow.config.md` が設定済みであること（未設定でもフォールバック動作で実行可能）
- GitHub CLI (`gh`) が認証済みであること

---

## 参考

- **詳細仕様**: [SKILL.md](./SKILL.md)
- **設定ファイル**: `../../docs/config-loader.md`
- **ワークフロー概要**: `../../docs/workflow-overview.md`
