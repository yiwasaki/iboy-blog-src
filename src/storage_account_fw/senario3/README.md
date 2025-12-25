# シナリオ3: ストレージアカウントとペアリージョン内からサービスエンドポイント経由でのアクセス

## 概要

このシナリオでは、Azure Storage Account のファイアウォール設定によるアクセス制限を検証するための環境を構築します。まず、Bicep テンプレートを使用してリソースをデプロイし、ファイアウォールによりアクセスがブロックされることを確認します。その後、スクリプトを実行して VM の IP アドレスを許可リストに追加し、アクセスが復旧することを検証します。

## デプロイされるリソース

- Windows Server 2022 VM (jw-win2022-01)
- Public IP Address
- Network Interface
- Storage Account  - ファイアウォール有効
- Storage Account  - 診断設定用
- 診断設定 (Blob/File サービスのログを診断設定用のストレージアカウントに送信)

## 前提条件

- Azure CLI がインストールされていること
- Azure にログイン済み (`az login`) であること
- リソースグループ "storage-test" が存在すること
- 全体のネットワークを構築するための 本プロジェクトのルートフォルダ内の main.bicep でネットワークに関連するリソースを作成済みであること
- VM の管理者パスワードを準備

## 手順
### 1. Bicep テンプレートのデプロイ

まず、以下のコマンドで Bicep テンプレートをデプロイします。
コマンドを実行すると、VM の管理者パスワード、テスト用のストレージアカウント名、テスト時にストレージアカウントの診断データを保存するためのストレージアカウント名を入力するプロンプトが出ますので、それぞれ値を指定してください。
パスワードはセキュア パラメータとなっているため、入力してもプロンプトの画面上には何も表示されませんが、正しく設定は可能です。


```bash
SOURCE_IP=$(curl -s ipinfo.io/ip)
az deployment group create \
  --resource-group storage-test \
  --template-file senario3.bicep \
  --parameters sourceRdpIp=$SOURCE_IP
```

デプロイが完了すると、VM が作成され、Storage Account のファイアウォールが有効になります。

`storage-update.sh` スクリプトを実行して、VM の Public IP を Storage Account の許可リストに追加します。

```bash
chmod +x storage-update.sh
./storage-update.sh
```

このスクリプトは以下の処理を行います：
- senario2.bicep にてデプロイされた VM の Public IP アドレスを取得
- Subnet に Storage サービスエンドポイントを追加
- Storage Account のネットワークルールに VM の Public IP を追加


### 2. エラーの確認

VM に RDP 接続し、Storage Account へのアクセスを試みてください。ファイアウォールによりアクセスが拒否されることを確認します。

### 3. スクリプトの実行
`resolve-problem.sh` スクリプトを実行して、VM の 紐づいた**サブネット**を Storage Account の許可リストに追加します。

```bash
chmod +x resolve-problem.sh
./resolve-problem.sh
```

### 4. エラーの解消確認

再度 VM から Storage Account へのアクセスを試み、エラーが解消されていることを確認してください。

## 注意事項

- このシナリオは検証目的のみで使用してください
- デプロイされたリソースは検証後に削除することを推奨します
- パスワードは強力なものを指定してください
