// ============================================================
// vm.bicep
// Windows VM with VM vCore Customization Feature (Preview)
//
// vcpusAvailable / vcpusPerCore で vCore 設定を制御
// デプロイ後の変更は az vm update で実施してください
//
// ⚠️ vCore 設定の変更には VM の割当解除が必要（動的変更不可）
// ============================================================

@description('Azure リージョン')
param location string

@description('リソース名プレフィックス')
param prefix string

@description('VM 名')
param vmName string = '${prefix}-vm'

@description('VM サイズ')
param vmSize string = 'Standard_D4s_v5'

@description('VM を配置するサブネットの ID')
param subnetId string

@description('管理者ユーザー名')
param adminUsername string

@description('管理者パスワード')
@secure()
param adminPassword string

@description('アクティブ vCPU 数')
@minValue(1)
param vcpusAvailable int = 2

@description('スレッド/コア数（1 = SMT 無効, 2 = デフォルト）')
@allowed([1, 2])
param vcpusPerCore int = 1

@description('OS ディスクのサイズ (GB)')
param osDiskSizeGB int = 128

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
          // パブリック IP は付与しない（Bastion 経由でアクセス）
        }
      }
    ]
  }
}

// ============================================================
// Virtual Machine
// vmSizeProperties は enableVcoreConstraint フラグで条件付き設定
// API バージョン 2021-07-01 以降が vmSizeProperties をサポート
// ============================================================
resource vm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
      vmSizeProperties: {
        vCPUsAvailable: vcpusAvailable
        vCPUsPerCore: vcpusPerCore
      }
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
          storageAccountType: 'Premium_LRS'
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
        // ストレージアカウント未指定 = マネージドストレージ使用（追加コストなし）
        enabled: true
      }
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
output effectiveVcpusAvailable int = vcpusAvailable
output effectiveVcpusPerCore int = vcpusPerCore
