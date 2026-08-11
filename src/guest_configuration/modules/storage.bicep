// ============================================================
// modules/storage.bicep
// 構成パッケージ保管用 Storage + Blob Private Endpoint
// ============================================================

@description('デプロイ先リージョン')
param location string

@description('リソース名プレフィックス')
param resourcePrefix string

@description('構成パッケージ格納コンテナー名')
param packageContainerName string

@description('構成パッケージをアップロードするユーザーの Microsoft Entra object ID')
param packageUploaderPrincipalId string

@description('接続先 VNet のリソース ID')
param vnetId string

@description('Private Endpoint を作成するサブネット ID')
param privateEndpointSubnetId string

var storageAccountName = take('${resourcePrefix}pkg${uniqueString(resourceGroup().id)}', 24)
var privateEndpointName = '${resourcePrefix}-blob-pe'
var privateDnsZoneName = 'privatelink.blob.${environment().suffixes.storage}'
var privateDnsLinkName = '${resourcePrefix}-blob-dns-link'
var peConnectionName = '${privateEndpointName}-conn'
var storageBlobDataContributorRoleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'

resource storageAccount 'Microsoft.Storage/storageAccounts@2025-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    publicNetworkAccess: 'Disabled'
    allowBlobPublicAccess: true
    allowSharedKeyAccess: false
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2025-01-01' = {
  parent: storageAccount
  name: 'default'
}

// 匿名読み取りは Private Endpoint 内からのみ成立させる
resource packageContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2025-01-01' = {
  parent: blobService
  name: packageContainerName
  properties: {
    publicAccess: 'Blob'
  }
}

// パッケージのアップロードに必要なデータプレーン権限をコンテナー単位で付与
resource packageUploaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(packageContainer.id, packageUploaderPrincipalId, storageBlobDataContributorRoleId)
  scope: packageContainer
  properties: {
    principalId: packageUploaderPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleId)
    principalType: 'User'
  }
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateDnsZoneName
  location: 'global'
}

resource privateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: privateDnsLinkName
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: privateEndpointName
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: peConnectionName
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
  }
}

resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = {
  parent: privateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'blob-zone'
        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
  dependsOn: [
    privateDnsZoneLink
  ]
}

output storageAccountName string = storageAccount.name
output packageContainerName string = packageContainer.name
output packageBaseUri string = 'https://${storageAccount.name}.blob.${environment().suffixes.storage}/${packageContainer.name}'
