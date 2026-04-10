// ============================================================
// vm.bicep
// Windows VM for Storage Account NSP 検証環境
//
// Standard_B2s (Burstable, 2 vCPU, 4 GB RAM) で低コスト運用
// Public IP なし — Bastion Developer 経由でアクセス
// 自動シャットダウン設定でコスト削減
// ============================================================

@description('Azure リージョン')
param location string

@description('リソース名プレフィックス')
param prefix string

@description('VM 名')
param vmName string = '${prefix}-vm'

@description('VM サイズ（Burstable 推奨）')
param vmSize string = 'Standard_B2s'

@description('VM を配置するサブネットの ID')
param subnetId string

@description('管理者ユーザー名')
param adminUsername string

@description('管理者パスワード')
@secure()
param adminPassword string

@description('OS ディスクのサイズ (GB)')
param osDiskSizeGB int = 128

@description('自動シャットダウン時刻 (HHmm, JST)')
param autoShutdownTime string = '2200'

@description('自動シャットダウンのタイムゾーン')
param autoShutdownTimeZone string = 'Tokyo Standard Time'

// ============================================================
// Network Interface（パブリック IP なし）
// ============================================================
resource nic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: '${vmName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

// ============================================================
// Virtual Machine
// ============================================================
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
        sku: '2022-datacenter-azure-edition'
        version: 'latest'
      }
      osDisk: {
        name: '${vmName}-osdisk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
        diskSizeGB: osDiskSizeGB
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

// ============================================================
// 自動シャットダウン（コスト削減）
// ============================================================
resource autoShutdown 'Microsoft.DevTestLab/schedules@2018-09-15' = {
  name: 'shutdown-computevm-${vmName}'
  location: location
  properties: {
    status: 'Enabled'
    taskType: 'ComputeVmShutdownTask'
    dailyRecurrence: {
      time: autoShutdownTime
    }
    timeZoneId: autoShutdownTimeZone
    targetResourceId: vm.id
    notificationSettings: {
      status: 'Disabled'
    }
  }
}

// ============================================================
// Outputs
// ============================================================
output vmId string = vm.id
output vmName string = vm.name
output nicId string = nic.id
output privateIPAddress string = nic.properties.ipConfigurations[0].properties.privateIPAddress
output principalId string = vm.identity.principalId
