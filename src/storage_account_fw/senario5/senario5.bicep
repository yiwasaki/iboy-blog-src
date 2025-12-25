// VM deployment for je-vnet `test` subnet
// Creates Windows Server 2022 VM with public IP and NIC

@description('Deployment location')
param location string = 'southeastasia'

@description('Deployment storageLocation')
param storageLocation string = 'japaneast'

@description('Virtual network name')
param vnetName string = 'sea-vnet'

@description('Subnet name')
param subnetName string = 'test-sea'

@description('Subnet address prefix (existing value)')
param subnetAddressPrefix string = '172.30.20.0/25'

@description('VM name')
param vmName string = 'sea-win2022-01'

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

@description('Source IP address for RDP access')
param sourceRdpIp string = '*'

@description('Virtual network name for East Japan (Firewall location)')
param vnetEastJapanName string = 'je-vnet'

@description('Location for Azure Firewall deployment (East Japan)')
param locationEastJapan string = 'japaneast'

// Existing Virtual Network - Southeast Asia (test VM)
resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: vnetName
}

// Existing Virtual Network - East Japan (Azure Firewall)
resource vnetEastJapan 'Microsoft.Network/virtualNetworks@2024-07-01' existing = {
  name: vnetEastJapanName
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-11-01'= {
  name: 'sea-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-RDP'
        properties: {
          priority: 1000
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: sourceRdpIp
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '3389'
        }
      }
    ]
  } 
}

// Subnet with service endpoint
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = {
  parent: vnet
  name: subnetName
  properties: {
    addressPrefix: subnetAddressPrefix
    networkSecurityGroup:{
      id: nsg.id
    }
    routeTable: {
      id: routeTableSeaUdr.id
    }
    serviceEndpoints: [
      {
        service: 'Microsoft.Storage'
      }
    ]
  }
}

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

// ===== AZURE FIREWALL DEPLOYMENT =====

// Azure Firewall Public IP (East Japan)
resource fwPublicIp 'Microsoft.Network/publicIPAddresses@2024-07-01' = {
  name: 'fw-pip-japaneast'
  location: locationEastJapan
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// Azure Firewall Management Public IP (Required for Basic SKU)
resource fwManagementPublicIp 'Microsoft.Network/publicIPAddresses@2024-07-01' = {
  name: 'fw-mgmt-pip-japaneast'
  location: locationEastJapan
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// Azure Firewall (Basic SKU - minimum cost)
resource azureFirewall 'Microsoft.Network/azureFirewalls@2024-07-01' = {
  name: 'fw-japaneast'
  location: locationEastJapan
  tags: tags
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Basic'
    }
    threatIntelMode: 'Alert'
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: '${vnetEastJapan.id}/subnets/AzureFirewallSubnet'
          }
          publicIPAddress: {
            id: fwPublicIp.id
          }
        }
      }
    ]
    managementIpConfiguration: {
      name: 'mgmt-ipconfig'
      properties: {
        subnet: {
          id: '${vnetEastJapan.id}/subnets/AzureFirewallManagementSubnet'
        }
        publicIPAddress: {
          id: fwManagementPublicIp.id
        }
      }
    }
    networkRuleCollections: [
      {
        name: 'AllowAll'
        properties: {
          priority: 100
          action: {
            type: 'Allow'
          }
          rules: [
            {
              name: 'AllowAllOutbound'
              protocols: [
                'TCP'
                'UDP'
              ]
              sourceAddresses: [
                '*'
              ]
              destinationAddresses: [
                '*'
              ]
              destinationPorts: [
                '*'
              ]
            }
          ]
        }
      }
    ]
  }
}

// User Defined Route (UDR) Table for Southeast Asia Subnet
resource routeTableSeaUdr 'Microsoft.Network/routeTables@2024-07-01' = {
  name: 'udr-sea-to-firewall'
  location: location
  tags: tags
  properties: {
    disableBgpRoutePropagation: false
    routes: sourceRdpIp != '*' ? [
      {
        name: 'RouteToRdpSource'
        properties: {
          addressPrefix: '${sourceRdpIp}/32'
          nextHopType: 'Internet'
        }
      }
      {
        name: 'RouteToFirewall'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: azureFirewall.properties.ipConfigurations[0].properties.privateIPAddress
        }
      }
    ] : [
      {
        name: 'RouteToFirewall'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: azureFirewall.properties.ipConfigurations[0].properties.privateIPAddress
        }
      }
    ]
  }
}

output vmId string = vmCompute.id
output vmPublicIpId string = vmPublicIp.id
output azureFirewallId string = azureFirewall.id
output azureFirewallPrivateIp string = azureFirewall.properties.ipConfigurations[0].properties.privateIPAddress
output routeTableId string = routeTableSeaUdr.id
