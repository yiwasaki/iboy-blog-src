# VM vCore Customization Feature 検証環境

> **⚠️ 注意**: VM vCore Customization Feature (Configurable Constrained Cores / SMT 無効化) は現在 **Preview** 機能です。本番環境への適用前に最新の GA 状況を確認してください。

## 概要

本環境は、Azure の **VM vCore Customization Feature** を検証するための Bicep テンプレートです。

| 機能 | 内容 |
|------|------|
| **Configurable Constrained Cores (CCC)** | VM の vCPU 数を任意の値に制限（ライセンスコスト最適化） |
| **SMT 無効化** | ハイパースレッディング(SMT/HT)を無効化（レイテンシ敏感なワークロード向け） |

**検証シナリオ**:
- Bicep で vCore 制約付き VM をデプロイ（2 vCPU、SMT 無効）
- デプロイ後の vCore 設定変更は `az vm update` で実施

---


## ファイル構成

```
vcore-lab/
├── infra/
│   ├── main.bicep                    # メインテンプレート
│   ├── main.bicepparam               # パラメータ（vCore 制約付き）
│   └── modules/
│       ├── network.bicep             # VNet / Subnet / NSG
│       ├── vm.bicep                  # Windows VM（vCore 制御）
│       └── bastion.bicep             # Bastion Developer SKU
└── README.md
```

---

## 前提条件

### 環境要件
動作検証は、以下の環境で実施いたしました。
| 要件 | 説明 |
|------|------|
| Azure CLI | v2.50.0 以上 (`az --version`) |
| Bicep CLI | v0.20.0 以上 (`az bicep version`) |

### リージョン要件

CCC (Configurable Constrained Cores) は Preview 機能のため、対応リージョンが限定されています。
デプロイ前に以下のコマンドで確認してください。

```bash
# Japan East で Standard_D8as_v6 の CCC 対応確認
az vm list-skus \
  --location japaneast \
  --resource-type virtualMachines \
  --query "[?name=='Standard_D8as_v6'].{Name:name, Restrictions:restrictions}" \
  --output table
```

> Bastion Developer の対応リージョン: Japan East は対応済み ✅

---

## デプロイ手順

### 1. リソースグループの作成

```bash
az group create \
  --name rg-vcore-lab \
  --location japaneast
```

### 2. デプロイ（vCore 制約付き VM）

```bash
# パスワードは対話入力（@secure() パラメータのため自動でプロンプトが表示されます）
az deployment group create \
  --resource-group rg-vcore-lab \
  --template-file infra/main.bicep \

```

**デプロイ後の状態**:
- VM: 2 vCPU、SMT 無効（物理コア 2 つのみ使用）
- `vmSizeProperties`: `{ vCPUsAvailable: 2, vCPUsPerCore: 1 }`

---

## vCore 設定の変更（az vm update）

> ⚠️ vCore 設定の変更は**VM の割当解除（Deallocate）が必要**です。
> 稼働中の VM の vCore 数をリアルタイムで変更することはできません。

### vCore 制約を解除する（デフォルトに戻す）

```bash
# 1. VM を割当解除
az vm deallocate --resource-group rg-vcore-lab --name vcore-lab-vm

# 2. vCore 制約を解除
az vm update --resource-group rg-vcore-lab --name vcore-lab-vm \
  --set hardwareProfile.vmSizeProperties=null

# 3. VM を起動
az vm start --resource-group rg-vcore-lab --name vcore-lab-vm
```

### vCore 制約を再適用する

```bash
# 1. VM を割当解除
az vm deallocate --resource-group rg-vcore-lab --name vcore-lab-vm

# 2. vCore 制約を設定（例: 2 vCPU, SMT 無効）
az vm update --resource-group rg-vcore-lab --name vcore-lab-vm \
  --v-cpus-available 2 --v-cpus-per-core 1

# 3. VM を起動
az vm start --resource-group rg-vcore-lab --name vcore-lab-vm
```

### 切り替え前後の比較

| 設定 | vCPUsAvailable | vCPUsPerCore | OS 上の論理 CPU 数 |
|------|:-:|:-:|:-:|
| 制約あり（初期デプロイ） | 2 | 1 (SMT 無効) | **2** |
| 制約解除後 | — (null) | — (null) | **8** |

---

## VM への接続方法（Bastion Developer）

1. [Azure ポータル](https://portal.azure.com) にアクセス
2. 対象 VM (`vcore-lab-vm`) を開く
3. 左メニューの **接続** → **Bastion** を選択
4. 認証タイプ・ユーザー名・パスワードを入力
5. **接続** をクリック → ブラウザ内で RDP セッションが開始

> 💡 Bastion Developer SKU は自動的に VNet にデプロイされます（初回接続時）。
> 専用の `AzureBastionSubnet` や パブリック IP は不要です。

---

## 検証方法

VM に接続後、以下のコマンドで vCore 設定を確認できます。

### Windows（PowerShell）

```powershell
# 論理プロセッサ数とコア数を確認
wmic cpu get NumberOfCores,NumberOfLogicalProcessors

# 詳細情報
Get-WmiObject -Class Win32_Processor | 
    Select-Object Name, NumberOfCores, NumberOfLogicalProcessors, ThreadCount
```

### 期待される出力

| 設定 | NumberOfCores | NumberOfLogicalProcessors |
|------|:---:|:---:|
| 制限なし（4 vCPU） | 2 | 4 |
| 制限あり（2 vCPU, SMT 無効） | 2 | 2 |

---

## vCore Customization Feature のパラメータ詳細

| パラメータ | 型 | デフォルト | 説明 |
|-----------|-----|-----------|------|
| `vcpusAvailable` | int | `2` | アクティブな vCPU 数 |
| `vcpusPerCore` | int | `1` | スレッド/コア数（1=SMT無効, 2=デフォルト） |

### ARM テンプレートでの表現

```json
"hardwareProfile": {
  "vmSize": "Standard_D4s_v5",
  "vmSizeProperties": {
    "vCPUsAvailable": 2,
    "vCPUsPerCore": 1
  }
}
```

> 📌 API バージョン `2021-07-01` 以降が必要

---

## クリーンアップ

```bash
# リソースグループごと削除（全リソース削除）
az group delete --name rg-vcore-lab --yes --no-wait
```

---

## 参考ドキュメント

- [VM vCore Customization Feature (Preview)](https://learn.microsoft.com/azure/virtual-machines/vm-customization)
- [VM vCore customization for SQL Server on Azure VMs](https://learn.microsoft.com/azure/azure-sql/virtual-machines/windows/vm-vcore-customization-for-sql)
- [Azure Bastion Developer SKU](https://learn.microsoft.com/azure/bastion/quickstart-developer-sku)
- [Azure Bastion SKU 比較](https://learn.microsoft.com/azure/bastion/bastion-sku-comparison)
- [Standard_D4s_v5 サイズ仕様](https://learn.microsoft.com/azure/virtual-machines/dv5-dsv5-series)
