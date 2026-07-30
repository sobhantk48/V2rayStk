class ProxyTraffic {
  const ProxyTraffic({
    required this.profileId,
    this.uploadBytes = 0,
    this.downloadBytes = 0,
    this.connectCount = 0,
    this.totalDurationSeconds = 0,
    this.lastUsedAt,
    this.lastPingMs,
  });

  final String profileId;
  final int uploadBytes;
  final int downloadBytes;
  final int connectCount;
  final int totalDurationSeconds;
  final DateTime? lastUsedAt;
  final int? lastPingMs;

  int get totalBytes => uploadBytes + downloadBytes;

  ProxyTraffic copyWith({
    String? profileId,
    int? uploadBytes,
    int? downloadBytes,
    int? connectCount,
    int? totalDurationSeconds,
    DateTime? lastUsedAt,
    int? lastPingMs,
  }) {
    return ProxyTraffic(
      profileId: profileId ?? this.profileId,
      uploadBytes: uploadBytes ?? this.uploadBytes,
      downloadBytes: downloadBytes ?? this.downloadBytes,
      connectCount: connectCount ?? this.connectCount,
      totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      lastPingMs: lastPingMs ?? this.lastPingMs,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'profileId': profileId,
      'uploadBytes': uploadBytes,
      'downloadBytes': downloadBytes,
      'connectCount': connectCount,
      'totalDurationSeconds': totalDurationSeconds,
      'lastUsedAt': lastUsedAt?.toIso8601String(),
      'lastPingMs': lastPingMs,
    };
  }

  factory ProxyTraffic.fromJson(Map<String, dynamic> json) {
    return ProxyTraffic(
      profileId: json['profileId'] as String? ?? '',
      uploadBytes: _asInt(json['uploadBytes']),
      downloadBytes: _asInt(json['downloadBytes']),
      connectCount: _asInt(json['connectCount']),
      totalDurationSeconds: _asInt(json['totalDurationSeconds']),
      lastUsedAt: json['lastUsedAt'] == null
          ? null
          : DateTime.tryParse(json['lastUsedAt'] as String),
      lastPingMs: json['lastPingMs'] as int?,
    );
  }

  static int _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }

    const List<String> units = <String>['KB', 'MB', 'GB', 'TB'];
    double value = bytes / 1024;
    int unitIndex = 0;

    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }

    return '${value.toStringAsFixed(value >= 100 ? 0 : 1)} ${units[unitIndex]}';
  }

  static String formatDuration(int seconds) {
    if (seconds <= 0) {
      return '0s';
    }
    final int hours = seconds ~/ 3600;
    final int minutes = (seconds % 3600) ~/ 60;
    final int secs = seconds % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    if (minutes > 0) {
      return '${minutes}m ${secs}s';
    }
    return '${secs}s';
  }
}

/// معیارهای مرتب‌سازی لیست آمار پروکسی‌ها.
enum StatsSort {
  traffic,
  connects,
  duration,
  lastUsed,
  ping,
}

extension StatsSortX on StatsSort {
  /// کلید ذخیره‌سازی/سریال‌سازی (برای SharedPreferences).
  String get key {
    switch (this) {
      case StatsSort.traffic:
        return 'traffic';
      case StatsSort.connects:
        return 'connects';
      case StatsSort.duration:
        return 'duration';
      case StatsSort.lastUsed:
        return 'lastUsed';
      case StatsSort.ping:
        return 'ping';
    }
  }

  static StatsSort fromKey(String? key) {
    return StatsSort.values.firstWhere(
      (StatsSort value) => value.key == key,
      orElse: () => StatsSort.traffic,
    );
  }

  /// برچسب دوزبانه؛ [isFa] را از locale فعلی بده.
  String label(bool isFa) {
    switch (this) {
      case StatsSort.traffic:
        return isFa ? 'مصرف داده' : 'Traffic';
      case StatsSort.connects:
        return isFa ? 'تعداد اتصال' : 'Connections';
      case StatsSort.duration:
        return isFa ? 'مدت اتصال' : 'Duration';
      case StatsSort.lastUsed:
        return isFa ? 'آخرین استفاده' : 'Last used';
      case StatsSort.ping:
        return isFa ? 'پینگ' : 'Ping';
    }
  }

  /// مقایسه‌گر نزولی (بهترین/بیشترین اول). برای ping صعودی است.
  int compare(ProxyTraffic a, ProxyTraffic b) {
    switch (this) {
      case StatsSort.traffic:
        return b.totalBytes.compareTo(a.totalBytes);
      case StatsSort.connects:
        return b.connectCount.compareTo(a.connectCount);
      case StatsSort.duration:
        return b.totalDurationSeconds.compareTo(a.totalDurationSeconds);
      case StatsSort.lastUsed:
        final DateTime aDate =
            a.lastUsedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final DateTime bDate =
            b.lastUsedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      case StatsSort.ping:
        final int aPing = a.lastPingMs ?? 1 << 30;
        final int bPing = b.lastPingMs ?? 1 << 30;
        return aPing.compareTo(bPing);
    }
  }
}
