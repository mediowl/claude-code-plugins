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
Phase 0: ブランチ準備 → Phase 0.5: スプリント契約（最大3回ループ）
→ Phase 1: 実装 + Code Simplification
→ Phase 2: 検証 → Phase 3: PR作成
→ Phase 4A: Reviewerレビュー（最大3回ループ）
→ Phase 4B: 監査エージェント（並列/直列フォールバック、最大3回ループ）
→ Phase 5: マージ待ち（人間のみ）
```

## 共通仕様

- **設定・Issue取得**: `../../docs/config-loader.md` および `../../docs/issue-context-guide.md` を参照
- **再開管理**: 前回スキル実行のagentIdは使用しない。`../../docs/agent-resume-guide.md` を参照
- **ペルソナ**: ペルソナ有効時のみ、サブエージェント呼び出し前に読み込み（`../../docs/config-loader.md` 参照）。Phase 0.5, 1, 4A, 4B の各エージェント呼び出し前に適用
- **サブエージェント出力の表示**: 完了後、出力をそのまま（ペルソナ口調含め）ユーザーに表示すること。無言で次フェーズに進むことは禁止
- **agentId記録**: 各サブエージェント呼び出し時にagentIdを記録し、修正ループではSendMessage({to: agentId})で再呼び出し
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

**Phase 0.5: スプリント契約**

Phase 1（実装）開始前に、implementer と reviewer が「スプリント契約」を交渉する。受入基準・テスト条件・レビュー観点を事前合意し、実装のゴールを明確化する。

> **参考**: Anthropic公式ブログ記事 "Harness design for long-running apps" (2026/3/24) の Sprint Contract パターンに基づく。

**スキップ条件**: ワークフロー開始時に取得済みの Issue コメントに「スプリント契約」という文字列が含まれている場合（`/dbz-plan` で計画テンプレートに契約が定義済み）、Phase 0.5 をスキップする。

- **検出方法**: Issue コメント本文の部分一致で判定（見出しレベルやバージョン番号に依存しない）。dbz-plan の計画テンプレートでは `###`（テンプレート内の他セクションと統一）、dbz-pr の Phase 0.5 契約では `##`（独立 Issue コメント）を使用するが、部分一致のため見出しレベルの差異は影響しない
- **スキップ時の動作**: 既存契約の内容をユーザーに表示し、「既存のスプリント契約を検出したため Phase 0.5 をスキップします」と通知して Phase 1 へ進む
- **非スキップ時**: 従来通り契約交渉を実行（既存動作に変更なし）

**契約フロー**:
1. implementer が契約を提案（`subagent_type: "dbz-workflow:workflow:implementer"` で起動。プロンプトに「Phase 0.5: スプリント契約の提案」であることとIssue情報を含める）
2. reviewer が契約を評価（`subagent_type: "dbz-workflow:workflow:reviewer"` で起動。プロンプトに「Phase 0.5: スプリント契約の評価」であることと契約内容を含める）
3. Critical/Major があれば implementer を SendMessage で再呼び出しし修正、再度 reviewer が評価（最大3回ループ）
4. Minor/Suggestion のみなら契約合意、Phase 1 へ進む

**implementer への指示内容**: 以下の構造化フォーマットで契約を提案すること。

```markdown
## スプリント契約

### 受入基準
- [ ] [基準1: 具体的かつ検証可能な条件]
- [ ] [基準2]

### FAIL 条件（契約違反とみなすケース）
- [FAIL] [条件1: この状態であれば実装失敗とみなす]
- [FAIL] [条件2]

### テスト条件
- [ ] [テスト1: 何をどう検証するか]
- [ ] [テスト2]

### レビュー観点（reviewer が重点的に確認する項目）
- [観点1]
- [観点2]
```

**reviewer への評価指示（形式的承認防止）**: 契約を評価する際、以下の観点で厳密にチェックすること。形式的な承認（rubber-stamping）は禁止。

- 各 FAIL 条件は**具体的かつ検証可能**か（曖昧な表現がないか）
- 受入基準に**漏れ**はないか（Issue の要件を網羅しているか）
- テスト条件は受入基準を**十分にカバー**しているか
- レビュー観点は実装の**リスク領域**を適切に捉えているか

**契約の永続化**: 合意した契約は以下のコマンドで Issue コメントに投稿する。

```bash
gh issue comment <issue_number> --body-file sprint-contract.md
```

契約コメントの見出しは `## スプリント契約 v{version}`（v0 から開始、ループごとに増加）とする。Phase 1 の implementer と Phase 4A の reviewer は、この契約を参照して作業を行う。

**Phase 0.5 の agentId 管理**: implementer と reviewer それぞれの agentId を `implementer_agent_id_phase05`、`reviewer_agent_id_phase05` として記録する。Phase 1 の implementer は新規起動（Phase 0.5 の agentId は使用しない）。

**最大ループ到達時**: 3回ループしても合意に至らない場合、残存する Critical/Major 指摘をユーザーに報告し、続行/手動修正/中断の選択を求める。

---

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

**git 操作のアトミック実行（必須）**: ワークツリー環境での競合防止のため、git add/commit/push は `&&` で連結した単一コマンドチェーンで実行する。

```bash
git add <files> && git commit -m "<message>" && git push -u origin <branch>
gh pr create --title "<title>" --body "<body>"
```

**PR作成後のブランチ名検証（必須）**: `gh pr view <PR番号> --json headRefName` で自分のブランチ名との一致を確認。不一致ならエラー報告しワークフローを中断。

**Phase 4A: Reviewerレビュー**

> **重要**: reviewer / audit-* エージェントの起動はこのdbz-prスキル（オーケストレーター）の責務。implementer にレビュー・監査を依頼してはならず、セルフレビュー結果は採用しない。

`subagent_type: "dbz-workflow:workflow:reviewer"` でAgent起動。PR番号とIssue情報をプロンプトに含める。

**Phase 4A 修正ループ**（Critical/Majorがあれば最大3回）:

> **implementerの再開上限**: Phase 1の初回呼び出しからPhase 4A終了までの合計SendMessage再開回数は最大3回。コンテキストリミット到達防止のための制限。

1. implementerを`SendMessage({to: agentId})`で再呼び出し（Phase 1のagentIdを使用）し、Critical/Major指摘を修正
2. 修正内容をコミット・プッシュ
3. reviewerを`SendMessage({to: agentId})`で再呼び出しし再レビュー
4. Critical/Major残存ならループ継続、Minor/SuggestionのみならPhase 4Bへ

**Phase 4B: 監査エージェント**

設定ファイル（`.claude/dbz-workflow.config.md`）に基づき有効なエージェントのみ実行。無効化されたエージェントはスキップしPRコメントで通知。未設定時はすべて有効（デフォルト一覧は `config-loader.md` 参照）。
- **audit-doc は強制有効**（設定で `false` でも実行）
- 監査エージェント自身は設定を読み込まない（workflow-prが制御）
- 各エージェントの `subagent_type` は `dbz-workflow:workflow:{agent-name}` 形式

**ツール検出とフォールバック**: Phase 4B 開始時に TaskCreate ツールの利用可否を確認。利用可能なら並列実行、利用不可ならAgentツールで直列実行し `[注意] Task ツール未検出のため直列実行` をPRコメントに記録。

**Phase 4B 修正ループ**（Critical/Majorがあれば最大3回）:

1. implementerを **fresh start + コンテキストサマリー** で呼び出し（Phase境界リセット: Phase 1のagentIdは使用しない）。`implementer_agent_id_phase4b` を記録し、2回目以降はSendMessageで再呼び出し
   - **コンテキストサマリー**（workflow-prが生成）: 変更ファイル一覧、実装方針、Phase 4Aでの修正内容
2. Critical/Majorを検出したエージェントのみSendMessageで再呼び出し
3. Critical/Major残存ならループ継続、すべてMinor/Suggestion以下ならPhase 5へ

**Phase 5: マージ待ち** -- Phase 4A/4B完了後、マージ待ち状態で停止。

## Documentation-Only Changes

全ての変更ファイルが`.md`の場合: Code Simplification と E2E tests をスキップ。lint/typecheck、品質監査、セルフチェックは必須。

## TodoList Integration

ワークフロー開始時にTodoWriteツールでPhase 0-0.5-1-2-3-4A-4B-5のタスクリストを作成し、各フェーズ完了時にステータスを更新する。

## Absolute Rules

1. **PR作成前に監査エージェントを実行しない**
2. **[Critical] PR 本流マージは人間のみ（最重要）** -- Claude Code は PR を main/develop 等の本流ブランチへマージ（`gh pr merge` または対応する `git merge`）してはならない
   - 理由: 人間がPRを確認しなくなり、品質保証の最終防衛ラインが崩壊するため
   - Phase 5 では「マージ待ち」状態で停止し、人間の操作を待つ
   - ローカル作業ブランチへの `git merge`（作業ブランチに main を取り込む等）や `git merge-base` 等の読み取り系コマンドは許容する
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
15. **git 操作はアトミック実行** -- git add/commit/push は `&&` で連結した単一コマンドチェーンで実行すること。ワークツリー環境での競合防止のため、コマンドを分割して個別実行することは禁止

## セマンティックバージョニング基準

plugin.json のバージョン管理については [CLAUDE.md](../../../CLAUDE.md) を参照してください。

## Error Handling

- **PR未作成で監査実行**: エラー表示し、Phase 3完了を促す
- **最大ループ回数到達（3回）**: 残存するCritical/Major指摘をユーザーに報告し、続行/手動修正/中断の選択を求める（Phase 4Bでは問題のあるエージェントのみ報告）

## References

- **エージェント**: ../../agents/workflow/
