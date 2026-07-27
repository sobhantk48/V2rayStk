class VpnStats {
  const VpnStats({
    this.pingMs,
    this.downloadBps = 0,
    this.uploadBps = 0,
    this.totalDownload = 0,
    this.totalUpload = 0,
    this.location,
    this.duration = Duration.zero,
  });

  final int? pingMs;
  final int downloadBps;
  final int uploadBps;
  final int totalDownload;
  final int totalUpload;
  final String? location;
  final Duration duration;

  VpnStats copyWith({
    int? pingMs,
    int? downloadBps,
    int? uploadBps,
    int? totalDownload,
    int? totalUpload,
    String? location,
    Duration? duration,
  }) {
    return VpnStats(
      pingMs: pingMs ?? this.pingMs,
      downloadBps: downloadBps ?? this.downloadBps,
      uploadBps: uploadBps ?? this.uploadBps,
      totalDownload: totalDownload ?? this.totalDownload,
      totalUpload: totalUpload ?? this.totalUpload,
      location: location ?? this.location,
      duration: duration ?? this.duration,
    );
  }

  static VpnStats fromMap(Map<String, dynamic> map, Duration duration) {
    int asInt(Object? value) => value is num ? value.toInt() : 0;
    return VpnStats(
      pingMs: map['ping'] is num ? (map['ping'] as num).toInt() : null,
      downloadBps: asInt(map['downloadBps']),
      uploadBps: asInt(map['uploadBps']),
      totalDownload: asInt(map['totalDownload']),
      totalUpload: asInt(map['totalUpload']),
      location: map['location'] as String?,
      duration: duration,
    );
  }
}
