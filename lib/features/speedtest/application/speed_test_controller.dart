import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/speed_test_result.dart';

final speedTestControllerProvider =
    StateNotifierProvider<SpeedTestController, SpeedTestState>(
  (ref) => SpeedTestController(),
);

class SpeedTestController extends StateNotifier<SpeedTestState> {
  SpeedTestController() : super(const SpeedTestState());

  static const _pingUrl = 'https://speed.cloudflare.com/__down?bytes=0';
  static const _downloadUrl =
      'https://speed.cloudflare.com/__down?bytes=100000000';
  static const _uploadUrl = 'https://speed.cloudflare.com/__up';

  static const _pingSamples = 10;
  static const _downloadSeconds = 10;
  static const _uploadSeconds = 8;

  bool _cancelled = false;

  Future<void> start() async {
    if (state.isRunning) return;
    _cancelled = false;
    state = const SpeedTestState(phase: SpeedTestPhase.ping);
    try {
      await _runPingPhase();
      if (_cancelled) return;
      await _runDownloadPhase();
      if (_cancelled) return;
      await _runUploadPhase();
      if (_cancelled) return;
      state = state.copyWith(
        phase: SpeedTestPhase.done,
        progress: 1.0,
      );
    } catch (e) {
      if (!_cancelled) {
        state = state.copyWith(
          phase: SpeedTestPhase.error,
          error: e.toString(),
        );
      }
    }
  }

  void cancel() {
    _cancelled = true;
    state = const SpeedTestState();
  }

  // ---------------------------------------------------------------
  // فاز ۱: پینگ + جیتر + پکت‌لاس
  // ---------------------------------------------------------------
  Future<void> _runPingPhase() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    final pings = <double>[];
    var lostCount = 0;

    try {
      for (var i = 0; i < _pingSamples; i++) {
        if (_cancelled) return;
        final sw = Stopwatch()..start();
        try {
          final req = await client
              .getUrl(Uri.parse(_pingUrl))
              .timeout(const Duration(seconds: 5));
          final res = await req.close().timeout(const Duration(seconds: 5));
          await res.drain<void>();
          sw.stop();
          pings.add(sw.elapsedMilliseconds.toDouble());
        } catch (_) {
          lostCount++;
        }
        state = state.copyWith(progress: (i + 1) / _pingSamples * 0.33);
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
    } finally {
      client.close(force: true);
    }

    final avgPing =
        pings.isEmpty ? 0.0 : pings.reduce((a, b) => a + b) / pings.length;

    state = state.copyWith(
      phase: SpeedTestPhase.download,
      pingMs: avgPing,
      jitterMs: _calculateJitter(pings),
      packetLossPercent: lostCount / _pingSamples * 100,
    );
  }

  double _calculateJitter(List<double> pings) {
    if (pings.length < 2) return 0;
    var totalDiff = 0.0;
    for (var i = 0; i < pings.length - 1; i++) {
      totalDiff += (pings[i + 1] - pings[i]).abs();
    }
    return totalDiff / (pings.length - 1);
  }

  // ---------------------------------------------------------------
  // فاز ۲: دانلود
  // ---------------------------------------------------------------
  Future<void> _runDownloadPhase() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);

    var totalBytes = 0;
    var lastSpeed = 0.0;
    final sw = Stopwatch()..start();

    try {
      final req = await client
          .getUrl(Uri.parse(_downloadUrl))
          .timeout(const Duration(seconds: 10));
      final res = await req.close().timeout(const Duration(seconds: 10));

      final completer = Completer<void>();
      late final StreamSubscription<List<int>> sub;

      sub = res.listen(
        (chunk) {
          totalBytes += chunk.length;
          final elapsed = sw.elapsedMilliseconds / 1000;
          if (elapsed > 0.5) {
            lastSpeed = totalBytes * 8 / (elapsed * 1024 * 1024);
            state = state.copyWith(
              currentSpeedMbps: lastSpeed,
              progress:
                  0.33 + (elapsed / _downloadSeconds).clamp(0.0, 1.0) * 0.33,
            );
          }
          if (_cancelled || elapsed >= _downloadSeconds) {
            sub.cancel();
            if (!completer.isCompleted) completer.complete();
          }
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete();
        },
        onError: (Object e) {
          if (!completer.isCompleted) completer.completeError(e);
        },
        cancelOnError: true,
      );

      await completer.future;
    } finally {
      client.close(force: true);
    }

    if (_cancelled) return;
    state = state.copyWith(
      phase: SpeedTestPhase.upload,
      downloadMbps: lastSpeed,
      currentSpeedMbps: 0,
    );
  }

  // ---------------------------------------------------------------
  // فاز ۳: آپلود
  // ---------------------------------------------------------------
  Future<void> _runUploadPhase() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);

    final chunk = Uint8List(256 * 1024); // چانک ۲۵۶ کیلوبایتی
    var totalBytes = 0;
    var lastSpeed = 0.0;
    final sw = Stopwatch()..start();

    try {
      // آپلود رو در چند درخواست پشت‌سرهم انجام می‌دیم تا close معطل نمونه
      while (!_cancelled && sw.elapsedMilliseconds < _uploadSeconds * 1000) {
        final req = await client
            .postUrl(Uri.parse(_uploadUrl))
            .timeout(const Duration(seconds: 10));
        req.headers.contentType = ContentType.binary;

        // در هر درخواست ۴ مگابایت می‌فرستیم
        for (var i = 0; i < 16; i++) {
          if (_cancelled || sw.elapsedMilliseconds >= _uploadSeconds * 1000) {
            break;
          }
          req.add(chunk);
          totalBytes += chunk.length;
        }
        await req.flush();
        final res = await req.close().timeout(const Duration(seconds: 15));
        await res.drain<void>();

        final elapsed = sw.elapsedMilliseconds / 1000;
        if (elapsed > 0.5) {
          lastSpeed = totalBytes * 8 / (elapsed * 1024 * 1024);
          state = state.copyWith(
            currentSpeedMbps: lastSpeed,
            progress: 0.66 + (elapsed / _uploadSeconds).clamp(0.0, 1.0) * 0.34,
          );
        }
      }
    } finally {
      client.close(force: true);
    }

    if (_cancelled) return;
    state = state.copyWith(
      downloadMbps: state.downloadMbps,
      uploadMbps: lastSpeed,
      currentSpeedMbps: 0,
    );
  }
}
