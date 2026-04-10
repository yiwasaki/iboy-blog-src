using './main.bicep'

// ============================================================
// main.bicepparam
// デプロイパラメータファイル
//
// 使用方法:
//   az deployment group create -g <rg> -f main.bicep -p main.bicepparam
// ============================================================

// ★ 必須: グローバルに一意な Storage Account 名を指定してください（3～24文字、英数字のみ）
param storageAccountTestName = ''   // 例: 'mystoragetest01'
param storageAccountDiagName = ''   // 例: 'mystoragediag01'

// ★ 必須: 管理者パスワード（12文字以上, 大文字・小文字・数字・特殊文字を含む）
param adminPassword = ''   // 例: 'MyP@ssw0rd1234'

// ★ 必須: ペアリージョン（例: japaneast ↔ japanwest）
param pairLocation = 'japanwest'

// オプション（デフォルト値あり）
// param prefix = 'nsp-lab'
// param location = resourceGroup().location
// param vmSize = 'Standard_B2s'
// param adminUsername = 'azureadmin'
// param nspAccessMode = 'Learning'
// param pairVmSize = 'Standard_B2s'
