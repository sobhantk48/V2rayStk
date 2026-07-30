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
    final int h = seconds ~/ 3600;
    final int m = (seconds % 3600) ~/ 60;
    final int s = seconds % 60;

    if (h > 0) {
      return '${h}h ${m}m';
    }
    if (m > 0) {
      return '${m}m ${s}s';
    }
    return '${s}s';
  }
}
