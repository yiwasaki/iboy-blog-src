# Azure Machine Configuration で sample-configuration モジュールを適用する検証環境

## 概要

Ubuntu 24.04 LTS の単一 VM に対して、Azure Machine Configuration（Guest Configuration）で [`sample-configuration/`](./sample-configuration/) 配下の DSC resource `MyServiceConfig`（指定した絶対 path にファイルが存在することを保証するだけの最小サンプル）を適用する検証環境です。

このディレクトリはリソースの役割で二層に分かれています。

- **検証基盤**（`main.bicep` / `modules/` / `scripts/`）: VNet・Bastion・Storage・Guest Configuration Extension 付き VM を作る、どのモジュールにも使い回せる土台
- **デプロイ対象モジュール**（[`sample-configuration/`](./sample-configuration/)）: 実際に VM へ適用する Guest Configuration パッケージ本体。新しいモジュールを作るときはこのディレクトリをコピーして使うスケルトンでもある（詳細は [`sample-configuration/README.md`](./sample-configuration/README.md)）

## ディレクトリ構成

```
guest_configuration/
├── main.bicep / main.bicepparam       # 検証基盤（VNet, Bastion, Storage, VM）
├── modules/                           # 基盤の Bicep サブモジュール
├── assignment.bicep                   # sample-configuration/ のモジュール用 Assignment（assignmentType/packageVersion 対応）
├── scripts/                            # Storage アップロード用ユーティリティ（enable/upload/disable-package-upload-access.sh）
└── sample-configuration/              # ← デプロイするモジュール本体はここ
    ├── configuration/                    # DSC Configuration + resource module（MyServiceConfig）
    ├── scripts/
    │   ├── build-package.ps1 / .sh       # このモジュール用のパッケージビルド（既定値 MyServiceConfig）
    │   └── test-package-locally.ps1      # 使い捨て環境でのローカル audit/remediate テスト
    └── package/                          # ビルド生成物の出力先（.gitignore 済み）
```

## アーキテクチャ

```
[Resource Group]
├── VNet (10.20.0.0/16)
│   ├── vm-subnet (10.20.1.0/24) + NSG
│   │   └── Ubuntu VM (Standard_B2s, System-Assigned MI, Public IP)
│   │       └── Guest Configuration Extension (ConfigurationforLinux)
│   │           └── sample-configuration/ の MyServiceConfig パッケージを適用
│   └── pe-subnet (10.20.2.0/24)
│       └── Private Endpoint (Blob)
├── Bastion Developer SKU (無料)
├── Storage Account (publicNetworkAccess: Disabled)
│   └── Blob container (publicAccess: Blob)
└── Private DNS Zone (privatelink.blob.core.windows.net)
```

## リソース一覧

- Ubuntu VM: `Standard_B2s`（コスト最小化優先）
- VM Public IP: `Standard`（送信経路として利用、受信は NSG で拒否）
- Bastion: `Developer`（無料）
- Storage Account: `Standard_LRS`, `publicNetworkAccess: Disabled`, `minimumTlsVersion: TLS1_2`
- Blob Private Endpoint + Private DNS Zone
- Guest Configuration Assignment（`assignment.bicep` で別デプロイ）

## 前提条件

- Azure CLI（`az`）
- Bicep CLI
- Bash / WSL
- PowerShell 7（`build-package.sh`/`build-package.ps1` を使用する場合のみ）
- `GuestConfiguration` PowerShell モジュール（パッケージ生成時のみ）
- `PSDesiredStateConfiguration 3.0.0-beta1`（Linux 対象のコンパイルに必要。パッケージ生成時のみ）
- デプロイ先サブスクリプションで次が登録済み
  - `Microsoft.GuestConfiguration`
  - `Microsoft.Compute`
  - `Microsoft.Network`
  - `Microsoft.Storage`
- デプロイ実行者にロール割り当てを作成できる権限（`Owner` または `Role Based Access Control Administrator`）

## 検証済み環境

以下の環境（WSL2 上の Ubuntu-24.04）で、パッケージビルドとデプロイ手順一式の動作を確認しています。バージョンが異なる環境では、モジュールの解決先や `PSDesiredStateConfiguration` のコンパイル経路が変わる場合があります。

| 項目 | バージョン |
|---|---|
| WSL | WSL2 |
| ディストリビューション | Ubuntu 24.04.3 LTS (Noble Numbat) |
| カーネル | `5.15.167.4-microsoft-standard-WSL2` |
| PowerShell（`pwsh`） | 7.6.4 |
| `GuestConfiguration` module | 4.12.0 |
| `PSDesiredStateConfiguration` module | 3.0.0 |
| Azure CLI（`az`） | 2.88.0 |
| Bicep（`az bicep`） | 0.43.8 |


## デプロイ手順

1. リソースグループを作成します。

```bash
az group create --name rg-gc-sample --location japaneast
```

2. `main.bicepparam` の `adminPassword` と `packageUploaderPrincipalId` を更新します。ログイン中のユーザーの Microsoft Entra object ID は次のコマンドで確認できます。

```bash
az ad signed-in-user show --query id --output tsv
```

3. 基盤をデプロイします。

```bash
az deployment group create \
  --resource-group rg-gc-sample \
  --template-file main.bicep \
  --parameters main.bicepparam
```

4. 適用する内容を決め、`sample-configuration/configuration/MyServiceConfig.ps1` の `Name` / `TargetPath` を実際の値に書き換えます（既定値のままでも `/tmp/HelloWorld` の存在を保証するだけの動作確認として使えます）。

5. カスタムパッケージを作成します。初めて実行する環境では、事前に `GuestConfiguration` と `PSDesiredStateConfiguration 3.0.0`（Linux 対象向け 3.0.0-beta1 の GA 名）をインストールしておきます。未インストールのまま実行すると、`build-package.ps1` がインストール方法を示すエラーで停止します。

```bash
pwsh -NoProfile -Command 'Install-Module -Name GuestConfiguration -Scope CurrentUser -Force'
pwsh -NoProfile -Command 'Install-Module -Name PSDesiredStateConfiguration -RequiredVersion 3.0.0-beta1 -AllowPrerelease -Scope CurrentUser -Force'
```

6. パッケージをビルドします。`sample-configuration/package/` に ZIP が生成されます。

```bash
bash ./sample-configuration/scripts/build-package.sh
```

この処理は VM に設定を適用するものではありません。ビルド環境（WSL など）はパッケージ作成にのみ使われ、`PSDesiredStateConfiguration` が DSC 構成を MOF にコンパイルし、`GuestConfiguration` が MOF・DSC リソース・メタ構成を `sample-configuration/package/MyServiceConfig.zip` にまとめます。生成した ZIP を実際に評価・適用するのは、Assignment を受け取った Azure VM 上の Guest Configuration Extension です。

Linux を対象とする構成のコンパイルには `PSDesiredStateConfiguration 3.0.0-beta1` が必要です。`/etc/opt/omi/conf/dsc/configuration` を要求するエラーが出た場合でも、旧 OMI ベースの DSC for Linux を追加インストールする必要はありません。`PSDesiredStateConfiguration 3.0.0` を明示的に import して、新しいコンパイル経路を使用します。

7. Storage Account の Public endpoint を有効化し、操作者の送信元 Public IPv4 アドレスを一時許可します。

`<your-public-ip>` は、Storage Account のファイアウォールで許可する送信元 IP アドレスです。
WSL では `curl -4 https://api.ipify.org` で確認できます。

```bash
bash ./scripts/enable-package-upload-access.sh \
  -g rg-gc-sample \
  -s <storage-account-name> \
  -o <your-public-ip>
```

7. パッケージを Blob へアップロードします。Storage firewall の反映遅延を考慮し、最大 12 回、10 秒間隔で再試行します。

```bash
bash ./scripts/upload-package.sh \
  -s <storage-account-name> \
  -c machine-configuration \
  -p ./sample-configuration/package/MyServiceConfig.zip
```

8. 成否にかかわらず、操作者 IP ルールを削除して Public endpoint を無効化します。

```bash
bash ./scripts/disable-package-upload-access.sh \
  -g rg-gc-sample \
  -s <storage-account-name> \
  -o <your-public-ip>
```

> 手順 6 の実行後は Storage Account が一時的に Public endpoint 経由で到達可能になります。手順 7 が失敗した場合も、必ず手順 8 を実行してください。

9. Assignment をデプロイします。`assignment.bicep` を使用します（`assignmentType` の既定値は安全側の `Audit`。実際にファイルを作成させるには `ApplyAndMonitor` または `ApplyAndAutoCorrect` を指定してください）。

```bash
package_hash="$(sha256sum ./sample-configuration/package/MyServiceConfig.zip | awk '{print $1}')"

az deployment group create \
  --resource-group rg-gc-sample \
  --template-file assignment.bicep \
  --parameters vmName=<vm-name> \
               packageContentUri=<package-url> \
               packageContentHash="$package_hash" \
               assignmentType=Audit
```

`packageContentHash` には文字列 `sha256` ではなく、アップロードした ZIP の64文字の SHA-256 値を指定します。パッケージを再生成した場合は、Blob を上書きしてから新しいハッシュ（必要なら `packageVersion` も更新して）で Assignment を再デプロイしてください。Assignment の取得は約5分間隔、構成評価は既定で15分間隔です。

## パラメーター表

### main.bicep（検証基盤）

| パラメーター | 必須 | デフォルト | 説明 |
|---|:---:|---|---|
| `location` |  | `resourceGroup().location` | デプロイ先リージョン |
| `resourcePrefix` |  | `gcauditd` | リソース名プレフィックス |
| `adminUsername` |  | `azureuser` | VM 管理者ユーザー |
| `adminPassword` | ✅ |  | VM 管理者パスワード |
| `vmSize` |  | `Standard_B2s` | VM サイズ |
| `packageContainerName` |  | `machine-configuration` | 構成 ZIP 保管先コンテナー |
| `packageUploaderPrincipalId` | ✅ |  | Blob コンテナーに `Storage Blob Data Contributor` を付与するユーザーの Microsoft Entra object ID |

### assignment.bicep（デプロイ対象モジュールの Assignment）

| パラメーター | 必須 | デフォルト | 説明 |
|---|:---:|---|---|
| `location` |  | `resourceGroup().location` | デプロイ先リージョン |
| `vmName` | ✅ |  | 対象 VM 名 |
| `guestConfigurationName` |  | `MyServiceConfig` | Assignment 名（package の `Name` と一致させる） |
| `packageContentUri` | ✅ |  | 構成パッケージ ZIP の URI |
| `packageContentHash` | ✅ |  | 構成パッケージ ZIP の SHA-256（64文字の16進数） |
| `packageVersion` |  | `1.0.0` | パッケージの version（更新時は ZIP を差し替えて `contentUri`/`contentHash` も更新する） |
| `assignmentType` |  | `Audit` | VM 上での適用方針（`Audit` / `ApplyAndMonitor` / `ApplyAndAutoCorrect`） |

## 検証手順

1. Bicep の構文を確認します（JSON は専用一時ディレクトリへ出力し、検証後に削除）。

```bash
mkdir -p .bicep-build
az bicep build --file main.bicep --outfile .bicep-build/main.json
az bicep build --file assignment.bicep --outfile .bicep-build/assignment.json
az bicep build-params --file main.bicepparam --outfile .bicep-build/main.parameters.json
rm -rf .bicep-build
```

2. Assignment の状態を確認します（`<vm-name>` を実際の VM 名に置き換え）。Guest Configuration Assignment は VM（`Microsoft.Compute`）とは別のプロバイダー名前空間（`Microsoft.GuestConfiguration`）にまたがる拡張リソースのため、`az resource show --resource-type ... --name ...` では正しい ID を組み立てられず `Not Found` になります。VM のリソース ID を取得してから配下のパスを組み立てて `--ids` で指定してください。

```bash
vm_id="$(az vm show -g rg-gc-sample -n <vm-name> --query id -o tsv)"

az resource show \
  --ids "${vm_id}/providers/Microsoft.GuestConfiguration/guestConfigurationAssignments/MyServiceConfig" \
  --query '{provisioningState:properties.provisioningState, complianceStatus:properties.complianceStatus}'
```

3. Bastion から VM に入り、管理者パスワードで SSH 接続し、`TargetPath` に指定したファイルが存在することを確認します（既定値のまま構成した場合）。

```bash
ls -l /tmp/HelloWorld
```

`assignmentType=Audit` の場合、ファイルは自動作成されません（準拠状況の報告のみ）。実際に作成させたい場合は Assignment を `ApplyAndMonitor` または `ApplyAndAutoCorrect` で再デプロイしてください。

4. 使い捨て環境（VM など）でパッケージ単体を audit → remediate → audit で確認したい場合は、ビルド環境上で次を実行します。

```bash
sudo pwsh ./sample-configuration/scripts/test-package-locally.ps1 \
  -PackagePath ./sample-configuration/package/MyServiceConfig.zip
```

## コスト備考

- NAT Gateway を使わず、VM の `Standard Public IP` を送信経路として利用し固定費を削減しています。
- Bastion は Developer SKU を利用します（無料）。
- 長時間放置を避けるため、検証後は必ずクリーンアップしてください。

## トラブルシューティング

- `GuestConfiguration` モジュールが見つからない
  - WSL の PowerShell に必要なモジュールをインストールします。

    ```bash
    pwsh -NoProfile -Command 'Install-Module -Name GuestConfiguration -Scope CurrentUser -Force'
    pwsh -NoProfile -Command 'Install-Module -Name PSDesiredStateConfiguration -RequiredVersion 3.0.0-beta1 -AllowPrerelease -Scope CurrentUser -Force'
    pwsh -NoProfile -Command 'Get-Module -ListAvailable -Name GuestConfiguration,PSDesiredStateConfiguration | Select-Object Name,Version,ModuleBase'
    ```

  - Windows 側の PowerShell にインストール済みでも、WSL の `/usr/bin/pwsh` からは参照されません。WSL 側で上記コマンドを実行してください。
- Guest Assignment が `NonCompliant` のまま
  - VM 上で `/var/lib/GuestConfig/gc_agent_logs/gc_agent.log` と Assignment report の `reasons` を確認し、パッケージ取得または DSC 実行のエラーを確認します（`MyServiceConfig.psm1` の `Get()` が返す `Reasons` に、`InvalidTargetPath` / `FileMissing` / `Compliant` などのコードが積まれます）
- Blob アップロードに失敗
  - `az storage account show -g <rg> -n <storage-account-name> --query '{publicNetworkAccess:publicNetworkAccess,ipRules:networkRuleSet.ipRules}'` で許可状態を確認
  - 操作者に対象コンテナーへの `Storage Blob Data Contributor` 権限があることを確認
  - 失敗後も `disable-package-upload-access.sh` を実行して Public endpoint と IP ルールを閉鎖
- SSH 接続に失敗
  - Bastion から管理者ユーザー名とパスワードで接続し、VM 側で `sudo cat /etc/ssh/sshd_config | grep PasswordAuthentication` を確認

## クリーンアップ

```bash
az group delete --name rg-gc-sample --yes --no-wait
```
