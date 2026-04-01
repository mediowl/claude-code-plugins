# PIWF v3 -- Product Innovation Workflow Framework

プロダクト開発ワークフロー（Phase 0-3 + ゲートレビュー + 振り返り）

## インストール

### 1. リポジトリをクローン

```bash
git clone https://github.com/mediowl/claude-code-plugins.git ~/.claude/plugin-sources/mediowl-plugins
```

### 2. マーケットプレイスを登録

```bash
claude plugin marketplace add ~/.claude/plugin-sources/mediowl-plugins
```

### 3. プラグインをインストール

```bash
# プロジェクトスコープ（チーム共有）
claude plugin install piwf@mediowl-plugins --scope project

# またはユーザースコープ（個人環境）
claude plugin install piwf@mediowl-plugins --scope user
```

### 4. 確認

```bash
claude plugin list
```

## 更新

プラグインのソースコードが更新された場合:

```bash
claude plugin update piwf@mediowl-plugins --scope project
```

> **注意**: 更新後は **Claude Code の再起動が必須**です。再起動しないと変更が反映されません。

> **開発者向け**: プラグインのソースを変更した場合、`plugin.json` のバージョン更新が必要です。詳細は [CLAUDE.md](../CLAUDE.md#バージョン管理ルール) を参照してください。

## 提供スキル

| スキル | 説明 |
|--------|------|
| `/piwf` | Phase 0-3 のワークフロー実行（司令塔） |
| `/piwf-retro` | プロジェクト完了後の振り返り |

## 使い方

### 新規プロジェクトを開始する

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

### フェーズ途中から再開する

```
PIWFの Phase 1 を再開します。
前フェーズの成果物は piwf-output/my-app/ にあります。
申し送りリスト: 競合分析のUntappd以外の比較が未完了（将来ランク）
```

### ゲートレビューを手動で依頼する

```
Phase 1 のゲートレビューをお願いします。
成果物: piwf-output/my-app/requirements-v1.md
特に見てほしい点: Must機能のスコープが[N]週間に収まるか
```

### 2回目以降のプロジェクト（振り返り活用）

```
PIWFのPhase 0を開始してください。

前回プロジェクトの振り返り:
piwf-output/prev-project/piwf-retrospective.md を参照してください。

【必須】
- 作りたいもの: ...
- MVP期間: ...
- 開発体制: ...
```

## フェーズ一覧

| Phase | 名称 | 目的 | 主な成果物 |
|---|---|---|---|
| 0 | バリデーション | やる価値があるか判断 | コンセプト定義、競合分析 |
| 1 | 要件定義 | 何を作るか具体化 | 要件定義書 |
| 2 | 設計・法務レビュー | 技術設計 + 法務リスク | 設計書、法務分析書 |
| 3 | 開発準備 | 実装に入れる状態にする | CLAUDE.md、タスク分割表、各種設計書 |

> PIWFのゴールは「Claude Codeが迷わず実装に入れる状態にすること」。Phase 3完了後の実装は `dbz-workflow` 等の別ワークフローに委譲する。

## 提供エージェント

### フェーズ定義

| エージェント | 説明 |
|-------------|------|
| `phase0` | バリデーション（アイデア検証） |
| `phase1` | 要件定義 |
| `phase2` | 設計・法務レビュー |
| `phase3` | 開発準備（設計詳細化・CLAUDE.md作成） |
| `gate-review` | ゲートレビュー（マルチエージェントオーケストレーター） |
| `templates` | 申し送り・変更履歴・レビュー依頼の書式 |

### ゲートレビューエージェント

各Phaseの成果物を専門観点からレビューするエージェント群です。ゲートレビュー時に `gate-review` が自動で並列実行します。

| Phase | エージェント | レビュー対象 |
|---|---|---|
| 0 | `competitive-reviewer`, `feasibility-reviewer` | コンセプト・競合分析・技術フィージビリティ |
| 1 | `requirements-reviewer`, `scope-reviewer`, `datamodel-reviewer` | 要件定義書・データモデル |
| 2 | `architecture-reviewer`, `security-reviewer`, `legal-reviewer`, `db-reviewer` | 設計書・法務分析書 |
| 3 | `handoff-reviewer`, `design-system-reviewer`, `library-reviewer` | CLAUDE.md・設計詳細・ライブラリ対策 |

**エージェント間の観点境界:**

- **datamodel-reviewer（Phase 1）** vs **db-reviewer（Phase 2）**: 前者は「何のデータを持つか」（エンティティ・リレーション設計）、後者は「どう実装するか」（制約・インデックス・マイグレーション）
- **architecture-reviewer** vs **security-reviewer**: 前者は認証の「アーキテクチャ設計」（配置場所、ミドルウェア構成）、後者は「セキュリティリスク」（脆弱性チェック、攻撃対策）

## 振り返りスキル（piwf-retro）

プロジェクト完了後に `/piwf-retro` を実行すると、以下を構造化して記録できます:

- ゲート検出問題の一覧
- 定量評価（申し送り消化率、イテレーション回数等）
- ナレッジ蓄積（ライブラリ対策、避けるべき落とし穴、設計判断）

出力される `piwf-retrospective.md` を次プロジェクトの Phase 0 で受け取ることで、過去の教訓を活かした開発が可能になります。

## ファイル構成

```
piwf/
├── .claude-plugin/
│   └── plugin.json
├── .claude/
│   └── settings.json
├── README.md
├── skills/
│   ├── piwf/
│   │   └── SKILL.md
│   └── piwf-retro/
│       └── SKILL.md
└── agents/
    └── piwf/
        ├── gate-review.md
        ├── phase0.md ... phase3.md
        ├── templates.md
        └── (12 reviewer agents)
```

## 記述ルール

- 設定ファイルおよびドキュメントに絵文字を使用しないこと
- 真偽値は `true`/`false` で記述すること
- 理由: 環境やフォントによって表示が崩れる可能性があるため

## アンインストール

```bash
claude plugin uninstall piwf@mediowl-plugins
```
