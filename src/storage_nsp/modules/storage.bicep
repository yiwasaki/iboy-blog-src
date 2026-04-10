// ============================================================
// storage.bicep
// Storage Account for NSP 検証環境
//
// テスト用 Storage Account + 診断用 Storage Account を作成
// テスト用は NSP で保護し、診断用はログ収集先として使用
// ============================================================

@description('Azure リージョン')
param location string

@description('テスト用 Storage Account 名（グローバル一意）')
param storageAccountTestName string

@description('診断用 Storage Account 名（グローバル一意）')
param storageAccountDiagName string

@description('VM のマネージド ID プリンシパル ID（RBAC 割り当て用）')
param vmPrincipalId string

// ============================================================
// テスト用 Storage Account（NSP で保護する対象）
// ============================================================
resource storageAccountTest 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountTestName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    // NSP 関連付け前はデフォルト (Enabled) で作成
    // NSP 関連付け後に SecuredByPerimeter へ変更
    publicNetworkAccess: 'Enabled'
  }
}

// テスト用 Blob コンテナ作成
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' existing = {
  parent: storageAccountTest
  name: 'default'
}

resource testContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'nsp-test'
  properties: {
    publicAccess: 'None'
  }
}

// ============================================================
// 診断用 Storage Account（ログ収集先）
// ============================================================
resource storageAccountDiag 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountDiagName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

// ============================================================
// Diagnostic Settings（テスト用 Storage → 診断用 Storage）
// ============================================================
resource blobDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${storageAccountTestName}-blob-diag'
  scope: blobService
  properties: {
    storageAccountId: storageAccountDiag.id
    logs: [
      {
        category: 'StorageRead'
        enabled: true
        retentionPolicy: { enabled: false, days: 0 }
      }
      {
        category: 'StorageWrite'
        enabled: true
        retentionPolicy: { enabled: false, days: 0 }
      }
      {
        category: 'StorageDelete'
        enabled: true
        retentionPolicy: { enabled: false, days: 0 }
      }
    ]
    metrics: []
  }
}

// ============================================================
// RBAC: VM マネージド ID → Storage Blob Data Contributor
// NSP intra-perimeter 通信に MI 認証が必要
// ============================================================
var storageBlobDataContributorRoleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccountTest.id, vmPrincipalId, storageBlobDataContributorRoleId)
  scope: storageAccountTest
  properties: {
    principalId: vmPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleId)
    principalType: 'ServicePrincipal'
  }
}

// ============================================================
// Outputs
// ============================================================
output storageAccountTestId string = storageAccountTest.id
output storageAccountTestName string = storageAccountTest.name
output storageAccountDiagId string = storageAccountDiag.id
output storageAccountDiagName string = storageAccountDiag.name
output testContainerName string = testContainer.name
