#!/usr/bin/env python3
"""
1) generator: افزودن پشتیبانی vmess (base64 JSON) و http
2) generator test: اصلاح انتظار tag به 'proxy'
3) patcher: انتقال dns-bootstrap به انتهای لیست + گارد Tor برای جلوگیری از نشت DNS
"""
import re
import shutil
from pathlib import Path

GEN = Path("lib/features/sing_box/application/sing_box_config_generator.dart")
GEN_TEST = Path("test/features/sing_box/application/sing_box_config_generator_test.dart")
PATCHER = Path("lib/features/sing_box/application/admin_config_patcher.dart")

ok, fail = [], []


def backup(p: Path) -> None:
    b = p.with_suffix(p.suffix + ".bak_tests")
    if not b.exists():
        shutil.copy2(p, b)


def report(name: str, changed: bool, note: str = "") -> None:
    (ok if changed else fail).append(f"{name}{(' :: ' + note) if note else ''}")


# ---------------------------------------------------------------- generator
src = GEN.read_text(encoding="utf-8")
backup(GEN)

# --- 1. early-return برای vmess قبل از Uri.parse
anchor = "  Map<String, dynamic> _buildOutboundFromUri(Profile profile) {\n"
if "_buildVmessOutbound(profile" in src:
    report("gen/vmess-early-return", True, "از قبل موجود بود")
elif anchor in src:
    src = src.replace(
        anchor,
        anchor
        + "    // vmess به صورت base64(JSON) است و با Uri.parse قابل تجزیه نیست.\n"
        + "    if (profile.type == ProfileType.vmess) {\n"
        + "      return _buildVmessOutbound(profile, 'proxy');\n"
        + "    }\n",
        1,
    )
    report("gen/vmess-early-return", True)
else:
    report("gen/vmess-early-return", False, "امضای _buildOutboundFromUri پیدا نشد")

# --- 2. شاخه http در switch
if "case ProfileType.http:" in src:
    report("gen/http-case", True, "از قبل موجود بود")
else:
    m = re.search(r"\n(\s*)default:\n\s*throw SingBoxConfigException\(\n", src)
    if m:
        indent = m.group(1)
        insert = (
            f"\n{indent}case ProfileType.http:\n"
            f"{indent}  return _buildHttpOutbound(uri, params, tag);\n"
        )
        src = src[: m.start()] + insert + src[m.start() + 1 :]
        report("gen/http-case", True)
    else:
        report("gen/http-case", False, "شاخه default پیدا نشد")

# --- 3. متدهای جدید
NEW_METHODS = r'''
  /// vmess://BASE64(JSON) را به outbound سازگار با sing-box تبدیل می‌کند.
  Map<String, dynamic> _buildVmessOutbound(Profile profile, String tag) {
    final String payload = profile.rawConfig
        .trim()
        .replaceFirst(RegExp(r'^vmess://', caseSensitive: false), '')
        .trim();
    if (payload.isEmpty) {
      throw const SingBoxConfigException('محتوای لینک vmess خالی است.');
    }

    final Map<String, dynamic> node = _decodeVmessPayload(payload);

    final String server = (node['add'] ?? node['address'] ?? '').toString();
    final int port = _asInt(node['port']);
    final String uuid = (node['id'] ?? node['uuid'] ?? '').toString();
    if (server.isEmpty || port <= 0 || uuid.isEmpty) {
      throw const SingBoxConfigException(
          'لینک vmess ناقص است (add/port/id الزامی هستند).');
    }

    String security = (node['scy'] ?? node['security'] ?? 'auto').toString();
    if (security.isEmpty || security == 'none') {
      security = 'auto';
    }

    final Map<String, dynamic> outbound = <String, dynamic>{
      'type': 'vmess',
      'tag': tag,
      'server': server,
      'server_port': port,
      'uuid': uuid,
      'security': security,
      'alter_id': _asInt(node['aid'] ?? node['alterId'] ?? 0),
    };

    final String net = (node['net'] ?? 'tcp').toString().toLowerCase();
    final String host = (node['host'] ?? '').toString();
    final String rawPath = (node['path'] ?? '').toString();
    final String path = rawPath.isEmpty ? '/' : rawPath;
    final String sniValue = (node['sni'] ?? '').toString();
    final String sni = sniValue.isNotEmpty ? sniValue : host;
    final String tls = (node['tls'] ?? '').toString().toLowerCase();

    if (net == 'ws') {
      outbound['transport'] = <String, dynamic>{
        'type': 'ws',
        'path': path,
        if (host.isNotEmpty) 'headers': <String, dynamic>{'Host': host},
      };
    } else if (net == 'grpc') {
      outbound['transport'] = <String, dynamic>{
        'type': 'grpc',
        'service_name': rawPath,
      };
    } else if (net == 'h2' || net == 'http') {
      outbound['transport'] = <String, dynamic>{
        'type': 'http',
        if (host.isNotEmpty) 'host': <String>[host],
        'path': path,
      };
    }

    if (tls == 'tls' || tls == 'reality') {
      outbound['tls'] = <String, dynamic>{
        'enabled': true,
        'server_name': sni.isNotEmpty ? sni : server,
        'utls': <String, dynamic>{
          'enabled': true,
          'fingerprint': (node['fp'] ?? 'chrome').toString(),
        },
      };
    }

    return outbound;
  }

  Map<String, dynamic> _decodeVmessPayload(String payload) {
    final String normalized = payload.replaceAll('-', '+').replaceAll('_', '/');
    final int missing = (4 - normalized.length % 4) % 4;
    final String padded = normalized + ('=' * missing);
    final String decoded = utf8.decode(base64.decode(padded));
    final Object? parsed = json.decode(decoded);
    if (parsed is! Map) {
      throw const SingBoxConfigException('ساختار JSON لینک vmess نامعتبر است.');
    }
    return Map<String, dynamic>.from(parsed);
  }

  /// http:// یا https:// با احراز هویت اختیاری.
  Map<String, dynamic> _buildHttpOutbound(
      Uri uri, Map<String, String> params, String tag) {
    final List<String> credentials = uri.userInfo.split(':');
    final String username =
        credentials.isNotEmpty ? _safeDecode(credentials.first) : '';
    final String password =
        credentials.length > 1 ? _safeDecode(credentials[1]) : '';
    final bool useTls = uri.scheme.toLowerCase() == 'https' ||
        (params['security'] ?? '').toLowerCase() == 'tls';

    final Map<String, dynamic> outbound = <String, dynamic>{
      'type': 'http',
      'tag': tag,
      'server': uri.host,
      'server_port': uri.hasPort ? uri.port : (useTls ? 443 : 80),
    };
    if (username.isNotEmpty) {
      outbound['username'] = username;
    }
    if (password.isNotEmpty) {
      outbound['password'] = password;
    }
    if (useTls) {
      outbound['tls'] = <String, dynamic>{
        'enabled': true,
        'server_name': params['sni'] ?? uri.host,
      };
    }
    return outbound;
  }

  String _safeDecode(String value) {
    try {
      return Uri.decodeComponent(value);
    } catch (_) {
      return value;
    }
  }

  int _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString().trim() ?? '') ?? 0;
  }
'''

helper_anchor = "  Map<String, dynamic>? _tryDecodeJsonObject(String raw) {"
if "_buildVmessOutbound(Profile profile" in src:
    report("gen/new-methods", True, "از قبل موجود بود")
elif helper_anchor in src:
    src = src.replace(helper_anchor, NEW_METHODS.strip("\n") + "\n\n" + helper_anchor, 1)
    report("gen/new-methods", True)
else:
    report("gen/new-methods", False, "انکر _tryDecodeJsonObject پیدا نشد")

GEN.write_text(src, encoding="utf-8")

# ------------------------------------------------------------ generator test
tsrc = GEN_TEST.read_text(encoding="utf-8")
backup(GEN_TEST)
old = "expect(outbound['tag'], 'VMess_Test');"
new = "expect(outbound['tag'], 'proxy');"
if new in tsrc:
    report("test/vmess-tag", True, "از قبل اصلاح شده بود")
elif old in tsrc:
    tsrc = tsrc.replace(old, new, 1)
    GEN_TEST.write_text(tsrc, encoding="utf-8")
    report("test/vmess-tag", True)
else:
    report("test/vmess-tag", False, "assertion مربوط به tag پیدا نشد")

# ---------------------------------------------------------------- patcher
psrc = PATCHER.read_text(encoding="utf-8")
backup(PATCHER)

# --- bootstrap به انتهای لیست
if "servers.insert(0," in psrc:
    psrc = psrc.replace("servers.insert(0,", "servers.add(", 1)
    report("patcher/bootstrap-order", True)
elif "servers.add(" in psrc and "dns-bootstrap" in psrc:
    report("patcher/bootstrap-order", True, "از قبل با add اضافه می‌شد")
else:
    report("patcher/bootstrap-order", False, "الگوی insert(0, پیدا نشد")

# --- گارد Tor در ابتدای _patchDns
if "_usesTorDns(config)" in psrc:
    report("patcher/tor-guard", True, "از قبل موجود بود")
else:
    m = re.search(r"(_patchDns\((?:.|\n)*?\)\s*\{\n)", psrc)
    if m:
        guard = (
            "    // در حالت Tor، DNS محلی (127.0.0.1:5353) نباید بازنویسی شود؛\n"
            "    // در غیر این صورت bootstrap مستقیم باعث نشت DNS می‌شود.\n"
            "    if (_usesTorDns(config)) {\n"
            "      return config;\n"
            "    }\n"
        )
        psrc = psrc[: m.end()] + guard + psrc[m.end() :]
        report("patcher/tor-guard", True)
    else:
        report("patcher/tor-guard", False, "امضای _patchDns پیدا نشد")

# --- متد کمکی _usesTorDns
TOR_HELPER = '''  /// آیا DNS محلی Tor در کانفیگ فعال است؟
  bool _usesTorDns(Map<String, dynamic> config) {
    final Object? dns = config['dns'];
    if (dns is! Map) {
      return false;
    }
    final Object? servers = dns['servers'];
    if (servers is! List) {
      return false;
    }
    for (final Object? server in servers) {
      if (server is Map &&
          (server['address'] ?? '').toString().contains('127.0.0.1:5353')) {
        return true;
      }
    }
    return false;
  }

'''
if "bool _usesTorDns(" in psrc:
    report("patcher/tor-helper", True, "از قبل موجود بود")
else:
    ha = "  String _dnsAddress(AdminSettings settings) {"
    if ha in psrc:
        psrc = psrc.replace(ha, TOR_HELPER + ha, 1)
        report("patcher/tor-helper", True)
    else:
        report("patcher/tor-helper", False, "انکر _dnsAddress پیدا نشد")

PATCHER.write_text(psrc, encoding="utf-8")

# ---------------------------------------------------------------- خروجی
print("=== موفق ===")
for item in ok:
    print("  [OK]", item)
if fail:
    print("=== ناموفق (نیاز به بررسی) ===")
    for item in fail:
        print("  [!!]", item)
    print("\n--- بدنه _patchDns برای بررسی ---")
    lines = PATCHER.read_text(encoding="utf-8").splitlines()
    for i, line in enumerate(lines, 1):
        if "_patchDns" in line or "dns-bootstrap" in line or "insert(" in line:
            lo, hi = max(0, i - 4), min(len(lines), i + 14)
            print(f"... خطوط {lo + 1}-{hi} ...")
            for n in range(lo, hi):
                print(f"{n + 1:4d}| {lines[n]}")
            break
else:
    print("\nهمه پچ‌ها اعمال شد.")
