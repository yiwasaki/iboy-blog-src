// Windows Server 2022 VM with Azure Entra ID authentication

@description('The location for all resources')
param location string = 'japaneast'

@description('The name of the virtual machine')
param vmName string = 'test-vm'

@description('The size of the virtual machine')
param vmSize string = 'Standard_D2s_v3'

@description('The admin username for the VM')
param adminUsername string = 'testadm'

@description('The admin password for the VM')
@secure()
param adminPassword string

@description('The name prefix for network resources')
param networkPrefix string = 'test'

// Variables
var vnetName = '${networkPrefix}-vnet'
var subnetName = 'default'
var nicName = '${vmName}-nic'
var osDiskName = '${vmName}-osdisk'

// Jumpbox VM variables
var jumpboxVmName = 'jumpbox'
var jumpboxNicName = '${jumpboxVmName}-nic'
var jumpboxOsDiskName = '${jumpboxVmName}-osdisk'

// Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
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
        name: subnetName
        properties: {
          addressPrefix: '10.0.0.0/24'
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.0.1.0/26'
        }
      }
    ]
  }
}

// Network Interface
resource nic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
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

// Virtual Machine
resource vm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: vmName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
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
        patchSettings: {
          patchMode: 'AutomaticByOS'
          assessmentMode: 'ImageDefault'
        }
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
        name: osDiskName
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
        caching: 'ReadWrite'
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

// AAD Login for Windows Extension
resource aadLoginExtension 'Microsoft.Compute/virtualMachines/extensions@2024-03-01' = {
  parent: vm
  name: 'AADLoginForWindows'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: 'AADLoginForWindows'
    typeHandlerVersion: '2.0'
    autoUpgradeMinorVersion: true
    settings: {
      mdmId: ''
    }
  }
}

// Jumpbox Network Interface
resource jumpboxNic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: jumpboxNicName
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

// Jumpbox Virtual Machine
resource jumpboxVm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: jumpboxVmName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: jumpboxVmName
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
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter'
        version: 'latest'
      }
      osDisk: {
        name: jumpboxOsDiskName
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
        caching: 'ReadWrite'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: jumpboxNic.id
        }
      ]
    }
  }
}

// Jumpbox AAD Login for Windows Extension
resource jumpboxAadLoginExtension 'Microsoft.Compute/virtualMachines/extensions@2024-03-01' = {
  parent: jumpboxVm
  name: 'AADLoginForWindows'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: 'AADLoginForWindows'
    typeHandlerVersion: '2.0'
    autoUpgradeMinorVersion: true
    settings: {
      mdmId: ''
    }
  }
}

// Azure Bastion (Developer SKU)
resource bastion 'Microsoft.Network/bastionHosts@2023-11-01' = {
  name: '${networkPrefix}-bastion'
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

// Outputs
output vmName string = vm.name
output vmId string = vm.id
output privateIpAddress string = nic.properties.ipConfigurations[0].properties.privateIPAddress

// Jumpbox Outputs
output jumpboxVmName string = jumpboxVm.name
output jumpboxVmId string = jumpboxVm.id
output jumpboxPrivateIpAddress string = jumpboxNic.properties.ipConfigurations[0].properties.privateIPAddress

// Bastion Outputs
output bastionName string = bastion.name
output bastionId string = bastion.id

// Network Outputs
output vnetName string = vnet.name
output vnetId string = vnet.id
output subnetId string = vnet.properties.subnets[0].id
