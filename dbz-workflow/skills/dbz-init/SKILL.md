---
name: dbz-init
description: 対話式で dbz-workflow 設定ファイルを生成する。プロジェクトタイプ、テストコマンド、監査エージェント設定などを対話で収集し、.claude/dbz-workflow.config.md を作成
---

# Workflow Init Skill

対話式で dbz-workflow 設定ファイルを生成するスキル。

## Usage

```
/dbz-init
```

引数なしで実行し、対話形式で設定ファイルを生成します。

---

## 機能

1. **プロジェクト情報の収集**: プロジェクトタイプ、技術スタック、テストコマンドなど
2. **監査エージェント設定**: プロジェクトタイプに応じた推奨設定
3. **設定ファイル生成**: `.claude/dbz-workflow.config.md` を自動生成
4. **既存設定の保護**: 既存設定がある場合は上書き確認

---

## Execution Flow

### 1. 既存設定ファイルの確認

**Read ツールで既存ファイルを確認**:

```bash
Read: .claude/dbz-workflow.config.md
```

**既存ファイルがある場合**:
- ユーザーに上書き確認を求める
- 「いいえ」の場合は処理を中断

**既存ファイルがない場合**:
- 次のステップへ進む

---

### 2. .claude/ ディレクトリの確認・作成

**Bash ツールでディレクトリの存在を確認**:

```bash
ls -la .claude
```

**ディレクトリが存在しない場合**:

```bash
mkdir -p .claude
```

**作成成功を確認**:

```bash
ls -la .claude
```

---

### 3. .claude/dbz-workflow/ ディレクトリの作成（条件付き）

**Phase 3でペルソナファイル生成を選択した場合のみ実行**:

```bash
mkdir -p .claude/dbz-workflow
```

このディレクトリには以下のペルソナファイルが配置されます:

**主要エージェント（固定）**:
- `reviewer.persona.md`
- `plan-reviewer.persona.md`
- `implementer.persona.md`
- `audit-doc.persona.md`

**監査エージェント（Phase 2で有効にしたもののみ）**:
- `audit-black-hacker.persona.md`（Phase 2で有効化された場合）
- `audit-white-hacker.persona.md`（Phase 2で有効化された場合）
- `audit-i18n.persona.md`（Phase 2で有効化された場合）
- `audit-design.persona.md`（Phase 2で有効化された場合）
- `audit-a11y.persona.md`（Phase 2で有効化された場合）
- `audit-link.persona.md`（Phase 2で有効化された場合）
- `audit-test.persona.md`（Phase 2で有効化された場合）

**Note**: audit-doc は主要エージェントとして必須のため、監査エージェント設定に関わらず常にペルソナファイルが生成されます。

---

### 4. config-wizard エージェントの呼び出し

**config-wizard エージェントを起動して対話を開始**:

プラグインに登録された `config-wizard` エージェントが設定ファイル生成を担当します。

**config-wizard の役割**:
- ユーザーとの対話で設定情報を収集
- プロジェクトタイプに応じた監査エージェント推奨設定を提供
- `.claude/dbz-workflow.config.md` を生成
- 完了通知をユーザーに表示

---

## config-wizard の対話内容

### Phase 1: プロジェクト情報の収集（質問セット1）

1. プロジェクトタイプ（Webフロントエンド / バックエンドAPI / CLIツール / ライブラリ / ドキュメントのみ）
2. テストコマンド（npm test / その他）
3. E2Eテストコマンド（npm run e2e / なし / その他）
4. デザインシステムの使用有無

### Phase 2: 詳細設定の収集（質問セット2）

1. 多言語対応（i18n）の有無
2. 監査エージェント設定（推奨設定 / カスタマイズ）
3. ペルソナ有効化（はい / いいえ）

**カスタマイズを選択した場合**:
- 各監査エージェント（7個、audit-doc除く）の有効/無効を選択

**ペルソナ有効化で「いいえ」を選択した場合**:
- Phase 3（ペルソナ設定）をスキップ
- 設定ファイルに `**ペルソナ有効**: false` を記載

### Phase 3: ペルソナ設定（質問セット3）

> **前提条件**: Phase 2 で「ペルソナ有効化」で「はい」を選択した場合のみ実行

1. ペルソナ設定の選択（共通ペルソナ / エージェント別ペルソナ）

**選択肢ごとの動作**:

#### a) 共通ペルソナ
- 設定ファイルに `**ペルソナ有効**: [OK]` を記載
- ペルソナ情報を収集（名前、役割、一人称、語尾、口調の特徴）
- `.claude/dbz-workflow/` ディレクトリを作成
- ペルソナ設定対象エージェント全員に同じ内容のペルソナファイルを書き込む
  - 主要4エージェント（reviewer, plan-reviewer, implementer, audit-doc）
  - Phase 2で有効にした監査エージェント（audit-black-hacker, audit-white-hacker, audit-i18n 等）

#### b) エージェント別ペルソナ
- 設定ファイルに `**ペルソナ有効**: [OK]` を記載
- ペルソナ設定対象エージェントそれぞれのペルソナ情報を個別に収集
  - 主要4エージェント（reviewer, plan-reviewer, implementer, audit-doc）
  - Phase 2で有効にした監査エージェント（audit-black-hacker, audit-white-hacker, audit-i18n 等）
- `.claude/dbz-workflow/` ディレクトリを作成
- 各エージェント専用のペルソナファイルを生成

---

## 生成される設定ファイル

`.claude/dbz-workflow.config.md` に設定ファイルが生成されます。

**テンプレートの詳細は `../../agents/workflow/config-wizard.md` を参照してください。**

---

## 完了通知

設定ファイル生成後、以下の情報を表示します：

```
[OK] 設定ファイルを生成しました

【生成された設定】
- ファイルパス: .claude/dbz-workflow.config.md
- プロジェクトタイプ: {プロジェクトタイプ}
- 有効な監査エージェント: {有効なエージェント一覧}
- テストコマンド: {テストコマンド}
- E2Eコマンド: {E2Eコマンド}

次のステップ:
1. 設定ファイルを確認・編集（任意）
2. /dbz-plan または /dbz-pr でワークフローを開始
```

---

## Error Handling

### 既存設定ファイルがある場合

```
既存の設定ファイルが見つかりました。

上書きしますか？
a) はい（既存設定を破棄して新規作成）
b) いいえ（処理を中断）
```

「いいえ」を選択した場合:
```
設定ファイル生成を中断しました。

既存の設定ファイル: .claude/dbz-workflow.config.md
```

### .claude/ ディレクトリが存在しない場合

自動的にディレクトリを作成します:

```bash
mkdir -p .claude
```

作成後、設定ファイルを生成します。

### 中断時の動作

ユーザーが対話を中断した場合:
- 部分的な設定ファイルを作成しない
- 「設定ファイル生成を中断しました」とメッセージを表示

---

## References

- **設定ファイル仕様**: `../../docs/config-loader.md`
- **config-wizard エージェント**: `../../agents/workflow/config-wizard.md`
- **ワークフロー**: `/dbz-plan`, `/dbz-pr`
