// ============================================================
// peering.bicep
// 双方向 VNet ピアリング
//
// VNet-A → VNet-B / VNet-B → VNet-A を同時に作成する。
// 双方向を 1 ファイルにまとめることで、依存関係を明確にする。
// ============================================================

@description('プライマリ VNet の名前')
param vnetAName string

@description('プライマリ VNet のリソース ID')
param vnetAId string

@description('ペアリージョン VNet の名前')
param vnetBName string

@description('ペアリージョン VNet のリソース ID')
param vnetBId string

// ============================================================
// Peering: VNet-A → VNet-B
// ============================================================
resource peeringAtoB 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-11-01' = {
  name: '${vnetAName}/peering-to-${vnetBName}'
  properties: {
    remoteVirtualNetwork: {
      id: vnetBId
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: false
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}

// ============================================================
// Peering: VNet-B → VNet-A
// ============================================================
resource peeringBtoA 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-11-01' = {
  name: '${vnetBName}/peering-to-${vnetAName}'
  properties: {
    remoteVirtualNetwork: {
      id: vnetAId
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: false
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}

// ============================================================
// Outputs
// ============================================================
output peeringAToBId string = peeringAtoB.id
output peeringBtoAId string = peeringBtoA.id
