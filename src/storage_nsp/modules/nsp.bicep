// ============================================================
// nsp.bicep
// Network Security Perimeter (NSP) for Storage Account 検証環境
//
// NSP 本体 + Profile + Access Rules + Storage Account Association
//
// accessMode:
//   'Learning'  = Transition モード（旧称 Learning）: NSP ルール + 既存 FW ルールの併用
//   'Enforced'  = Enforced モード: NSP ルールのみで制御
//
// ⚠️ Bicep API 上の値は 'Learning' だが、ドキュメント上は
//    "Transition mode (formerly Learning mode)" と記載
// ============================================================

@description('Azure リージョン')
param location string

@description('リソース名プレフィックス')
param prefix string

@description('NSP に関連付ける Storage Account の Resource ID')
param storageAccountId string

@description('NSP 診断ログの保存先 Storage Account の Resource ID')
param diagnosticStorageAccountId string

@description('NSP Association の accessMode')
@allowed(['Learning', 'Enforced'])
param accessMode string = 'Learning'

// ============================================================
// Network Security Perimeter
// ============================================================
resource nsp 'Microsoft.Network/networkSecurityPerimeters@2025-05-01' = {
  name: '${prefix}-nsp'
  location: location
  properties: {}
}

// ============================================================
// Profile
// ============================================================
resource profile 'Microsoft.Network/networkSecurityPerimeters/profiles@2025-05-01' = {
  parent: nsp
  name: 'default-profile'
  properties: {}
}

// ============================================================
// Access Rules
// ============================================================

// Inbound: サブスクリプションベースのアクセス許可
resource ruleSubscription 'Microsoft.Network/networkSecurityPerimeters/profiles/accessRules@2025-05-01' = {
  parent: profile
  name: 'allow-subscription'
  properties: {
    direction: 'Inbound'
    subscriptions: [
      {
        id: '/subscriptions/${subscription().subscriptionId}'
      }
    ]
  }
}

// ============================================================
// Resource Association（Storage Account を NSP に関連付け）
// ============================================================
resource association 'Microsoft.Network/networkSecurityPerimeters/resourceAssociations@2025-05-01' = {
  parent: nsp
  name: '${prefix}-sa-association'
  properties: {
    accessMode: accessMode
    privateLinkResource: {
      id: storageAccountId
    }
    profile: {
      id: profile.id
    }
  }
}

// 診断用 Storage Account も同一 NSP に関連付け（NSP 未紐付けだとログ出力が遮断される）
resource associationDiag 'Microsoft.Network/networkSecurityPerimeters/resourceAssociations@2025-05-01' = {
  parent: nsp
  name: '${prefix}-sa-diag-association'
  properties: {
    accessMode: accessMode
    privateLinkResource: {
      id: diagnosticStorageAccountId
    }
    profile: {
      id: profile.id
    }
  }
}

// NSP Diagnostic Settings（すべてのログを診断用 Storage Account に保存）
resource nspDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${prefix}-nsp-diag'
  scope: nsp
  properties: {
    storageAccountId: diagnosticStorageAccountId
    logs: [
      {
        categoryGroup: 'allLogs'
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

// ============================================================
// Outputs
// ============================================================
output nspId string = nsp.id
output nspName string = nsp.name
output profileId string = profile.id
output profileName string = profile.name
output associationId string = association.id
output associationDiagId string = associationDiag.id
output accessMode string = accessMode
