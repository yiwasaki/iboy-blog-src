// ============================================================
// main.bicep
// Azure Machine Configuration (Ubuntu auditd) 検証環境
// ============================================================

@description('デプロイ先リージョン')
param location string = resourceGroup().location

@description('リソース名プレフィックス')
@maxLength(12)
param resourcePrefix string = 'gcauditd'

@description('VM 管理者ユーザー名')
param adminUsername string = 'azureuser'

@description('VM ログイン用管理者パスワード')
@secure()
@minLength(12)
param adminPassword string

@description('VM サイズ')
@allowed([
  'Standard_B2s'
  'Standard_D2s_v5'
])
param vmSize string = 'Standard_B2s'

@description('VM 用サブネット CIDR')
param vmSubnetPrefix string = '10.20.1.0/24'

@description('Private Endpoint 用サブネット CIDR')
param privateEndpointSubnetPrefix string = '10.20.2.0/24'

@description('VNet CIDR')
param vnetAddressPrefix string = '10.20.0.0/16'

@description('構成パッケージ格納コンテナー名')
param packageContainerName string = 'machine-configuration'

@description('構成パッケージをアップロードするユーザーの Microsoft Entra object ID')
param packageUploaderPrincipalId string

var prefix = take(replace(toLower(resourcePrefix), '-', ''), 12)

// ============================================================
// ネットワーク
// ============================================================
module network './modules/network.bicep' = {
  name: 'mod-network'
  params: {
    location: location
    resourcePrefix: prefix
    vnetAddressPrefix: vnetAddressPrefix
    vmSubnetPrefix: vmSubnetPrefix
    privateEndpointSubnetPrefix: privateEndpointSubnetPrefix
  }
}

// ============================================================
// Bastion Developer
// ============================================================
module bastion './modules/bastion.bicep' = {
  name: 'mod-bastion'
  params: {
    location: location
    resourcePrefix: prefix
    vnetId: network.outputs.vnetId
  }
}

// ============================================================
// Storage + Blob Private Endpoint
// ============================================================
module storage './modules/storage.bicep' = {
  name: 'mod-storage'
  params: {
    location: location
    resourcePrefix: prefix
    packageContainerName: packageContainerName
    packageUploaderPrincipalId: packageUploaderPrincipalId
    vnetId: network.outputs.vnetId
    privateEndpointSubnetId: network.outputs.privateEndpointSubnetId
  }
}

// ============================================================
// Ubuntu VM + Guest Configuration Extension
// ============================================================
module vm './modules/vm.bicep' = {
  name: 'mod-vm'
  params: {
    location: location
    resourcePrefix: prefix
    adminUsername: adminUsername
    adminPassword: adminPassword
    vmSize: vmSize
    vmSubnetId: network.outputs.vmSubnetId
    publicIpId: network.outputs.publicIpId
  }
}

output vmName string = vm.outputs.vmName
output vnetName string = network.outputs.vnetName
output bastionName string = bastion.outputs.bastionName
output storageAccountName string = storage.outputs.storageAccountName
output packageContainerName string = storage.outputs.packageContainerName
output packageBaseUri string = storage.outputs.packageBaseUri
