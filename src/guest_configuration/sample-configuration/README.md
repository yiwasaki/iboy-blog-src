# Guest Configuration カスタムパッケージ スケルトン

新しい Azure Machine Configuration（Guest Configuration）のカスタム構成を作るときに、毎回ゼロから書かないための最小構成テンプレート。VM・ネットワークなどの検証基盤は含まない（authoring 部分のみ）。基盤が必要な場合は [`src/guest_configuration_auditd/`](../../../src/guest_configuration_auditd/) の `main.bicep` 一式を参考にするか、既存の検証環境を使い回すこと。

設計判断の根拠は [`research/2026-08-06-azure-machine-configuration-custom-implementation.md`](../../../research/2026-08-06-azure-machine-configuration-custom-implementation.md) を参照。特にセクション3（コードの型）、6.3（`guest_configuration_auditd` を汎用化する際に直すべき点）、8（実装チェックリスト）はこのスケルトンの設計にそのまま反映している。

## 構成

```text
skeleton/
├── configuration/
│   ├── MyServiceConfig.ps1                # DSC Configuration（authoring 環境専用。VM 上では実行しない）
│   └── modules/
│       └── MyServiceConfig/
│           ├── MyServiceConfig.psd1       # module manifest
│           ├── MyServiceConfig.psm1       # class-based DSC resource（Get/Test/Set 本体）
│           └── templates/                 # resource が読む静的ファイルを置く場所（任意）
├── scripts/
│   ├── build-package.ps1                  # MOF コンパイル + ZIP 作成 + SHA-256 算出
│   ├── build-package.sh                   # 上記の bash ラッパー
│   └── test-package-locally.ps1           # audit -> remediate -> audit のローカルテスト
├── assignment.bicep                       # 既存 VM への単体 Guest Configuration Assignment
└── .gitignore                             # ビルド生成物（MOF, ZIP, .bicep-build/）を除外
```

## 使い方

### 1. コピーしてリネームする

このディレクトリを新しいシナリオ名でコピーし（例: `src/guest_configuration_nginx/`）、プレースホルダー `MyServiceConfig` をリソース名に一括置換する。置換対象はファイル名・フォルダ名・ファイル内容の両方。

```bash
cp -r article/guest_configuration_auditd/skeleton src/guest_configuration_<new-scenario>
cd src/guest_configuration_<new-scenario>

# ファイル/フォルダ名の置換（例: MyServiceConfig -> NginxConfig）
mv configuration/MyServiceConfig.ps1 configuration/NginxConfig.ps1
mv configuration/modules/MyServiceConfig configuration/modules/NginxConfig
mv configuration/modules/NginxConfig/MyServiceConfig.psd1 configuration/modules/NginxConfig/NginxConfig.psd1
mv configuration/modules/NginxConfig/MyServiceConfig.psm1 configuration/modules/NginxConfig/NginxConfig.psm1

# ファイル内容の置換
grep -rl 'MyServiceConfig' . | xargs sed -i 's/MyServiceConfig/NginxConfig/g'
```

`MyServiceConfig.psd1` の `GUID` は `New-Guid` で新規生成した値に置き換える（プレースホルダーの `00000000-...` のまま使わない）。

### 2. DSC resource を実装する

`configuration/modules/<Name>/<Name>.psm1` の `[DscProperty]` を管理したい設定値に合わせて追加・削除し、`Get()` / `Test()` / `Set()` 内の `TODO` を実装する。守るべき契約:

- `Get()` は実際の OS 状態（ファイル、service、registry など）を取得して返す。宣言値をそのまま返さない。
- `Test()` は状態を変更しない。
- `Set()` は冪等にする（差分があるときだけ副作用を起こす）。
- `Test()` が `false` を返すすべての条件に、安定した `Reason.Code` を対応させる。
- 外部 command へ渡す値（service 名など）は allowlist や形式検証を行ってから渡す。高権限（Linux は root、Windows は LocalSystem）で実行されるため、command injection につながる実装をしない。

### 3. DSC Configuration に desired value を書く

`configuration/<Name>.ps1` の `Node localhost` ブロックへ、実際に適用したい値を書く。

### 4. package をビルドする

```bash
# Linux 対象は PSDesiredStateConfiguration 3.0.0-beta1、Windows 対象は 2.0.7 を事前にインストールしておく
bash ./scripts/build-package.sh -n <Name>
```

### 5. ローカルでテストする

特権を持つ使い捨て環境（VM など）で、audit → remediation → audit を確認する。

```bash
sudo pwsh ./scripts/test-package-locally.ps1 -PackagePath ./package/<Name>.zip
```

### 6. 配布する

- 1台の検証・少数の明示対象: `assignment.bicep` で対象 VM へ直接割り当てる（`assignmentType` は既定で安全側の `Audit`。実際に変更を適用するなら `ApplyAndMonitor` または `ApplyAndAutoCorrect` を指定する）。
- 複数台への正式配布: `New-GuestConfigurationPolicy` で Policy definition を生成し、Azure Policy として割り当てる（このスケルトンには含まれない。手順は research ドキュメントのセクション5.3を参照）。

ZIP を Blob などへ置く手順（一時許可 → upload → 遮断）は `src/guest_configuration_auditd/scripts/` の `enable-package-upload-access.sh` / `upload-package.sh` / `disable-package-upload-access.sh` を参考にする。

## 実装チェックリスト

research ドキュメントのセクション8から抜粋。

- [ ] 管理対象の各 property に、actual state の取得・比較・適用が対応している
- [ ] `Get()` は actual state と prefix 付き `Reasons` を返す
- [ ] `Test()` は状態を変更しない
- [ ] `Set()` は冪等で、必要な差分だけを変更し、失敗時は例外にする
- [ ] shell command へ渡す property は allowlist と形式検証を行う
- [ ] `Absent` を公開する場合は削除処理を実装する（未実装なら公開しない）
- [ ] module 固有の template / script は `modules/<Name>/` 配下に置く（`FilesToInclude` に頼らない）
- [ ] ZIP は展開後100 MB以下で、秘密情報を含まない
- [ ] 特権を持つ使い捨て環境で audit → remediation → audit を通す
- [ ] 最終 ZIP から SHA-256 を計算し、`assignment.bicep` の `packageContentHash` と一致させる
- [ ] `assignmentType` は副作用に応じて選ぶ（検証は `Audit`、本適用は `ApplyAndMonitor` / `ApplyAndAutoCorrect`）
