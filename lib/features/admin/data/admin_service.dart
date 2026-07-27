import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/admin_settings.dart';

/// مدیریت رمز و تنظیمات پنل ادمین.
/// رمز به‌صورت متن ذخیره نمی‌شود؛ فقط SHA-256 از (salt + password).
class AdminService {
  AdminService._();

  static const String _storageKey = 'admin_settings_v1';
  static const String defaultPassword = 'admin';

  static AdminSettings? _cache;
  static bool _unlocked = false;

  static bool get isUnlocked => _unlocked;

  static void lock() {
    _unlocked = false;
  }

  static Future<AdminSettings> load() async {
    final AdminSettings? cached = _cache;
    if (cached != null) {
      return cached;
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      final AdminSettings created = _withPassword(
        const AdminSettings(passwordHash: '', salt: ''),
        defaultPassword,
      );
      await _persist(prefs, created);
      _cache = created;
      return created;
    }
    AdminSettings settings;
    try {
      settings = AdminSettings.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } on Object {
      settings = _withPassword(
        const AdminSettings(passwordHash: '', salt: ''),
        defaultPassword,
      );
      await _persist(prefs, settings);
    }
    if (settings.passwordHash.isEmpty || settings.salt.isEmpty) {
      settings = _withPassword(settings, defaultPassword);
      await _persist(prefs, settings);
    }
    _cache = settings;
    return settings;
  }

  static Future<void> save(AdminSettings settings) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await _persist(prefs, settings);
    _cache = settings;
  }

  static Future<bool> unlock(String password) async {
    final AdminSettings settings = await load();
    final bool ok = _hash(settings.salt, password) == settings.passwordHash;
    if (ok) {
      _unlocked = true;
    }
    return ok;
  }

  static Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final AdminSettings settings = await load();
    if (_hash(settings.salt, currentPassword) != settings.passwordHash) {
      return false;
    }
    await save(_withPassword(settings, newPassword));
    return true;
  }

  static Future<bool> isDefaultPassword() async {
    final AdminSettings settings = await load();
    return _hash(settings.salt, defaultPassword) == settings.passwordHash;
  }

  static Future<void> _persist(
    SharedPreferences prefs,
    AdminSettings settings,
  ) async {
    await prefs.setString(_storageKey, jsonEncode(settings.toJson()));
  }

  static AdminSettings _withPassword(AdminSettings base, String password) {
    final String salt = _newSalt();
    return base.copyWith(salt: salt, passwordHash: _hash(salt, password));
  }

  static String _newSalt() {
    final Random random = Random.secure();
    final List<int> bytes =
        List<int>.generate(16, (int _) => random.nextInt(256));
    return _toHex(bytes);
  }

  static String _hash(String salt, String password) {
    return _toHex(_sha256(utf8.encode('$salt:$password')));
  }

  static String _toHex(List<int> bytes) {
    final StringBuffer buffer = StringBuffer();
    for (final int byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  // ---- SHA-256 خالص Dart (بدون وابستگی خارجی) ----

  static const List<int> _k = <int>[
    0x428a2f98,
    0x71374491,
    0xb5c0fbcf,
    0xe9b5dba5,
    0x3956c25b,
    0x59f111f1,
    0x923f82a4,
    0xab1c5ed5,
    0xd807aa98,
    0x12835b01,
    0x243185be,
    0x550c7dc3,
    0x72be5d74,
    0x80deb1fe,
    0x9bdc06a7,
    0xc19bf174,
    0xe49b69c1,
    0xefbe4786,
    0x0fc19dc6,
    0x240ca1cc,
    0x2de92c6f,
    0x4a7484aa,
    0x5cb0a9dc,
    0x76f988da,
    0x983e5152,
    0xa831c66d,
    0xb00327c8,
    0xbf597fc7,
    0xc6e00bf3,
    0xd5a79147,
    0x06ca6351,
    0x14292967,
    0x27b70a85,
    0x2e1b2138,
    0x4d2c6dfc,
    0x53380d13,
    0x650a7354,
    0x766a0abb,
    0x81c2c92e,
    0x92722c85,
    0xa2bfe8a1,
    0xa81a664b,
    0xc24b8b70,
    0xc76c51a3,
    0xd192e819,
    0xd6990624,
    0xf40e3585,
    0x106aa070,
    0x19a4c116,
    0x1e376c08,
    0x2748774c,
    0x34b0bcb5,
    0x391c0cb3,
    0x4ed8aa4a,
    0x5b9cca4f,
    0x682e6ff3,
    0x748f82ee,
    0x78a5636f,
    0x84c87814,
    0x8cc70208,
    0x90befffa,
    0xa4506ceb,
    0xbef9a3f7,
    0xc67178f2,
  ];

  static int _rotr(int x, int n) => ((x >> n) | (x << (32 - n))) & 0xFFFFFFFF;

  static List<int> _sha256(List<int> input) {
    final List<int> h = <int>[
      0x6a09e667,
      0xbb67ae85,
      0x3c6ef372,
      0xa54ff53a,
      0x510e527f,
      0x9b05688c,
      0x1f83d9ab,
      0x5be0cd19,
    ];
    final List<int> message = List<int>.of(input);
    final int bitLength = input.length * 8;
    message.add(0x80);
    while (message.length % 64 != 56) {
      message.add(0);
    }
    for (int i = 7; i >= 0; i--) {
      message.add((bitLength >> (8 * i)) & 0xFF);
    }

    final List<int> w = List<int>.filled(64, 0);
    for (int chunk = 0; chunk < message.length; chunk += 64) {
      for (int i = 0; i < 16; i++) {
        final int j = chunk + i * 4;
        w[i] = (message[j] << 24) |
            (message[j + 1] << 16) |
            (message[j + 2] << 8) |
            message[j + 3];
      }
      for (int i = 16; i < 64; i++) {
        final int s0 =
            _rotr(w[i - 15], 7) ^ _rotr(w[i - 15], 18) ^ (w[i - 15] >> 3);
        final int s1 =
            _rotr(w[i - 2], 17) ^ _rotr(w[i - 2], 19) ^ (w[i - 2] >> 10);
        w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xFFFFFFFF;
      }

      int a = h[0];
      int b = h[1];
      int c = h[2];
      int d = h[3];
      int e = h[4];
      int f = h[5];
      int g = h[6];
      int hh = h[7];

      for (int i = 0; i < 64; i++) {
        final int s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
        final int ch = (e & f) ^ ((~e & 0xFFFFFFFF) & g);
        final int t1 = (hh + s1 + ch + _k[i] + w[i]) & 0xFFFFFFFF;
        final int s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
        final int maj = (a & b) ^ (a & c) ^ (b & c);
        final int t2 = (s0 + maj) & 0xFFFFFFFF;
        hh = g;
        g = f;
        f = e;
        e = (d + t1) & 0xFFFFFFFF;
        d = c;
        c = b;
        b = a;
        a = (t1 + t2) & 0xFFFFFFFF;
      }

      h[0] = (h[0] + a) & 0xFFFFFFFF;
      h[1] = (h[1] + b) & 0xFFFFFFFF;
      h[2] = (h[2] + c) & 0xFFFFFFFF;
      h[3] = (h[3] + d) & 0xFFFFFFFF;
      h[4] = (h[4] + e) & 0xFFFFFFFF;
      h[5] = (h[5] + f) & 0xFFFFFFFF;
      h[6] = (h[6] + g) & 0xFFFFFFFF;
      h[7] = (h[7] + hh) & 0xFFFFFFFF;
    }

    final List<int> out = <int>[];
    for (final int value in h) {
      out.addAll(<int>[
        (value >> 24) & 0xFF,
        (value >> 16) & 0xFF,
        (value >> 8) & 0xFF,
        value & 0xFF,
      ]);
    }
    return out;
  }
}
