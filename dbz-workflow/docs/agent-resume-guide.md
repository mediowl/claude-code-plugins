# agent-resume-guide.md

同じスキル実行内でサブエージェントを複数回呼ぶ場合、`resume` パラメータで前回のコンテキストを引き継ぐ。

---

## 基本ルール

1. **1回目**: `resume` なしで呼び出し、`agentId` を記録
2. **2回目以降**: `resume` に agentId を指定
3. **別のスキル実行**: agentId は引き継がない（各スキル実行は独立）
4. **異なるエージェント種別**: agentId を共有しない

---

## Phase境界リセット

implementer は Phase 4A → Phase 4B 移行時に **必ず fresh start** で起動（コンテキスト肥大化防止）。fresh start 時は親スキルがコンテキストサマリー（変更ファイル一覧、実装方針、Phase 4A修正内容）をプロンプトに含める。

---

## エージェント別の resume 戦略

| エージェント | Phase | 戦略 | agentId 変数名 |
|------------|-------|------|---------------|
| reviewer | 4A | ループごとに resume | `reviewer_agent_id` |
| audit-* | 4B | エージェントごとにagentId管理、ループごとにresume | `audit_{name}_agent_id` |
| implementer | 1 + 4A | Phase内でresume（上限3回） | `implementer_agent_id` |
| implementer | 4B | fresh start + サマリー → 以降resume | `implementer_agent_id_phase4b` |
| plan-reviewer | 4（plan） | ループごとに resume | `plan_reviewer_agent_id` |

---

## フォールバック

agentId取得失敗・resume失敗時は `[注意]` を表示し **fresh start で継続**（ワークフロー中断しない）。

> Task ツール未対応環境でのフォールバック（Agent ツールでの直列実行）については、SKILL.md を参照。
