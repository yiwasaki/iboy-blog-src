# pip install dnspython
import dns.message
import dns.query
import dns.rdatatype

def dnspython_udp_fixed_src(where: str, name: str, src_ip: str = None, src_port: int = 5353):
    """
    Send a DNS A-record query over UDP using a fixed source IP address and UDP port.

    This helper is intended to demonstrate Azure VNet port restrictions by forcing the
    DNS query to originate from a specific source IP/port combination.

    :param where: The target DNS server to query (IP address or hostname).
    :param name: The DNS name (FQDN) to resolve.
    :param src_ip: Optional source IP address to bind for the outgoing UDP packet.
                   If None, the system default routing will determine the source IP.
    :param src_port: Source UDP port to use for the query. Defaults to 5353.
    :return: A dns.message.Message instance containing the DNS response.
    :raises dns.exception.Timeout: If the query does not receive a response within the timeout.
    :raises dns.exception.DNSException: For other DNS-related errors raised by dnspython.
    """
    print(f"Querying {name} at {where} from src_ip={src_ip}, src_port={src_port}")
    
    # A レコードの標準クエリを作成
    q = dns.message.make_query(name, dns.rdatatype.A)
    # source_port に固定ポート、source に固定送信元 IP（必要なら）を設定
    response = dns.query.udp(q, where=where, source=src_ip, source_port=src_port, timeout=3.0)
    return response

if __name__ == '__main__':
    ans = dnspython_udp_fixed_src('168.63.129.16', 'google.com', src_ip=None, src_port=65330)
    for rrset in ans.answer:
        print(rrset)
