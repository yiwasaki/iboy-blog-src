#!/bin/bash
# ============================================================
# build-package.sh
# Guest Configuration カスタムパッケージを作成する（build-package.ps1 の bash ラッパー）
#
# Usage:
#   bash ./scripts/build-package.sh
#   bash ./scripts/build-package.sh -n MyServiceConfig -o ./package
# ============================================================

set -euo pipefail

usage() {
    echo "Usage: $0 [-n <configuration-name>] [-o <output-root>]"
    echo ""
    echo "Options:"
    echo "  -n  Configuration name"
    echo "  -o  Output root directory"
    exit 1
}

CONFIGURATION_NAME="MyServiceConfig"
OUTPUT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

while getopts "n:o:" opt; do
    case "$opt" in
        n) CONFIGURATION_NAME="$OPTARG" ;;
        o) OUTPUT_ROOT="$OPTARG" ;;
        *) usage ;;
    esac
done

if ! command -v pwsh >/dev/null 2>&1; then
    echo "Error: PowerShell (pwsh) が見つかりません。" >&2
    exit 1
fi

script_dir="$(cd "$(dirname "$0")" && pwd)"
script_path="$script_dir/build-package.ps1"

if [[ ! -f "$script_path" ]]; then
    echo "Error: PowerShell build script not found: $script_path" >&2
    exit 1
fi

pwsh "$script_path" -ConfigurationName "$CONFIGURATION_NAME" -OutputRoot "$OUTPUT_ROOT"
