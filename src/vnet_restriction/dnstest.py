# pip install dnspython
import dns.message
import dns.query
import dns.rdatatype

def dnspython_udp_fixed_src(where: str, name: str, src_ip: str = None, src_port: int = 5353):
    # A レコードの標準クエリを作成
    q = dns.message.make_query(name, dns.rdatatype.A)
    # source_port に固定ポート、source に固定送信元 IP（必要なら）を設定
    response = dns.query.udp(q, where=where, source=src_ip, source_port=src_port, timeout=3.0)
    return response

if __name__ == '__main__':
    ans = dnspython_udp_fixed_src('168.63.129.16', 'google.com', src_ip=None, src_port=65330)
    for rrset in ans.answer:
        print(rrset)
