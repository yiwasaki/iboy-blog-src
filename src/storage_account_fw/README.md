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
  - `test-sea`: `172.30.20.0/25` - テスト用サブネット

## ファイル構成

```
.
├── vnet.bicep           # Bicep テンプレートファイル
├── vnet.bicepparam      # Bicep パラメータファイル
└── README.md            # このファイル
```

## テスト環境
このスクリプトの動作は、実際のスクリプトを使ってデプロイして試しています。
動作検証をした環境は以下の通りです。

- OS: Windows 11 上の WSL2 にて稼働する Ubuntu 24.04
- Azure CLI: 2.81.0

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
### 1. リソースグループをデプロイ
```bash
az group create --name <ResourceGroupName> --location <Location>
```

### 2. パラメータファイルを使用したデプロイ

```bash
az deployment group create \
  --name vnet-deployment \
  --resource-group test \
  --template-file main.bicep \
  --parameters main.bicepparam
```

もし、コマンドラインでパラメータを指定してデプロイしたい場合は、以下のようにパラメータを指定できます。

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




## 関連リソース

- [Azure Virtual Networks の概要](https://learn.microsoft.com/ja-jp/azure/virtual-network/virtual-networks-overview)
- [Bicep リファレンス](https://learn.microsoft.com/ja-jp/azure/azure-resource-manager/bicep/reference)
- [Azure CLI ドキュメント](https://learn.microsoft.com/ja-jp/cli/azure/)
