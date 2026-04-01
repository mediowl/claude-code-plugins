# Issue情報の活用ガイド

## 基本ルール

- Issue本文とコメントの**両方を全て読んでから**作業を開始すること
- Issueの範囲内で作業を行う（スコープ厳守）
- Issue情報がない場合は呼び出し元に確認を求める

**取得コマンド**: `gh issue view <issue_number> --json title,body,comments`（コメント取得には `--json` が必須）

---

## GitHub画像の自動取得（必須）

画像URL（`user-images.githubusercontent.com`, `github.com/user-attachments/assets/`, `private-user-images.githubusercontent.com`）が含まれている場合:

```bash
curl -f -H "Authorization: token $(gh auth token)" -L "<画像URL>" -o /tmp/gh-image-issue-<issue_number>-1.png
```

ダウンロード後は `Read` で確認。失敗時は画像なしで継続。エージェント呼び出し時はプロンプトに画像パスを含める。
