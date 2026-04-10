# Storage Account NSP (Network Security Perimeter) 検証環境

Storage Account に対する Network Security Perimeter (NSP) の動作を検証する環境です。

## アーキテクチャ

```
[Resource Group]
├── [プライマリリージョン]
│   ├── VNet (10.0.0.0/16) + Subnet (snet-vm, 10.0.0.0/24) + NSG
│   │   └── NSG Rules: Allow-RDP-from-Bastion (100) / Deny-RDP-from-Internet (200)
│   ├── VM: nsp-lab-vm (Standard_B2s, Windows Server 2022, System-Assigned MI)
│   │   └── 自動シャットダウン 22:00 JST
│   └── Bastion Developer SKU (無料, AzureBastionSubnet 不要)
│
├── [ペアリージョン]
│   ├── VNet (10.1.0.0/16) + Subnet (snet-vm, 10.1.0.0/24) + NSG
│   │   └── NSG Rules: Allow-RDP-from-Bastion (100) / Deny-RDP-from-Internet (200)
│   └── VM: nsp-lab-pair-vm (Standard_B2s, Windows Server 2022, System-Assigned MI)
│       └── 自動シャットダウン 22:00 JST
│
├── VNet ピアリング (双方向: プライマリ ↔ ペアリージョン)
│
├── Storage Account (テスト用, Standard_LRS, System-Assigned MI)
│   ├── Blob Container: nsp-test
│   └── Diagnostic Settings → 診断用 Storage Account
├── Storage Account (診断用, Standard_LRS)
│
└── Network Security Perimeter
    ├── Profile: default-profile
    │   └── Access Rule: allow-subscription (Inbound, サブスクリプションベース)
    └── Association → テスト用 Storage Account (mode: Learning/Transition)
```

## デプロイ手順

### 1. リソースグループ作成

```bash
az group create --name rg-storage-nsp --location japaneast
```

### 2. パラメータファイルを編集

`main.bicepparam` を開き、必須パラメータを環境に合わせて更新してください。

| パラメータ | 説明 |
|-----------|------|
| `storageAccountTestName` | テスト用 Storage Account 名（グローバル一意） |
| `storageAccountDiagName` | 診断用 Storage Account 名（グローバル一意） |
| `adminPassword` | VM 管理者パスワード（12 文字以上） |
| `pairLocation` | ペアリージョン（例: `japanwest`） |

### 3. デプロイ実行

```bash
az deployment group create \
  --name nsp-lab-deployment \
  --resource-group rg-storage-nsp \
  --template-file main.bicep \
  --parameters main.bicepparam
```

### 4. デプロイ確認 (What-If)

```bash
az deployment group what-if \
  --resource-group rg-storage-nsp \
  --template-file main.bicep \
  --parameters main.bicepparam
```

## 検証シナリオ

### シナリオ 1: Transition モード（初期状態）でアクセス確認

1. Azure Portal → Bastion → VM にログイン
2. VM 内で PowerShell を起動
3. Az モジュールをインストール・ログイン

```powershell
Install-Module -Name Az -Scope CurrentUser -Force
Connect-AzAccount
```

4. テストスクリプトを実行

```powershell
.\scripts\test-access.ps1 -StorageAccountName "iboysansp01"
```

**期待結果**: 全テスト PASS（Transition モードでは既存ルール + NSP ルールの両方で評価）

### シナリオ 2: Enforced モードでアクセス拒否確認

1. NSP Association を Enforced に切替

```bash
./scripts/switch-nsp-mode.sh \
  -g rg-storage-nsp \
  -n nsp-lab-nsp \
  -p nsp-lab \
  -m Enforced
```

2. **Access Rule を削除** してから VM 内でテストスクリプトを再実行

**期待結果**: Blob 操作が 403 AuthorizationFailure で失敗

### シナリオ 3: Subscription ベース Inbound Rule でアクセス復旧

デプロイ時に `allow-subscription` ルールが含まれているため、Enforced モードでも同一サブスクリプションからのアクセスは許可されます。

1. テストスクリプトを実行

```powershell
.\scripts\test-access.ps1 -StorageAccountName "iboysansp01"
```

**期待結果**: 全テスト PASS（サブスクリプションルールによりアクセス許可）

### シナリオ 4: Transition モードに戻す

```bash
./scripts/switch-nsp-mode.sh \
  -g rg-storage-nsp \
  -n nsp-lab-nsp \
  -p nsp-lab \
  -m Transition
```

## コスト概算

| リソース | SKU | 月額概算 |
|---------|-----|---------|
| VM プライマリ (Standard_B2s) | Burstable 2vCPU/4GB | ~$30 |
| VM ペアリージョン (Standard_B2s) | Burstable 2vCPU/4GB | ~$30 |
| Bastion Developer | Developer (無料) | $0 |
| Storage Account ×2 | Standard_LRS | ~$1 |
| NSP | - | $0 |
| OS Disk プライマリ (128GB) | Standard_LRS | ~$5 |
| OS Disk ペアリージョン (128GB) | Standard_LRS | ~$5 |
| **合計** | | **~$71/月** |

※ 自動シャットダウン (22:00 JST) 設定済み。VM 停止中は Compute 課金なし。

## 注意事項

- **NSP の accessMode**: Bicep API 上の値は `Learning` ですが、ドキュメントでは "Transition mode (formerly Learning mode)" と記載されています
- **Service Endpoint 非対応**: NSP で保護された Storage Account では Service Endpoint トラフィックが拒否されます。IaaS→PaaS 通信には Private Endpoint を推奨
- **Enforced モードと Trusted Service**: Enforced モードでは Azure Trusted Service の例外も無効化されます
- **Storage Account 名**: グローバル一意が必要です。コマンド実行時に指定してください。

## クリーンアップ

```bash
az group delete --name rg-storage-nsp --yes --no-wait
```
