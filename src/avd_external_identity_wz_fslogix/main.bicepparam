using './main.bicep'

// デプロイ先リージョン
param location = 'japaneast'

// リソース名のプレフィックス (英小文字・数字のみ、最大 8 文字)
// 例: 'avdfsl', 'avdlab', 'myavd'
param resourcePrefix = 'avdfsl'

// セッションホスト VM の管理者ユーザー名
param vmAdminUsername = 'avdadmin'

// セッションホスト VM の管理者パスワード
// ※ デプロイ時にコマンドラインで指定すること (最低 12 文字、英大文字・英小文字・数字・記号を含む)
//   例: az deployment group create ... --parameters vmAdminPassword='<強力なパスワード>'
// param vmAdminPassword = ''  // ← パスワードはファイルに記載せずコマンドラインで渡すこと

// FSLogix プロファイル格納用 Storage Account 名 (グローバル一意、3-24 文字、英小文字・数字のみ)
// 未指定時は uniqueString(resourceGroup().id) から自動採番される
// param profileStorageAccountName = 'fslprofiles<unique>'

// FSLogix プロファイル用ファイル共有名
param profileShareName = 'profiles'

// FSLogix プロファイル用ファイル共有のクォータ (GiB)
param profileShareQuotaGiB = 100
