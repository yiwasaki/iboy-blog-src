// ============================================================
// bastion.bicep
// Azure Bastion Developer SKU (無料)
// ============================================================
// Developer SKU は:
//   - AzureBastionSubnet が不要
//   - Public IP が不要
//   - VNet ID の参照のみ必要
//   - 共有プールアーキテクチャ（接続時に自動デプロイ）
// ============================================================

@description('Azure リージョン')
param location string

@description('リソース名プレフィックス')
param prefix string

@description('Bastion を関連付ける VNet の ID')
param vnetId string

// ============================================================
// Bastion Host (Developer SKU)
// ============================================================
resource bastion 'Microsoft.Network/bastionHosts@2023-11-01' = {
  name: '${prefix}-bastion'
  location: location
  sku: {
    name: 'Developer'
  }
  properties: {
    virtualNetwork: {
      id: vnetId
    }
  }
}

// ============================================================
// Outputs
// ============================================================
output bastionId string = bastion.id
output bastionName string = bastion.name
