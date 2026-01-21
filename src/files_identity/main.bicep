// Storage Account with Azure Files and Entra Kerberos authentication

@description('The location for all resources')
param location string = 'japaneast'

@description('The name of the storage account')
param storageAccountName string

@description('The name of the file share')
param fileShareName string = 'fileshare'

@description('The quota of the file share in GiB')
param fileShareQuota int = 100

// Storage variables
var storageAccountNameCleaned = replace(storageAccountName, '-', '')

// Storage Account with Azure Files and Entra Kerberos
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountNameCleaned
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
    azureFilesIdentityBasedAuthentication: {
      directoryServiceOptions: 'AADKERB'
      defaultSharePermission: 'StorageFileDataSmbShareElevatedContributor'
    }
  }
}

// File Service
resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    protocolSettings: {
      smb: {
        versions: 'SMB3.0;SMB3.1.1'
        authenticationMethods: 'Kerberos'
        kerberosTicketEncryption: 'AES-256'
        channelEncryption: 'AES-128-GCM;AES-256-GCM'
      }
    }
  }
}

// File Share
resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-05-01' = {
  parent: fileService
  name: fileShareName
  properties: {
    shareQuota: fileShareQuota
    enabledProtocols: 'SMB'
    accessTier: 'TransactionOptimized'
  }
}

// Diagnostic Storage Account
resource diagnosticStorageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: '${storageAccountNameCleaned}diag'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
  }
}

// File Service Diagnostic Setting
resource fileServiceDiagnosticSetting 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'file-service-diagnostics'
  scope: fileService
  properties: {
    storageAccountId: storageAccount.id
    logs: [
      {
        category: 'StorageRead'
        enabled: true
      }
      {
        category: 'StorageWrite'
        enabled: true
      }
      {
        category: 'StorageDelete'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'Transaction'
        enabled: true
      }
    ]
  }
}

// Storage Outputs
output storageAccountName string = storageAccount.name
output storageAccountId string = storageAccount.id
output fileShareName string = fileShare.name
output fileShareUrl string = '\\\\${storageAccount.name}.file.${environment().suffixes.storage}\\${fileShareName}'

// Diagnostic Storage Outputs
output diagnosticStorageAccountName string = diagnosticStorageAccount.name
output diagnosticStorageAccountId string = diagnosticStorageAccount.id
