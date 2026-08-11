#!/bin/bash
# ============================================================
# enable-package-upload-access.sh
# Storage Account の Public endpoint と操作者 IP を一時許可する
#
# Usage:
#   bash ./scripts/enable-package-upload-access.sh -g <resource-group> -s <storage-account> -o <operator-public-ip>
#
# 前提条件:
#   Azure CLI でログイン済みであること
# ============================================================

set -euo pipefail

usage() {
    echo "Usage: $0 -g <resource-group> -s <storage-account> -o <operator-public-ip>"
    echo ""
    echo "Options:"
    echo "  -g  Resource group name"
    echo "  -s  Storage account name"
    echo "  -o  Operator public IPv4 address"
    exit 1
}

RESOURCE_GROUP=""
STORAGE_ACCOUNT=""
OPERATOR_PUBLIC_IP=""

while getopts "g:s:o:" opt; do
    case "$opt" in
        g) RESOURCE_GROUP="$OPTARG" ;;
        s) STORAGE_ACCOUNT="$OPTARG" ;;
        o) OPERATOR_PUBLIC_IP="$OPTARG" ;;
        *) usage ;;
    esac
done

if [[ -z "$RESOURCE_GROUP" || -z "$STORAGE_ACCOUNT" || -z "$OPERATOR_PUBLIC_IP" ]]; then
    usage
fi

if [[ ! "$OPERATOR_PUBLIC_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    echo "Error: Public IPv4 address を指定してください: $OPERATOR_PUBLIC_IP" >&2
    exit 1
fi

if ! command -v az >/dev/null 2>&1; then
    echo "Error: Azure CLI (az) が見つかりません。" >&2
    exit 1
fi

if ! az account show >/dev/null 2>&1; then
    echo "Error: Azure にログインしていません。'az login' を実行してください。" >&2
    exit 1
fi

echo "===== Enable Package Upload Access ====="

echo "[INFO] Public network access を有効化します。"
az storage account update \
    --resource-group "$RESOURCE_GROUP" \
    --name "$STORAGE_ACCOUNT" \
    --public-network-access Enabled \
    --default-action Deny \
    --output none

echo "[INFO] 操作者 IP を許可します。"
if ! az storage account network-rule add \
    --resource-group "$RESOURCE_GROUP" \
    --account-name "$STORAGE_ACCOUNT" \
    --ip-address "$OPERATOR_PUBLIC_IP" \
    --output none; then
    echo "[ERROR] IP ルールを追加できなかったため、Public network access を無効化します。" >&2
    az storage account update \
        --resource-group "$RESOURCE_GROUP" \
        --name "$STORAGE_ACCOUNT" \
        --public-network-access Disabled \
        --output none
    exit 1
fi

public_network_access="$(az storage account show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$STORAGE_ACCOUNT" \
    --query publicNetworkAccess \
    --output tsv)"
ip_rule_count="$(az storage account show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$STORAGE_ACCOUNT" \
    --query "length(networkRuleSet.ipRules[?ipAddressOrRange=='${OPERATOR_PUBLIC_IP}'])" \
    --output tsv)"

if [[ "$public_network_access" != "Enabled" || "$ip_rule_count" != "1" ]]; then
    echo "[FAIL] Storage firewall の許可状態を確認できませんでした。" >&2
    exit 1
fi

echo "[PASS] Public network access: $public_network_access"
echo "[PASS] Allowed operator IP: $OPERATOR_PUBLIC_IP"
echo "[INFO] データプレーンへの反映には時間がかかる場合があります。次に upload-package.sh を実行してください。"