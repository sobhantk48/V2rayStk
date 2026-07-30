import 'profile_type.dart';

/// نگهبان (sentinel) برای تشخیص «مقدار داده نشده» از «مقدار null».
const Object _unset = Object();

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
    this.subscriptionId,
  });

  final String id;
  final String name;
  final ProfileType type;
  final String rawConfig;
  final DateTime createdAt;
  final String? server;
  final int? port;
  final bool isActive;

  /// شناسهٔ گروهی که این پروفایل داخلش است. null = بدون گروه.
  final String? groupId;

  /// شناسهٔ اشتراکی که این پروفایل از آن وارد شده. null = دستی.
  final String? subscriptionId;

  Profile copyWith({
    String? id,
    String? name,
    ProfileType? type,
    String? rawConfig,
    DateTime? createdAt,
    Object? server = _unset,
    Object? port = _unset,
    bool? isActive,
    Object? groupId = _unset,
    Object? subscriptionId = _unset,
    bool clearGroup = false,
    bool clearSubscription = false,
  }) {
    return Profile(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      rawConfig: rawConfig ?? this.rawConfig,
      createdAt: createdAt ?? this.createdAt,
      server: server == _unset ? this.server : server as String?,
      port: port == _unset ? this.port : port as int?,
      isActive: isActive ?? this.isActive,
      groupId: clearGroup
          ? null
          : (groupId == _unset ? this.groupId : groupId as String?),
      subscriptionId: clearSubscription
          ? null
          : (subscriptionId == _unset
              ? this.subscriptionId
              : subscriptionId as String?),
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
      'subscriptionId': subscriptionId,
    };
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unnamed profile',
      type: ProfileTypeX.fromName(json['type'] as String?),
      rawConfig: json['rawConfig'] as String? ?? '',
      createdAt: json['createdAt'] == null
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.parse(json['createdAt'] as String),
      server: json['server'] as String?,
      port: _parsePort(json['port']),
      isActive: json['isActive'] as bool? ?? false,
      groupId: json['groupId'] as String?,
      subscriptionId: json['subscriptionId'] as String?,
    );
  }

  static int? _parsePort(Object? value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is String) {
      return int.tryParse(value);
    }

    return null;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is Profile &&
        other.id == id &&
        other.name == name &&
        other.type == type &&
        other.rawConfig == rawConfig &&
        other.createdAt == createdAt &&
        other.server == server &&
        other.port == port &&
        other.isActive == isActive &&
        other.groupId == groupId &&
        other.subscriptionId == subscriptionId;
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        type,
        rawConfig,
        createdAt,
        server,
        port,
        isActive,
        groupId,
        subscriptionId,
      );
}
