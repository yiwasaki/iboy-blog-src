// ============================================================
// main.bicep
// VM vCore Customization Feature 検証環境
//
// 使用方法:
//   az deployment group create -g <rg> -f main.bicep -p main.bicepparam
//
//   # パスワードをコマンドラインで指定する場合
//   az deployment group create -g <rg> -f main.bicep -p main.bicepparam adminPassword='<password>'
//
// ⚠️ デプロイ後の vCore 設定変更は az vm update で実施してください
// ============================================================

targetScope = 'resourceGroup'

// ============================================================
// Parameters
// ============================================================
@description('Azure リージョン（Bastion Developer 対応リージョンを指定）')
param location string = resourceGroup().location

@description('リソース名プレフィックス')
param prefix string = 'vcore-lab'

@description('VM サイズ（vCore Customization Feature 対応サイズ）')
param vmSize string = 'Standard_D8as_v6'

@description('管理者ユーザー名')
param adminUsername string = 'azureadmin'

@description('管理者パスワード')
@secure()
param adminPassword string

@description('アクティブ vCPU 数')
@minValue(1)
param vcpusAvailable int = 2

@description('スレッド/コア数（1 = SMT 無効 = 物理コアのみ, 2 = デフォルト / SMT 有効）')
@allowed([1, 2])
param vcpusPerCore int = 1

@description('VNet アドレス空間')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('VM サブネットのアドレスプレフィックス')
param vmSubnetPrefix string = '10.0.0.0/24'

@description('OS ディスクのサイズ (GB)')
param osDiskSizeGB int = 128

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

// Azure Bastion（Developer SKU = 無料）
module bastion 'modules/bastion.bicep' = {
  name: 'bastion-deployment'
  params: {
    location: location
    prefix: prefix
    vnetId: network.outputs.vnetId
  }
}

// Windows VM（vCore Customization Feature）
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
    vcpusAvailable: vcpusAvailable
    vcpusPerCore: vcpusPerCore
    osDiskSizeGB: osDiskSizeGB
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
output effectiveVcpusAvailable int = vcpusAvailable
output effectiveVcpusPerCore int = vcpusPerCore

@description('現在の vCore 設定サマリー')
output vcoreConfigSummary string = 'vCPUsAvailable=${vcpusAvailable}, vCPUsPerCore=${vcpusPerCore} (SMT ${vcpusPerCore == 1 ? 'disabled' : 'enabled'})'
