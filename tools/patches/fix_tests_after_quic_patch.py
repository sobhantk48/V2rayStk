#!/usr/bin/env python3
"""همگام‌سازی تست‌ها و generator بعد از پچ QUIC/sniff/DNS."""
import re
import shutil
import pathlib

ROOT = pathlib.Path.home() / "development" / "V2rayStk"
report = []


def backup(path, tag):
    bak = path.with_suffix(path.suffix + "." + tag + ".bak")
    if not bak.exists():
        shutil.copy2(path, bak)


# ---------------------------------------------------------------- 1) generator
gen = ROOT / "lib/features/sing_box/application/sing_box_config_generator.dart"
src = gen.read_text(encoding="utf-8")

if re.search(r"'address': 'tcp://8\.8\.8\.8',\s*\n\s*'address_resolver'", src):
    report.append("generator: address_resolver از قبل بود (بدون تغییر)")
elif "'address': 'tcp://8.8.8.8'," not in src:
    report.append("!! generator: خط tcp://8.8.8.8 پیدا نشد - دستی بررسی کن")
else:
    out, done = [], False
    for line in src.split("\n"):
        out.append(line)
        if not done and line.strip() == "'address': 'tcp://8.8.8.8',":
            indent = line[: len(line) - len(line.lstrip())]
            out.append(indent + "'address_resolver': 'bootstrap-dns',")
            done = True
    backup(gen, "resolver")
    gen.write_text("\n".join(out), encoding="utf-8")
    report.append("generator: address_resolver=bootstrap-dns به proxy-dns برگشت")

# --------------------------------------------------------------- 2) sniff test
sniff = ROOT / "test/features/sing_box/application/sing_box_tor_sniff_test.dart"
src = sniff.read_text(encoding="utf-8")
orig = src

src = re.sub(
    r"test\('[^']*',\s*\(\)\s*\{\s*\n\s*expect\(tunInbound\(vlessProfile\)"
    r"\['sniff_override_destination'\], isFalse\);",
    "test('override روشن است تا نام دامنه به outbound برسد', () {\n"
    "      expect(tunInbound(vlessProfile)['sniff_override_destination'], isTrue,\n"
    "          reason: 'اگر false باشد سرور فقط IP جعلی TUN را می بیند');",
    src,
)
src = re.sub(
    r"test\('[^']*',\s*\(\)\s*\{\s*\n\s*expect\(tunInbound\(vlessProfile\)"
    r"\['domain_strategy'\], 'ipv4_only'\);",
    "test('domain_strategy محلی وجود ندارد', () {\n"
    "      expect(tunInbound(vlessProfile).containsKey('domain_strategy'), isFalse,\n"
    "          reason: 'ipv4_only باعث resolve محلی و شکستن SNI می شود');",
    src,
)

groups = list(re.finditer(r"group\('([^']*)'", src))
if len(groups) >= 2:
    g = groups[1]
    src = src[: g.start(1)] + "حالت غیرتور: دامنه به پروکسی می رسد" + src[g.end(1) :]

src = re.sub(
    r"^///.*ipv4_only.*$",
    "/// در حالت غیرتور: دامنه باید override شود تا SNI درست به سرور برسد.",
    src,
    flags=re.M,
)

if src != orig:
    backup(sniff, "override")
    sniff.write_text(src, encoding="utf-8")
    report.append("sniff test: انتظار non-Tor به override=true و بدون domain_strategy")
else:
    report.append("!! sniff test: هیچ تغییری اعمال نشد - دستی بررسی کن")

# ----------------------------------------------------------- 3) udp block test
udp = ROOT / "test/features/sing_box/application/sing_box_tor_udp_block_test.dart"
src = udp.read_text(encoding="utf-8")
orig = src
src, n = re.subn(
    r"\(rule\)\s*=>\s*rule\['network'\]\s*==\s*'udp'\s*&&\s*"
    r"rule\['outbound'\]\s*==\s*'block',",
    "(rule) =>\n"
    "      rule['network'] == 'udp' &&\n"
    "      rule['outbound'] == 'block' &&\n"
    "      rule['port'] == null,",
    src,
    count=1,
)
if n:
    backup(udp, "fullblock")
    udp.write_text(src, encoding="utf-8")
    report.append("udp test: helper فقط بلاک کامل UDP را می شمارد (port==null)")
else:
    report.append("!! udp test: الگوی helper پیدا نشد - دستی بررسی کن")

# --------------------------------------------------------- 4) تست جدید QUIC
quic = ROOT / "test/features/sing_box/application/sing_box_quic_block_test.dart"
quic.write_text(
    """import 'package:flutter_test/flutter_test.dart';
import 'package:v2ray_stk/features/profiles/domain/profile.dart';
import 'package:v2ray_stk/features/profiles/domain/profile_type.dart';
import 'package:v2ray_stk/features/sing_box/application/sing_box_config_generator.dart';

/// در حالت غیرتور فقط UDP/443 و UDP/8443 بلاک می شوند تا مرورگر از QUIC
/// به HTTP/2 روی TCP برگردد. بلاک کامل UDP فقط مخصوص Tor است.
void main() {
  const generator = SingBoxConfigGenerator();
  final now = DateTime.now();

  List<Map<String, dynamic>> routeRules(Profile profile) {
    final config = generator.generate(profile).value;
    final route = Map<String, dynamic>.from(config['route'] as Map);
    return (route['rules'] as List)
        .cast<Map>()
        .map(Map<String, dynamic>.from)
        .toList();
  }

  final vlessProfile = Profile(
    id: 'vless-quic-1',
    name: 'WS Node',
    type: ProfileType.vless,
    rawConfig:
        'vless://11111111-2222-3333-4444-555555555555@example.com:443'
        '?security=tls&type=ws&host=example.com&path=%2Fws',
    createdAt: now,
    server: 'example.com',
    port: 443,
  );

  final torProfile = Profile(
    id: 'tor-quic-1',
    name: 'Tor Local SOCKS',
    type: ProfileType.socks,
    rawConfig: 'socks://127.0.0.1:9050',
    createdAt: now,
    server: '127.0.0.1',
    port: 9050,
  );

  Map<String, dynamic>? quicRule(Profile profile) {
    for (final rule in routeRules(profile)) {
      if (rule['network'] != 'udp' || rule['outbound'] != 'block') continue;
      final ports = (rule['port'] as List?)?.cast<int>();
      if (ports != null && ports.contains(443)) return rule;
    }
    return null;
  }

  bool hasFullUdpBlock(Profile profile) => routeRules(profile).any(
        (rule) =>
            rule['network'] == 'udp' &&
            rule['outbound'] == 'block' &&
            rule['port'] == null,
      );

  group('بلاک QUIC در حالت غیرتور', () {
    test('UDP/443 بلاک است', () {
      expect(quicRule(vlessProfile), isNotNull,
          reason: 'بدون این قانون یوتیوب روی QUIC معلق می ماند');
    });

    test('UDP/8443 هم در همان قانون هست', () {
      final ports = (quicRule(vlessProfile)?['port'] as List?)?.cast<int>();
      expect(ports, contains(8443));
    });

    test('کل UDP بلاک نمی شود', () {
      expect(hasFullUdpBlock(vlessProfile), isFalse,
          reason: 'پروکسی معمولی باید UDP غیر QUIC را داشته باشد');
    });

    test('هیچ قانون بلاکی روی TCP نیست', () {
      final blocked = routeRules(vlessProfile).any((rule) =>
          rule['outbound'] == 'block' && rule['network'] == 'tcp');
      expect(blocked, isFalse);
    });
  });

  group('حالت Tor دست نخورده می ماند', () {
    test('بلاک کامل UDP باقی است', () {
      expect(hasFullUdpBlock(torProfile), isTrue);
    });
  });
}
""",
    encoding="utf-8",
)
report.append("تست جدید ساخته شد: sing_box_quic_block_test.dart")

print("\n".join("  - " + line for line in report))
