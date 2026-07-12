#!/bin/bash

STORAGE_ACCOUNT="<Storage Account Name>"

OID=$(az ad sp list --display-name "[Storage Account] ${STORAGE_ACCOUNT}.file.core.windows.net" --query "[0].id" -o tsv)
APP_ID=$(az ad sp show --id ${OID} --query appId -o tsv)

az ad app permission admin-consent --id ${APP_ID}
