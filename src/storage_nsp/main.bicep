// ============================================================
// main.bicep
// Storage Account NSP (Network Security Perimeter) 検証環境
//
// 使用方法:
//   az deployment group create -g <rg> -f main.bicep -p main.bicepparam
//
// 構成:
//   - VNet + Subnet + NSG（Bastion RDP のみ許可）
//   - Azure Bastion Developer（無料）
//   - Windows VM (Standard_B2s, Public IP なし)
//   - Storage Account (テスト用 + 診断用)
//   - Network Security Perimeter + Profile + Access Rules + Association
// ============================================================

targetScope = 'resourceGroup'

// ============================================================
// Parameters
// ============================================================
@description('Azure リージョン（Bastion Developer 対応リージョンを指定）')
param location string = resourceGroup().location

@description('リソース名プレフィックス')
param prefix string = 'nsp-lab'

@description('VM サイズ（Burstable 推奨）')
param vmSize string = 'Standard_B2s'

@description('管理者ユーザー名')
param adminUsername string = 'azureadmin'

@description('管理者パスワード')
@secure()
param adminPassword string

@description('テスト用 Storage Account 名（グローバル一意）')
param storageAccountTestName string

@description('診断用 Storage Account 名（グローバル一意）')
param storageAccountDiagName string

@description('VNet アドレス空間')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('VM サブネットのアドレスプレフィックス')
param vmSubnetPrefix string = '10.0.0.0/24'

@description('NSP Association の accessMode（Learning = Transition モード）')
@allowed(['Learning', 'Enforced'])
param nspAccessMode string = 'Learning'

@description('ペアリージョン（例: japanwest – japaneast とペアになるリージョン）')
param pairLocation string

@description('ペアリージョン側 VM サイズ')
param pairVmSize string = 'Standard_B2s'

// ============================================================
// Modules
// ============================================================

// ネットワーク（VNet / Subnet / NSG）
module network 'modules/network.bicep' = {
  name: 'network-deployment'
  params: {
    location: location
    prefix: prefix
    vnetAddressPrefix: vnetAddressPrefix
    vmSubnetPrefix: vmSubnetPrefix
  }
}

// ペアリージョン ネットワーク（VNet / Subnet / NSG）
module networkPair 'modules/network.bicep' = {
  name: 'network-pair-deployment'
  params: {
    location: pairLocation
    prefix: '${prefix}-pair'
    vnetAddressPrefix: '10.1.0.0/16'
    vmSubnetPrefix: '10.1.0.0/24'
  }
}

// Azure Bastion（Developer SKU = 無料）
module bastion 'modules/bastion.bicep' = {
  name: 'bastion-deployment'
  params: {
    location: location
    prefix: prefix
    vnetId: network.outputs.vnetId
  }
}

// Windows VM（Standard_B2s, Public IP なし）
module vm 'modules/vm.bicep' = {
  name: 'vm-deployment'
  params: {
    location: location
    prefix: prefix
    vmName: '${prefix}-vm'
    vmSize: vmSize
    subnetId: network.outputs.vmSubnetId
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
}

// ペアリージョン VM（Standard_B2s, Public IP なし）
module vmPair 'modules/vm.bicep' = {
  name: 'vm-pair-deployment'
  params: {
    location: pairLocation
    prefix: '${prefix}-pair'
    vmName: '${prefix}-pair-vm'
    vmSize: pairVmSize
    subnetId: networkPair.outputs.vmSubnetId
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
}

// Storage Account（テスト用 + 診断用）
module storage 'modules/storage.bicep' = {
  name: 'storage-deployment'
  params: {
    location: location
    storageAccountTestName: storageAccountTestName
    storageAccountDiagName: storageAccountDiagName
    vmPrincipalId: vm.outputs.principalId
  }
}

// Network Security Perimeter
module nsp 'modules/nsp.bicep' = {
  name: 'nsp-deployment'
  params: {
    location: location
    prefix: prefix
    storageAccountId: storage.outputs.storageAccountTestId
    diagnosticStorageAccountId: storage.outputs.storageAccountDiagId
    accessMode: nspAccessMode
  }
}

// VNet ピアリング（プライマリ ↔ ペアリージョン）
module peering 'modules/peering.bicep' = {
  name: 'peering-deployment'
  params: {
    vnetAName: network.outputs.vnetName
    vnetAId: network.outputs.vnetId
    vnetBName: networkPair.outputs.vnetName
    vnetBId: networkPair.outputs.vnetId
  }
}

// ============================================================
// Outputs
// ============================================================
output vnetId string = network.outputs.vnetId
output vmId string = vm.outputs.vmId
output vmName string = vm.outputs.vmName
output vmPrivateIP string = vm.outputs.privateIPAddress
output bastionName string = bastion.outputs.bastionName
output storageAccountTestName string = storage.outputs.storageAccountTestName
output storageAccountDiagName string = storage.outputs.storageAccountDiagName
output nspName string = nsp.outputs.nspName
output nspAccessMode string = nsp.outputs.accessMode
output testContainerName string = storage.outputs.testContainerName
// ペアリージョン
output pairVnetId string = networkPair.outputs.vnetId
output pairVmId string = vmPair.outputs.vmId
output pairVmName string = vmPair.outputs.vmName
output pairVmPrivateIP string = vmPair.outputs.privateIPAddress
