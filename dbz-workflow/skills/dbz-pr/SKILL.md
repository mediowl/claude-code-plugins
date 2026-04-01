---
name: dbz-pr
description: PRワークフローを開始・管理する。Issue番号を渡してブランチ作成から開始、または現在のブランチで進捗確認
---

# PR Workflow Skill

PRワークフローを簡単に開始・管理するスキル。

## Input

- `issue_number`: Issue番号（例: `XXX`, `#XXX`）-- 新規ワークフロー開始
- `--status`: 進捗状況のみ表示
- 引数なし: 現在のブランチで進捗確認

## Usage Examples

```
/dbz-pr XXX          # Issue #XXXのワークフローを開始
/dbz-pr #XXX         # 同上（#付きでもOK）
/dbz-pr              # 現在のブランチで進捗確認
/dbz-pr --status     # 進捗状況のみ表示（次アクションなし）
```

## Workflow Phases

```
Phase 0: ブランチ準備 → Phase 1: 実装 + Code Simplification
→ Phase 2: 検証 → Phase 3: PR作成
→ Phase 4A: Reviewerレビュー（最大3回ループ）
→ Phase 4B: 監査エージェント（並列/直列フォールバック、最大3回ループ）
→ Phase 5: マージ待ち（人間のみ）
```

## 共通仕様

- **設定・Issue取得**: `../../docs/config-loader.md` および `../../docs/issue-context-guide.md` を参照
- **resume管理**: 前回スキル実行のagentIdは使用しない。`../../docs/agent-resume-guide.md` を参照
- **ペルソナ**: ペルソナ有効時のみ、サブエージェント呼び出し前に読み込み（`../../docs/config-loader.md` 参照）。Phase 1, 4A, 4B の各エージェント呼び出し前に適用
- **サブエージェント出力の表示**: 完了後、出力をそのまま（ペルソナ口調含め）ユーザーに表示すること。無言で次フェーズに進むことは禁止
- **agentId記録**: 各サブエージェント呼び出し時にagentIdを記録し、修正ループではresumeで再呼び出し
- **前提条件**: Phase 4A/4B はPRが存在すること

## Execution Flow

### 1. Issue番号が指定された場合（新規開始）

**Phase 0: ブランチ準備**

```bash
main_worktree=$(git worktree list --porcelain | head -1 | sed 's/worktree //')
current_dir=$(pwd -P)

if [ "$current_dir" = "$main_worktree" ]; then
  git checkout main && git pull origin main
  git checkout -b <type>/<issue>-<description>
else
  git fetch origin main
  git checkout -b <type>/<issue>-<description> origin/main
fi
```

**ブランチ命名規則**: `feat/`, `fix/`, `refactor/`, `docs/` + `<issue>-<description>`。Issue titleから適切なtypeとdescriptionを推測する。

**並列実行時のワークツリー分離ガードレール（必須）**: Phase 0 開始時に `git worktree list` を実行し、メインワークツリーかつ他ワークツリーが存在する場合、[Critical] 警告を表示しワークフローを中断する。同一ワークツリーで複数ブランチの並列操作は禁止。

> **Note**: /dbz-team 実行中は teammate がワークツリーを使用するため、Lead のメインワークツリーでも他ワークツリーの存在が検出される。Lead がメインワークツリーで別途 /dbz-pr を実行した場合にガードレールが発動するが、これは並列作業の安全性を確保するための意図された動作である。

### 2. 進捗確認（引数なし or --status）

`git status` でステージング状況、`gh pr view` でPR状況、各フェーズの完了状況をチェック。

### 3. 各フェーズの実行

**Phase 1: 実装**

- `subagent_type: "dbz-workflow:workflow:implementer"` でAgent起動。Issue情報をプロンプトに含める
- Implementer完了後、**dbz-prが`/simplify`スキルを呼び出す**（コード変更がない場合はスキップ）
- `/simplify`完了後はユーザー入力を待たず、直ちにPhase 2へ進む
- **implementer出力の検証（必須）**: 出力にレビュー・監査系の見出し（「[OK] APPROVED」等）が含まれていたら、セルフレビューの可能性を警告し、Phase 4A/4Bで正規レビューを実施

**Phase 2: 検証**

```bash
npm run lint
npm run typecheck
npm test
# E2Eテスト（プロジェクト固有）
```

**Phase 3: PR作成**

```bash
git add <files>
git commit -m "<message>"
git push -u origin <branch>
gh pr create --title "<title>" --body "<body>"
```

**PR作成後のブランチ名検証（必須）**: `gh pr view <PR番号> --json headRefName` で自分のブランチ名との一致を確認。不一致ならエラー報告しワークフローを中断。

**Phase 4A: Reviewerレビュー**

> **重要**: reviewer / audit-* エージェントの起動はこのdbz-prスキル（オーケストレーター）の責務。implementer にレビュー・監査を依頼してはならず、セルフレビュー結果は採用しない。

`subagent_type: "dbz-workflow:workflow:reviewer"` でAgent起動。PR番号とIssue情報をプロンプトに含める。

**Phase 4A 修正ループ**（Critical/Majorがあれば最大3回）:

> **implementerのresume上限**: Phase 1の初回呼び出しからPhase 4A終了までの合計resume回数は最大3回。コンテキストリミット到達防止のための制限。

1. implementerを`resume`で再呼び出し（Phase 1のagentIdを使用）し、Critical/Major指摘を修正
2. 修正内容をコミット・プッシュ
3. reviewerを`resume`で再呼び出しし再レビュー
4. Critical/Major残存ならループ継続、Minor/SuggestionのみならPhase 4Bへ

**Phase 4B: 監査エージェント**

設定ファイル（`.claude/dbz-workflow.config.md`）に基づき有効なエージェントのみ実行。無効化されたエージェントはスキップしPRコメントで通知。未設定時はすべて有効（デフォルト一覧は `config-loader.md` 参照）。
- **audit-doc は強制有効**（設定で `false` でも実行）
- 監査エージェント自身は設定を読み込まない（workflow-prが制御）
- 各エージェントの `subagent_type` は `dbz-workflow:workflow:{agent-name}` 形式

**ツール検出とフォールバック**: Phase 4B 開始時に TaskCreate ツールの利用可否を確認。利用可能なら並列実行、利用不可ならAgentツールで直列実行し `[注意] Task ツール未検出のため直列実行` をPRコメントに記録。

**Phase 4B 修正ループ**（Critical/Majorがあれば最大3回）:

1. implementerを **fresh start + コンテキストサマリー** で呼び出し（Phase境界リセット: Phase 1のagentIdは使用しない）。`implementer_agent_id_phase4b` を記録し、2回目以降はresumeで再呼び出し
   - **コンテキストサマリー**（workflow-prが生成）: 変更ファイル一覧、実装方針、Phase 4Aでの修正内容
2. Critical/Majorを検出したエージェントのみresumeで再呼び出し
3. Critical/Major残存ならループ継続、すべてMinor/Suggestion以下ならPhase 5へ

**Phase 5: マージ待ち** -- Phase 4A/4B完了後、マージ待ち状態で停止。完了メッセージにハーネス見直しの案内（`/dbz-retro`）を含める。

## Documentation-Only Changes

全ての変更ファイルが`.md`の場合: Code Simplification と E2E tests をスキップ。lint/typecheck、品質監査、セルフチェックは必須。

## TodoList Integration

ワークフロー開始時にTodoWriteツールでPhase 0-5のタスクリストを作成し、各フェーズ完了時にステータスを更新する。

## Absolute Rules

1. **PR作成前に監査エージェントを実行しない**
2. **[Critical] マージは人間のみ（最重要）** -- Claude Code は `git merge` / `gh pr merge` を **絶対に実行しない**
   - 理由: 人間がPRを確認しなくなり、品質保証の最終防衛ラインが崩壊するため
   - Phase 5 では「マージ待ち」状態で停止し、人間の操作を待つ
3. **Critical/Majorを放置しない**（Phase 4A/4Bで最大3回ループ）
4. **PRコメント投稿必須**（コンソール出力だけでなく、必ずPRにもコメント投稿すること）
5. **内部タスク番号に`#`使用禁止**（GitHub誤リンク防止）
6. **具体的な数の明記禁止**（例: [NG]「45箇所」→ [OK]「変数名リネーム」）
7. **簡素化スキップ禁止** -- `/simplify` を飛ばして PR 作成しない
8. **検証スキップ禁止** -- テスト/型/リント未確認のまま PR を出さない
9. **スコープ逸脱禁止** -- 指摘箇所以外を勝手に修正しない
10. **Issue情報なしでのエージェント呼び出し禁止** -- エージェント呼び出し時は必ずIssue情報（タイトル・背景）を含めること
11. **`git add -A` / `git add .` 使用禁止** -- 変更ファイルを明示的に指定すること
12. **サブエージェントのPRコメント投稿を代行禁止** -- サブエージェントは自身でPRコメントを投稿する責務を持つ。親エージェント（workflow-pr）は投稿を代行しない
13. **サブエージェントの結果を改変禁止** -- 例: reviewerが「Minor 3件」と判定した場合、親エージェントが「Major 1件」に変更することは禁止。問題があればユーザーに判断を委ねる
14. **implementer のセルフレビュー禁止** -- implementer が reviewer/audit-* の役割を兼ねることを禁止。セルフレビュー結果が含まれていた場合は無視し、正規フェーズで再実行すること

## セマンティックバージョニング基準

plugin.json のバージョン管理については [CLAUDE.md](../../../CLAUDE.md) を参照してください。

## Error Handling

- **PR未作成で監査実行**: エラー表示し、Phase 3完了を促す
- **最大ループ回数到達（3回）**: 残存するCritical/Major指摘をユーザーに報告し、続行/手動修正/中断の選択を求める（Phase 4Bでは問題のあるエージェントのみ報告）

## References

- **エージェント**: ../../agents/workflow/
