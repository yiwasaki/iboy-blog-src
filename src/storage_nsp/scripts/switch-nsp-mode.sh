#!/bin/bash
# ============================================================
# switch-nsp-mode.sh
# NSP Association の accessMode を切り替える（テスト用 + 診断用の両方）
#
# 使用方法:
#   # Transition (Learning) → Enforced に切替
#   ./switch-nsp-mode.sh -g <resource-group> -n nsp-lab-nsp -p nsp-lab -m Enforced
#
#   # Enforced → Transition (Learning) に戻す
#   ./switch-nsp-mode.sh -g <resource-group> -n nsp-lab-nsp -p nsp-lab -m Learning
# ============================================================

set -euo pipefail

usage() {
    echo "Usage: $0 -g <resource-group> -n <nsp-name> -p <prefix> -m <Learning|Enforced>"
    echo ""
    echo "Options:"
    echo "  -g  Resource group name"
    echo "  -n  Network Security Perimeter name"
    echo "  -p  Resource name prefix (e.g. nsp-lab)"
    echo "  -m  Access mode (Learning or Enforced)"
    exit 1
}

RESOURCE_GROUP=""
NSP_NAME=""
PREFIX=""
ACCESS_MODE=""

while getopts "g:n:p:m:" opt; do
    case $opt in
        g) RESOURCE_GROUP="$OPTARG" ;;
        n) NSP_NAME="$OPTARG" ;;
        p) PREFIX="$OPTARG" ;;
        m) ACCESS_MODE="$OPTARG" ;;
        *) usage ;;
    esac
done

if [[ -z "$RESOURCE_GROUP" || -z "$NSP_NAME" || -z "$PREFIX" || -z "$ACCESS_MODE" ]]; then
    usage
fi

# Association 名を prefix から導出（nsp.bicep と整合）
ASSOCIATION_TEST="${PREFIX}-sa-association"
ASSOCIATION_DIAG="${PREFIX}-sa-diag-association"

if [[ "$ACCESS_MODE" != "Learning" && "$ACCESS_MODE" != "Enforced" ]]; then
    echo "Error: Access mode must be 'Learning' or 'Enforced'"
    exit 1
fi

echo "============================================================"
echo " NSP Access Mode Switch"
echo "============================================================"
echo "Resource Group      : $RESOURCE_GROUP"
echo "NSP Name            : $NSP_NAME"
echo "Association (test)  : $ASSOCIATION_TEST"
echo "Association (diag)  : $ASSOCIATION_DIAG"
echo "Target Mode         : $ACCESS_MODE"
echo ""

if ! command -v az >/dev/null 2>&1; then
    echo "Error: Azure CLI (az) が見つかりません。"
    exit 1
fi

if ! az account show >/dev/null 2>&1; then
    echo "Error: Azure にログインしていません。'az login' を実行してください。"
    exit 1
fi

# NSP コマンドは拡張機能 nsp が必要
if ! az extension show --name nsp >/dev/null 2>&1; then
    echo "Info: Azure CLI 拡張機能 'nsp' をインストールします。"
    az extension add --name nsp --allow-preview true >/dev/null
fi

# 現在の状態を確認
echo "--- Current Association Status ---"
for ASSOC in "$ASSOCIATION_TEST" "$ASSOCIATION_DIAG"; do
    az network perimeter association show \
        --resource-group "${RESOURCE_GROUP}" \
        --perimeter-name "${NSP_NAME}" \
        --name "${ASSOC}" \
        --query "{name:name, accessMode:properties.accessMode, provisioningState:properties.provisioningState}" \
        -o table
    echo ""
done

echo "--- Switching to ${ACCESS_MODE} mode ---"

# accessMode を更新（テスト用 + 診断用）
for ASSOC in "$ASSOCIATION_TEST" "$ASSOCIATION_DIAG"; do
    echo "Updating: ${ASSOC}"
    az network perimeter association update \
        --resource-group "${RESOURCE_GROUP}" \
        --perimeter-name "${NSP_NAME}" \
        --name "${ASSOC}" \
        --access-mode "${ACCESS_MODE}" \
        --only-show-errors \
        -o none
done

echo ""
echo "--- Updated Association Status ---"
for ASSOC in "$ASSOCIATION_TEST" "$ASSOCIATION_DIAG"; do
    az network perimeter association show \
        --resource-group "${RESOURCE_GROUP}" \
        --perimeter-name "${NSP_NAME}" \
        --name "${ASSOC}" \
        --query "{name:name, accessMode:properties.accessMode, provisioningState:properties.provisioningState}" \
        -o table
    echo ""
done

echo "Done. Access mode switched to ${ACCESS_MODE}."
