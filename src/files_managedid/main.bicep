// Azure Files マネージドID SMB アクセス 検証環境
// このテンプレートは、マネージドIDを使用したAzure FilesへのSMBアクセスを検証するための環境をデプロイします

@description('リソースのデプロイ先リージョン')
param location string = 'japaneast'

@description('リソース名のプレフィックス')
@maxLength(7)
param resourcePrefix string = 'filesmi'

// 変数定義
var sanitizedResourcePrefix = take(replace(toLower(resourcePrefix), '-', ''), 7)
var storageAccountName = '${sanitizedResourcePrefix}st${uniqueString(resourceGroup().id)}'
var diagStorageAccountName = '${sanitizedResourcePrefix}diag${uniqueString(resourceGroup().id)}'
var fileShareName = 'share01'

// Storage Account (SMBOAuth 有効化)
resource storageAccount 'Microsoft.Storage/storageAccounts@2025-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
    // マネージドID SMB アクセス (SMB OAuth) 認証の設定
    azureFilesIdentityBasedAuthentication: {
      directoryServiceOptions: 'None'
      defaultSharePermission: 'StorageFileDataSmbShareElevatedContributor'
      smbOAuthSettings: {
        isSmbOAuthEnabled: true
      }
    }
  }
}

// File Service
resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2025-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    shareDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

// File Share
resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2025-01-01' = {
  parent: fileService
  name: fileShareName
  properties: {
    accessTier: 'TransactionOptimized'
    shareQuota: 100
    enabledProtocols: 'SMB'
  }
}

// 診断ログ出力用ストレージアカウント
resource diagStorageAccount 'Microsoft.Storage/storageAccounts@2025-01-01' = {
  name: diagStorageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
  }
}

// File Service の診断設定
resource fileDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-file'
  scope: fileService
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
    metrics: [
      {
        category: 'Transaction'
        enabled: true
      }
    ]
  }
}

// 出力
output storageAccountName string = storageAccount.name
output fileShareName string = fileShare.name
output diagStorageAccountName string = diagStorageAccount.name
