using './main.bicep'

param locationEastJapan = 'japaneast'
param locationWestJapan = 'japanwest'
param locationSoutheastAsia = 'southeastasia'

param vnetEastJapanName = 'je-vnet'
param vnetWestJapanName = 'jw-vnet'
param vnetSoutheastAsiaName = 'sea-vnet'

param tags = {
  environment: 'validation'
  purpose: 'network-testing'
  createdDate: '2024-01-01'
}
