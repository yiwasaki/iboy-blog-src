using './main.bicep'

// ============================================================
// main.bicepparam
// Azure Machine Configuration (Ubuntu auditd) 検証用パラメーター
// ============================================================

// デプロイ先リージョン
param location = 'japaneast'

// リソース名プレフィックス
param resourcePrefix = 'gcauditd'

// VM 管理者ユーザー名
param adminUsername = 'azureuser'

// VM ログイン用管理者パスワード（デプロイ時に必ず置き換えて使用）
param adminPassword = 'ChangeMe-P@ssw0rd!'

// 検証コストを抑える既定サイズ
param vmSize = 'Standard_B2s'

// ネットワーク
param vnetAddressPrefix = '10.20.0.0/16'
param vmSubnetPrefix = '10.20.1.0/24'
param privateEndpointSubnetPrefix = '10.20.2.0/24'

// 構成パッケージ格納コンテナー
param packageContainerName = 'machine-configuration'

// 構成パッケージをアップロードするユーザーの Microsoft Entra object ID（置き換えて使用）
param packageUploaderPrincipalId = '<Object ID>'
