#!/usr/bin/env python3
"""
Patch: افزودن Hysteria2 و TUIC به V2rayStk
اجرای دوباره امن است (idempotent) و از هر فایل بکاپ .bak می‌گیرد.
"""

import os
import shutil
import sys

ROOT = os.getcwd()
GEN = os.path.join(ROOT, "lib/features/sing_box/application/sing_box_config_generator.dart")
PARSER = os.path.join(ROOT, "lib/features/profiles/application/profile_import_parser.dart")


def backup(path):
    bak = path + ".bak"
    if not os.path.exists(bak):
        shutil.copy2(path, bak)
        print("  بکاپ:", os.path.relpath(bak, ROOT))


def read(p):
    with open(p, "r", encoding="utf-8") as f:
        return f.read()


def write(p, t):
    with open(p, "w", encoding="utf-8") as f:
        f.write(t)


# ---------------------------------------------------------------- generator
SWITCH_ANCHOR = """      case ProfileType.wireguard:
      case ProfileType.hysteria2:
      case ProfileType.tuic:
      case ProfileType.unknown:"""

SWITCH_REPLACEMENT = """      case ProfileType.hysteria2:
        return _buildHysteria2Outbound(profile);
      case ProfileType.tuic:
        return _buildTuicOutbound(profile);
      case ProfileType.wireguard:
      case ProfileType.unknown:"""

NEW_METHODS = r"""
  // ----- Hysteria2 -----------------------------------------------------------
  Map<String, dynamic> _buildHysteria2Outbound(Profile profile) {
    final Uri uri = Uri.parse(profile.rawConfig);
    final String server = uri.host;
    final int port = uri.hasPort && uri.port != 0 ? uri.port : 443;
    _require(server.isNotEmpty, 'Hysteria2 server host is required.');

    final String password = Uri.decodeComponent(uri.userInfo);
    _require(password.isNotEmpty, 'Hysteria2 password is required.');

    final Map<String, String> q = uri.queryParameters;
    final String sni = q['sni'] ?? q['peer'] ?? server;

    final Map<String, dynamic> outbound = <String, dynamic>{
      'type': 'hysteria2',
      'tag': _safeTag(profile),
      'server': server,
      'server_port': port,
      'password': password,
      'tls': <String, dynamic>{
        'enabled': true,
        'server_name': sni,
        'insecure': _isTruthy(q['insecure']),
        'alpn': _readAlpn(q['alpn'], fallback: 'h3'),
      },
    };

    final int? up = _readMbps(q['upmbps'] ?? q['up']);
    final int? down = _readMbps(q['downmbps'] ?? q['down']);
    if (up != null) outbound['up_mbps'] = up;
    if (down != null) outbound['down_mbps'] = down;

    final String? obfs = q['obfs'];
    if (obfs != null && obfs.trim().isNotEmpty) {
      outbound['obfs'] = <String, dynamic>{
        'type': obfs.trim(),
        'password': q['obfs-password'] ?? q['obfs_password'] ?? '',
      };
    }
    return outbound;
  }

  // ----- TUIC ----------------------------------------------------------------
  Map<String, dynamic> _buildTuicOutbound(Profile profile) {
    final Uri uri = Uri.parse(profile.rawConfig);
    final String server = uri.host;
    final int port = uri.hasPort && uri.port != 0 ? uri.port : 443;
    _require(server.isNotEmpty, 'TUIC server host is required.');

    final List<String> creds = uri.userInfo.split(':');
    final String uuid = Uri.decodeComponent(creds.isNotEmpty ? creds[0] : '');
    final String password =
        creds.length > 1 ? Uri.decodeComponent(creds[1]) : '';
    _require(uuid.isNotEmpty, 'TUIC uuid is required.');

    final Map<String, String> q = uri.queryParameters;
    final String sni = q['sni'] ?? q['peer'] ?? server;

    return <String, dynamic>{
      'type': 'tuic',
      'tag': _safeTag(profile),
      'server': server,
      'server_port': port,
      'uuid': uuid,
      'password': password,
      'congestion_control': q['congestion_control'] ?? 'bbr',
      'udp_relay_mode': q['udp_relay_mode'] ?? 'native',
      'zero_rtt_handshake': _isTruthy(q['zero_rtt_handshake']),
      'tls': <String, dynamic>{
        'enabled': true,
        'server_name': sni,
        'insecure': _isTruthy(q['allow_insecure'] ?? q['insecure']),
        'alpn': _readAlpn(q['alpn'], fallback: 'h3'),
      },
    };
  }

  // ----- Helpers -------------------------------------------------------------
  int? _readMbps(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final int? parsed = int.tryParse(value.trim());
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  List<String> _readAlpn(String? value, {required String fallback}) {
    if (value == null || value.trim().isEmpty) return <String>[fallback];
    final List<String> parts = value
        .split(',')
        .map((String e) => e.trim())
        .where((String e) => e.isNotEmpty)
        .toList();
    return parts.isEmpty ? <String>[fallback] : parts;
  }

  bool _isTruthy(String? value) {
    if (value == null) return false;
    final String v = value.trim().toLowerCase();
    return v == '1' || v == 'true' || v == 'yes';
  }
"""


def patch_generator():
    print("• sing_box_config_generator.dart")
    src = read(GEN)

    if "_buildHysteria2Outbound" in src:
        print("  از قبل patch شده — رد شد.")
        return

    backup(GEN)

    if SWITCH_ANCHOR not in src:
        print("  خطا: anchor بلوک switch پیدا نشد.")
        sys.exit(1)
    src = src.replace(SWITCH_ANCHOR, SWITCH_REPLACEMENT, 1)
    print("  بلوک switch شکسته شد.")

    idx = src.rstrip().rfind("}")
    if idx == -1:
        print("  خطا: آکولاد پایانی کلاس پیدا نشد.")
        sys.exit(1)
    src = src[:idx] + NEW_METHODS + "}\n"
    print("  متدهای Hysteria2/TUIC + helperها اضافه شد.")

    write(GEN, src)
    print("  ذخیره شد.")


# ------------------------------------------------------------------- parser
PARSE_ANCHOR = """    if (value.startsWith('ss://')) {"""

PARSE_BLOCK = """    if (value.startsWith('hysteria2://') || value.startsWith('hy2://')) {
      return _parseUriBased(value, ProfileType.hysteria2);
    }

    if (value.startsWith('tuic://') || value.startsWith('tuic-v5://')) {
      return _parseUriBased(value, ProfileType.tuic);
    }

    if (value.startsWith('ss://')) {"""

MAP_ANCHOR = """      case 'shadowsocks':
      case 'ss':
        return ProfileType.shadowsocks;"""

MAP_BLOCK = """      case 'shadowsocks':
      case 'ss':
        return ProfileType.shadowsocks;
      case 'hysteria2':
      case 'hy2':
        return ProfileType.hysteria2;
      case 'tuic':
      case 'tuic-v5':
        return ProfileType.tuic;"""


def patch_parser():
    print("• profile_import_parser.dart")
    src = read(PARSER)
    changed = False
    backup(PARSER)

    if "hysteria2://" not in src:
        if PARSE_ANCHOR not in src:
            print("  خطا: anchor متد parse پیدا نشد.")
            sys.exit(1)
        src = src.replace(PARSE_ANCHOR, PARSE_BLOCK, 1)
        changed = True
        print("  تشخیص scheme اضافه شد.")

    if "case 'hysteria2':" not in src:
        if MAP_ANCHOR not in src:
            print("  خطا: anchor متد _mapProtocol پیدا نشد.")
            sys.exit(1)
        src = src.replace(MAP_ANCHOR, MAP_BLOCK, 1)
        changed = True
        print("  نگاشت _mapProtocol اضافه شد.")

    if changed:
        write(PARSER, src)
        print("  ذخیره شد.")
    else:
        print("  از قبل patch شده — رد شد.")


if __name__ == "__main__":
    for p in (GEN, PARSER):
        if not os.path.exists(p):
            print("فایل پیدا نشد:", p)
            sys.exit(1)
    patch_generator()
    patch_parser()
    print("\nتمام شد. اجرا کن: flutter analyze")
