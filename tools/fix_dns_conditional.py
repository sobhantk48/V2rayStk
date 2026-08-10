#!/usr/bin/env python3
import re, sys, shutil

P = "lib/features/sing_box/application/sing_box_config_generator.dart"
src = open(P, encoding="utf-8").read()
shutil.copy(P, P + ".bak_dns")
orig = src

# ---------- 1) محاسبه isTor داخل generate ----------
old = "  SingBoxConfig generate(Profile profile) {\n    try {"
new = ("  SingBoxConfig generate(Profile profile) {\n"
       "    final bool isTor = _isTorProfile(profile);\n"
       "    try {")
assert old in src, "anchor generate() پیدا نشد"
src = src.replace(old, new, 1)

# ---------- 2) پاس دادن isTor به هر سه فراخوانی _wrap ----------
src = src.replace("_wrap(_adoptSingBoxConfig(json))",
                  "_wrap(_adoptSingBoxConfig(json), isTor: isTor)", 1)
src = src.replace("_wrap(_v2rayConverter.convert(json, tag: 'proxy'))",
                  "_wrap(_v2rayConverter.convert(json, tag: 'proxy'), isTor: isTor)", 1)
src = src.replace("_wrap(_buildOutboundFromUri(profile))",
                  "_wrap(_buildOutboundFromUri(profile), isTor: isTor)", 1)

# ---------- 3) امضای _wrap ----------
old = "  Map<String, dynamic> _wrap(Map<String, dynamic> outbound) {"
new = ("  Map<String, dynamic> _wrap(Map<String, dynamic> outbound,\n"
       "      {bool isTor = false}) {")
assert old in src, "anchor _wrap پیدا نشد"
src = src.replace(old, new, 1)

# ---------- 4) جایگزینی کل بلوک dns (۶ فاصله تورفتگی) با _buildDns ----------
start_marker = "      'dns': {"
end_marker = "      'inbounds': ["
i = src.index(start_marker)
j = src.index(end_marker)
src = src[:i] + "      'dns': _buildDns(isTor),\n" + src[j:]

# ---------- 5) SOCKS واقعی به‌جای تور هاردکد ----------
src = src.replace("        return _buildTorOutbound(uri, tag);",
                  "        return _buildSocksOutbound(uri, params, tag);", 1)

# حذف متد _buildTorOutbound
src = re.sub(
    r"  Map<String, dynamic> _buildTorOutbound\(Uri uri, String tag\) \{.*?\n  \}\n",
    "", src, flags=re.S)

# ---------- 6) تزریق متدهای جدید قبل از _tryDecodeJsonObject ----------
methods = '''  /// تشخیص پروفایل تور: SOCKS روی لوکال‌هاست
  bool _isTorProfile(Profile profile) {
    if (profile.type != ProfileType.socks) return false;
    try {
      final uri = Uri.parse(profile.rawConfig.trim());
      final String h = uri.host.toLowerCase();
      return h == '127.0.0.1' || h == 'localhost' || h == '::1';
    } catch (_) {
      return false;
    }
  }

  /// DNS داینامیک: تور از DNSPort محلی (direct)، بقیه از DNS راه‌دور (proxy)
  Map<String, dynamic> _buildDns(bool isTor) {
    final List<Map<String, dynamic>> servers = isTor
        ? <Map<String, dynamic>>[
            {
              'tag': 'proxy-dns',
              'address': 'udp://127.0.0.1:5353',
              'detour': 'direct',
            },
            {'tag': 'block-dns', 'address': 'rcode://success'},
          ]
        : <Map<String, dynamic>>[
            {
              'tag': 'proxy-dns',
              'address': 'tcp://1.1.1.1',
              'detour': 'proxy',
            },
            {'tag': 'block-dns', 'address': 'rcode://success'},
          ];

    return <String, dynamic>{
      'servers': servers,
      'rules': <Map<String, dynamic>>[],
      'final': 'proxy-dns',
      'strategy': 'ipv4_only',
      'independent_cache': true,
      'disable_cache': false,
    };
  }

  Map<String, dynamic> _buildSocksOutbound(
      Uri uri, Map<String, String> params, String tag) {
    final String host = uri.host.isNotEmpty ? uri.host : '127.0.0.1';
    final int port = uri.hasPort ? uri.port : 9050;

    final Map<String, dynamic> out = <String, dynamic>{
      'type': 'socks',
      'tag': tag,
      'server': host,
      'server_port': port,
      'version': '5',
    };

    final String info = uri.userInfo;
    if (info.isNotEmpty && info.contains(':')) {
      final int k = info.indexOf(':');
      out['username'] = Uri.decodeComponent(info.substring(0, k));
      out['password'] = Uri.decodeComponent(info.substring(k + 1));
    }
    return out;
  }

'''
anchor = "  Map<String, dynamic>? _tryDecodeJsonObject(String raw) {"
assert anchor in src, "anchor _tryDecodeJsonObject پیدا نشد"
src = src.replace(anchor, methods + anchor, 1)

if src == orig:
    print("⚠️ هیچ تغییری اعمال نشد")
    sys.exit(1)

open(P, "w", encoding="utf-8").write(src)
print("✅ پچ اعمال شد. بکاپ:", P + ".bak_dns")
for k in ["_buildDns", "_isTorProfile", "_buildSocksOutbound",
          "isTor: isTor", "_buildTorOutbound", "local-dns"]:
    print(f"  {k}: {src.count(k)}")
