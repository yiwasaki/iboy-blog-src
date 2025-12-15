# Azure Virtual Networks Validation Environment

ネットワーク検証用環境を構築するための Azure Bicep テンプレートです。複数リージョンにおいて、3 つの Virtual Networks と各サブネットを作成します。

## 概要

このテンプレートは以下の 3 つの Virtual Networks を、それぞれ異なるリージョンにデプロイします：

### VNet1: 東日本 (Japan East)
- **VNet 名**: `je-vnet`
- **アドレス空間**: `172.30.0.0/23`
- **サブネット**:
  - `test`: `172.30.0.0/24` - テスト用サブネット
  - `AzureFirewallSubnet`: `172.30.1.0/24` - Azure Firewall 用専用サブネット

### VNet2: 西日本 (Japan West)
- **VNet 名**: `jw-vnet`
- **アドレス空間**: `172.30.10.0/24`
- **サブネット**:
  - `test-west`: `172.30.10.0/25` - テスト用サブネット

### VNet3: 東南アジア (Southeast Asia)
- **VNet 名**: `sea-vnet`
- **アドレス空間**: `172.30.20.0/24`
- **サブネット**:
  - `test-west`: `172.30.20.0/25` - テスト用サブネット

## ファイル構成

```
.
├── vnet.bicep           # Bicep テンプレートファイル
├── vnet.bicepparam      # Bicep パラメータファイル
└── README.md            # このファイル
```

## 前提条件

- Azure CLI がインストールされている
- Azure サブスクリプションへのアクセス権限
- Azure CLI でのログイン完了

### Azure CLI インストール確認

```bash
az --version
```

### Azure へのログイン

```bash
az login
```

サブスクリプションを指定する場合：

```bash
az account set --subscription <subscription-id>
```

## デプロイ方法

### 1. パラメータファイルを使用したデプロイ（推奨）

```bash
az deployment group create \
  --name vnet-deployment \
  --resource-group test \
  --template-file src/storage_account_fw/vnet.bicep \
  --parameters src/storage_account_fw/vnet.bicepparam
```

### 2. コマンドラインでパラメータを指定してデプロイ

```bash
az deployment group create \
  --name vnet-deployment \
  --resource-group test \
  --template-file src/storage_account_fw/vnet.bicep \
  --parameters \
    vnetEastJapanName=je-vnet \
    vnetWestJapanName=jw-vnet \
    vnetSoutheastAsiaName=sea-vnet
```

### 3. デプロイ前に検証する

実際にデプロイする前にテンプレートを検証します：

```bash
az deployment group validate \
  --resource-group test \
  --template-file src/storage_account_fw/vnet.bicep \
  --parameters src/storage_account_fw/vnet.bicepparam
```

検証が成功すると、以下のようなメッセージが表示されます：

```
{
  "error": null,
  "properties": {
    ...
  }
}
```

## デプロイ後の確認

### デプロイの状態を確認

```bash
az deployment group show \
  --name vnet-deployment \
  --resource-group test
```

### デプロイの出力値を表示

```bash
az deployment group show \
  --name vnet-deployment \
  --resource-group test \
  --query properties.outputs
```

出力例：

```json
{
  "vnetEastJapanId": {
    "type": "String",
    "value": "/subscriptions/xxx/resourceGroups/test/providers/Microsoft.Network/virtualNetworks/je-vnet"
  },
  "vnetEastJapanName": {
    "type": "String",
    "value": "je-vnet"
  },
  ...
}
```

### 作成された VNet をリスト表示

```bash
az network vnet list --resource-group test --output table
```

### VNet の詳細情報を確認

```bash
az network vnet show \
  --resource-group test \
  --name je-vnet
```

## カスタマイズ

### VNet 名を変更する

`vnet.bicepparam` ファイルを編集して、VNet の名前をカスタマイズできます：

```bicepparam
param vnetEastJapanName = 'my-je-vnet'
param vnetWestJapanName = 'my-jw-vnet'
param vnetSoutheastAsiaName = 'my-sea-vnet'
```

### タグを追加する

`vnet.bicepparam` ファイルでタグをカスタマイズできます：

```bicepparam
param tags = {
  environment: 'production'
  purpose: 'network-testing'
  owner: 'network-team'
  costCenter: 'engineering'
}
```

### ロケーション（リージョン）を変更する

コマンドラインでロケーションを指定してカスタマイズ：

```bash
az deployment group create \
  --name vnet-deployment \
  --resource-group test \
  --template-file src/storage_account_fw/vnet.bicep \
  --parameters \
    locationEastJapan=eastasia \
    locationWestJapan=japanwest \
    locationSoutheastAsia=southeastasia
```

## トラブルシューティング

### リソースグループが存在しない

```bash
az group create --name test --location japaneast
```

### パラメータエラー

テンプレートを検証して詳細なエラーメッセージを確認：

```bash
az deployment group validate \
  --resource-group test \
  --template-file src/storage_account_fw/vnet.bicep \
  --parameters src/storage_account_fw/vnet.bicepparam
```

### デプロイのロールバック

デプロイが失敗した場合、作成されたリソースを削除：

```bash
az resource delete \
  --resource-group test \
  --name je-vnet \
  --resource-type Microsoft.Network/virtualNetworks
```

## 関連リソース

- [Azure Virtual Networks の概要](https://learn.microsoft.com/ja-jp/azure/virtual-network/virtual-networks-overview)
- [Bicep リファレンス](https://learn.microsoft.com/ja-jp/azure/azure-resource-manager/bicep/reference)
- [Azure CLI ドキュメント](https://learn.microsoft.com/ja-jp/cli/azure/)
