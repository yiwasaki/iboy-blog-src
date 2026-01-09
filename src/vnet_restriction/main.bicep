// パラメータ
@description('デプロイするリージョン')
param location string = resourceGroup().location

@description('VNetのアドレス空間')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('VMサブネットのアドレス空間')
param vmSubnetAddressPrefix string = '10.0.1.0/24'

@description('VM管理者ユーザー名')
param adminUsername string

@secure()
@description('VM管理者パスワード')
param adminPassword string

// 変数
var vnetName = 'test-vnet'
var vmSubnetName = 'vm-subnet'
var vmName = 'test-vm'
var nicName = '${vmName}-nic'
var bastionName = 'test-bastion'

// VNet
resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: vmSubnetName
        properties: {
          addressPrefix: vmSubnetAddressPrefix
        }
      }
    ]
  }
}

// VMサブネットの参照
resource vmSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' existing = {
  parent: vnet
  name: vmSubnetName
}

// VMのネットワークインターフェイス
resource nic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: vmSubnet.id
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

// Windows Server VM
resource vm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B4ms'
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter'
        version: 'latest'
      }
      osDisk: {
        name: '${vmName}-osdisk'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
        deleteOption: 'Delete'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
  }
}

// Azure Bastion (Developer Tier)
// Developer Tier では、VNetの参照は必須です
resource bastion 'Microsoft.Network/bastionHosts@2023-11-01' = {
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

// 出力
output vnetId string = vnet.id
output vmId string = vm.id
output bastionId string = bastion.id
output vmPrivateIp string = nic.properties.ipConfigurations[0].properties.privateIPAddress
