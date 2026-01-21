#!/bin/bash

# 環境変数の設定
RESOURCE_GROUP="<Resource Group Name>"
VM_NAME="<VM Name>"

# PowerShell コマンドでレジストリ設定を追加
# CloudKerberosTicketRetrievalEnabled を有効化
az vm run-command invoke \
  --resource-group ${RESOURCE_GROUP} \
  --name ${VM_NAME} \
  --command-id RunPowerShellScript \
  --scripts "reg add HKLM\SYSTEM\CurrentControlSet\Control\Lsa\Kerberos\Parameters /v CloudKerberosTicketRetrievalEnabled /t REG_DWORD /d 1"
