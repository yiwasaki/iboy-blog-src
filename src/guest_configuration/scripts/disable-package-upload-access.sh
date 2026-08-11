#!/bin/bash
# ============================================================
# disable-package-upload-access.sh
# 操作者 IP ルールを削除し、Storage Account の Public endpoint を無効化する
#
# Usage:
#   bash ./scripts/disable-package-upload-access.sh -g <resource-group> -s <storage-account> -o <operator-public-ip>
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

if ! command -v az >/dev/null 2>&1; then
    echo "Error: Azure CLI (az) が見つかりません。" >&2
    exit 1
fi

if ! az account show >/dev/null 2>&1; then
    echo "Error: Azure にログインしていません。'az login' を実行してください。" >&2
    exit 1
fi

echo "===== Disable Package Upload Access ====="

echo "[INFO] 操作者 IP ルールを削除します。"
if ! az storage account network-rule remove \
    --resource-group "$RESOURCE_GROUP" \
    --account-name "$STORAGE_ACCOUNT" \
    --ip-address "$OPERATOR_PUBLIC_IP" \
    --output none; then
    echo "[WARN] IP ルールを削除できませんでした。Public network access の無効化を続行します。" >&2
fi

echo "[INFO] Public network access を無効化します。"
az storage account update \
    --resource-group "$RESOURCE_GROUP" \
    --name "$STORAGE_ACCOUNT" \
    --public-network-access Disabled \
    --output none

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

if [[ "$public_network_access" != "Disabled" || "$ip_rule_count" != "0" ]]; then
    echo "[FAIL] Storage firewall を安全な状態へ戻せませんでした。" >&2
    exit 1
fi

echo "[PASS] Public network access: $public_network_access"
echo "[PASS] Removed operator IP: $OPERATOR_PUBLIC_IP"