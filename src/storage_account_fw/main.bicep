// Virtual Networks deployment for multi-region network validation environment
// Regions: Japan East (je-vnet), Japan West (jw-vnet), Southeast Asia (sea-vnet)

metadata description = 'Create three regional Virtual Networks with subnets for network validation'

// ===== PARAMETERS =====

@description('Deployment location for East Japan VNet')
param locationEastJapan string = 'japaneast'

@description('Deployment location for West Japan VNet')
param locationWestJapan string = 'japanwest'

@description('Deployment location for Southeast Asia VNet')
param locationSoutheastAsia string = 'southeastasia'

@description('VNet name for East Japan region')
param vnetEastJapanName string = 'je-vnet'

@description('VNet name for West Japan region')
param vnetWestJapanName string = 'jw-vnet'

@description('VNet name for Southeast Asia region')
param vnetSoutheastAsiaName string = 'sea-vnet'

@description('Resource tags')
param tags object = {
  environment: 'validation'
  purpose: 'network-testing'
}

// ===== VARIABLES =====

// East Japan VNet configuration
var vnetEastJapanAddressSpace = '172.30.0.0/23'
var subnetTestEastJapan = '172.30.0.0/24'
// Split firewall network into data plane and management plane (Basic SKU requirement)
var subnetAzureFirewallEastJapan = '172.30.1.0/26'
var subnetAzureFirewallManagementEastJapan = '172.30.1.64/26'

// West Japan VNet configuration
var vnetWestJapanAddressSpace = '172.30.10.0/24'
var subnetTestWestJapan = '172.30.10.0/25'

// Southeast Asia VNet configuration
var vnetSoutheastAsiaAddressSpace = '172.30.20.0/24'
var subnetTestSoutheastAsia = '172.30.20.0/25'

// ===== RESOURCES =====

// ===== EAST JAPAN VNET AND SUBNETS =====
@description('Virtual Network in Japan East region')
resource vnetEastJapan 'Microsoft.Network/virtualNetworks@2024-03-01' = {
  name: vnetEastJapanName
  location: locationEastJapan
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetEastJapanAddressSpace
      ]
    }
    subnets: [
      {
        name: 'test'
        properties: {
          addressPrefix: subnetTestEastJapan
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
            }
          ]
        }
      }
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: subnetAzureFirewallEastJapan
        }
      }
      {
        name: 'AzureFirewallManagementSubnet'
        properties: {
          addressPrefix: subnetAzureFirewallManagementEastJapan
        }
      }
    ]
  }
}

// ===== WEST JAPAN VNET AND SUBNETS =====
@description('Virtual Network in Japan West region')
resource vnetWestJapan 'Microsoft.Network/virtualNetworks@2024-03-01' = {
  name: vnetWestJapanName
  location: locationWestJapan
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetWestJapanAddressSpace
      ]
    }
    subnets: [
      {
        name: 'test-west'
        properties: {
          addressPrefix: subnetTestWestJapan
        }
      }
    ]
  }
}

// ===== SOUTHEAST ASIA VNET AND SUBNETS =====
@description('Virtual Network in Southeast Asia region')
resource vnetSoutheastAsia 'Microsoft.Network/virtualNetworks@2024-03-01' = {
  name: vnetSoutheastAsiaName
  location: locationSoutheastAsia
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetSoutheastAsiaAddressSpace
      ]
    }
    subnets: [
      {
        name: 'test-sea'
        properties: {
          addressPrefix: subnetTestSoutheastAsia
        }
      }
    ]
  }
}

// ===== VNET PEERINGS =====

@description('Peering: je-vnet -> jw-vnet')
resource peeringEastToWest 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-03-01' = {
  parent: vnetEastJapan
  name: 'peering-east-to-west'
  properties: {
    remoteVirtualNetwork: {
      id: vnetWestJapan.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: false
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}

@description('Peering: jw-vnet -> je-vnet')
resource peeringWestToEast 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-03-01' = {
  parent: vnetWestJapan
  name: 'peering-west-to-east'
  properties: {
    remoteVirtualNetwork: {
      id: vnetEastJapan.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: false
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}

@description('Peering: je-vnet -> sea-vnet')
resource peeringEastToSea 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-03-01' = {
  parent: vnetEastJapan
  name: 'peering-east-to-sea'
  properties: {
    remoteVirtualNetwork: {
      id: vnetSoutheastAsia.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: false
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}

@description('Peering: sea-vnet -> je-vnet')
resource peeringSeaToEast 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-03-01' = {
  parent: vnetSoutheastAsia
  name: 'peering-sea-to-east'
  properties: {
    remoteVirtualNetwork: {
      id: vnetEastJapan.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: false
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}

// ===== OUTPUTS =====


@description('East Japan VNet resource ID')
output vnetEastJapanId string = vnetEastJapan.id

@description('East Japan VNet name')
output vnetEastJapanName string = vnetEastJapan.name

@description('West Japan VNet resource ID')
output vnetWestJapanId string = vnetWestJapan.id

@description('West Japan VNet name')
output vnetWestJapanName string = vnetWestJapan.name

@description('Southeast Asia VNet resource ID')
output vnetSoutheastAsiaId string = vnetSoutheastAsia.id

@description('Southeast Asia VNet name')
output vnetSoutheastAsiaName string = vnetSoutheastAsia.name
