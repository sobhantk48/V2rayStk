import 'dart:async';
import 'dart:io';

import '../domain/profile.dart';

/// نتیجهٔ یک اندازه‌گیری تأخیر (TCP handshake) برای یک پروفایل.
class LatencySample {
  const LatencySample({
    required this.profileId,
    required this.latencyMs,
    this.error,
  });

  final String profileId;

  /// تأخیر برحسب میلی‌ثانیه. اگر `null` باشد یعنی تست ناموفق بوده است.
  final int? latencyMs;

  /// دلیل خطا: no-host / no-port / timeout / unreachable
  final String? error;

  bool get isOk => latencyMs != null;
}

/// اندازه‌گیری تأخیر سرورها با اتصال TCP (بدون نیاز به بالا بودن هستهٔ sing-box).
class LatencyService {
  const LatencyService();

  static const Duration defaultTimeout = Duration(seconds: 3);
  static const int defaultConcurrency = 8;

  Future<LatencySample> measureProfile(
    Profile profile, {
    Duration timeout = defaultTimeout,
  }) async {
    final String host = (profile.server ?? '').trim();
    final int? port = profile.port;

    if (host.isEmpty) {
      return LatencySample(
        profileId: profile.id,
        latencyMs: null,
        error: 'no-host',
      );
    }
    if (port == null || port <= 0 || port > 65535) {
      return LatencySample(
        profileId: profile.id,
        latencyMs: null,
        error: 'no-port',
      );
    }

    final Stopwatch watch = Stopwatch()..start();
    Socket? socket;
    try {
      socket = await Socket.connect(host, port, timeout: timeout);
      watch.stop();
      return LatencySample(
        profileId: profile.id,
        latencyMs: watch.elapsedMilliseconds,
      );
    } on SocketException {
      return LatencySample(
        profileId: profile.id,
        latencyMs: null,
        error: 'unreachable',
      );
    } on TimeoutException {
      return LatencySample(
        profileId: profile.id,
        latencyMs: null,
        error: 'timeout',
      );
    } catch (_) {
      return LatencySample(
        profileId: profile.id,
        latencyMs: null,
        error: 'error',
      );
    } finally {
      try {
        socket?.destroy();
      } catch (_) {
        // ignore
      }
    }
  }

  /// تست موازی همهٔ پروفایل‌ها با محدودیت تعداد اتصال هم‌زمان.
  Future<List<LatencySample>> measureAll(
    List<Profile> profiles, {
    Duration timeout = defaultTimeout,
    int concurrency = defaultConcurrency,
    void Function(LatencySample sample, int done, int total)? onProgress,
  }) async {
    final List<LatencySample> output = <LatencySample>[];
    if (profiles.isEmpty) {
      return output;
    }

    int cursor = 0;
    int done = 0;
    final int workers = concurrency.clamp(1, 32);

    Future<void> worker() async {
      while (true) {
        if (cursor >= profiles.length) {
          return;
        }
        final int index = cursor;
        cursor = cursor + 1;

        final LatencySample sample = await measureProfile(
          profiles[index],
          timeout: timeout,
        );
        output.add(sample);
        done = done + 1;
        onProgress?.call(sample, done, profiles.length);
      }
    }

    await Future.wait(
      List<Future<void>>.generate(workers, (int _) => worker()),
    );
    return output;
  }
}
