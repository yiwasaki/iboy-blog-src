// ============================================================
// assignment.bicep
// 既存 VM への Guest Configuration Assignment（単体割り当て）
//
// 複数台への配布は Azure Policy（New-GuestConfigurationPolicy）を使う。
// これは 1台の検証・少数の明示対象向け。
// ============================================================

@description('デプロイ先リージョン')
param location string = resourceGroup().location

@description('対象 VM 名')
param vmName string

@description('Guest Configuration Assignment 名（package の Name と一致させる）')
param guestConfigurationName string = 'MyServiceConfig'

@description('構成パッケージ ZIP の URI')
param packageContentUri string

@description('構成パッケージ ZIP の SHA-256（64文字の16進数）')
param packageContentHash string

@description('パッケージの version（更新時は ZIP 名ごと変えて contentUri/contentHash も更新する）')
param packageVersion string = '1.0.0'

@description('VM 上での適用方針。既定は安全側の Audit')
@allowed([
  'Audit'
  'ApplyAndMonitor'
  'ApplyAndAutoCorrect'
])
param assignmentType string = 'Audit'

resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' existing = {
  name: vmName
}

resource guestAssignment 'Microsoft.GuestConfiguration/guestConfigurationAssignments@2024-04-05' = {
  name: guestConfigurationName
  scope: vm
  location: location
  properties: {
    guestConfiguration: {
      name: guestConfigurationName
      kind: 'DSC'
      contentUri: packageContentUri
      contentHash: packageContentHash
      version: packageVersion
      assignmentType: assignmentType
    }
  }
}

output assignmentName string = guestAssignment.name
