import 'profile_type.dart';

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

  /// شناسه گروه؛ null یعنی «بدون گروه».
  final String? groupId;

  /// اگر پروفایل از یک لینک اشتراک آمده باشد، شناسه آن اشتراک.
  final String? subscriptionId;

  bool get hasGroup => groupId != null && groupId!.isNotEmpty;

  bool get isFromSubscription =>
      subscriptionId != null && subscriptionId!.isNotEmpty;

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
    String? subscriptionId,
    bool clearGroup = false,
    bool clearSubscription = false,
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
      groupId: clearGroup ? null : (groupId ?? this.groupId),
      subscriptionId:
          clearSubscription ? null : (subscriptionId ?? this.subscriptionId),
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
      groupId: _parseNullableString(json['groupId']),
      subscriptionId: _parseNullableString(json['subscriptionId']),
    );
  }

  static String? _parseNullableString(Object? value) {
    if (value is String && value.isNotEmpty) {
      return value;
    }
    return null;
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
  bool operator ==(Object other) =>
      identical(this, other) || (other is Profile && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
