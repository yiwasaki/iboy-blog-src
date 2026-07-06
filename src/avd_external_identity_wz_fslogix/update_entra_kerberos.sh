#!/bin/bash
# Usage: ./update_entra_kerberos.sh -s <Storage Account Name>
#
# FSLogix プロファイル用 Storage Account のサービス プリンシパル アプリケーションに
# `kdc_enable_cloud_group_sids` タグを付与し、KDC でクラウド専用グループ SID を発行できる
# ようにする。クラウド専用 ID (B2B ゲスト含む) で Entra Kerberos を利用する際に必須。
#
# 前提:
#   - az login 済み
#   - Cloud Application Administrator もしくは Application Administrator ロール

set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 -s <storageAccountName>

  -s   FSLogix プロファイル用 Storage Account 名 (main.bicep の profileStorageAccountName)
  -h   ヘルプ
EOF
  exit 1
}

STORAGE_ACCOUNT=""
while getopts "s:h" opt; do
  case "${opt}" in
    s) STORAGE_ACCOUNT="${OPTARG}" ;;
    h|*) usage ;;
  esac
done

if [[ -z "${STORAGE_ACCOUNT}" ]]; then
  echo "Error: -s <storageAccountName> is required" >&2
  usage
fi

OID=$(az ad sp list --display-name "[Storage Account] ${STORAGE_ACCOUNT}.file.core.windows.net" --query "[0].id" -o tsv)
if [[ -z "${OID}" ]]; then
  echo "Error: Service principal for ${STORAGE_ACCOUNT} not found." >&2
  exit 1
fi

APP_ID=$(az ad sp show --id "${OID}" --query appId -o tsv)

# 既存タグを取得し、kdc_enable_cloud_group_sids が無ければ追加
EXISTING_TAGS=$(az ad app show --id "${APP_ID}" --query "tags" -o json)
if echo "${EXISTING_TAGS}" | grep -q "kdc_enable_cloud_group_sids"; then
  echo "Tag 'kdc_enable_cloud_group_sids' already set on appId ${APP_ID}"
  exit 0
fi

az ad app update --id "${APP_ID}" --set tags='["kdc_enable_cloud_group_sids"]' --output none
echo "Tag 'kdc_enable_cloud_group_sids' added to ${STORAGE_ACCOUNT} (appId: ${APP_ID})"
