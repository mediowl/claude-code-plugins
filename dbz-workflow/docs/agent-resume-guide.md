# agent-resume-guide.md

同じスキル実行内でサブエージェントを複数回呼ぶ場合、`SendMessage({to: agentId})` で前回のコンテキストを引き継いで再開する。

> **前提条件**: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` が有効であること。未設定の場合、SendMessage は利用できないため fresh start で代替する。

---

## 基本ルール

1. **1回目**: 新規起動し、`agentId` を記録
2. **2回目以降**: `SendMessage({to: agentId})` で再開
3. **別のスキル実行**: agentId は引き継がない（各スキル実行は独立）
4. **異なるエージェント種別**: agentId を共有しない

---

## Phase境界リセット

implementer は Phase 4A → Phase 4B 移行時に **必ず fresh start** で起動（コンテキスト肥大化防止）。fresh start 時は親スキルがコンテキストサマリー（変更ファイル一覧、実装方針、Phase 4A修正内容）をプロンプトに含める。

---

## エージェント別の再開戦略

| エージェント | Phase | 戦略 | agentId 変数名 |
|------------|-------|------|---------------|
| reviewer | 4A | ループごとに SendMessage で再開 | `reviewer_agent_id` |
| audit-* | 4B | エージェントごとにagentId管理、ループごとにSendMessageで再開 | `audit_{name}_agent_id` |
| implementer | 1 + 4A | Phase内でSendMessageで再開（上限3回） | `implementer_agent_id` |
| implementer | 4B | fresh start + サマリー → 以降SendMessageで再開 | `implementer_agent_id_phase4b` |
| plan-reviewer | 4（plan） | ループごとに SendMessage で再開 | `plan_reviewer_agent_id` |

---

## フォールバック

agentId取得失敗・SendMessage失敗時は `[注意]` を表示し **fresh start で継続**（ワークフロー中断しない）。

> Task ツール未対応環境でのフォールバック（Agent ツールでの直列実行）については、SKILL.md を参照。
