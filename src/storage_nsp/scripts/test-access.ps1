# ============================================================
# test-access.ps1
# VM 内で実行する Storage Account アクセステスト
#
# 使用方法（VM 内の PowerShell で実行）:
#   .\test-access.ps1 -StorageAccountName "iboysansp01" -ContainerName "nsp-test"
#
# 前提条件:
#   - Az モジュールがインストール済み（Install-Module -Name Az -Scope CurrentUser）
#   - マネージド ID でログイン済み（Connect-AzAccount -Identity）
# ============================================================

param(
    [Parameter(Mandatory = $true)]
    [string]$StorageAccountName,

    [Parameter(Mandatory = $false)]
    [string]$ContainerName = "nsp-test",

    [Parameter(Mandatory = $false)]
    [string]$TestBlobName = "nsp-test-blob.txt"
)

$ErrorActionPreference = "Stop"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Storage Account NSP Access Test" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Storage Account : $StorageAccountName"
Write-Host "Container       : $ContainerName"
Write-Host "Test Blob       : $TestBlobName"
Write-Host "Timestamp       : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host ""

# マネージド ID でログイン（VM 内実行時）
Write-Host "--- Connecting with Managed Identity ---" -ForegroundColor Yellow
try {
    Connect-AzAccount -Identity | Out-Null
    Write-Host "[PASS] Logged in with Managed Identity." -ForegroundColor Green
} catch {
    Write-Host "[WARN] MI login failed. Falling back to current session: $($_.Exception.Message)" -ForegroundColor DarkYellow
}
Write-Host ""

# テスト 1: Storage Account コンテキスト取得
Write-Host "--- Test 1: Get Storage Account Context ---" -ForegroundColor Yellow
try {
    $context = (Get-AzStorageAccount | Where-Object { $_.StorageAccountName -eq $StorageAccountName }).Context
    if ($context) {
        Write-Host "[PASS] Storage Account context acquired." -ForegroundColor Green
    } else {
        Write-Host "[FAIL] Storage Account context is null." -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "[FAIL] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# テスト 2: Blob アップロード
Write-Host ""
Write-Host "--- Test 2: Upload Blob ---" -ForegroundColor Yellow
try {
    $testContent = "NSP test at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $tempFile = [System.IO.Path]::GetTempFileName()
    Set-Content -Path $tempFile -Value $testContent

    Set-AzStorageBlobContent `
        -Container $ContainerName `
        -File $tempFile `
        -Blob $TestBlobName `
        -Context $context `
        -Force | Out-Null

    Write-Host "[PASS] Blob uploaded successfully." -ForegroundColor Green
    Remove-Item -Path $tempFile -Force
} catch {
    Write-Host "[FAIL] $($_.Exception.Message)" -ForegroundColor Red
    if ($tempFile -and (Test-Path $tempFile)) { Remove-Item -Path $tempFile -Force }
}

# テスト 3: Blob ダウンロード
Write-Host ""
Write-Host "--- Test 3: Download Blob ---" -ForegroundColor Yellow
try {
    $downloadPath = [System.IO.Path]::GetTempFileName()
    Get-AzStorageBlobContent `
        -Container $ContainerName `
        -Blob $TestBlobName `
        -Destination $downloadPath `
        -Context $context `
        -Force | Out-Null

    $content = Get-Content -Path $downloadPath
    Write-Host "[PASS] Blob downloaded. Content: $content" -ForegroundColor Green
    Remove-Item -Path $downloadPath -Force
} catch {
    Write-Host "[FAIL] $($_.Exception.Message)" -ForegroundColor Red
    if ($downloadPath -and (Test-Path $downloadPath)) { Remove-Item -Path $downloadPath -Force }
}

# テスト 4: Blob 一覧取得
Write-Host ""
Write-Host "--- Test 4: List Blobs ---" -ForegroundColor Yellow
try {
    $blobs = Get-AzStorageBlob -Container $ContainerName -Context $context
    Write-Host "[PASS] Listed $($blobs.Count) blob(s)." -ForegroundColor Green
    $blobs | ForEach-Object { Write-Host "  - $($_.Name)" }
} catch {
    Write-Host "[FAIL] $($_.Exception.Message)" -ForegroundColor Red
}

# テスト 5: Blob 削除
Write-Host ""
Write-Host "--- Test 5: Delete Blob ---" -ForegroundColor Yellow
try {
    Remove-AzStorageBlob `
        -Container $ContainerName `
        -Blob $TestBlobName `
        -Context $context `
        -Force

    Write-Host "[PASS] Blob deleted successfully." -ForegroundColor Green
} catch {
    Write-Host "[FAIL] $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Test Complete" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
