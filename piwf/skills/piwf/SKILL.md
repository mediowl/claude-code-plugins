---
name: piwf
description: プロダクト開発ワークフロー（Phase 0〜3 + ゲートレビュー）
---

# PIWF — Product Innovation Workflow Framework v3

## Hooks 登録チェック（スキル実行開始時に必ず実施）

このプラグインは以下の hooks を提供しているが、Claude Code はプラグインの hooks を自動登録しない。
スキル実行開始時に、以下の手順で hooks が登録済みか確認せよ。

### チェック手順

1. 以下のファイルを順に確認する:
   - `.claude/settings.json`（プロジェクトスコープ）
   - `~/.claude/settings.json`（ユーザースコープ）
2. いずれかのファイルに以下の **両方** が登録されていれば OK:
   - `hooks.SessionStart` に `check-update.sh` を含むエントリ
   - `hooks.PreToolUse` に `guard-dangerous-commands.sh` を含むエントリ
3. 片方でも未登録の場合、以下の案内を表示してからワークフローを続行せよ:

```
[注意] piwf プラグインの hooks が settings.json に登録されていません。
以下の機能が無効になっています:

- SessionStart hook: プラグインの自動更新チェック
- PreToolUse hook: 危険コマンド（rm -rf, git push --force 等）のブロック

セットアップ方法:
プロジェクトの .claude/settings.json（またはユーザーの ~/.claude/settings.json）に以下を追記してください:

{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/plugin-sources/mediowl-plugins/piwf/hooks/check-update.sh piwf mediowl-plugins mediowl/claude-code-plugins",
            "timeout": 30
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/plugin-sources/mediowl-plugins/piwf/hooks/guard-dangerous-commands.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
}

詳細は piwf の README.md「Hooks のセットアップ」を参照してください。
```

### 注意事項

- hooks が未登録でもワークフロー自体は実行可能。案内表示後にブロックせず続行すること
- 既に登録済みの場合は何も表示せずそのまま進めること

## このスキルの使い方

ユーザーが「PIWF」「Phase N」「ゲートレビュー」に言及したら、このスキルに従って行動せよ。

## 絶対ルール

1. **ゲート通過なしにフェーズを飛ばすな**
2. **Conditional通過時は申し送りリストを必ず作成せよ**
3. **レビュー指摘はトリアージしてから対応せよ**（ブロッカー/重要/将来）
4. **文書改訂時は変更履歴サマリーを冒頭に記載せよ**
5. **各フェーズ冒頭で前フェーズの申し送り消化を確認せよ**
6. **フェーズごとにセッションを分けることを推奨** — ゲートレビュー後、Pass/Conditionalなら次Phaseの開始をユーザーに案内する（同一セッションでの続行も可）
7. **迷ったり不明な点は必ず確認する。"〜だろう"で勝手に断定して進めないこと**
8. **技術的なこと → Context7 / WebSearch で事実確認。不明ならユーザーに委ねる**
9. **仕様や制約 → ユーザーに確認する**

## フェーズ振り分け

ユーザーの指示に応じて、該当するフェーズファイルを読み込んで実行せよ。

| ユーザーの指示 | 読むファイル |
|---|---|
| Phase 0、バリデーション、アイデア検証 | `../../agents/piwf/phase0.md` |
| Phase 1、要件定義 | `../../agents/piwf/phase1.md` |
| Phase 2、設計、法務 | `../../agents/piwf/phase2.md` |
| Phase 3、開発準備、CLAUDE.md作成 | `../../agents/piwf/phase3.md` |
| ゲートレビュー、レビュー | `../../agents/piwf/gate-review.md` |
| テンプレート、書式、申し送り | `../../agents/piwf/templates.md` |

## フェーズ一覧（概要）

| Phase | 名称 | 目的 | 主な成果物 |
|---|---|---|---|
| 0 | バリデーション | やる価値があるか判断 | コンセプト定義、競合分析 |
| 1 | 要件定義 | 何を作るか具体化 | 要件定義書 |
| 2 | 設計・法務レビュー | 技術設計＋法務リスク | 設計書、法務分析書 |
| 3 | 開発準備 | 実装に入れる状態にする | CLAUDE.md、タスク分割表、各種設計書 |

> PIWFのゴールは「Claude Codeが迷わず実装に入れる状態にすること」。Phase 3完了後の実装は dbz-workflow 等の別ワークフローに委譲する。

## 開始時にユーザーから受け取るべき情報

Phase 0を開始する前に、以下の情報をユーザーに求めよ。不足している場合は質問して埋めること。

### 必須（これがないとPhase 0を始めるな）
1. **何を作りたいか** — ざっくりでOK（例：「短編小説の投稿サイト」）
2. **MVP期間** — 何週間で作りたいか（例：3週間 -- これはフォーマット例であり、エージェントがデフォルト値として採用してはならない。必ずユーザーが指定した期間を使うこと）
3. **開発体制** — 個人開発 / チーム / Claude Codeメイン 等

### あると精度が上がる（なければヒアリングで補え）
4. **ターゲットユーザーのイメージ** — 誰に使ってほしいか
5. **技術スタックの希望や制約** — 「Next.js + Supabase」等
6. **参考にしたいサービス** — 「〇〇みたいなイメージ」
7. **マネタイズの方針** — 考えているか否か
8. **過去プロジェクトの振り返り** — `/piwf-retro` スキルで生成した `piwf-retrospective.md` があれば受け取れ（2回目以降のプロジェクト）

---

## 使い方の例

### 新規プロジェクト開始時
```
PIWFのPhase 0を開始してください。

【必須】
- 作りたいもの: クラフトビールの記録・発見アプリ
- MVP期間: 3週間
- 開発体制: 個人開発、Claude Codeメイン

【あれば精度UP】
- ターゲット: クラフトビール好きのライト層
- 技術: Next.js + Supabase
- 参考: Untappd の日本版的なイメージ
- マネタイズ: まだ考えていない
```

### フェーズ途中から再開する場合
```
PIWFの Phase 1 を再開します。
前フェーズの成果物は piwf-output/tan-pen/ にあります。
申し送りリスト: 競合分析のUntappd以外の比較が未完了（将来ランク）
```

### 手動でゲートレビューを依頼する場合
```
Phase 1 のゲートレビューをお願いします。
成果物: piwf-output/tan-pen/requirements-v1.md
特に見てほしい点: Must機能のスコープが[N]週間に収まるか
```
