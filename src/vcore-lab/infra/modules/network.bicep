// ============================================================
// network.bicep
// VNet / Subnet / NSG for vCore Customization Lab
// ============================================================

@description('Azure リージョン')
param location string

@description('リソース名プレフィックス')
param prefix string

@description('VNet アドレス空間')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('VM サブネットのアドレスプレフィックス')
param vmSubnetPrefix string = '10.0.0.0/24'

// ============================================================
// Network Security Group
// ============================================================
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: '${prefix}-nsg-vm'
  location: location
  properties: {
    securityRules: [
      {
        // Bastion から RDP 接続可能なように VNet からの RDP トラフィックを許可
        name: 'Allow-RDP-from-Bastion'
        properties: {
          priority: 100
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '3389'
        }
      }
      {
        // インターネットからの直接 RDP を拒否
        name: 'Deny-RDP-from-Internet'
        properties: {
          priority: 200
          protocol: 'Tcp'
          access: 'Deny'
          direction: 'Inbound'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '3389'
        }
      }
    ]
  }
}

// ============================================================
// Virtual Network
// ============================================================
resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: '${prefix}-vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'snet-vm'
        properties: {
          addressPrefix: vmSubnetPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
          // プライベートエンドポイントポリシーを有効化（セキュリティ強化）
          privateEndpointNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}

// ============================================================
// Outputs
// ============================================================
output vnetId string = vnet.id
output vnetName string = vnet.name
output vmSubnetId string = vnet.properties.subnets[0].id
output nsgId string = nsg.id
