STORAGE_ACCOUNT="<Storage Account Name>"

OID=$(az ad sp list --display-name "[Storage Account] ${STORAGE_ACCOUNT}.file.core.windows.net" --query "[0].id" -o tsv)
APP_ID=$(az ad sp show --id ${OID} --query appId -o tsv)

az ad app permission grant --id $APP_ID --api 00000003-0000-0000-c000-000000000000 --scope User.Read profile openid
