@{
    # module を import したときに最初に読み込む実装ファイル
    RootModule           = 'MyServiceConfig.psm1'

    # package が依存する module の version。実装変更のたびに更新する
    ModuleVersion        = '1.0.3'

    # module を一意に識別する固定 GUID。新規作成時に 1 回だけ生成し、以後 version を上げても変えない
    # New-Guid で生成する
    GUID                 = 'e79c6fb5-e879-48cd-882d-0375a121543e'

    Author               = 'blog-lab'
    CompanyName          = 'N/A'
    Copyright            = '(c) blog-lab'
    Description          = 'sample guest configuration'

    # この module から DSC resource として公開する class 名
    DscResourcesToExport = @('MyServiceConfig')

    # Windows 対象は 2.0.7、Linux 対象は 3.0.0-beta1 系でコンパイルする
    # (docs: azure/governance/machine-configuration/how-to/develop-custom-package/1-set-up-authoring-environment)
    PowerShellVersion    = '7.2'
}
