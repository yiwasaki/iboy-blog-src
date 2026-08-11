# ============================================================
# MyServiceConfig.ps1
# Guest Configuration 用 DSC 構成定義
#
# この .ps1 は対象 VM 上では実行されない。authoring 環境
# （scripts/build-package.ps1）から呼び出して localhost.mof を
# 生成するためだけに使う。
# ============================================================

Configuration MyServiceConfig {
    param(
        [string]$NodeName = 'MyServiceConfig'
    )

    Import-DscResource -ModuleName MyServiceConfig

    Node $NodeName {
        # TODO: instance 名（Main）と各 property の desired value を実際の設定に置き換える
        # TargetPath は必ず絶対 path で指定する。agent は root で動くため、
        # '~' や相対 path を書くと authoring 時の想定と実行時の対象がズレる。
        MyServiceConfig Main {
            Ensure     = 'Present'
            Name       = 'my-service'
            TargetPath = '/tmp/HelloWorld'
        }
    }
}
