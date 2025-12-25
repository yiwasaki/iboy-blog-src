// VM deployment for je-vnet `test` subnet
// Creates Windows Server 2022 VM with public IP and NIC

@description('Deployment location')
param location string = 'japanwest'

@description('Deployment storageLocation')
param storageLocation string = 'japaneast'

@description('Virtual network name')
param vnetName string = 'jw-vnet'

@description('Subnet name')
param subnetName string = 'test-west'

@description('VM name')
param vmName string = 'jw-win2022-01'

@description('Admin username for the VM')
param adminUsername string = 'azureuser'

@secure()
@description('Admin password for the VM')
param adminPassword string

@description('VM size (default 4 vCPU Bv2 series)')
param vmSize string = 'Standard_B4ms'

@description('Resource tags')
param tags object = {
  environment: 'validation'
  purpose: 'network-testing'
}

@description('Storage account name for logs')
param storageAccountTestName string = 'iboystragefwtest100'

@description('Storage account name for diagnostics')
param storageAccountDiagName string = 'iboysadiag100'


// Public IP
resource vmPublicIp 'Microsoft.Network/publicIPAddresses@2022-09-01' = {
  name: '${vmName}-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// Network Interface
resource vmNic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: '${vmName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, subnetName)
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: vmPublicIp.id
          }
        }
      }
    ]
  }
}

// Virtual Machine
resource vmCompute 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: vmName
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'windowsserver'
        sku: '2022-datacenter'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: vmNic.id
        }
      ]
    }
  }
}

@description('Storage account for application / logs target')
resource storageAccountTest 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountTestName
  location: storageLocation
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
  }
}

@description('Storage account to store diagnostics')
resource storageAccountDiag 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountDiagName
  location: storageLocation
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
  }
}

// ===== DIAGNOSTIC SETTINGS =====

@description('Blob service diagnostics: send blob service logs from iboysafwtest100 to iboysadiag100')
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' existing = {
  parent: storageAccountTest
  name: 'default'
}

resource storageDiagBlob 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'iboysafwtest100-blob-to-iboysadiag100'
  scope: blobService
  properties: {
    storageAccountId: storageAccountDiag.id
    logs: [
      {
        category: 'StorageRead'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'StorageWrite'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'StorageDelete'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
    metrics: []
  }
}

@description('File service diagnostics: send file service logs from iboysafwtest100 to iboysadiag100')
resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2023-01-01' existing = {
  parent: storageAccountTest
  name: 'default'
}

resource fileShareTest 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  parent: fileService
  name: 'test'
  properties: {
    shareQuota: 100
  }
}

resource storageDiagFile 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'iboysafwtest100-file-to-iboysadiag100'
  scope: fileService
  properties: {
    storageAccountId: storageAccountDiag.id
    logs: [
      {
        category: 'StorageRead'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'StorageWrite'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'StorageDelete'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
    metrics: []
  }
}

output vmId string = vmCompute.id
output vmPublicIpId string = vmPublicIp.id
