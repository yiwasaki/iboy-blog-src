@description('デプロイするリージョン')
param location string = resourceGroup().location

@description('VM管理者ユーザー名')
@minLength(1)
@maxLength(20)
param adminUsername string

@secure()
@description('VM管理者パスワード')
@minLength(12)
@maxLength(123)
param adminPassword string

@description('NVMe非対応のVMサイズ')
param vmSize string = 'Standard_D2s_v4'

@description('VNetのアドレス空間')
param vnetAddressPrefix string = '10.10.0.0/16'

@description('VMサブネットのアドレス空間')
param vmSubnetAddressPrefix string = '10.10.1.0/24'

var vnetName = 'nvme-vnet'
var vmSubnetName = 'vm-subnet'
var vmName = 'nvme-win2025-vm'
var nicName = '${vmName}-nic'
var osDiskName = '${vmName}-osdisk'
var bastionName = 'nvme-bastion'

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

resource vm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
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
        sku: '2025-datacenter-g2'
        version: 'latest'
      }
      osDisk: {
        name: osDiskName
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
        caching: 'ReadWrite'
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

output vmId string = vm.id
output vmPrivateIp string = nic.properties.ipConfigurations[0].properties.privateIPAddress
output bastionId string = bastion.id
output vnetId string = vnet.id
