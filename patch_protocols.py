#!/usr/bin/env python3
"""پچ خودکار پشتیبانی Hysteria2 / TUIC / WireGuard در V2rayStk."""

import re
import shutil
import sys
from pathlib import Path

ROOT = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path.cwd()
PARSER = ROOT / "lib/features/profiles/application/profile_import_parser.dart"
GEN = ROOT / "lib/features/sing_box/application/sing_box_config_generator.dart"


def die(msg):
    print("[X] " + msg)
    sys.exit(1)


def read(path):
    if not path.is_file():
        die("فایل پیدا نشد: %s" % path)
    return path.read_text(encoding="utf-8")


def backup(path):
    bak = path.with_suffix(path.suffix + ".bak")
    if not bak.exists():
        shutil.copy2(path, bak)
        print("[i] بکاپ: %s" % bak.name)


def replace_block(text, header, new_block):
    """جایگزینی یک متد کامل با شمارش آکولاد."""
    idx = text.find(header)
    if idx == -1:
        return None
    open_idx = text.find("{", idx + len(header) - 1)
    if open_idx == -1:
        return None
    depth = 0
    end = None
    for i in range(open_idx, len(text)):
        ch = text[i]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                end = i
                break
    if end is None:
        return None
    line_start = text.rfind("\n", 0, idx) + 1
    return text[:line_start] + new_block + text[end + 1:]


# ---------------------------------------------------------------- accessors
gen_src = read(GEN)
found = set(re.findall(r"profile\.([A-Za-z_][A-Za-z0-9_]*)", gen_src))
print("[i] فیلدهای Profile که در جنراتور استفاده شده: %s" % ", ".join(sorted(found)))

CANDIDATES = {
    "__HOST__": ["address", "host", "server", "serverAddress", "hostname"],
    "__PORT__": ["port", "serverPort"],
    "__SECRET__": ["password", "pass", "secret", "psk"],
    "__UUID__": ["uuid", "id", "userId", "user"],
    "__RAW__": ["rawConfig", "config", "raw", "link", "uri", "source", "rawUri"],
}

resolved = {}
for key, names in CANDIDATES.items():
    pick = next((n for n in names if n in found), None)
    if pick is None:
        die("هیچ‌کدام از فیلدهای %s برای %s در Profile پیدا نشد. "
            "فایل lib/.../profile.dart را بفرست." % (names, key))
    resolved[key] = pick
    print("[i] %s -> profile.%s" % (key, pick))

# ---------------------------------------------------------------- parser
parser_src = read(PARSER)

NEW_MAP = r"""  ProfileType _mapProtocol(String protocol) {
    switch (protocol.trim().toLowerCase()) {
      case 'vmess':
        return ProfileType.vmess;
      case 'vless':
      case 'reality':
        return ProfileType.vless;
      case 'trojan':
      case 'trojan-go':
        return ProfileType.trojan;
      case 'shadowsocks':
      case 'ss':
        return ProfileType.shadowsocks;
      case 'hysteria2':
      case 'hy2':
        return ProfileType.hysteria2;
      case 'tuic':
      case 'tuic5':
        return ProfileType.tuic;
      case 'wireguard':
      case 'wg':
        return ProfileType.wireguard;
      case 'socks':
      case 'socks5':
      case 'socks4':
        return ProfileType.socks;
      case 'http':
      case 'https':
        return ProfileType.http;
      default:
        return ProfileType.unknown;
    }
  }
"""

patched = replace_block(parser_src, "ProfileType _mapProtocol(String protocol) {", NEW_MAP)
if patched is None:
    die("متد _mapProtocol پیدا نشد.")
backup(PARSER)
PARSER.write_text(patched, encoding="utf-8")
print("[OK] _mapProtocol به‌روزرسانی شد.")

# ---------------------------------------------------------------- generator
NEW_SWITCH = r"""  Map<String, dynamic> _buildOutbound(Profile profile) {
    switch (profile.type) {
      case ProfileType.vmess:
        return _buildVmessOutbound(profile);
      case ProfileType.vless:
        return _buildVlessOutbound(profile);
      case ProfileType.trojan:
        return _buildTrojanOutbound(profile);
      case ProfileType.shadowsocks:
        return _buildShadowsocksOutbound(profile);
      case ProfileType.socks:
        return _buildSocksOutbound(profile);
      case ProfileType.http:
        return _buildHttpOutbound(profile);
      case ProfileType.hysteria2:
        return _buildHysteria2Outbound(profile);
      case ProfileType.tuic:
        return _buildTuicOutbound(profile);
      case ProfileType.wireguard:
        return _buildWireGuardOutbound(profile);
      case ProfileType.unknown:
        throw const SingBoxConfigException(
          'Unknown profile type cannot be converted to a sing-box outbound.',
        );
    }
  }
"""

HELPERS = r"""
  // ===================== phase 3: extra protocols =====================

  void _ensure(bool condition, String message) {
    if (!condition) {
      throw SingBoxConfigException(message);
    }
  }

  String _textOf(dynamic value) {
    if (value == null) {
      return '';
    }
    return value.toString().trim();
  }

  String _hostOf(Profile profile) => _textOf(profile.__HOST__);

  String _secretOf(Profile profile) => _textOf(profile.__SECRET__);

  String _uuidOf(Profile profile) => _textOf(profile.__UUID__);

  int _portOf(Profile profile, int fallback) {
    final dynamic value = profile.__PORT__;
    if (value is int && value > 0) {
      return value;
    }
    return int.tryParse(_textOf(value)) ?? fallback;
  }

  bool _flagOf(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    return normalized == '1' || normalized == 'true' || normalized == 'yes';
  }

  List<String> _csv(String? value) {
    if (value == null || value.trim().isEmpty) {
      return const <String>[];
    }
    return value
        .split(',')
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toList(growable: false);
  }

  /// پارامترهای کوئری لینک اشتراک را (کلیدها lowercase) برمی‌گرداند.
  Map<String, String> _queryParams(Profile profile) {
    final text = _textOf(profile.__RAW__);
    if (text.isEmpty) {
      return const <String, String>{};
    }
    final questionMark = text.indexOf('?');
    if (questionMark < 0) {
      return const <String, String>{};
    }
    var query = text.substring(questionMark + 1);
    final hash = query.indexOf('#');
    if (hash >= 0) {
      query = query.substring(0, hash);
    }
    final result = <String, String>{};
    for (final part in query.split('&')) {
      if (part.isEmpty) {
        continue;
      }
      final eq = part.indexOf('=');
      if (eq <= 0) {
        continue;
      }
      try {
        final key = Uri.decodeComponent(part.substring(0, eq)).toLowerCase();
        result[key] = Uri.decodeComponent(part.substring(eq + 1));
      } catch (_) {
        // پارامتر خراب نادیده گرفته می‌شود.
      }
    }
    return result;
  }

  Map<String, dynamic> _tlsBlock(
    Map<String, String> params,
    String host, {
    bool enabled = true,
  }) {
    final serverName = _textOf(
      params['sni'] ?? params['peer'] ?? params['host'] ?? host,
    );
    final alpn = _csv(params['alpn']);
    return <String, dynamic>{
      'enabled': enabled,
      if (serverName.isNotEmpty) 'server_name': serverName,
      'insecure': _flagOf(params['insecure']) ||
          _flagOf(params['allowinsecure']) ||
          _flagOf(params['skip-cert-verify']),
      if (alpn.isNotEmpty) 'alpn': alpn,
    };
  }

  Map<String, dynamic> _buildHysteria2Outbound(Profile profile) {
    final host = _hostOf(profile);
    _ensure(host.isNotEmpty, 'Hysteria2 server address is empty.');
    final params = _queryParams(profile);
    final password = _secretOf(profile).isNotEmpty
        ? _secretOf(profile)
        : _textOf(params['password'] ?? params['auth']);
    _ensure(password.isNotEmpty, 'Hysteria2 password is empty.');

    final obfs = _textOf(params['obfs']);
    final obfsPassword = _textOf(
      params['obfs-password'] ?? params['obfs_password'] ?? params['obfsparam'],
    );
    final up = int.tryParse(_textOf(params['upmbps'] ?? params['up']));
    final down = int.tryParse(_textOf(params['downmbps'] ?? params['down']));

    return <String, dynamic>{
      'type': 'hysteria2',
      'tag': _safeTag(profile),
      'server': host,
      'server_port': _portOf(profile, 443),
      'password': password,
      if (up != null && up > 0) 'up_mbps': up,
      if (down != null && down > 0) 'down_mbps': down,
      if (obfs.isNotEmpty)
        'obfs': <String, dynamic>{
          'type': obfs,
          if (obfsPassword.isNotEmpty) 'password': obfsPassword,
        },
      'tls': _tlsBlock(params, host),
    };
  }

  Map<String, dynamic> _buildTuicOutbound(Profile profile) {
    final host = _hostOf(profile);
    _ensure(host.isNotEmpty, 'TUIC server address is empty.');
    final params = _queryParams(profile);
    final uuid = _uuidOf(profile).isNotEmpty
        ? _uuidOf(profile)
        : _textOf(params['uuid']);
    _ensure(uuid.isNotEmpty, 'TUIC uuid is empty.');
    final password = _secretOf(profile).isNotEmpty
        ? _secretOf(profile)
        : _textOf(params['password']);

    final congestion = _textOf(
      params['congestion_control'] ?? params['congestion'],
    );
    final relayMode = _textOf(
      params['udp_relay_mode'] ?? params['udp-relay-mode'],
    );

    final tls = _tlsBlock(params, host);
    if (!tls.containsKey('alpn')) {
      tls['alpn'] = const <String>['h3'];
    }

    return <String, dynamic>{
      'type': 'tuic',
      'tag': _safeTag(profile),
      'server': host,
      'server_port': _portOf(profile, 443),
      'uuid': uuid,
      if (password.isNotEmpty) 'password': password,
      'congestion_control': congestion.isEmpty ? 'bbr' : congestion,
      'udp_relay_mode': relayMode.isEmpty ? 'native' : relayMode,
      if (_flagOf(params['zero_rtt_handshake']) ||
          _flagOf(params['reduce_rtt']))
        'zero_rtt_handshake': true,
      'tls': tls,
    };
  }

  Map<String, dynamic> _buildWireGuardOutbound(Profile profile) {
    final host = _hostOf(profile);
    _ensure(host.isNotEmpty, 'WireGuard endpoint address is empty.');
    final params = _queryParams(profile);

    var privateKey = _secretOf(profile);
    if (privateKey.isEmpty) {
      privateKey = _textOf(
        params['privatekey'] ?? params['secret_key'] ?? params['pk'],
      );
    }
    _ensure(privateKey.isNotEmpty, 'WireGuard private key is empty.');

    final peerPublicKey = _textOf(
      params['publickey'] ?? params['peer_public_key'] ?? params['pubkey'],
    );
    _ensure(peerPublicKey.isNotEmpty, 'WireGuard peer public key is empty.');

    var localAddress = _csv(params['address'] ?? params['ip']);
    if (localAddress.isEmpty) {
      localAddress = const <String>['172.16.0.2/32'];
    }

    final preSharedKey = _textOf(
      params['presharedkey'] ?? params['pre_shared_key'] ?? params['psk'],
    );
    final mtu = int.tryParse(_textOf(params['mtu']));
    final reserved = _csv(params['reserved'])
        .map((String item) => int.tryParse(item) ?? 0)
        .toList(growable: false);

    return <String, dynamic>{
      'type': 'wireguard',
      'tag': _safeTag(profile),
      'server': host,
      'server_port': _portOf(profile, 51820),
      'local_address': localAddress,
      'private_key': privateKey,
      'peer_public_key': peerPublicKey,
      if (preSharedKey.isNotEmpty) 'pre_shared_key': preSharedKey,
      'mtu': (mtu != null && mtu >= 1280 && mtu <= 1500) ? mtu : 1408,
      if (reserved.length == 3) 'reserved': reserved,
    };
  }
"""

for placeholder, name in resolved.items():
    HELPERS = HELPERS.replace(placeholder, name)

patched_gen = replace_block(
    gen_src, "Map<String, dynamic> _buildOutbound(Profile profile) {", NEW_SWITCH
)
if patched_gen is None:
    die("متد _buildOutbound پیدا نشد.")

if "_buildHysteria2Outbound(Profile profile) {" in patched_gen:
    print("[i] متدهای سازنده از قبل موجود بودند؛ فقط switch به‌روز شد.")
else:
    close_idx = patched_gen.rstrip().rfind("}")
    if close_idx == -1:
        die("آکولاد پایانی کلاس پیدا نشد.")
    patched_gen = (
        patched_gen[:close_idx] + HELPERS + patched_gen[close_idx:]
    )

backup(GEN)
GEN.write_text(patched_gen, encoding="utf-8")
print("[OK] sing_box_config_generator.dart به‌روزرسانی شد.")
print("\n[DONE] حالا اجرا کن:  flutter analyze")
