# ============================================================
# MyServiceConfig.psm1
# Azure Machine Configuration 用 class-based DSC resource
#
# 目的:
#   TargetPath で指定されたファイルの存在を保証する。
#   Ensure = Present なら作成し、Ensure = Absent なら削除する。
#
# 設計方針:
#   対象ファイルは必ず TargetPath で「絶対 path」として受け取る。
#   $HOME / GetFolderPath('UserProfile') / 相対 path のような
#   「実行ユーザー・カレントディレクトリに依存する解決」は使わない。
#   Machine Configuration の agent は root で動くため、そうした ambient な
#   解決に頼ると authoring 時の想定と実行時の対象がズレる。
#
# 契約（変更しないこと）:
#   - Get()   : resource class 自身を返す。実ファイル・service など actual state を取得し、
#               現在の状態を Reasons に積む。状態変更は行わない
#   - Test()  : desired state なら $true。状態変更は行わない
#   - Set()   : desired state へ収束させる。同じ入力で複数回呼ばれても同じ結果になるよう冪等にする
#
# Reasons を必ず 1 件以上返すこと（重要）:
#   GC worker (GuestConfiguration 4.12.0) は Get() が Reasons を空配列で返すと
#   `DscConfigurationExecutionFailed / GetConfiguration did not succeed.` で失敗する。
#   非準拠のときだけ理由を積む実装にすると、Set() で収束した「準拠」状態になった
#   瞬間に監査が落ちるため、準拠時も Compliant の Reason を 1 件返している。
#   このため Test() は Reasons.Count ではなく IsInDesiredState() で判定する
#   （準拠時にも Reason があるため、件数では準拠判定できない）。
#
# 参照: research/2026-08-06-azure-machine-configuration-custom-implementation.md セクション 3, 6.3, 8
# ============================================================

enum Ensure {
    Absent
    Present
}

# 非準拠の理由を Machine Configuration の report へ返すための型
# class 名は module 固有名にする（他 module の Reason 型と衝突させないため）
class MyServiceConfigReason {
    # program から識別・集計できる安定した理由コード
    [DscProperty()]
    [string] $Code

    # 利用者が原因を理解するための説明文
    [DscProperty()]
    [string] $Phrase
}

[DscResource()]
class MyServiceConfig {
    # resource instance を一意に識別する必須の Key property
    [DscProperty(Key)]
    [string] $Name

    # Present: TargetPath のファイルを存在させる / Absent: 削除する
    [DscProperty(Mandatory)]
    [Ensure] $Ensure = [Ensure]::Present

    # 管理対象ファイルの絶対 path。相対 path は実行時の CWD に依存するため受け付けない
    [DscProperty(Mandatory)]
    [string] $TargetPath

    # Get() が返す非準拠理由。Configuration からは設定できない出力専用 property にする
    [DscProperty(NotConfigurable)]
    [MyServiceConfigReason[]] $Reasons

    # Reason object の生成処理を共通化する内部 helper
    hidden [MyServiceConfigReason] NewReason([string] $code, [string] $phrase) {
        $reason = [MyServiceConfigReason]::new()
        $reason.Code = $code
        $reason.Phrase = $phrase
        return $reason
    }

    # TargetPath が絶対 path として妥当かを判定する
    # 不正な値のまま Test/Set へ進むと意図しない場所を操作する事故になるため入口で弾く
    hidden [bool] IsValidTargetPath() {
        if ([string]::IsNullOrWhiteSpace($this.TargetPath)) {
            return $false
        }
        return [System.IO.Path]::IsPathRooted($this.TargetPath)
    }

    # 準拠しているかどうかだけを判定する。Reasons の件数には依存しない
    hidden [bool] IsInDesiredState() {
        if (-not $this.IsValidTargetPath()) {
            return $false
        }

        $exists = Test-Path -LiteralPath $this.TargetPath -PathType Leaf

        if ($this.Ensure -eq [Ensure]::Present) {
            return $exists
        }
        return -not $exists
    }

    # OS から actual state を取得し、resource と Reasons に格納して返す
    # Reasons は準拠・非準拠にかかわらず必ず 1 件以上返す（冒頭の注意書きを参照）
    [MyServiceConfig] Get() {
        $current = [MyServiceConfig]::new()
        $current.Name = $this.Name
        $current.Ensure = $this.Ensure
        $current.TargetPath = $this.TargetPath
        $current.Reasons = @()

        # 設定値自体が不正な場合は、ファイルを見に行かず理由だけ返す
        if (-not $this.IsValidTargetPath()) {
            $current.Reasons += $this.NewReason(
                'MyServiceConfig:MyServiceConfig:InvalidTargetPath',
                "TargetPath must be a non-empty absolute path. Actual value: '$($this.TargetPath)'"
            )
            return $current
        }

        $exists = Test-Path -LiteralPath $this.TargetPath -PathType Leaf

        if ($this.Ensure -eq [Ensure]::Present) {
            if ($exists) {
                $current.Reasons += $this.NewReason(
                    'MyServiceConfig:MyServiceConfig:Compliant',
                    "File exists as desired: $($this.TargetPath)"
                )
            }
            else {
                $current.Reasons += $this.NewReason(
                    'MyServiceConfig:MyServiceConfig:FileMissing',
                    "File is missing: $($this.TargetPath)"
                )
            }
        }
        else {
            if ($exists) {
                $current.Reasons += $this.NewReason(
                    'MyServiceConfig:MyServiceConfig:FileShouldBeAbsent',
                    "File should be absent but exists: $($this.TargetPath)"
                )
            }
            else {
                $current.Reasons += $this.NewReason(
                    'MyServiceConfig:MyServiceConfig:Compliant',
                    "File is absent as desired: $($this.TargetPath)"
                )
            }
        }

        return $current
    }

    # desired state なら true を返す。状態変更は行わない
    [bool] Test() {
        return $this.IsInDesiredState()
    }

    # actual state を desired state へ収束させる
    [void] Set() {
        # 不正な TargetPath のまま状態変更すると事故になるため、収束させずに失敗させる
        if (-not $this.IsValidTargetPath()) {
            throw "TargetPath must be a non-empty absolute path. Actual value: '$($this.TargetPath)'"
        }

        if ($this.Ensure -eq [Ensure]::Absent) {
            if (Test-Path -LiteralPath $this.TargetPath -PathType Leaf) {
                Remove-Item -LiteralPath $this.TargetPath -Force
            }
            return
        }

        if (Test-Path -LiteralPath $this.TargetPath -PathType Leaf) {
            return
        }

        # 親ディレクトリが無い場合に備えて先に作成する（既存なら何もしない）
        $parent = Split-Path -Path $this.TargetPath -Parent
        if ($parent -and -not (Test-Path -LiteralPath $parent -PathType Container)) {
            New-Item -Path $parent -ItemType Directory -Force | Out-Null
        }

        New-Item -Path $this.TargetPath -ItemType File -Force | Out-Null
    }
}
