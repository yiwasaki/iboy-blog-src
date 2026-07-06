# AVD 外部 ID (Entra B2B) + FSLogix on Azure Files 検証環境

## 概要

[`src/avd_external_identity/`](../avd_external_identity/README.md) (FSLogix なし) をベースに、**FSLogix プロファイル コンテナーを Azure Files (GPv2 / Entra Kerberos) に配置** する構成へ拡張した検証環境です。外部 ID (Entra B2B ゲスト) ユーザーがサインオン時に FSLogix プロファイルをマウントできることを確認することを目的とします。

検証コストを最小化するため、以下を採用しています。

- Storage Account: **StorageV2 (GPv2) + Standard_LRS** (Premium FileStorage は固定課金が発生するため不採用)
- セッション ホスト VM: **Standard_B4ms** (バースト可能、停止時はコンピュート無料)
- ホストプール: **Pooled / maxSessionLimit = 1** (シングルセッション)

> **注意**: 外部 ID + FSLogix の組み合わせは記事執筆時点で **プレビュー** 段階です。本番運用前に最新の Microsoft Learn ドキュメントで GA 状況・既知の制約を確認してください。

## アーキテクチャ図

```
┌────────────────────────────────────────────────────────────────────┐
│  Azure サブスクリプション / リソースグループ                       │
│                                                                    │
│  ┌──────────────┐    ┌──────────────────────────────────────────┐ │
│  │  AVD 制御面  │    │  仮想ネットワーク (10.0.0.0/16)          │ │
│  │              │    │  ┌────────────────────────────────────┐  │ │
│  │  ホストプール│    │  │  sessionhosts サブネット           │  │ │
│  │  アプリグループ   │  │  (10.0.0.0/24)                     │  │ │
│  │  ワークスペース   │  │  ┌────────────────────────────┐    │  │ │
│  └──────────────┘    │  │  │ セッションホスト           │    │  │ │
│         │            │  │  │ Standard_B4ms              │    │  │ │
│         │ 登録トークン│  │  │ Win11 24H2 AVD (FSLogix同梱)│   │  │ │
│         └────────────┼──┼─▶│ Entra ID 参加済             │    │  │ │
│                      │  │  └─────────┬──────────────────┘    │  │ │
│                      │  └─────────────┼─────────────────────┘  │ │
│                      └────────────────┼──────────────────────────┘ │
│                                       │ SMB (Kerberos / AES-256)   │
│                                       ▼                            │
│                  ┌──────────────────────────────────────────┐      │
│                  │  Storage Account (GPv2 / Standard_LRS)   │      │
│                  │  AADKERB 認証 / kdc_enable_cloud_group_sids   │ │
│                  │  └─ File Share: profiles (100 GiB)       │      │
│                  └──────────────────────────────────────────┘      │
└────────────────────────────────────────────────────────────────────┘

外部ユーザー (Entra B2B ゲスト)
    │
    ▼ Windows App / Web ブラウザ
AVD ゲートウェイ (Azure マネージド)
    │
    ▼ リバース接続
セッションホスト VM ─ サインオン時 FSLogix がプロファイル VHDX を Azure Files からマウント
```

## 構成リソース一覧

| リソース種別 | 名前 (`avdfsl` プレフィックス時) | 備考 |
|---|---|---|
| Virtual Network | `avdfsl-vnet` | 10.0.0.0/16 |
| サブネット | `sessionhosts` | 10.0.0.0/24 |
| Storage Account | `fsl<unique>` | GPv2 / Standard_LRS / AADKERB |
| File Service | `default` | SMB Kerberos / AES-256 |
| File Share | `profiles` | 100 GiB / TransactionOptimized |
| AVD ホストプール | `avdfsl-hp` | Pooled / maxSession=1 |
| アプリケーショングループ | `avdfsl-dag` | Desktop タイプ |
| ワークスペース | `avdfsl-ws` | アプリグループに関連付け |
| ネットワークインターフェース | `avdfsl-sh-0-nic` | 動的プライベート IP |
| 仮想マシン | `avdfsl-sh-0` | Standard_B4ms / win11-24h2-avd |
| VM 拡張機能 | AADLoginForWindows | Entra ID 参加ログイン有効化 |
| VM 拡張機能 | Microsoft.PowerShell.DSC | AVD エージェント登録 |
| Run Command | `configureFslogix` | FSLogix / Entra Kerberos レジストリ設定 |

## 前提条件

- Azure CLI バージョン 2.50.0 以降
- `az bicep` 拡張機能
- デプロイ先サブスクリプションへの `Contributor` 権限
- Entra ID での B2B ゲスト招待権限 (招待する場合)
- `Cloud Application Administrator` または `Application Administrator` ロール (post-deploy スクリプト実行用)
- VM 管理者パスワードを格納した **既存の Azure Key Vault** (別リソースグループでも可)
  - シークレット名: `vm-admin-password` (値: 12 文字以上、英大文字・英小文字・数字・記号を含む)
  - デプロイ実行ユーザーに Key Vault の `Key Vault Secrets User` 以上の RBAC ロールが付与されていること

## デプロイ手順

```bash
# 1. Azure へログイン
az login

# 2. リソースグループの作成
az group create \
  --name rg-avd-fslogix-lab \
  --location japaneast

# 3. Bicep のビルド確認 (任意)
az bicep build --file main.bicep

# 4. main.bicepparam の Key Vault 参照を設定
# main.bicepparam を開き、vmAdminPassword の getSecret() 引数を実環境の値に書き換える:
#   getSecret('<サブスクリプション ID>', '<Key Vault の RG 名>', '<Key Vault 名>', 'vm-admin-password')

# 5. デプロイ実行
az deployment group create \
  --resource-group rg-avd-fslogix-lab \
  --template-file main.bicep \
  --parameters main.bicepparam

# 6. Storage Account 名を控える (post-deploy スクリプトで使用)
STORAGE_ACCOUNT=$(az deployment group show \
  --resource-group rg-avd-fslogix-lab \
  --name main \
  --query "properties.outputs.profileStorageAccountName.value" -o tsv)
echo "Storage Account: ${STORAGE_ACCOUNT}"
```

> **注意**: デプロイ前に `main.bicepparam` の `vmAdminPassword = getSecret(...)` の引数 4 つ (サブスクリプション ID・Key Vault RG 名・Key Vault 名・シークレット名) を実環境の値に書き換えてください。プレースホルダのまま実行するとデプロイが失敗します。

## デプロイ後の必須設定

### 1. Storage Account のサービス プリンシパルへ管理者同意を付与

```bash
chmod +x update_entraid_grant.sh
./update_entraid_grant.sh -s "${STORAGE_ACCOUNT}"
```

### 2. KDC でクラウド専用グループ SID 発行を有効化

```bash
chmod +x update_entra_kerberos.sh
./update_entra_kerberos.sh -s "${STORAGE_ACCOUNT}"
```

### 3. Microsoft Entra で RDP 認証を有効化 (外部 ID 必須)

```powershell
Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.Applications

Connect-MgGraph -Scopes "Application.Read.All","Application-RemoteDesktopConfig.ReadWrite.All"

$WCLspId = (Get-MgServicePrincipal -Filter "AppId eq '270efc09-cd0d-444b-a71f-39af4910ec45'").Id

$desktopSecurityConf = Get-MgServicePrincipalRemoteDesktopSecurityConfiguration -ServicePrincipalId $WCLspId
if ($desktopSecurityConf.IsRemoteDesktopProtocolEnabled -ne $true) {
  Update-MgServicePrincipalRemoteDesktopSecurityConfiguration -ServicePrincipalId $WCLspId -IsRemoteDesktopProtocolEnabled
}
```

## デプロイ後の設定 (外部 ID アクセス付与)

### 1. B2B ゲストの招待

```bash
az ad invitation create \
  --invited-user-email "guest@external-tenant.com" \
  --invite-redirect-url "https://myapps.microsoft.com"
```

### 2. アプリケーショングループへの登録とRBAC ロール付与

| ロール | 対象 | 用途 |
|---|---|---|
| `Desktop Virtualization User` | アプリケーション グループ | AVD デスクトップ利用 |
| `Virtual Machine User Login` | セッション ホスト VM | Entra ID 参加 VM へのログイン |

```bash
GUEST_OBJ_ID=$(az ad user show \
  --id "guest_externaltenantcom#EXT#@<リソーステナントドメイン>" \
  --query id -o tsv)

# AVD アプリケーション グループへの登録
APP_GROUP_ID=$(az desktopvirtualization applicationgroup show \
  --resource-group rg-avd-fslogix-lab \
  --name avdfsl-dag \
  --query id -o tsv)

# AVD アプリケーション グループへのRBACの設定
az role assignment create \
  --role "Desktop Virtualization User" \
  --assignee "$GUEST_OBJ_ID" \
  --scope "$APP_GROUP_ID"

# VM へのRBACの設定
VM_ID=$(az vm show \
  --resource-group rg-avd-fslogix-lab \
  --name avdfsl-sh-0 \
  --query id -o tsv)
az role assignment create \
  --role "Virtual Machine User Login" \
  --assignee "$GUEST_OBJ_ID" \
  --scope "$VM_ID"
```

> **補足**: 本テンプレートでは Storage Account の `defaultSharePermission` を `StorageFileDataSmbShareElevatedContributor` に設定しているため、SMB レベルでの個別 RBAC 付与は不要です。
> クラウド専用 ID に対する個別ユーザー / グループへの共有レベル RBAC 割り当ては、**対応リージョンでのみ利用可能**です (Japan East は SSD/Premium 限定)。対応リージョンは公式ドキュメントを参照してください ([Microsoft Entra Kerberos authentication for Azure Files](https://learn.microsoft.com/azure/storage/files/storage-files-identity-auth-hybrid-identities-enable#regional-availability-for-microsoft-entra-kerberos))。本構成 (Standard_LRS / Japan East) では `defaultSharePermission` による一律設定を採用しています。


## パラメータ表

| パラメータ名 | 型 | デフォルト値 | 必須 | 説明 |
|---|---|---|---|---|
| `location` | string | `japaneast` | - | リソースのデプロイ先リージョン |
| `resourcePrefix` | string | `avdfsl` | - | リソース名のプレフィックス (最大 8 文字) |
| `vmAdminUsername` | string | `avdadmin` | - | VM 管理者ユーザー名 |
| `vmAdminPassword` | securestring | - | ✅ | VM 管理者パスワード。`main.bicepparam` の `getSecret()` で既存 Key Vault から取得 |
| `profileStorageAccountName` | string | `fsl<unique>` | - | プロファイル用 Storage Account 名 (グローバル一意) |
| `profileShareName` | string | `profiles` | - | プロファイル用ファイル共有名 |
| `profileShareQuotaGiB` | int | `100` | - | ファイル共有クォータ (GiB) |
| `tokenExpirationTime` | string | `utcNow + 2h` | - | ホストプール登録トークン有効期限 |
| `diagStorageAccountName` | string | `diag<unique>` | - | 診断ログ用 Storage Account 名 (グローバル一意) |

## デプロイ後検証手順

```bash
# セッションホストの登録確認 (デプロイ後 5-10 分待機)
az desktopvirtualization sessionhost list \
  --resource-group rg-avd-fslogix-lab \
  --host-pool-name avdfsl-hp \
  --query "[].{name:name,status:properties.status,agent:properties.agentVersion}" -o table

# Run Command (FSLogix 設定) の結果確認
az vm run-command show \
  --resource-group rg-avd-fslogix-lab \
  --vm-name avdfsl-sh-0 \
  --name configureFslogix \
  --instance-view \
  --query "instanceView.{state:executionState,output:output,error:error}" -o json
```

外部 ID ユーザーで AVD にサインオンした後、セッション内で以下を確認します。

```powershell
# プロファイル VHDX がマウントされているか
Get-Volume | Where-Object FileSystemLabel -like "Profile-*"

# FSLogix イベント ログ
Get-WinEvent -LogName "Microsoft-FSLogix-Apps/Operational" -MaxEvents 20
```

## FSLogix プロファイルの作成タイミングと NTFS ACL

### プロファイル ファイルが Azure Files に作成されるタイミング

ファイル共有 `profiles` はデプロイ時点では空です。プロファイル フォルダと VHDX は **エンド ユーザーが AVD に初回サインオンしたタイミング** で、そのユーザー自身の Kerberos チケットを使って FSLogix サービスが作成します。

| # | タイミング | 動作 |
|---|---|---|
| 1 | デプロイ完了 | ファイル共有 `profiles` は空 |
| 2 | ユーザーが AVD にサインオン | FSLogix がレジストリ `VHDLocations` を読み、`\\<sa>.file.core.windows.net\profiles` に SMB 接続 |
| 3 | プロファイル フォルダ生成 | `<SID>_<username>` 形式のフォルダを **そのユーザー本人のコンテキスト** で作成 |
| 4 | VHDX 生成 | フォルダ内に `Profile_<username>.vhdx` (動的) を作成・マウント |
| 5 | 以降のサインオン | 既存 VHDX を再マウントするだけ (新規作成なし) |

### NTFS ACL を明示的に設定していない理由

本テンプレートでは Azure Files ファイル共有のルートに対する NTFS ACL を **デフォルトのまま** にしています。これは検証環境の用途において、デフォルト ACL のみで FSLogix のプロファイル作成・マウントが正常に動作するためです。

#### クラウド専用 ID 構成での ACL 設定ツールの制約

クラウド専用 ID (Entra Kerberos) では、ACL 設定に利用できるツールが限定されています ([Configure directory-level and file-level permissions for Azure file shares](https://learn.microsoft.com/azure/storage/files/storage-files-identity-configure-file-level-permissions))。

| ツール | クラウド専用 ID で利用可能か |
|---|---|
| Windows File Explorer | ⛔ 不可 |
| `icacls` | ⛔ 不可 |
| Azure Portal の ACL エディタ | ✅ 可能 |
| PowerShell `RestSetAcls` モジュール | ✅ 可能 |

また、いずれの方式も Bicep からは宣言できないため、本テンプレートでは ACL 操作を行いません。

#### 新規ファイル共有のデフォルト NTFS ACL

| プリンシパル | 権限 | 適用範囲 |
|---|---|---|
| `BUILTIN\Users` | Read & Execute, **List Folder Contents**, **Create Folders / Append Data** | このフォルダ、サブフォルダ、ファイル |
| `CREATOR OWNER` | **Full Control** | サブフォルダーとファイル (継承のみ) |
| `BUILTIN\Administrators` | Full Control | このフォルダ、サブフォルダ、ファイル |
| `NT AUTHORITY\SYSTEM` | Full Control | このフォルダ、サブフォルダ、ファイル |

#### デフォルト ACL で FSLogix が動作する理由 (ステップ別)

1. **ルート直下にプロファイル フォルダを作成**
   - Azure Files SMB スタックは認証済みユーザーを `BUILTIN\Users` メンバーとして扱う
   - ルートの `Users: Create Folders / Append Data` 権限により、ユーザー自身のフォルダを作成可能
2. **作成したフォルダの所有者になる**
   - Windows の標準動作として、フォルダ作成者が **そのフォルダの Owner SID** になる
   - これにより `CREATOR OWNER` の継承 ACE が発火し、自分のフォルダに対して **Full Control を取得**
3. **フォルダ内で VHDX を作成・読み書き**
   - 自分が Owner = Full Control を持つフォルダ内なので、VHDX の作成・書き込み・拡張・排他ロックすべて成功
4. **複数ユーザーの並行サインオン**
   - 各ユーザーは自分専用のフォルダを作成し、それぞれが Creator Owner となる
   - ユーザー間で書き込みが競合することはない

#### デフォルト ACL の残存リスク (検証環境では許容)

「動作する」ことと「分離されている」ことは別です。デフォルト ACL のままだと以下の状態になります。

| 操作 | 可否 | 根拠 |
|---|---|---|
| 自分のプロファイル フォルダ作成 | ✅ | ルートの `Users: Create Folders` |
| 自分の VHDX 作成・読み書き | ✅ | フォルダの `Creator Owner: Full Control` |
| 他人のフォルダ名を **列挙** | ⚠️ できる | ルートの `Users: List Folder Contents` |
| 他人のフォルダの中を **読み取り** | ⚠️ できる | サブフォルダへの `Users: Read & Execute` 継承 |
| 他人の VHDX を **削除・改ざん** | ❌ できない | 他人のサブフォルダ/ファイルは Creator Owner のみが Full Control を持つ。`Users` の継承権限は Read & Execute どまり。さらにマウント中は排他ロックされる |

つまり「他人のプロファイルが**見えてしまう**が、**壊すことはできない**」状態です。少数ユーザーで動作確認する検証用途では実害がないため、本テンプレートではこのまま運用します。

#### 本番採用時の対応 (参考)

本番では Azure Portal の ACL エディタまたは `RestSetAcls` PowerShell モジュールで、以下のようにルート ACL を厳格化することを推奨します。

- `BUILTIN\Users` の継承を「このフォルダのみ」に絞り、サブフォルダ/ファイルへの継承 ACE を削除
- 結果として、各ユーザーは自分のフォルダ作成のみ可能で、他人のフォルダの列挙・読み取りは不可となる

## コスト注意

| リソース | SKU | コスト傾向 |
|---|---|---|
| セッションホスト VM | Standard_B4ms | バースト可能、停止中はコンピュート無料 |
| OS ディスク | StandardSSD_LRS 128 GB | 約 1,200 円/月 (常時課金) |
| プロファイル Storage Account | StorageV2 / Standard_LRS | 容量課金 (約 5 円/GB/月) + トランザクション課金 |
| File Share `profiles` | 100 GiB クォータ | 実使用量のみ課金 (クォータは上限値) |
| AVD 制御面 | - | 無料 |

> **💡 コスト削減ヒント**:
> - 使用しない時間帯はセッション ホスト VM を停止 (`az vm deallocate`)
> - 検証完了後はリソース グループごと削除

## トラブルシューティング

### FSLogix プロファイルがマウントされない

> **重要**: `CloudKerberosTicketRetrievalEnabled` レジストリ設定は **OS 再起動後に有効** になります。`configureFslogix` Run Command 完了後、初回サインオン前に一度セッション ホスト VM を再起動してください (`az vm restart -g rg-avd-fslogix-lab -n avdfsl-sh-0`)。

1. Run Command の実行結果を確認 (上記 `az vm run-command show`)。`Failed` の場合は `error` フィールドを確認
2. セッション内で FSLogix イベント ログを確認:
   ```powershell
   Get-WinEvent -LogName "Microsoft-FSLogix-Apps/Operational" -MaxEvents 50 | Format-List
   ```
3. 共有への手動アクセスを確認 (admin として):
   ```powershell
   Test-Path "\\<storageAccount>.file.core.windows.net\profiles"
   ```
4. `update_entra_kerberos.sh` を実行済みか (タグ未付与だと B2B ゲストの Kerberos チケットに必要な SID が含まれない)

### セッションホストが `Unavailable` のまま

```bash
az vm extension list \
  --resource-group rg-avd-fslogix-lab \
  --vm-name avdfsl-sh-0 \
  --query "[].{name:name,state:provisioningState}" -o table
```

DSC 拡張機能が `Failed` の場合は VM のゲスト ログ (`C:\WindowsAzure\Logs\`) を確認してください。

### 外部ユーザーが接続できない

- アプリケーション グループへの `Desktop Virtualization User` ロール割り当てを確認
- VM への `Virtual Machine User Login` ロール割り当てを確認
- リソース テナントのクロステナント アクセス設定で外部テナントからの B2B アクセスが許可されているか確認
- ホスト テナント側の Conditional Access が AVD アプリへのアクセスをブロックしていないか確認

### 登録トークンの期限切れ (デプロイから 2 時間以上経過後の再デプロイ)

```bash
az desktopvirtualization hostpool update \
  --resource-group rg-avd-fslogix-lab \
  --name avdfsl-hp \
  --registration-info expiration-time="$(date -u -d '+2 hour' '+%Y-%m-%dT%H:%M:%S')" registration-token-operation=Update
```

## クリーンアップ

```bash
az group delete \
  --name rg-avd-fslogix-lab \
  --yes --no-wait
```

> **注意**: Entra ID 上には VM デバイス オブジェクトが残存します。再デプロイ時に同名 VM を作成する場合は、Entra ID から該当デバイス オブジェクトを削除してください。

## 注意事項

- このテンプレートは検証目的のみで使用してください
- 外部 ID + FSLogix はプレビュー機能を含むため、本番採用前に最新ドキュメントを確認してください
- このコードの実行に伴って発生するいかなる不利益に関しても、開発者は一切の責任を負いません
