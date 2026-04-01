---
name: dbz-team
description: 複数Issueを並列処理するチームワークフロースキル。TeamCreateでチーム作成、各teammateがワークツリー内でdbz-plan + dbz-prを実行
---

# Team Workflow Skill

複数Issueを並列処理するチームワークフロースキル。

## Input

- `issue_numbers`: スペースまたはカンマ区切りのIssue番号リスト（例: `101 102 103`, `101,102,103`, `#101 #102`）

## Usage Examples

```
/dbz-team 101 102 103          # Issue #101, #102, #103 を並列処理
/dbz-team 101,102,103          # カンマ区切りでもOK
/dbz-team #101 #102 #103       # #付きでもOK
```

---

## Required Tools

TeamCreate, SendMessage, EnterWorktree, ExitWorktree, TaskCreate, TaskList, TaskUpdate

---

## Workflow Phases

```
Phase 0: 準備（スペック算出・チーム作成・タスク作成・teammate スポーン）
    |
Phase 1: 並列実行（各 teammate がワークツリー内で計画 + 実装 + PR）
    |
Phase 2: キュー管理（Lead がタスク割り当て・質問中継・失敗処理・定期監視）
    |
Phase 3: 最終レポート（成功/失敗テーブル + PR リンク）
```

---

## Execution Flow

### 設定ファイル読み込み・Issue情報取得（ワークフロー開始時・必須）

ワークフロー開始前に以下を実行:

1. `.claude/dbz-workflow.config.md` を読み込む（なければフォールバック）
2. 各Issueの情報を `gh issue view <number> --json title,body,comments` で取得

**詳細仕様**: `../../docs/config-loader.md` および `../../docs/issue-context-guide.md` を参照

---

### Phase 0: 準備

#### 0-1. 同時実行数算出

以下の式で同時実行数を算出する:

```
max_concurrent = min(5, floor(cores / 2), floor(mem_gb / 4))
```

最低値は 1。算出失敗時はデフォルト 2 にフォールバック。

**OS別コマンド**:

| OS | CPU コア数 | メモリ（GB） |
|----|-----------|-------------|
| Linux | `nproc` | `free -g \| awk '/Mem:/{print $2}'` |
| macOS | `sysctl -n hw.ncpu` | `echo $(( $(sysctl -n hw.memsize) / 1073741824 ))` |

#### 0-2. チーム作成

```
TeamCreate(team_name: "dbz-team-{timestamp}")
```

#### 0-3. タスク作成

各Issueに対して TaskCreate でタスクを作成する。

#### 0-4. teammate スポーン

同時実行数分の teammate を Agent（team_name 指定, name: `worker-{issue_number}`）でスポーンする。

---

### Phase 1: 並列実行

各 teammate に以下の指示テンプレートを渡す。

#### Step 1: ワークツリー進入

```
EnterWorktree(name: "team-{issue_number}")
```

#### Step 2: 計画（dbz-plan 相当）

1. `gh issue view <issue_number> --json title,body,comments` でIssue情報を取得
2. 関連コードの調査（Grep, Glob, Read）
3. 不明点がある場合は **SendMessage で Lead に質問**する（AskUserQuestion は禁止）
4. 計画を作成し、Issueコメントに投稿する
5. plan-reviewer エージェント（`subagent_type: "dbz-workflow:workflow:plan-reviewer"`）でレビュー（最大3ループ）
6. **自動承認判定**:
   - Minor/Suggestion のみ → 自動で Step 3 へ進む
   - Critical が含まれる → SendMessage で Lead に報告し、Lead 経由でユーザー確認

> **dbz-plan Phase 5 との差分**: dbz-plan ではユーザーに選択肢を提示するが、dbz-team では Minor/Suggestion のみの場合は自動承認する。

#### Step 3: 実装・PR（dbz-pr 相当）

1. ブランチ作成（サブワークツリーのため fetch + checkout）:
   ```bash
   git fetch origin main
   git checkout -b <type>/<issue>-<description> origin/main
   ```
2. implementer（`subagent_type: "dbz-workflow:workflow:implementer"`）で実装
3. `/simplify` スキル実行（コード変更がある場合）
4. 検証（テストコマンド実行）
5. PR 作成
6. reviewer（`subagent_type: "dbz-workflow:workflow:reviewer"`）レビュー（最大3ループ）
7. 監査エージェント実行（設定に基づき有効なもののみ、最大3ループ）

#### Step 4: 完了報告

1. TaskUpdate でタスクを完了に更新
2. SendMessage で Lead に報告（PR URL を含む）

#### Step 5: ワークツリー退出

```
ExitWorktree
```

#### AskUserQuestion 置き換えルール

teammate は AskUserQuestion を使用してはならない。代わりに SendMessage で Lead に質問する。Lead が AskUserQuestion でユーザーに中継する。

#### 失敗時の報告フォーマット

```
[失敗報告]
Issue: #XXX
Phase: {失敗したフェーズ}
エラー内容: {エラーの詳細}
試行回数: {リトライ回数}
```

---

### Phase 2: キュー管理（Lead）

Lead は以下の責務を担う:

1. **タスク割り当て**: teammate が完了（または shutdown_request）したら、未処理タスクがあれば新規 teammate をスポーンする
2. **質問中継**: teammate からの SendMessage を受け取り、AskUserQuestion でユーザーに転送する
3. **失敗処理**: teammate が失敗した場合、記録して他の teammate は継続する
4. **定期監視**: `/loop` スキルで teammate の進捗を定期監視する（後述）

#### 定期監視（/loop）

Phase 1 の並列実行開始後、Lead は `/loop` スキルを使って teammate の処理状況を定期的に監視する。

**開始タイミング**: Phase 0 完了後、最初の teammate スポーン直後に `/loop` を開始する

**実行コマンド**:

```
/loop 2m 進捗確認
```

**監視間隔**: 2分（デフォルト）

**監視時の実行手順**:

1. `TaskList` で全タスクの状態を取得する
2. 以下の形式で進捗サマリーをユーザーに表示する:

```markdown
### 進捗状況

| Issue | ステータス | 担当 |
|-------|-----------|------|
| #101 | 実行中 | worker-101 |
| #102 | 完了 | worker-102 |
| #103 | 未着手 | - |

完了: 1/3 | 実行中: 1 | 未着手: 1
```

3. 完了・失敗したタスクがあれば、タスク割り当て（責務 1）を実行する

**終了条件**: 全タスクが完了または失敗した時点で `/loop` を停止する

---

### Phase 3: 最終レポート

全タスク完了後、以下の形式で最終レポートを出力する:

```markdown
## dbz-team 実行結果

| Issue | ステータス | PR |
|-------|-----------|-----|
| #101 | [OK] 完了 | #201 |
| #102 | [OK] 完了 | #202 |
| #103 | [NG] 失敗 | - |

### 失敗詳細（該当する場合）

- Issue #103: {エラーの詳細}
```

---

## Absolute Rules

1. **マージは人間のみ** — teammate は `git merge` / `gh pr merge` を絶対に実行しない
2. **teammate 間で同一Issue処理禁止** — 1つのIssueは1つの teammate のみが担当する
3. **Lead は teammate の結果を改変しない** — レビュー結果やPR内容を Lead が書き換えることは禁止
4. **AskUserQuestion は Lead のみ使用** — teammate は SendMessage で Lead に質問する
5. **ワークツリー分離厳守** — 各 teammate は EnterWorktree で分離されたワークツリーで作業する
6. **内部タスク番号に `#` 使用禁止** — GitHub誤リンク防止
7. **同時実行数超過でスポーンしない** — Phase 0 で算出した max_concurrent を超える teammate を同時にスポーンしない
8. **失敗 teammate を無限リトライしない** — 失敗した teammate は記録し、同一Issueの再試行は行わない

---

## Error Handling

| パターン | 対応 |
|---------|------|
| OS スペック算出失敗 | デフォルト 2 にフォールバック |
| TeamCreate / EnterWorktree 失敗 | 中断し、個別に `/dbz-plan` + `/dbz-pr` の実行を案内 |
| teammate エラー停止 | Lead に報告し、他の teammate は継続 |
| 全 teammate 失敗 | エラーサマリーを報告 |
| Issue 未存在 | ユーザーにスキップまたは中断の選択肢を提示 |

---

## References

- **エージェント**: ../../agents/workflow/
- **設定ファイル**: ../../docs/config-loader.md
- **Issue情報**: ../../docs/issue-context-guide.md
