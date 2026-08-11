# ============================================================
# build-package.ps1
# Guest Configuration カスタムパッケージを作成する
#
# Usage:
#   .\build-package.ps1
#   .\build-package.ps1 -ConfigurationName MyServiceConfig -OutputRoot .\out
#
# 前提:
#   - Windows 対象: PSDesiredStateConfiguration 2.0.7 をインストール済み
#   - Linux 対象:   PSDesiredStateConfiguration 3.0.0-beta1 (prerelease) をインストール済み
#   - 両対象共通:   GuestConfiguration モジュールをインストール済み
# ============================================================

param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigurationName = 'MyServiceConfig',

    [Parameter(Mandatory = $false)]
    [string]$OutputRoot = (Join-Path $PSScriptRoot '..'),

    # Windows 対象なら 2.0.7、Linux 対象なら 3.0.0 系（3.0.0-beta1 の GA 名は 3.0.0）を指定する
    [Parameter(Mandatory = $false)]
    [version]$DscModuleVersion = [version]'3.0.0'
)

$ErrorActionPreference = 'Stop'

$scenarioRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$configurationRoot = Join-Path $scenarioRoot 'configuration'
$buildRoot = Join-Path $scenarioRoot '.bicep-build'
$mofOutDir = Join-Path $configurationRoot $ConfigurationName
$packageOutDir = Join-Path $OutputRoot 'package'
$localModuleRoot = Join-Path $configurationRoot 'modules'

Write-Host '===== Build Guest Configuration Package =====' -ForegroundColor Cyan
Write-Host "ScenarioRoot: $scenarioRoot"
Write-Host "ConfigurationName: $ConfigurationName"

try {
    if (Test-Path $buildRoot) {
        Remove-Item -Path $buildRoot -Recurse -Force
    }
    New-Item -Path $buildRoot -ItemType Directory | Out-Null

    if (-not (Get-Module -ListAvailable -Name GuestConfiguration)) {
        throw "GuestConfiguration モジュールが見つかりません。'Install-Module -Name GuestConfiguration -Scope CurrentUser' を実行してください。"
    }

    $dscModule = Get-Module -ListAvailable -Name PSDesiredStateConfiguration |
        Where-Object Version -EQ $DscModuleVersion |
        Select-Object -First 1
    if (-not $dscModule) {
        throw "PSDesiredStateConfiguration $DscModuleVersion が見つかりません。対象 OS に合う version をインストールしてください（Windows: 2.0.7 / Linux: 3.0.0-beta1）。"
    }

    Import-Module PSDesiredStateConfiguration -RequiredVersion $dscModule.Version -Force
    $env:PSModulePath = "$localModuleRoot$([IO.Path]::PathSeparator)$env:PSModulePath"
    . (Join-Path $configurationRoot "$ConfigurationName.ps1")
    & $ConfigurationName -OutputPath $mofOutDir

    # コンパイル結果のファイル名は Configuration 内の Node 名で決まる。
    # MyServiceConfig.ps1 は既定で Node 名 = $ConfigurationName のため、
    # 通常の DSC コンパイルが生成する 'localhost.mof' ではなく "$ConfigurationName.mof" が直接生成される。
    # Node 名を 'localhost' に変更した Configuration にも対応できるよう、両方のケースを扱う。
    $compiledMof = Join-Path $mofOutDir 'localhost.mof'
    $namedMof = Join-Path $mofOutDir "$ConfigurationName.mof"
    if (Test-Path $compiledMof) {
        Move-Item -Path $compiledMof -Destination $namedMof -Force
    }
    elseif (-not (Test-Path $namedMof)) {
        throw "コンパイル済み MOF が見つかりません: $compiledMof または $namedMof"
    }

    if (-not (Test-Path $packageOutDir)) {
        New-Item -Path $packageOutDir -ItemType Directory | Out-Null
    }

    # module folder（modules/<ConfigurationName>/ 配下）はまるごと ZIP に含まれるため、
    # 同梱したい静的ファイルは FilesToInclude ではなく module 内の templates/ に置く
    $pkgParams = @{
        Name          = $ConfigurationName
        Configuration = $namedMof
        Type          = 'AuditAndSet'
        Path          = $packageOutDir
        Force         = $true
    }

    New-GuestConfigurationPackage @pkgParams | Out-Null

    $zipPath = Join-Path $packageOutDir "$ConfigurationName.zip"
    $hash = (Get-FileHash -Path $zipPath -Algorithm SHA256).Hash

    $result = [PSCustomObject]@{
        PackagePath = $zipPath
        Sha256 = $hash
    }

    Write-Host '[PASS] Package build complete.' -ForegroundColor Green
    $result | Format-List | Out-String | Write-Host
}
finally {
    if (Test-Path $buildRoot) {
        Remove-Item -Path $buildRoot -Recurse -Force
    }
}
