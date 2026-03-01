// 検証用 VM および関連リソース (VNet, Bastion, NIC, Role Assignment)
// 単独でデプロイ可能なテンプレートです

@description('リソースのデプロイ先リージョン')
param location string = 'japaneast'

@description('リソース名のプレフィックス')
param resourcePrefix string = 'filesmi'

@description('VM の管理者ユーザー名')
param adminUsername string = 'azureuser'

@description('VM の管理者パスワード')
@secure()
param adminPassword string

@description('ロール割り当て対象のストレージアカウント名')
param storageAccountName string

// 変数定義
var vnetName = '${resourcePrefix}-vnet'
var vmSubnetName = 'vm-subnet'
var bastionName = '${resourcePrefix}-bastion'
var vmName = '${resourcePrefix}-vm'
var nicName = '${vmName}-nic'

// ストレージアカウントのロールID
// Storage File Data SMB MI Admin
var storageFileDataSmbMiAdminRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a235d3ee-5935-4cfb-8cc5-a3303ad5995e')

// 既存のストレージアカウントを参照
resource storageAccount 'Microsoft.Storage/storageAccounts@2025-01-01' existing = {
  name: storageAccountName
}

// Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: vmSubnetName
        properties: {
          addressPrefix: '10.0.1.0/24'
        }
      }
    ]
  }
}

// Bastion (Developer SKU)
// Developer SKU では、VNet参照のみで動作します（Public IPやBastionSubnetは不要）
resource bastion 'Microsoft.Network/bastionHosts@2023-09-01' = {
  name: bastionName
  location: location
  sku: {
    name: 'Developer'
  }
  properties: {
    virtualNetwork: {
      id: vnet.id
    }
  }
}

// Network Interface for VM
resource nic 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: nicName
  location: location
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

// Windows VM
resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vmName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D4s_v6'
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-azure-edition'
        version: 'latest'
      }
      osDisk: {
        name: '${vmName}-osdisk'
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
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
        patchSettings: {
          patchMode: 'AutomaticByOS'
          assessmentMode: 'ImageDefault'
        }
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

// Role Assignment: Storage File Data SMB MI Admin
// VMのマネージドIDに対してストレージアカウントへのアクセス権を付与
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, vm.id, storageFileDataSmbMiAdminRoleId)
  scope: storageAccount
  properties: {
    roleDefinitionId: storageFileDataSmbMiAdminRoleId
    principalId: vm.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// 出力
output vmName string = vm.name
output vmPrincipalId string = vm.identity.principalId
output bastionName string = bastion.name
output vnetName string = vnet.name
