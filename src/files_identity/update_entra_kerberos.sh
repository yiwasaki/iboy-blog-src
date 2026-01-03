TENANT_ID="<Tenant ID>"
STORAGE_ACCOUNT="<Storage Account Name>"

OID=$(az ad sp list --display-name "[Storage Account] ${STORAGE_ACCOUNT}.file.core.windows.net" --query "[0].id" -o tsv)
APP_ID=$(az ad sp show --id ${OID} --query appId -o tsv)

# アプリケーションにタグを追加して、KDCでクラウドグループSIDを有効にする
az ad app update --id ${APP_ID} --set tags='["kdc_enable_cloud_group_sids"]'