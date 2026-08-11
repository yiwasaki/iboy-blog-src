// ============================================================
// modules/vm.bicep
// Ubuntu VM + Guest Configuration Extension
// ============================================================

@description('デプロイ先リージョン')
param location string

@description('リソース名プレフィックス')
param resourcePrefix string

@description('VM 管理者ユーザー名')
param adminUsername string

@description('VM ログイン用管理者パスワード')
@secure()
param adminPassword string

@description('VM サイズ')
param vmSize string

@description('VM を配置するサブネット ID')
param vmSubnetId string

@description('VM に関連付ける Public IP のリソース ID')
param publicIpId string

var vmName = '${resourcePrefix}-vm'
var nicName = '${vmName}-nic'

resource nic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vmSubnetId
          }
          publicIPAddress: {
            id: publicIpId
          }
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vmName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'ubuntu-24_04-lts'
        sku: 'server'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
        caching: 'ReadWrite'
      }
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
        provisionVMAgent: true
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

// 拡張機能は自動更新を有効にし、Apply 構成に必要なバージョン帯を取り込む
resource guestConfigurationExtension 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = {
  parent: vm
  name: 'GuestConfiguration'
  location: location
  properties: {
    publisher: 'Microsoft.GuestConfiguration'
    type: 'ConfigurationforLinux'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
    settings: {}
    protectedSettings: {}
  }
}

output vmName string = vm.name
output vmId string = vm.id
output vmPrincipalId string = vm.identity.principalId
