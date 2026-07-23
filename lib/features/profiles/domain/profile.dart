enum ProfileType {
  vmess,
  vless,
  trojan,
  shadowsocks,
  socks,
  http,
  wireguard,
  hysteria2,
  tuic,
  unknown,
}

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
  });

  final String id;
  final String name;
  final ProfileType type;
  final String rawConfig;
  final DateTime createdAt;
  final String? server;
  final int? port;
  final bool isActive;

  Profile copyWith({
    String? id,
    String? name,
    ProfileType? type,
    String? rawConfig,
    DateTime? createdAt,
    String? server,
    int? port,
    bool? isActive,
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
    };
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      name: json['name'] as String,
      type: _profileTypeFromString(json['type'] as String?),
      rawConfig: json['rawConfig'] as String? ?? '',
      createdAt: json['createdAt'] == null
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.parse(json['createdAt'] as String),
      server: json['server'] as String?,
      port: json['port'] as int?,
      isActive: json['isActive'] as bool? ?? false,
    );
  }

  static ProfileType _profileTypeFromString(String? value) {
    for (final ProfileType type in ProfileType.values) {
      if (type.name == value) {
        return type;
      }
    }
    return ProfileType.unknown;
  }
}
