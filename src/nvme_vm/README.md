# NVMe 検証用 Windows/Linux VM (Bicep)

NVMe ディスクコントローラ対応の VM を検証するための Windows/Linux VM を作成する Bicep テンプレートです。既定の `vmSize` は NVMe 非対応サイズのため、検証対象に合わせて変更してください。

## 何が作成されるか
- VNet + VM サブネット
- Windows Server 2025 Datacenter (Gen2) の VM
- NIC (プライベート IP)
- Azure Bastion (Developer Tier)

## 前提条件
- Azure CLI (`az`) と Bicep
- 対象サブスクリプションでのリソース作成権限
- 管理者ユーザー名/パスワードを準備

## 使い方

### 1) リソース グループ作成
```bash
az group create -n <rg-name> -l <location>
```

### 2) デプロイ
```bash
az deployment group create \
  -g <rg-name> \
  -f ./windows.bicep \
  -p adminUsername=<admin-user> adminPassword=<admin-password> \
  -p vmSize=<vm-size>
```
もし、Linux OSでのVMが必要な場合は、`windows.bicep` の代わりに `linux.bicep` を使用してください。

## パラメーター
- `location` (string, 省略可): デプロイ先リージョン。既定はリソース グループのリージョン。
- `adminUsername` (string, 必須): VM 管理者ユーザー名。
- `adminPassword` (secure string, 必須): VM 管理者パスワード。
- `vmSize` (string, 省略可): VM サイズ。既定は `Standard_D2s_v4` (NVMe 非対応)、NVMe対応サイズには、例えば、Standard_D2as_v7を利用します。
- `vnetAddressPrefix` (string, 省略可): VNet アドレス空間。既定は `10.10.0.0/16`。
- `vmSubnetAddressPrefix` (string, 省略可): VM サブネット アドレス空間。既定は `10.10.1.0/24`。

## 出力
- `vmId`: 作成された VM のリソース ID
- `vmPrivateIp`: VM のプライベート IP
- `bastionId`: Bastion のリソース ID
- `vnetId`: VNet のリソース ID

### 3) ディスクコントローラの更新
[Azure NVMe Utilities](https://github.com/Azure/SAP-on-Azure-Scripts-and-Utilities/tree/main/Azure-NVMe-Utils) に記載の手順に沿って、NVMe ディスクコントローラへの対応、およびサイズの変更を実施してください。

なお、ブログ: [NVMe ディスクコントローラーを利用したAzure VMサイズへのサイズ変更は多くの制限がある](https://qiita.com/iboy/items/12f8cd96036c4ef755ad) にまとめられています通り、Windows OSに関しては、こちらの方法では、ディスクコントローラ変更後に、OSのブート構成が正しくない状況となり、VMのブートに失敗しますので、ご注意ください。

## 補足
- 本テンプレートを利用して作成された VM は検証用となっていますので、本番環境での利用は推奨されません。
- 本テンプレートを利用することで発生したいかなる損害についても、作者は責任を負いかねます。