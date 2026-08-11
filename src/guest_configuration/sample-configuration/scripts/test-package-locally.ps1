# ============================================================
# test-package-locally.ps1
# ビルド済み package を、実際の VM へ配布する前に手元でテストする
#
# Linux では root、Windows では管理者権限の PowerShell 7 で実行する。
# Remediation は実行環境自体を変更するため、使い捨て VM など安全な環境で行うこと。
#
# Usage:
#   sudo pwsh ./scripts/test-package-locally.ps1
#   sudo pwsh ./scripts/test-package-locally.ps1 -PackagePath ./package/MyServiceConfig.zip
# ============================================================

param(
    [Parameter(Mandatory = $false)]
    [string]$PackagePath = (Join-Path $PSScriptRoot '..' 'package' 'MyServiceConfig.zip')
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $PackagePath)) {
    throw "Package が見つかりません: $PackagePath。先に build-package.ps1 / build-package.sh を実行してください。"
}

Write-Host '===== 1/3: 適用前の準拠状況を確認 =====' -ForegroundColor Cyan
Get-GuestConfigurationPackageComplianceStatus -Path $PackagePath -Verbose

Write-Host '===== 2/3: Remediation（Set() の実行）=====' -ForegroundColor Cyan
Write-Host '[WARN] この操作は実行環境の状態を実際に変更します。' -ForegroundColor Yellow
Start-GuestConfigurationPackageRemediation -Path $PackagePath -Verbose

Write-Host '===== 3/3: 適用後の準拠状況を再確認 =====' -ForegroundColor Cyan
$result = Get-GuestConfigurationPackageComplianceStatus -Path $PackagePath -Verbose

if ($result.complianceStatus -ne $true -and $result.complianceStatus -ne 'Compliant') {
    Write-Host '[FAIL] Remediation 後も NonCompliant です。Reasons を確認してください。' -ForegroundColor Red
    exit 1
}

Write-Host '[PASS] Remediation 後に Compliant を確認しました。' -ForegroundColor Green
