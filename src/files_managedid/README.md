# Azure Files マネージドID SMB アクセス 検証環境

このテンプレートは、Azure Files のマネージドIDによる SMB ファイル共有へのアクセスを検証するための環境をデプロイします。

## 機能概要

Azure Files では、プレビュー機能として、マネージドID を使用した SMB ファイル共有へのアクセスがサポートされています。この機能により、VM のシステムアサインドマネージドID を使用して、パスワードやキーを使用せずに Azure Files にアクセスできます。

## デプロイされるリソース

このテンプレートは、以下のリソースをデプロイします：

### ストレージアカウント
- **リージョン**: Japan East
- **冗長性**: ローカル冗長ストレージ (LRS)
- **SMBOAuth**: 有効
- **ファイル共有**: 1つ（TransactionOptimized、100GB）

### 仮想マシン
- **OS**: Windows Server 2022 Datacenter Azure Edition
- **VM サイズ**: Standard_D4s_v6 (vCPU: 4, メモリ: 16GB)
- **ディスク**: Standard SSD
- **マネージドID**: システムアサインド マネージドID 有効

### ネットワーク
- **仮想ネットワーク**: 10.0.0.0/16
  - VM サブネット: 10.0.1.0/24
- **Bastion**: Developer SKU（仮想ネットワーク参照のみで動作し、BastionSubnet は作成されません）

### RBAC
- VM のマネージドID に **Storage File Data SMB MI Admin** ロールを付与
  - 対象ストレージアカウントの Azure Files (SMB) に対する管理権限（ファイル共有およびデータの作成・更新・削除など）

## デプロイ方法

### 前提条件
- Azure CLI
- 適切な権限を持つ Azure サブスクリプション

### Azure CLI を使用したデプロイ

```bash
# リソースグループの作成
az group create \
  --name rg-files-managedid-test \
  --location japaneast

# 共通リソース (ストレージアカウントなど) のデプロイ (main.bicep)
az deployment group create \
  --resource-group rg-files-managedid-test \
  --template-file main.bicep

# VM のデプロイ (vm.bicep)
az deployment group create \
  --resource-group rg-files-managedid-test \
  --template-file vm.bicep \
  --parameters adminPassword='<強力なパスワード>' \
               storageAccountName='<main.bicep の出力 storageAccountName>'
```

## 検証手順

デプロイ完了後、以下の手順でマネージドID を使用した Azure Files へのアクセスを検証できます。

### 1. VM への接続

Azure Portal から Bastion を使用して VM に接続します。

### 2. PowerShell でファイル共有をマウント

VM 上で以下のPowerShell コマンドを実行して、マネージドID の資格情報を更新します。

```powershell
# ストレージアカウント名を設定
$storageAccountName = "<デプロイ時の出力から取得>"

# Azure Files SMB マネージドIDクライアント PowerShell モジュールのインストール
Install-Module AzFilesSmbMIClient 
Import-Module AzFilesSmbMIClient 
# PowerShell 実行ポリシーの変更
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
# マネージドID の資格情報を更新
AzFilesSmbMIClient.exe refresh --uri https://$storageAccountName.file.core.windows.net/
```

>TIPS: `AzFilesSmbMIClient.exe` の引数として refresh を指定しています。この場合、プロセスが動き続けて、一定期間(1日) 毎に、自動で資格情報が更新されるようになります。
>一度だけ検証用に使いたい場合は set の引数を指定すると、手動で更新可能です。ただし、この場合は、資格情報の有効期限が切れるとアクセスできなくなることが想定されるため、注意が必要です。

その後、ストレージアカウントのマウントに関しては、VM 上で以下の PowerShell コマンドを実行します：

```powershell
# ストレージアカウント名とファイル共有名を設定
$storageAccountName = "<デプロイ時の出力から取得>"
$fileShareName = "share01"

# マネージドID を使用してファイル共有をマウント
$connectTestResult = Test-NetConnection -ComputerName "$storageAccountName.file.core.windows.net" -Port 445
if ($connectTestResult.TcpTestSucceeded) {
    # ドライブをマウント（マネージドIDを使用）
    New-PSDrive -Name Z -PSProvider FileSystem -Root "\\$storageAccountName.file.core.windows.net\$fileShareName" -Persist
    
    Write-Host "ファイル共有が正常にマウントされました: Z:\"
} else {
    Write-Error "ポート 445 への接続に失敗しました"
}
```

### 3. アクセスの確認

```powershell
# ファイルの作成テスト
Set-Content -Path "Z:\test.txt" -Value "マネージドID経由でのアクセステスト"

# ファイルの読み取りテスト
Get-Content -Path "Z:\test.txt"

# ディレクトリ一覧の表示
Get-ChildItem -Path "Z:\"
```

## 参考情報

- [マネージド ID を使用した認証ベースの Azure ファイル共有へのアクセス](https://learn.microsoft.com/ja-jp/azure/storage/files/files-managed-identities?tabs=windows)
- [Azure Files の SMB セキュリティ設定](https://learn.microsoft.com/ja-jp/azure/storage/files/files-smb-protocol)
- [Azure Bastion Developer SKU](https://learn.microsoft.com/ja-jp/azure/bastion/quickstart-developer-sku)

## クリーンアップ

検証完了後、リソースグループごと削除することで、すべてのリソースを削除できます。

```bash
# Azure CLI
az group delete --name rg-files-managedid-test --yes --no-wait
```


## ライセンス

MIT License
