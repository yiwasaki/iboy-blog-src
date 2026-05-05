#!/bin/bash
# Usage: ./update_entraid_grant.sh -s <Storage Account Name>
#
# FSLogix プロファイル用 Storage Account のサービス プリンシパルに対して、
# Entra Kerberos に必要な Microsoft Graph 権限 (User.Read / profile / openid) の
# 管理者同意を付与する。
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
  echo "Error: Service principal for ${STORAGE_ACCOUNT} not found. AADKERB が正しく構成されているか確認してください。" >&2
  exit 1
fi

APP_ID=$(az ad sp show --id "${OID}" --query appId -o tsv)

az ad app permission grant \
  --id "${APP_ID}" \
  --api 00000003-0000-0000-c000-000000000000 \
  --scope "User.Read profile openid" \
  --output none

echo "Admin consent granted for ${STORAGE_ACCOUNT} (appId: ${APP_ID})"
