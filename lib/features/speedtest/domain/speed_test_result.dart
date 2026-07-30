enum SpeedTestPhase { idle, ping, download, upload, done, error }

class SpeedTestState {
  const SpeedTestState({
    this.phase = SpeedTestPhase.idle,
    this.progress = 0,
    this.pingMs = 0,
    this.jitterMs = 0,
    this.packetLossPercent = 0,
    this.downloadMbps = 0,
    this.uploadMbps = 0,
    this.currentSpeedMbps = 0,
    this.error,
  });

  final SpeedTestPhase phase;
  final double progress;
  final double pingMs;
  final double jitterMs;
  final double packetLossPercent;
  final double downloadMbps;
  final double uploadMbps;
  final double currentSpeedMbps;
  final String? error;

  bool get isRunning =>
      phase == SpeedTestPhase.ping ||
      phase == SpeedTestPhase.download ||
      phase == SpeedTestPhase.upload;

  /// امتیاز گیمینگ: پینگ و جیتر و پکت‌لاس مهمه
  int get gamingScore {
    if (phase != SpeedTestPhase.done) return 0;
    double score = 100;
    score -= (pingMs / 4).clamp(0, 50);
    score -= (jitterMs * 1.5).clamp(0, 25);
    score -= (packetLossPercent * 5).clamp(0, 25);
    return score.clamp(0, 100).round();
  }

  /// امتیاز وبگردی: پینگ + سرعت دانلود
  int get browsingScore {
    if (phase != SpeedTestPhase.done) return 0;
    double score = 100;
    score -= (pingMs / 8).clamp(0, 40);
    if (downloadMbps < 20) score -= (20 - downloadMbps) * 3;
    return score.clamp(0, 100).round();
  }

  /// امتیاز استریم: سرعت دانلود پایدار
  int get streamingScore {
    if (phase != SpeedTestPhase.done) return 0;
    double score = (downloadMbps / 50 * 100);
    score -= (packetLossPercent * 3).clamp(0, 20);
    return score.clamp(0, 100).round();
  }

  SpeedTestState copyWith({
    SpeedTestPhase? phase,
    double? progress,
    double? pingMs,
    double? jitterMs,
    double? packetLossPercent,
    double? downloadMbps,
    double? uploadMbps,
    double? currentSpeedMbps,
    String? error,
  }) {
    return SpeedTestState(
      phase: phase ?? this.phase,
      progress: progress ?? this.progress,
      pingMs: pingMs ?? this.pingMs,
      jitterMs: jitterMs ?? this.jitterMs,
      packetLossPercent: packetLossPercent ?? this.packetLossPercent,
      downloadMbps: downloadMbps ?? this.downloadMbps,
      uploadMbps: uploadMbps ?? this.uploadMbps,
      currentSpeedMbps: currentSpeedMbps ?? this.currentSpeedMbps,
      error: error ?? this.error,
    );
  }
}
