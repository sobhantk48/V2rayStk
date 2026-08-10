#!/usr/bin/env python3
import pathlib, sys

changed = []

# ---------- 1) MainActivity.kt ----------
p = pathlib.Path("android/app/src/main/kotlin/com/example/v2ray_stk/MainActivity.kt")
s = p.read_text(encoding="utf-8"); o = s

s = s.replace(
    '''                    "connect" -> {
                        StatsProvider.reset()
                        prepareAndConnect(call.argument<String>("config") ?: "")
                        result.success(null)
                    }''',
    '''                    "connect" -> {
                        StatsProvider.reset()
                        pendingTorEnabled =
                            call.argument<Boolean>("torEnabled") ?: false
                        prepareAndConnect(call.argument<String>("config") ?: "")
                        result.success(null)
                    }''')

s = s.replace(
    "    private var pendingConfig: String? = null",
    "    private var pendingConfig: String? = null\n    private var pendingTorEnabled: Boolean = false")

s = s.replace(
    '''    private fun startVpnService(config: String) {
        val intent = Intent(this, V2rayVpnService::class.java).apply {
            action = V2rayVpnService.ACTION_CONNECT
            putExtra(V2rayVpnService.EXTRA_CONFIG, config)
        }''',
    '''    private fun startVpnService(config: String) {
        val intent = Intent(this, V2rayVpnService::class.java).apply {
            action = V2rayVpnService.ACTION_CONNECT
            putExtra(V2rayVpnService.EXTRA_CONFIG, config)
            putExtra(V2rayVpnService.EXTRA_TOR_ENABLED, pendingTorEnabled)
        }''')

if s != o:
    p.write_text(s, encoding="utf-8"); changed.append("MainActivity.kt")

# ---------- 2) vpn_platform_service.dart ----------
p = pathlib.Path("lib/core/platform/vpn_platform_service.dart")
s = p.read_text(encoding="utf-8"); o = s

s = s.replace(
    '''  Future<void> connect(String config) async {
    await _channel.invokeMethod<void>(
      'connect',
      <String, dynamic>{
        'config': config,
      },
    );
  }''',
    '''  Future<void> connect(String config, {bool torEnabled = false}) async {
    await _channel.invokeMethod<void>(
      'connect',
      <String, dynamic>{
        'config': config,
        'torEnabled': torEnabled,
      },
    );
  }''')

if s != o:
    p.write_text(s, encoding="utf-8"); changed.append("vpn_platform_service.dart")

# ---------- 3) vpn_controller.dart ----------
p = pathlib.Path("lib/features/vpn/application/vpn_controller.dart")
s = p.read_text(encoding="utf-8"); o = s

s = s.replace(
    '''  Future<void> connect() async {
    state = VpnConnectionState.connecting;
    try {
      final Profile profile = await _resolveActiveProfile();
      await _service.connect(await _buildConfigJson(profile));
      state = VpnConnectionState.connected;''',
    '''  Future<void> connect() async {
    state = VpnConnectionState.connecting;
    try {
      final Profile profile = await _resolveActiveProfile();
      final bool tor = await _isTorNeeded(profile);
      await _service.connect(
        await _buildConfigJson(profile),
        torEnabled: tor,
      );
      state = VpnConnectionState.connected;''')

s = s.replace(
    '''  Future<void> connectWithProfile(Profile profile) async {
    state = VpnConnectionState.connecting;
    try {
      await _service.connect(await _buildConfigJson(profile));
      state = VpnConnectionState.connected;''',
    '''  Future<void> connectWithProfile(Profile profile) async {
    state = VpnConnectionState.connecting;
    try {
      final bool tor = await _isTorNeeded(profile);
      await _service.connect(
        await _buildConfigJson(profile),
        torEnabled: tor,
      );
      state = VpnConnectionState.connected;''')

# تابع تشخیص نیاز به Tor
if "_isTorNeeded" in s and "Future<bool> _isTorNeeded" not in s:
    s = s.replace(
        "  Future<Profile> _resolveActiveProfile() async {",
        '''  /// Tor فقط وقتی اجرا می‌شود که در پنل ادمین روشن باشد،
  /// یا پروفایل فعال صراحتاً از نوع Tor باشد.
  Future<bool> _isTorNeeded(Profile profile) async {
    if (profile.type == ProfileType.tor) {
      return true;
    }
    final AdminSettings settings = await _reader.read();
    if (settings.torEnabled) {
      return true;
    }
    final String raw = profile.rawConfig.toLowerCase();
    if (profile.type == ProfileType.socks &&
        (profile.server == '127.0.0.1' || profile.server == 'localhost') &&
        profile.port == 9050) {
      return true;
    }
    return raw.startsWith('tor://');
  }

  Future<Profile> _resolveActiveProfile() async {''')

if s != o:
    p.write_text(s, encoding="utf-8"); changed.append("vpn_controller.dart")

if not changed:
    print("!! هیچ تغییری اعمال نشد")
    sys.exit(1)
print("OK پچ شد:", ", ".join(changed))
