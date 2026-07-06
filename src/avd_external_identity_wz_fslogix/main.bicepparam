using './main.bicep'

// デプロイ先リージョン
param location = 'japaneast'

// リソース名のプレフィックス (英小文字・数字のみ、最大 8 文字)
// 例: 'avdfsl', 'avdlab', 'myavd'
param resourcePrefix = 'avdfsl'

// セッションホスト VM の管理者ユーザー名 (固定値)
param vmAdminUsername = 'avdadmin'

// セッションホスト VM の管理者パスワード — 既存 Key Vault のシークレットから取得
// getSecret('<サブスクリプション ID>', '<Key Vault のリソースグループ名>', '<Key Vault 名>', '<シークレット名>')
// 例: getSecret('xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'rg-keyvault', 'kv-lab', 'vm-admin-password')
param vmAdminPassword = getSecret('<subscriptionId>', '<keyVaultResourceGroupName>', '<keyVaultName>', '<vm-admin-password>')

// FSLogix プロファイル格納用 Storage Account 名 (グローバル一意、3-24 文字、英小文字・数字のみ)
// 未指定時は uniqueString(resourceGroup().id) から自動採番される
// param profileStorageAccountName = 'fslprofiles<unique>'

// FSLogix プロファイル用ファイル共有名
param profileShareName = 'profiles'

// FSLogix プロファイル用ファイル共有のクォータ (GiB)
param profileShareQuotaGiB = 100
