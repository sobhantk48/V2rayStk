import 'profile_type.dart';

/// مدل یک کانفیگ/پروکسی.
/// - [groupId] برای «مدیریت گروه‌ها» (null = گروه پیش‌فرض)
/// - [subscriptionUrl] برای پروفایل‌هایی که از Subscription آمده‌اند
/// - [latencyMs] آخرین پینگ اندازه‌گیری‌شده (Ping All)
/// - [uploadBytes]/[downloadBytes] آمار مصرف هر پروکسی
class Profile {
  const Profile({
    required this.id,
    required this.name,
    required this.type,
    required this.rawConfig,
    required this.createdAt,
    this.server,
    this.port,
    this.isActive = false,
    this.groupId,
    this.subscriptionUrl,
    this.latencyMs,
    this.uploadBytes = 0,
    this.downloadBytes = 0,
    this.sortIndex = 0,
  });

  final String id;
  final String name;
  final ProfileType type;
  final String rawConfig;
  final DateTime createdAt;
  final String? server;
  final int? port;
  final bool isActive;
  final String? groupId;
  final String? subscriptionUrl;
  final int? latencyMs;
  final int uploadBytes;
  final int downloadBytes;
  final int sortIndex;

  bool get isFromSubscription =>
      subscriptionUrl != null && subscriptionUrl!.trim().isNotEmpty;

  int get totalBytes => uploadBytes + downloadBytes;

  /// «vless · 1.2.3.4:443»
  String get subtitle {
    final String host = server ?? '-';
    final String p = port == null ? '' : ':$port';
    return '${type.label} · $host$p';
  }

  Profile copyWith({
    String? id,
    String? name,
    ProfileType? type,
    String? rawConfig,
    DateTime? createdAt,
    String? server,
    int? port,
    bool? isActive,
    String? groupId,
    bool clearGroupId = false,
    String? subscriptionUrl,
    bool clearSubscriptionUrl = false,
    int? latencyMs,
    bool clearLatency = false,
    int? uploadBytes,
    int? downloadBytes,
    int? sortIndex,
  }) {
    return Profile(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      rawConfig: rawConfig ?? this.rawConfig,
      createdAt: createdAt ?? this.createdAt,
      server: server ?? this.server,
      port: port ?? this.port,
      isActive: isActive ?? this.isActive,
      groupId: clearGroupId ? null : (groupId ?? this.groupId),
      subscriptionUrl:
          clearSubscriptionUrl ? null : (subscriptionUrl ?? this.subscriptionUrl),
      latencyMs: clearLatency ? null : (latencyMs ?? this.latencyMs),
      uploadBytes: uploadBytes ?? this.uploadBytes,
      downloadBytes: downloadBytes ?? this.downloadBytes,
      sortIndex: sortIndex ?? this.sortIndex,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'type': type.name,
      'rawConfig': rawConfig,
      'createdAt': createdAt.toIso8601String(),
      'server': server,
      'port': port,
      'isActive': isActive,
      'groupId': groupId,
      'subscriptionUrl': subscriptionUrl,
      'latencyMs': latencyMs,
      'uploadBytes': uploadBytes,
      'downloadBytes': downloadBytes,
      'sortIndex': sortIndex,
    };
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unnamed profile',
      type: ProfileTypeX.fromName(json['type'] as String?),
      rawConfig: json['rawConfig'] as String? ?? '',
      createdAt: _parseDate(json['createdAt']),
      server: json['server'] as String?,
      port: _parseInt(json['port']),
      isActive: json['isActive'] as bool? ?? false,
      groupId: json['groupId'] as String?,
      subscriptionUrl: json['subscriptionUrl'] as String?,
      latencyMs: _parseInt(json['latencyMs']),
      uploadBytes: _parseInt(json['uploadBytes']) ?? 0,
      downloadBytes: _parseInt(json['downloadBytes']) ?? 0,
      sortIndex: _parseInt(json['sortIndex']) ?? 0,
    );
  }

  static DateTime _parseDate(Object? value) {
    if (value is String) {
      return DateTime.tryParse(value) ??
          DateTime.fromMillisecondsSinceEpoch(0);
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static int? _parseInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is Profile && other.id == id && other.rawConfig == rawConfig;

  @override
  int get hashCode => Object.hash(id, rawConfig);
}
