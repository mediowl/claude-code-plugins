# ゲートレビュー手順（マルチエージェント版）

## 概要

ゲートレビューは、各Phaseの成果物を複数の専門レビューエージェントが並列で評価し、その結果を統合してゲート判定を行う仕組みである。

## オーケストレーション手順

### Step 1: Phase番号の確認
ユーザーからどのPhaseのゲートレビューかを確認せよ。成果物が揃っているかを確認せよ。

### Step 2: 対象エージェントの取得
以下のPhase別エージェントマッピングから、対象Phaseのレビューエージェントを取得せよ。

### Step 3: Task tool による並列実行
各エージェントをTask toolで**並列に**実行せよ。subagent_typeにはカスタムエージェントタイプ（`piwf:piwf:エージェント名`）を指定し、プロンプトにはレビュー対象の成果物を含めること。

```
Task tool 呼び出し例:

subagent_type: "piwf:piwf:competitive-reviewer"
prompt: |
  以下の成果物をレビューしてください:

  ---
  [レビュー対象の成果物]
  ---

  チェックリストの各項目を確認し、出力フォーマットに従って指摘事項を出力してください。
```

### Step 4: 結果の統合
全エージェントの結果を統合し、トリアージ・判定を行う（後述の「統合・トリアージ手順」に従え）。

---

## Phase別エージェントマッピング

| Phase | エージェント | subagent_type |
|---|---|---|
| 0 | competitive-reviewer, feasibility-reviewer | `piwf:piwf:competitive-reviewer`, `piwf:piwf:feasibility-reviewer` |
| 1 | requirements-reviewer, scope-reviewer, datamodel-reviewer | `piwf:piwf:requirements-reviewer`, `piwf:piwf:scope-reviewer`, `piwf:piwf:datamodel-reviewer` |
| 2 | architecture-reviewer, security-reviewer, legal-reviewer, db-reviewer | `piwf:piwf:architecture-reviewer`, `piwf:piwf:security-reviewer`, `piwf:piwf:legal-reviewer`, `piwf:piwf:db-reviewer` |
| 3 | handoff-reviewer, design-system-reviewer, library-reviewer | `piwf:piwf:handoff-reviewer`, `piwf:piwf:design-system-reviewer`, `piwf:piwf:library-reviewer` |

---

## 統合・トリアージ手順

### 指摘の統合
全エージェントの出力を一つの表に統合せよ。各指摘にはどのエージェントが出したかを記録すること。

### 重複の排除
複数エージェントが同じ問題を異なる観点で指摘した場合:
- 重複として統合し、関連するエージェント名を併記せよ
- ランクは最も高いものを採用せよ

### 指摘のトリアージ
発見した問題を以下に分類せよ:

| ランク | 定義 | 対応 |
|---|---|---|
| **ブロッカー** | 対応しないと次に進めない | 現フェーズで必ず解決 |
| **重要** | このフェーズ中に対応すべき | 現フェーズで対応（時間切れなら申し送り） |
| **将来** | 次フェーズ以降でOK | 申し送りリストに記録 |

### 複数エージェントの指摘が競合した場合
同ランクで競合する場合の優先順: **技術的リスク > ビジネスリスク > UX**

---

## ゲート判定基準

| 判定 | 条件 | 次のアクション |
|---|---|---|
| **Pass** | 全ブロッカー解決済み、重要指摘なし | 次フェーズへ進む |
| **Conditional** | ブロッカーなし、重要指摘が残存 | 申し送りリスト作成 -> 次フェーズへ |
| **Fail** | ブロッカーあり | 現フェーズで対応 -> 再レビュー |

---

## 結果の出力

ゲートレビューの結果を以下の形式で出力せよ:

```markdown
## ゲートレビュー結果: Phase [N]

**判定: [Pass / Conditional / Fail]**

### レビュー実施エージェント
- [エージェント名1]
- [エージェント名2]
- ...

### 指摘事項

| # | 内容 | ランク | 指摘元エージェント | 対応 |
|---|---|---|---|---|
| 1 | ... | ブロッカー | ... | 現フェーズで対応 |
| 2 | ... | 重要 | ... | 申し送り |
| 3 | ... | 将来 | ... | 申し送り |

### 申し送りリスト（Conditional / Fail の場合）
[templates.md の書式で出力]
```
