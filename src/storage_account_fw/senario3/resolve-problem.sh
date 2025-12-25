# /bin/bash
# Update Storage Account
RESOURCE_GROUP="storage-test"
STORAGE_ACCOUNT="iboystragefwtest100"
PUBLIC_IP_NAME="je-win2022-01-pip"
VNET_NAME="jw-vnet"
SUBNET_NAME="test-west"

SUBNET_ID=$(az network vnet subnet show --vnet-name $VNET_NAME --name $SUBNET_NAME --resource-group $RESOURCE_GROUP --query id -o tsv)
az storage account network-rule add  --resource-group $RESOURCE_GROUP   --account-name $STORAGE_ACCOUNT --subnet $SUBNET_ID