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

@description('Allowed source IP address for RDP access. Use * to allow from any IP address.')
param allowedSourceIpAddress string = '*'

@description('The name of the storage account')
param storageAccountName string

@description('The name of the file share')
param fileShareName string = 'fileshare'

@description('The quota of the file share in GiB')
param fileShareQuota int = 100

// Variables
var vnetName = '${networkPrefix}-vnet'
var subnetName = 'default'
var nsgName = '${networkPrefix}-nsg'
var nicName = '${vmName}-nic'
var publicIpName = '${vmName}-pip'
var osDiskName = '${vmName}-osdisk'

// Jumpbox VM variables
var jumpboxVmName = 'jumpbox'
var jumpboxNicName = '${jumpboxVmName}-nic'
var jumpboxPublicIpName = '${jumpboxVmName}-pip'
var jumpboxOsDiskName = '${jumpboxVmName}-osdisk'

// Storage variables
var storageAccountNameCleaned = replace(storageAccountName, '-', '')

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
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

// Network Security Group
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowRDP'
        properties: {
          priority: 1000
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: allowedSourceIpAddress
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '3389'
        }
      }
    ]
  }
}

// Public IP Address
resource publicIp 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: publicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
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
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: nsg.id
    }
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
          storageAccountType: 'Premium_LRS'
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

// Jumpbox Public IP Address
resource jumpboxPublicIp 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: jumpboxPublicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
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
          publicIPAddress: {
            id: jumpboxPublicIp.id
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: nsg.id
    }
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
          storageAccountType: 'Premium_LRS'
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

// Storage Account with Azure Files and Entra Kerberos
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountNameCleaned
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
    azureFilesIdentityBasedAuthentication: {
      directoryServiceOptions: 'AADKERB'
      defaultSharePermission: 'StorageFileDataSmbShareElevatedContributor'
    }
  }
}

// File Service
resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    protocolSettings: {
      smb: {
        versions: 'SMB3.0;SMB3.1.1'
        authenticationMethods: 'Kerberos'
        kerberosTicketEncryption: 'AES-256'
        channelEncryption: 'AES-128-GCM;AES-256-GCM'
      }
    }
  }
}

// File Share
resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-05-01' = {
  parent: fileService
  name: fileShareName
  properties: {
    shareQuota: fileShareQuota
    enabledProtocols: 'SMB'
    accessTier: 'TransactionOptimized'
  }
}

// Outputs
output vmName string = vm.name
output vmId string = vm.id
output publicIpAddress string = publicIp.properties.ipAddress
output privateIpAddress string = nic.properties.ipConfigurations[0].properties.privateIPAddress
output vmResourceId string = vm.id

// Jumpbox Outputs
output jumpboxVmName string = jumpboxVm.name
output jumpboxVmId string = jumpboxVm.id
output jumpboxPublicIpAddress string = jumpboxPublicIp.properties.ipAddress
output jumpboxPrivateIpAddress string = jumpboxNic.properties.ipConfigurations[0].properties.privateIPAddress
output jumpboxVmResourceId string = jumpboxVm.id

// Storage Outputs
output storageAccountName string = storageAccount.name
output storageAccountId string = storageAccount.id
output fileShareName string = fileShare.name
output fileShareUrl string = '\\\\${storageAccount.name}.file.${environment().suffixes.storage}\\${fileShareName}'
