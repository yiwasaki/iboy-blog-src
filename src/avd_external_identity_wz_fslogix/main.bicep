metadata description = 'Azure Virtual Desktop 外部 ID (Entra B2B) シングルセッション + FSLogix プロファイル on Azure Files (GPv2 / Entra Kerberos) 検証環境'

// ============================================================
// パラメータ
// ============================================================

@description('リソースのデプロイ先リージョン')
param location string = 'japaneast'

@description('リソース名のプレフィックス (最大 8 文字、英小文字・数字のみ)')
@maxLength(8)
param resourcePrefix string = 'avdfsl'

@description('セッションホスト VM の管理者ユーザー名')
param vmAdminUsername string = 'avdadmin'

@description('セッションホスト VM の管理者パスワード (最低 12 文字)')
@secure()
@minLength(12)
param vmAdminPassword string

@description('FSLogix プロファイル格納用 Storage Account 名 (グローバル一意、3-24 文字、英小文字・数字のみ)。デフォルトはリソースグループ ID から導出。')
@minLength(3)
@maxLength(24)
param profileStorageAccountName string = toLower('fsl${uniqueString(resourceGroup().id)}')

@description('FSLogix プロファイル用ファイル共有名')
param profileShareName string = 'profiles'

@description('FSLogix プロファイル用ファイル共有のクォータ (GiB)')
@minValue(100)
@maxValue(102400)
param profileShareQuotaGiB int = 100

@description('ホストプール登録トークンの有効期限 (デプロイ開始時刻 + 2 時間, UTC ISO8601)')
param tokenExpirationTime string = dateTimeAdd(utcNow('o'), 'PT2H')

@description('診断ログ保存用 Storage Account 名 (グローバル一意、3-24 文字、英小文字・数字のみ)。デフォルトはリソースグループ ID から導出。')
@minLength(3)
@maxLength(24)
param diagStorageAccountName string = toLower('diag${uniqueString(resourceGroup().id)}')

// ============================================================
// 変数
// ============================================================

var prefix = toLower(resourcePrefix)

// ネットワーク
var vnetName = '${prefix}-vnet'
var subnetName = 'sessionhosts'

// AVD コンポーネント
var hostPoolName = '${prefix}-hp'
var appGroupName = '${prefix}-dag'
var workspaceName = '${prefix}-ws'

// セッションホスト VM (computerName は Windows 制限 15 文字以内)
var sessionHostName = '${prefix}-l2-sh-0'
var nicName = '${sessionHostName}-nic'
var osDiskName = '${sessionHostName}-osdisk'

// AVD エージェント DSC 設定 ZIP の URL
// ※ 最新版は https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/ を確認して更新してください
var avdAgentDscUrl = 'https://wvdportalstorageblob.blob.${environment().suffixes.storage}/galleryartifacts/Configuration_1.0.02990.697.zip'

// FSLogix プロファイル UNC パス (\\<account>.file.<suffix>\<share>)
var profileShareUnc = '\\\\${profileStorageAccountName}.file.${environment().suffixes.storage}\\${profileShareName}'

// FSLogix + Entra Kerberos クライアント構成 PowerShell スクリプト
// セッションホスト OS 上で以下を構成:
//   1. FSLogix プロファイル レジストリ (HKLM\SOFTWARE\FSLogix\Profiles)
//   2. Entra Kerberos クラウド チケット取得 (HKLM\SYSTEM\CurrentControlSet\Control\Lsa\Kerberos\Parameters)
var fslogixConfigScript = join(
  [
    '$ErrorActionPreference = \'Stop\''
    '$profilesKey = \'HKLM:\\SOFTWARE\\FSLogix\\Profiles\''
    'if (-not (Test-Path $profilesKey)) { New-Item -Path $profilesKey -Force | Out-Null }'
    'New-ItemProperty -Path $profilesKey -Name \'Enabled\' -PropertyType DWord -Value 1 -Force | Out-Null'
    'New-ItemProperty -Path $profilesKey -Name \'VHDLocations\' -PropertyType MultiString -Value @(\'${profileShareUnc}\') -Force | Out-Null'
    'New-ItemProperty -Path $profilesKey -Name \'DeleteLocalProfileWhenVHDShouldApply\' -PropertyType DWord -Value 1 -Force | Out-Null'
    'New-ItemProperty -Path $profilesKey -Name \'FlipFlopProfileDirectoryName\' -PropertyType DWord -Value 1 -Force | Out-Null'
    'New-ItemProperty -Path $profilesKey -Name \'VolumeType\' -PropertyType String -Value \'VHDX\' -Force | Out-Null'
    '$kerberosKey = \'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Lsa\\Kerberos\\Parameters\''
    'if (-not (Test-Path $kerberosKey)) { New-Item -Path $kerberosKey -Force | Out-Null }'
    'New-ItemProperty -Path $kerberosKey -Name \'CloudKerberosTicketRetrievalEnabled\' -PropertyType DWord -Value 1 -Force | Out-Null'
    'Write-Output \'FSLogix and Entra Kerberos client settings configured.\''
  ],
  '\n'
)

var tags = {
  environment: 'lab'
  purpose: 'avd-external-identity-fslogix'
}

// ============================================================
// 仮想ネットワーク
// ============================================================

// AVD セッションホスト用 VNet / サブネット
resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: '10.0.0.0/24'
        }
      }
    ]
  }
}

// ============================================================
// FSLogix プロファイル用 Storage Account (GPv2 / Entra Kerberos)
// ============================================================

// 検証環境のためコスト最優先で StorageV2 (GPv2) + Standard_LRS を選択。
// Premium FileStorage は IOPS 性能は高いが固定課金が発生するため利用しない。
// directoryServiceOptions: 'AADKERB' により Entra Kerberos 認証 (クラウド専用 ID) を有効化。
resource profileStorageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: profileStorageAccountName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    // Entra Kerberos 構成中も共有キー アクセスは内部的に必要なため true のまま
    allowSharedKeyAccess: true
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    networkAcls: {
      bypass: 'AzureServices'
      // 検証環境用にパブリック アクセスを許可。本番では Private Endpoint への切り替えを推奨
      defaultAction: 'Allow'
    }
    azureFilesIdentityBasedAuthentication: {
      directoryServiceOptions: 'AADKERB'
      // 既定で SMB マウントしたユーザーへ Elevated Contributor 権限を付与 (検証用簡素化)。
      // 本番では None にして個別 RBAC を割り当てること。
      defaultSharePermission: 'StorageFileDataSmbShareElevatedContributor'
    }
  }
}

// File Service: SMB 認証を Kerberos / AES-256 に固定
resource profileFileService 'Microsoft.Storage/storageAccounts/fileServices@2023-05-01' = {
  parent: profileStorageAccount
  name: 'default'
  properties: {
    protocolSettings: {
      smb: {
        versions: 'SMB3.0;SMB3.1.1'
        authenticationMethods: 'Kerberos'
        kerberosTicketEncryption: 'AES-256'
        channelEncryption: 'AES-128-GCM;AES-256-GCM'
      }
    }
  }
}

// FSLogix プロファイル用 ファイル共有
resource profileFileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-05-01' = {
  parent: profileFileService
  name: profileShareName
  properties: {
    shareQuota: profileShareQuotaGiB
    enabledProtocols: 'SMB'
    accessTier: 'TransactionOptimized'
  }
}

// ============================================================
// 診断ログ用 Storage Account
// ============================================================

// FSLogix / Entra Kerberos のアクセスログ確認用ストレージアカウント。
// Azure Files の全ログ (StorageRead / StorageWrite / StorageDelete) を転送することで、
// クラウド専用 ID (Entra Kerberos) での認証が正しく行われているかを検証する。
resource diagStorageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: diagStorageAccountName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    networkAcls: {
      bypass: 'AzureServices'
      // 検証環境用にパブリック アクセスを許可
      defaultAction: 'Allow'
    }
  }
}

// Azure Files 診断設定: StorageRead / StorageWrite / StorageDelete の全ログを診断ログ用ストレージへ転送。
// FSLogix の SMB アクセスを確認し、Entra Kerberos (クラウド専用 ID) 認証の動作を検証する。
resource profileFileServiceDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-files-all'
  scope: profileFileService
  properties: {
    storageAccountId: diagStorageAccount.id
    logs: [
      {
        category: 'StorageRead'
        enabled: true
      }
      {
        category: 'StorageWrite'
        enabled: true
      }
      {
        category: 'StorageDelete'
        enabled: true
      }
    ]
  }
}

// ============================================================
// AVD ホストプール
// ============================================================

// Pooled + maxSessionLimit:1 = シングルセッション構成
// 外部 ID (Entra B2B) は CA/MFA をリソーステナント側で制御するため VM 側の設定変更は不要
resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2024-04-03' = {
  name: hostPoolName
  location: location
  tags: tags
  properties: {
    hostPoolType: 'Pooled'
    loadBalancerType: 'BreadthFirst'
    preferredAppGroupType: 'Desktop'
    maxSessionLimit: 1 // シングルセッション (1 VM 同時 1 ユーザーのみ)
    validationEnvironment: false
    customRdpProperty: 'enablerdsaadauth:i:1' // 外部 ID 利用時に必須の Microsoft Entra SSO
    startVMOnConnect: true
    // 登録トークン: デプロイから 2 時間有効 (tokenExpirationTime パラメータで調整可能)
    registrationInfo: {
      expirationTime: tokenExpirationTime
      registrationTokenOperation: 'Update'
    }
  }
}

// ============================================================
// アプリケーショングループ
// ============================================================

// デスクトップアプリケーショングループ (フルデスクトップを外部 ID ユーザーへ公開)
resource appGroup 'Microsoft.DesktopVirtualization/applicationGroups@2024-04-03' = {
  name: appGroupName
  location: location
  tags: tags
  properties: {
    applicationGroupType: 'Desktop'
    hostPoolArmPath: hostPool.id
    description: 'AVD 外部 ID + FSLogix 検証用デスクトップアプリケーショングループ'
    friendlyName: 'AVD 外部 ID + FSLogix デスクトップ'
  }
}

// ============================================================
// ワークスペース
// ============================================================

// ワークスペース (Windows App / Web クライアントでのエントリポイント)
resource workspace 'Microsoft.DesktopVirtualization/workspaces@2024-04-03' = {
  name: workspaceName
  location: location
  tags: tags
  properties: {
    applicationGroupReferences: [
      appGroup.id
    ]
    description: 'AVD 外部 ID + FSLogix 検証ワークスペース'
    friendlyName: 'AVD 外部 ID + FSLogix 検証'
  }
}

// ============================================================
// セッションホスト VM
// ============================================================

// ネットワークインターフェース
resource nic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: nicName
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: vnet.properties.subnets[0].id
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

// セッションホスト VM
// Standard_B4ms: 4 vCPU / 16 GB RAM / バースト可能 — 最低コスト構成
// イメージは AVD シングルセッション SKU (FSLogix エージェント プリインストール済み)
resource sessionHostVm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: sessionHostName
  location: location
  tags: tags
  identity: {
    // Entra ID 参加 (AADJoin) に必要
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B4ms' // 4 vCPU / 16 GB RAM、コスト最優先
    }
    osProfile: {
      computerName: sessionHostName
      adminUsername: vmAdminUsername
      adminPassword: vmAdminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
        patchSettings: {
          patchMode: 'AutomaticByOS'
          assessmentMode: 'ImageDefault'
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsDesktop'
        offer: 'Windows-11'
        // FSLogix が事前にインストールされている AVD 向けシングルセッション イメージ
        sku: 'win11-24h2-avd'
        version: 'latest'
      }
      osDisk: {
        name: osDiskName
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
        caching: 'ReadWrite'
        diskSizeGB: 128
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}

// ============================================================
// VM 拡張機能
// ============================================================

// AADLoginForWindows: Entra ID 参加 VM への Entra ID 認証ログインを有効化
resource aadLoginExtension 'Microsoft.Compute/virtualMachines/extensions@2024-03-01' = {
  parent: sessionHostVm
  name: 'AADLoginForWindows'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: 'AADLoginForWindows'
    typeHandlerVersion: '2.0'
    autoUpgradeMinorVersion: true
    settings: {
      mdmId: '' // MDM/Intune 未登録
    }
  }
}

// AVD DSC 拡張機能: AVD エージェントをインストールし、ホストプールへ登録
// aadJoin: true により VM の Entra ID 参加も同時に実行
resource avdDscExtension 'Microsoft.Compute/virtualMachines/extensions@2024-03-01' = {
  parent: sessionHostVm
  name: 'Microsoft.PowerShell.DSC'
  location: location
  dependsOn: [
    aadLoginExtension
  ]
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.73'
    autoUpgradeMinorVersion: true
    settings: {
      modulesUrl: avdAgentDscUrl
      configurationFunction: 'Configuration.ps1\\AddSessionHost'
      properties: {
        hostPoolName: hostPool.name
        registrationInfoTokenCredential: {
          UserName: 'PLACEHOLDER_DO_NOT_USE'
          Password: 'PrivateSettingsRef:registrationInfoToken'
        }
        aadJoin: true
        mdmId: ''
      }
    }
    protectedSettings: {
      Items: {
        registrationInfoToken: hostPool.listRegistrationTokens('2024-04-03').value[0].token
      }
    }
  }
}

// ============================================================
// FSLogix / Entra Kerberos クライアント構成 (Run Command)
// ============================================================

// AVD DSC 拡張機能 (Entra ID 参加 + AVD 登録) 完了後に、FSLogix プロファイル レジストリと
// Entra Kerberos クラウド チケット取得設定をセッションホストに適用する。
// FSLogix エージェントは win11-24h2-avd イメージにプリインストール済みのため、
// レジストリ設定のみで有効化される。
resource configureFslogix 'Microsoft.Compute/virtualMachines/runCommands@2024-03-01' = {
  parent: sessionHostVm
  name: 'configureFslogix'
  location: location
  dependsOn: [
    avdDscExtension
  ]
  properties: {
    source: {
      script: fslogixConfigScript
    }
    timeoutInSeconds: 600
    treatFailureAsDeploymentFailure: true
  }
}

// ============================================================
// 出力
// ============================================================

@description('ホストプールのリソース ID')
output hostPoolId string = hostPool.id

@description('ワークスペースのリソース ID')
output workspaceId string = workspace.id

@description('アプリケーショングループのリソース ID')
output appGroupId string = appGroup.id

@description('セッションホスト VM のリソース ID')
output sessionHostVmId string = sessionHostVm.id

@description('FSLogix プロファイル用 Storage Account 名')
output profileStorageAccountName string = profileStorageAccount.name

@description('FSLogix プロファイル用ファイル共有 UNC パス')
output profileShareUnc string = profileShareUnc

@description('診断ログ用 Storage Account 名')
output diagStorageAccountName string = diagStorageAccount.name
