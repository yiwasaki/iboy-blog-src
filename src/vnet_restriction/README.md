
# Azure VNet 制約検証環境

## Bicepテンプレート

`main.bicep`は、Azure VNetの制約を検証するためのテスト環境を自動デプロイします。

### デプロイされるリソース

- **VNet** (`test-vnet`)
  - VMサブネット: VM デプロイ向けのサブネット

- **Windows Server VM** (`test-vm`)
  - OS: Windows Server 2022 Datacenter Edition
  - VMサイズ: Standard_B4ms
  - OSディスク: Standard SSD

- **Azure Bastion** (Developer Tier)
  - VMへの安全な接続を提供
  - Developer Tier の場合は、Azure Bastion Subnet なども不要

### デプロイ方法

```bash
# リソースグループの作成
az group create --name rg-vnet-test --location japaneast

# デプロイ（パスワードはデプロイ時に対話的に入力）
az deployment group create \
  --resource-group rg-vnet-test \
  --template-file main.bicep \
  --parameters adminUsername=azureuser
```

### VMへの接続方法

1. Azure Portalでtest-vmを開く
2. 「接続」→「Bastion」を選択
3. 管理者ユーザー名とパスワードを入力して接続

---

## DNS制約テスト

## 初期設定
Python 環境を準備します。コマンドはご自身の環境に合わせて変更いただいて問題ありませんが、例えば以下のようなコマンドを実行します

```PowerShell
>py -m pip install dnspython
```

インストールが完了したら、以下のようにコマンドを実行してインストールされているかを確認します。

```PowerShell
PS >py -m pip show dnspython
Name: dnspython
Version: 2.8.0
Summary: DNS toolkit
Home-page: https://www.dnspython.org
Author:
Author-email: Bob Halley <halley@dnspython.org>
License: ISC
Location: C:\Users\<UserId>\AppData\Local\Programs\Python\Python314\Lib\site-packages
Requires:
Required-by:
PS >
```

## テストの実行
まず、ソースポートを 53053 など適当なエフェメラルポートに設定してコマンドを実行します。

```PowerShell
PS > py .\dnstest.py
google.com. 106 IN A 172.217.31.174
PS >
```
この場合、問題なく成功します。
もし、失敗する場合は、同一のポートを他のプロセスが使っている可能性があるので、ポートを変えてみてから試してみたください。

次に、Azure VNet でサポートされていないポート 65330 に設定して再実行します。
以下のようにタイムアウトになって名前解決に失敗したら、想定された動作となります。

```PowerShell
PS > py .\dnstest.py
Traceback (most recent call last):
  File "C:\Users\<UserId>\AppData\Local\Programs\Python\Python314\Lib\site-packages\dns\query.py", line 744, in _udp_recv
    return sock.recvfrom(max_size)
           ~~~~~~~~~~~~~^^^^^^^^^^
BlockingIOError: [WinError 10035] A non-blocking socket operation could not be completed immediately

During handling of the above exception, another exception occurred:

Traceback (most recent call last):
  File "C:\Users\<UserId>\Desktop\InstantDns\dnstest.py", line 14, in <module>
    ans = dnspython_udp_fixed_src('168.63.129.16', 'google.com', src_ip=None, src_port=65330)
  File "C:\Users\<UserId>\Desktop\InstantDns\dnstest.py", line 10, in dnspython_udp_fixed_src
    response = dns.query.udp(q, where=where, source=src_ip, source_port=src_port, timeout=3.0)
  File "C:\Users\<UserId>\AppData\Local\Programs\Python\Python314\Lib\site-packages\dns\query.py", line 967, in udp
    (r, received_time) = receive_udp(
                         ~~~~~~~~~~~^
        s,
        ^^
    ...<9 lines>...
        q,
        ^^
    )
    ^
  File "C:\Users\<UserId>\AppData\Local\Programs\Python\Python314\Lib\site-packages\dns\query.py", line 857, in receive_udp
    (wire, from_address) = _udp_recv(sock, 65535, expiration)
                           ~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^
  File "C:\Users\<UserId>\AppData\Local\Programs\Python\Python314\Lib\site-packages\dns\query.py", line 746, in _udp_recv
    _wait_for_readable(sock, expiration)
    ~~~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^
  File "C:\Users\<UserId>\AppData\Local\Programs\Python\Python314\Lib\site-packages\dns\query.py", line 245, in _wait_for_readable
    _wait_for(s, True, False, True, expiration)
    ~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "C:\Users\<UserId>\AppData\Local\Programs\Python\Python314\Lib\site-packages\dns\query.py", line 241, in _wait_for
    raise dns.exception.Timeout
dns.exception.Timeout: The DNS operation timed out.
PS >
```