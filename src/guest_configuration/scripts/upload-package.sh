#!/bin/bash
# ============================================================
# upload-package.sh
# Guest Configuration パッケージを Blob にアップロードする
#
# Usage:
#   bash ./scripts/upload-package.sh -s <storage-account> -c <container> -p <package-path>
#
# 前提条件:
#   enable-package-upload-access.sh を実行済みであること
#   Azure CLI でログイン済みで、Blob データプレーン権限があること
# ============================================================

set -euo pipefail

usage() {
    echo "Usage: $0 -s <storage-account> [-c <container>] -p <package-path>"
    echo ""
    echo "Options:"
    echo "  -s  Storage account name"
    echo "  -c  Blob container name (default: machine-configuration)"
    echo "  -p  Package ZIP path"
    exit 1
}

STORAGE_ACCOUNT=""
CONTAINER_NAME="machine-configuration"
PACKAGE_PATH=""

while getopts "s:c:p:" opt; do
    case "$opt" in
        s) STORAGE_ACCOUNT="$OPTARG" ;;
        c) CONTAINER_NAME="$OPTARG" ;;
        p) PACKAGE_PATH="$OPTARG" ;;
        *) usage ;;
    esac
done

if [[ -z "$STORAGE_ACCOUNT" || -z "$PACKAGE_PATH" ]]; then
    usage
fi

if [[ ! -f "$PACKAGE_PATH" ]]; then
    echo "Error: Package file not found: $PACKAGE_PATH" >&2
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

blob_name="$(basename "$PACKAGE_PATH")"
url="https://${STORAGE_ACCOUNT}.blob.core.windows.net/${CONTAINER_NAME}/${blob_name}"
max_attempts=12

echo "===== Upload Guest Configuration Package ====="

for ((attempt = 1; attempt <= max_attempts; attempt++)); do
    echo "[INFO] Upload attempt: ${attempt}/${max_attempts}"
    if az storage blob upload \
        --account-name "$STORAGE_ACCOUNT" \
        --auth-mode login \
        --container-name "$CONTAINER_NAME" \
        --name "$blob_name" \
        --file "$PACKAGE_PATH" \
        --overwrite true \
        --only-show-errors \
        --output none; then
        echo "[PASS] Upload complete."
        echo "Package URL: $url"
        exit 0
    fi

    if ((attempt < max_attempts)); then
        echo "[WARN] Storage firewall の反映待ちとして 10 秒後に再試行します。"
        sleep 10
    fi
done

echo "[FAIL] パッケージをアップロードできませんでした。IP ルールと Storage Blob Data Contributor 権限を確認してください。" >&2
exit 1