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
3. hooks 登録チェック: `bash "${CLAUDE_PLUGIN_ROOT}/hooks/check-hooks-registration.sh"` を実行し、出力があればユーザーに表示する（スキルの実行はブロックしない）

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

**ワークツリー分離検証（必須）**: EnterWorktree 直後に以下を実行し、ワークツリーが正しく分離されていることを確認する。

```bash
pwd && git worktree list
```

**検証基準**:
- `pwd` の出力が `.claude/worktrees/team-{issue_number}` を含むこと
- `git worktree list` でメインワークツリーと別のパスが表示されること

**検証失敗時**: メインワークツリーのまま（パスに `.claude/worktrees/` を含まない）の場合、**作業を即座に中断**し、以下のフォーマットで Lead に報告する:

```
[失敗報告]
Issue: #XXX
Phase: Step 1（ワークツリー進入）
エラー内容: EnterWorktree 後のワークツリー分離検証に失敗。pwd = {実際のパス}
試行回数: 1
```

> **背景**: EnterWorktree の Claude Code 側既知バグ（CWD ズレによるネスト: anthropics/claude-code#27881, #27974, #27134）により、ワークツリーが正しく分離されず、複数 teammate が同じワークツリーを共有してしまう問題が報告されている。

#### Step 2: 計画（dbz-plan 相当）

1. `gh issue view <issue_number> --json title,body,comments` でIssue情報を取得
2. 関連コードの調査（Grep, Glob, Read）
3. 不明点がある場合は **SendMessage で Lead に質問**する（AskUserQuestion は禁止）
4. 計画（スプリント契約含む）を作成し、Issueコメントに投稿する
5. **SendMessage で Lead に「計画投稿完了」を報告**する
6. Lead が `plan-reviewer-{issue}` teammate をスポーンする（後述 Phase 2 参照）
7. plan-reviewer teammate からレビュー結果を **SendMessage で直接受信**する
8. **修正ループ**（最大3回）:
   - Critical/Major があれば計画を修正し、再投稿 → Lead に「計画修正完了」を報告 → Lead が plan-reviewer を再スポーン
   - Critical が含まれ、かつ最大ループ到達 → SendMessage で Lead に報告し、Lead 経由でユーザー確認
   - Minor/Suggestion のみ → 自動で Step 3 へ進む

> **dbz-plan Phase 5 との差分**: dbz-plan ではユーザーに選択肢を提示するが、dbz-team では Minor/Suggestion のみの場合は自動承認する。

#### 報告タイミング（各ステップ完了時に SendMessage で Lead に報告）

1. 計画を Issue に投稿した後
2. plan-reviewer の結果を Issue に投稿した後
3. PR を作成した後
4. reviewer の結果を PR に投稿した後
5. 各監査の結果を PR に投稿した後
6. 全作業完了後（構造化フォーマットで最終報告）

#### Step 3: 実装・PR（dbz-pr 相当）

1. ブランチ作成（サブワークツリーのため fetch + checkout）:
   ```bash
   git fetch origin main
   git checkout -b <type>/<issue>-<description> origin/main
   ```
2. **teammate 自身が直接実装する**（計画に基づいてコードを実装。implementer エージェントの別途スポーンは不要）

**git 操作のアトミック実行（必須）**: ワークツリー環境では、git 操作（add, commit, push）を単一コマンドチェーン（`&&` 連結）で実行し、プロセス間介入による競合を防ぐ。

```bash
# [OK] アトミック実行（推奨）
git add <files> && git commit -m "<message>" && git push -u origin <branch>

# [NG] コマンドを分割して実行（禁止）
git add <files>
git commit -m "<message>"
git push -u origin <branch>
```

**競合検出時の対応**: git 操作中にエラー（例: `fatal: cannot lock ref`, `error: failed to push`）が発生した場合、**作業を即座に中断**し、以下のフォーマットで Lead に報告する:

```
[失敗報告]
Issue: #XXX
Phase: Step 3（git 操作競合）
エラー内容: {エラーメッセージ全文}
試行回数: 1
```
3. Phase 0.5（スプリント契約交渉）: 計画にスプリント契約が含まれている場合はスキップ（dbz-pr と同じ仕様）
4. `/simplify` スキル実行（コード変更がある場合）
5. 検証（テストコマンド実行）
6. PR 作成
7. **SendMessage で Lead に「PR作成完了」を報告**する
8. Lead が `reviewer-{issue}` teammate をスポーンする（後述 Phase 2 参照）
9. reviewer teammate からレビュー結果を **SendMessage で直接受信**する
10. **reviewer 修正ループ**（最大3回）:
    - Critical/Major があれば修正し、コミット・プッシュ → Lead に「reviewer修正完了」を報告 → Lead が reviewer を再スポーン
    - Critical/Major が残存し、かつ最大ループ到達 → Lead に報告し、Lead 経由でユーザーに続行/手動修正/中断の選択を求める
    - Minor/Suggestion のみ → 監査フェーズへ
11. **SendMessage で Lead に「reviewer完了」を報告**する
12. Lead が `audit-{type}-{issue}` teammate をスポーンする（後述 Phase 2 参照）
13. 監査 teammate からの結果を **SendMessage で直接受信**する
14. **監査修正ループ**（最大3回）:
    - Critical/Major があれば修正し、コミット・プッシュ → Lead に「監査修正完了」を報告 → Lead が監査を再スポーン
    - Critical/Major が残存し、かつ最大ループ到達 → Lead に報告し、Lead 経由でユーザーに続行/手動修正/中断の選択を求める
    - Minor/Suggestion のみ → Step 4 へ

> **注意**: reviewer / 監査 teammate の実行結果は PR コメントとして残る。コメントが存在しない場合、Lead は完了を承認しない。
> **teammate からの Agent ツール呼び出し不可**: Claude Code v2.1.70 以降、teammate は Agent ツール（subagent_type 指定）を直接呼び出せない。そのため reviewer / 監査は Lead が別 teammate としてスポーンし、teammate 間で SendMessage 連携する設計としている。

#### Step 4: 完了報告

以下のフォーマットで SendMessage を使い Lead に報告する:

```
[完了報告]
Issue: #XXX
PR: #YYY

## reviewer 結果
- 指摘件数: Critical X / Major X / Minor X / Suggestion X
- 修正コミット: {あり/なし}

## 監査結果
- {監査エージェント名}: Critical X / Major X / Minor X / Suggestion X
- 修正コミット: {あり/なし}
```

Lead は報告内容と PR コメントの整合性を検証した上で TaskUpdate で完了にする。

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
5. **完了検証**: teammate から完了報告を受けた際、以下を確認してから TaskUpdate で完了にする:
   - `gh pr view <PR番号> --json comments,reviews` でレビュー・監査コメントの存在を確認
   - コメントが存在しない場合は teammate に差し戻す
6. **遅延スポーン（役割別 teammate）**: teammate からの報告を受けたら、次の役割 teammate をスポーンする（詳細は後述）

#### 遅延スポーン仕様

teammate は Agent ツール（subagent_type 指定）を直接呼び出せない（Claude Code v2.1.70 制約）。そのため Lead が以下のタイミングで役割別 teammate をスポーンする。

**スポーントリガーと対象**:

| トリガー（teammate からの報告） | スポーン対象 | teammate 名 |
|-------------------------------|------------|-------------|
| 「計画投稿完了」 | plan-reviewer | `plan-reviewer-{issue}` |
| 「計画修正完了」（ループ時） | plan-reviewer | `plan-reviewer-{issue}` （再スポーン） |
| 「PR作成完了」 | reviewer | `reviewer-{issue}` |
| 「reviewer修正完了」（ループ時） | reviewer | `reviewer-{issue}` （再スポーン） |
| 「reviewer完了」 | 監査エージェント | `audit-{type}-{issue}` |
| 「監査修正完了」（ループ時） | 監査エージェント | `audit-{type}-{issue}` （再スポーン） |

**スポーン指示テンプレート**:

各 teammate には以下の最低限の情報を含むプロンプトを渡す:

- **plan-reviewer**: Issue番号、計画が投稿されたIssueコメントURL、レビュー結果のIssueコメント投稿先、レビュー完了後に `worker-{issue}` teammate へ SendMessage で結果を通知する指示
- **reviewer**: Issue番号、PR番号、スプリント契約の内容、レビュー結果のPRコメント投稿先、レビュー完了後に `worker-{issue}` teammate へ SendMessage で結果を通知する指示
- **監査（audit-*）**: Issue番号、PR番号、監査結果のPRコメント投稿先、監査完了後に `worker-{issue}` teammate へ SendMessage で結果を通知する指示

**監査 teammate のスポーン方法**:

設定で有効な監査エージェントが複数ある場合（例: audit-doc, audit-link）、直列にスポーンする。1つの監査 teammate が完了し結果を teammate に通知した後、次の監査 teammate をスポーンする。

**max_concurrent との関係**:

Phase 0 で算出する `max_concurrent` は **実装 teammate（`worker-{issue}`）の同時スポーン数** にのみ適用する。遅延スポーンされる役割別 teammate（plan-reviewer / reviewer / 監査）は max_concurrent のカウント対象外とする。理由: 役割別 teammate は実装 teammate の進行に必要な依存関係であり、制限すると実装がデッドロックする。

**同時存在 teammate 数の目安**:

遅延スポーンにより、同時に存在する teammate 数は以下の範囲に収まる:
- 最小: Issue 数（実装 teammate のみ）
- 最大: Issue 数 x 2（実装 teammate + reviewer/監査 teammate が同時に1つずつ存在するケース）
- plan-reviewer / reviewer / 監査は順次実行のため、同一 Issue で複数の役割 teammate が同時存在することはない

#### 中間チェックポイント（Lead の義務）

teammate からの報告を受けるたびに、該当するチェックを即座に実施する。
確認できない場合は teammate に差し戻し、確認できるまで次ステップに進ませない。

| タイミング | 確認コマンド | 確認内容 | 次のアクション |
|-----------|------------|---------|-------------|
| 計画投稿後 | `gh issue view <N> --json comments` | 計画コメントの存在 | plan-reviewer teammate をスポーン |
| plan-reviewer 後 | `gh issue view <N> --json comments` | plan-reviewer 結果コメントの存在 | Critical/Major あれば teammate に差し戻し |
| PR 作成後 | `gh pr view <N>` | PR の存在 | reviewer teammate をスポーン |
| reviewer 後 | `gh pr view <N> --json comments` | reviewer 結果コメントの存在 | Critical/Major あれば teammate に差し戻し、なければ監査 teammate をスポーン |
| 各監査後 | `gh pr view <N> --json comments` | 監査結果コメントの存在 | Critical/Major あれば teammate に差し戻し |

**原則: teammate の報告を鵜呑みにせず、必ずコマンドで事実確認する。**

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

1. **PR 本流マージは人間のみ** — teammate は PR を main/develop 等の本流ブランチへマージ（`gh pr merge` または対応する `git merge`）してはならない。PR 本流マージの最終承認は人間の責務。ローカル作業ブランチへの `git merge`（作業ブランチに main を取り込む等）や `git merge-base` 等の読み取り系コマンドは許容する
2. **teammate 間で同一Issue処理禁止** — 1つのIssueは1つの teammate のみが担当する
3. **Lead は teammate の結果を改変しない** — レビュー結果やPR内容を Lead が書き換えることは禁止
4. **AskUserQuestion は Lead のみ使用** — teammate は SendMessage で Lead に質問する
5. **ワークツリー分離厳守** — 各 teammate は EnterWorktree で分離されたワークツリーで作業する。EnterWorktree 直後に `pwd` と `git worktree list` で分離を検証し、検証失敗時は即座に中断すること（Step 1 参照）
6. **内部タスク番号に `#` 使用禁止** — GitHub誤リンク防止
7. **同時実行数超過でスポーンしない** — Phase 0 で算出した max_concurrent を超える実装 teammate（`worker-{issue}`）を同時にスポーンしない。遅延スポーンの役割別 teammate（plan-reviewer / reviewer / 監査）はカウント対象外（詳細は Phase 2 遅延スポーン仕様を参照）
8. **失敗 teammate を無限リトライしない** — 失敗した teammate は記録し、同一Issueの再試行は行わない
9. **Lead はエビデンス未確認で TaskUpdate しない** — teammate の報告だけで完了扱いにせず、Issue/PR コメントの存在をコマンドで確認すること
10. **git 操作はアトミック実行** — git add/commit/push は `&&` で連結した単一コマンドチェーンで実行すること。コマンドを分割して個別実行することは禁止（Step 3 参照）

---

## Error Handling

| パターン | 対応 |
|---------|------|
| OS スペック算出失敗 | デフォルト 2 にフォールバック |
| TeamCreate / EnterWorktree 失敗 | 中断し、個別に `/dbz-plan` + `/dbz-pr` の実行を案内 |
| ワークツリー分離検証失敗 | teammate は即座に中断し Lead に報告。Lead は EnterWorktree の再試行を指示するか、個別に `/dbz-plan` + `/dbz-pr` の実行を案内 |
| git 操作中の競合検出 | teammate は即座に中断し Lead に報告。Lead は状態を確認し、再試行または手動対応を判断 |
| teammate エラー停止 | Lead に報告し、他の teammate は継続 |
| 全 teammate 失敗 | エラーサマリーを報告 |
| Issue 未存在 | ユーザーにスキップまたは中断の選択肢を提示 |

---

## References

- **エージェント**: ../../agents/workflow/
- **設定ファイル**: ../../docs/config-loader.md
- **Issue情報**: ../../docs/issue-context-guide.md
