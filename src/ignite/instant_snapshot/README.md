# getstatus.sh

## 概要

`getstatus.sh` は Azure CLI を使って指定したスナップショットの状態を定期的に確認し、状態が `Pending` でなくなったら終了する簡易監視スクリプトです。

本スクリプトは、記事 [MS Ignite 2025 で発表された Instant Access Snapshot for Azure managed Disk について確認してみる](https://qiita.com/iboy/items/6c2dd788d2701fc14f07) の中で、Instant Access Snapshot が無い環境で、スナップショットからディスク作成が開始できるようになるまでの時間を調査するために以下のブログ記事で使用されました。 

## 前提

- `az` (Azure CLI) がインストールされ、ログインされていること（`az login`）。
- スクリプト内の `SNAP_ID` を監視対象のスナップショットのリソース ID に設定すること。

## 使い方

1. ファイルの実行権限を付与して実行します。

```bash
chmod +x getstatus.sh
./getstatus.sh
```

2. 必要に応じてスクリプト内の `INTERVAL`（ポーリング間隔、秒）や `SNAP_ID` を変更してください。

## スクリプトの動作（要点）

- `set -euo pipefail` によりエラー発生時は即終了します。
- `INTERVAL`（デフォルト 10 秒）ごとにループして、`az resource show --ids "$SNAP_ID" --query "properties.snapshotAccessState" -o tsv` でスナップショットの `snapshotAccessState` を取得します。
- 取得した状態はタイムスタンプとともに標準出力へ出力されます。
- 状態が `Pending` でなくなった場合、`Snapshot state is <state>; exiting.` と表示してループを抜け、スクリプトを終了します。

## 例（出力イメージ）

```
Fri Dec  9 12:00:00 UTC 2025
Pending
Fri Dec  9 12:00:10 UTC 2025
Complete
Snapshot state is Complete; exiting.
```

## 注意点

- `SNAP_ID` はサブスクリプション／リソースグループ／スナップショット名を含むフルリソース ID である必要があります。
- polling 間隔を短くしすぎると API レートに影響する可能性があるため注意してください.
