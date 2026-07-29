/// Helpers مشترک برای ساخت بلوک‌های tls و transport و endpoint
/// سازگار با sing-box 1.11+
class SingBoxTlsTransport {
  const SingBoxTlsTransport._();

  static Map<String, dynamic>? buildTls({
    required bool enabled,
    String? serverName,
    bool insecure = false,
    List<String>? alpn,
    String? fingerprint,
    String? realityPublicKey,
    String? realityShortId,
  }) {
    if (!enabled) return null;
    final Map<String, dynamic> tls = <String, dynamic>{'enabled': true};
    if (serverName != null && serverName.trim().isNotEmpty) {
      tls['server_name'] = serverName.trim();
    }
    if (insecure) tls['insecure'] = true;
    if (alpn != null && alpn.isNotEmpty) tls['alpn'] = alpn;

    final bool isReality =
        realityPublicKey != null && realityPublicKey.trim().isNotEmpty;
    if (isReality) {
      tls['reality'] = <String, dynamic>{
        'enabled': true,
        'public_key': realityPublicKey.trim(),
        if (realityShortId != null && realityShortId.trim().isNotEmpty)
          'short_id': realityShortId.trim(),
      };
      tls['utls'] = <String, dynamic>{
        'enabled': true,
        'fingerprint': (fingerprint == null || fingerprint.trim().isEmpty)
            ? 'chrome'
            : fingerprint.trim(),
      };
      tls.remove('insecure');
    } else if (fingerprint != null && fingerprint.trim().isNotEmpty) {
      tls['utls'] = <String, dynamic>{
        'enabled': true,
        'fingerprint': fingerprint.trim(),
      };
    }
    return tls;
  }

  static Map<String, dynamic>? buildTransport({
    String? type,
    String? path,
    String? host,
    String? serviceName,
    Map<String, String>? extraHeaders,
  }) {
    final String kind = (type ?? '').trim().toLowerCase();
    if (kind.isEmpty || kind == 'tcp' || kind == 'raw' || kind == 'none') {
      return null;
    }
    switch (kind) {
      case 'ws':
      case 'websocket':
        final Map<String, String> headers = <String, String>{
          if (host != null && host.trim().isNotEmpty) 'Host': host.trim(),
          ...?extraHeaders,
        };
        return <String, dynamic>{
          'type': 'ws',
          'path': (path == null || path.isEmpty) ? '/' : path,
          if (headers.isNotEmpty) 'headers': headers,
        };
      case 'grpc':
        return <String, dynamic>{
          'type': 'grpc',
          'service_name': serviceName ?? path?.replaceAll('/', '') ?? '',
        };
      case 'http':
      case 'h2':
        return <String, dynamic>{
          'type': 'http',
          if (host != null && host.trim().isNotEmpty)
            'host': <String>[host.trim()],
          'path': (path == null || path.isEmpty) ? '/' : path,
        };
      case 'httpupgrade':
        return <String, dynamic>{
          'type': 'httpupgrade',
          if (host != null && host.trim().isNotEmpty) 'host': host.trim(),
          'path': (path == null || path.isEmpty) ? '/' : path,
        };
      case 'quic':
        return <String, dynamic>{'type': 'quic'};
      default:
        return null;
    }
  }

  static Map<String, dynamic> buildWireGuardEndpoint({
    required String tag,
    required String server,
    required int serverPort,
    required String privateKey,
    required String peerPublicKey,
    List<String> localAddress = const <String>['10.0.0.2/32'],
    String? preSharedKey,
    int mtu = 1408,
    List<int>? reserved,
    int? keepalive,
  }) {
    return <String, dynamic>{
      'type': 'wireguard',
      'tag': tag,
      'system': false,
      'mtu': mtu <= 0 ? 1408 : mtu,
      'address':
          localAddress.isEmpty ? const <String>['10.0.0.2/32'] : localAddress,
      'private_key': privateKey,
      'peers': <Map<String, dynamic>>[
        <String, dynamic>{
          'address': server,
          'port': serverPort,
          'public_key': peerPublicKey,
          if (preSharedKey != null && preSharedKey.isNotEmpty)
            'pre_shared_key': preSharedKey,
          'allowed_ips': const <String>['0.0.0.0/0', '::/0'],
          if (reserved != null && reserved.length == 3) 'reserved': reserved,
          if (keepalive != null && keepalive > 0)
            'persistent_keepalive_interval': keepalive,
        },
      ],
    };
  }
}
