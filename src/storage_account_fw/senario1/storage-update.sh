#!/bin/bash
# Update Storage Account
RESOURCE_GROUP="storage-test"
STORAGE_ACCOUNT="iboystragefwtest100"
PUBLIC_IP_NAME="je-win2022-01-pip"

VM_IP=$(az network public-ip show --resource-group $RESOURCE_GROUP --name $PUBLIC_IP_NAME --query ipAddress -o tsv)
az storage account network-rule add   --resource-group $RESOURCE_GROUP   --account-name $STORAGE_ACCOUNT   --ip-address $VM_IP